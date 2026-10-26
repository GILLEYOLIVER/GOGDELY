import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hosted Master. It never opens the local demo or displays simulated metrics.
class OnlineMasterShell extends StatefulWidget {
  const OnlineMasterShell({super.key});

  @override
  State<OnlineMasterShell> createState() => _OnlineMasterShellState();
}

class _OnlineMasterShellState extends State<OnlineMasterShell> {
  static const _api = String.fromEnvironment('GOGDELY_API_BASE_URL');
  static const _blue = Color(0xFF2563EB);
  static const _graphite = Color(0xFF151B2B);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFDCE4F2);

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  SupabaseClient? _client;
  AuthMFAEnrollResponse? _enrollment;
  Factor? _factor;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _audit = [];
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _busy = false;
  bool _eligible = false;
  bool _mfaReady = false;
  bool _adminReady = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<dynamic> _request(String path, {String method = 'GET', Object? body}) async {
    final token = _client?.auth.currentSession?.accessToken;
    if (token == null) throw const _MasterFailure('Entre novamente para continuar.');
    final headers = {
      'accept': 'application/json', 'authorization': 'Bearer $token',
      if (body != null) 'content-type': 'application/json',
    };
    final uri = Uri.parse('$_api$path');
    final response = await (method == 'POST'
        ? http.post(uri, headers: headers, body: jsonEncode(body))
        : method == 'PATCH'
            ? http.patch(uri, headers: headers, body: jsonEncode(body))
            : http.get(uri, headers: headers)).timeout(const Duration(seconds: 15));
    if (response.statusCode == 403) {
      throw const _MasterFailure('Esta conta não tem permissão para acessar o Master ou precisa confirmar o segundo fator.');
    }
    if (response.statusCode == 503) {
      throw const _MasterFailure('A administração ainda não está disponível no banco de homologação.');
    }
    if (response.statusCode == 409) {
      final detail = (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
      throw _MasterFailure(detail == 'An owner must accept the invitation before activation'
          ? 'A empresa precisa de um responsável vinculado antes de ser ativada.'
          : 'Este endereço ou pedido já existe. Atualize a lista antes de tentar novamente.');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _MasterFailure('Não foi possível concluir a operação (${response.statusCode}).');
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  String _requestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _bootstrap() async {
    try {
      if (!_api.startsWith('https://')) {
        throw const _MasterFailure('A API online não foi configurada.');
      }
      final result = await http.get(Uri.parse('$_api/api/v1/client-config'))
          .timeout(const Duration(seconds: 15));
      if (result.statusCode != 200) {
        throw const _MasterFailure('A autenticação online está indisponível.');
      }
      final config = jsonDecode(result.body) as Map<String, dynamic>;
      await Supabase.initialize(
        url: config['supabase_url'] as String,
        publishableKey: config['supabase_publishable_key'] as String,
      );
      _client = Supabase.instance.client;
      if (_client!.auth.currentSession != null) await _resume();
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível iniciar o Master. Confira a conexão e tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    if (_client == null || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _client!.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text,
      );
      _password.clear();
      await _resume();
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível entrar. Confira os dados e a autorização da conta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    await _request('/api/v1/master/eligibility');
    if (!mounted) return;
    setState(() => _eligible = true);
    final level = _client!.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;
    if (level == AuthenticatorAssuranceLevels.aal2) {
      setState(() => _mfaReady = true);
      await _refresh();
      return;
    }
    final factors = await _client!.auth.mfa.listFactors();
    if (!mounted) return;
    setState(() {
      _factor = factors.totp.isEmpty ? null : factors.totp.first;
      _mfaReady = false;
    });
  }

  Future<void> _enroll() async {
    if (_client == null || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final enrollment = await _client!.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'GOGDELY',
        friendlyName: 'GOGDELY Master',
      );
      if (mounted) setState(() => _enrollment = enrollment);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível iniciar o segundo fator.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyMfa() async {
    final factorId = _enrollment?.id ?? _factor?.id;
    if (_client == null || factorId == null || _busy) return;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Digite o código de seis números do autenticador.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _client!.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
      _code.clear();
      if (mounted) setState(() { _enrollment = null; _mfaReady = true; });
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Código inválido ou expirado. Gere um novo código no autenticador.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_client == null || !_mfaReady) return;
    setState(() { _busy = true; _error = null; });
    try {
      final results = await Future.wait([
        _request('/api/v1/master/overview'),
        _request('/api/v1/master/companies'),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as Map<String, dynamic>;
          _companies = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
        });
      }
      try {
        final events = await _request('/api/v1/master/audit') as List<dynamic>;
        if (mounted) {
          setState(() {
            _audit = events.cast<Map<String, dynamic>>();
            _adminReady = true;
          });
        }
      } on _MasterFailure {
        if (mounted) setState(() { _audit = []; _adminReady = false; });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is _MasterFailure
            ? error.message : 'Não foi possível atualizar os dados do Master.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await _client?.auth.signOut();
    if (mounted) {
      setState(() {
        _eligible = false; _mfaReady = false; _enrollment = null;
        _factor = null; _overview = null; _companies = []; _error = null;
        _audit = []; _adminReady = false; _notice = null;
      });
    }
  }

  Future<void> _createCompany() async {
    if (!_adminReady || _busy) return;
    final name = TextEditingController();
    final branch = TextEditingController();
    final slug = TextEditingController();
    final reason = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(title: const Text('Nova empresa'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Text('A empresa começa como rascunho e não aparece para clientes.'),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome da empresa')),
              const SizedBox(height: 12),
              TextField(controller: branch, decoration: const InputDecoration(labelText: 'Nome da primeira loja')),
              const SizedBox(height: 12),
              TextField(controller: slug, decoration: const InputDecoration(labelText: 'Endereço da loja', hintText: 'minha-loja')),
              const SizedBox(height: 12),
              TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo do cadastro')),
            ],
          ))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Criar rascunho')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      if (name.text.trim().length < 2 || branch.text.trim().length < 2 ||
          !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug.text.trim()) ||
          slug.text.trim().length < 3 || reason.text.trim().length < 8) {
        setState(() => _error = 'Informe empresa, loja, endereço válido e motivo com pelo menos 8 caracteres.');
        return;
      }
      await _runCommand(() => _request('/api/v1/master/companies', method: 'POST', body: {
        'request_id': _requestId(), 'name': name.text.trim(),
        'branch_name': branch.text.trim(), 'slug': slug.text.trim(),
        'reason': reason.text.trim(),
      }), 'Empresa criada como rascunho.');
    } finally {
      name.dispose(); branch.dispose(); slug.dispose(); reason.dispose();
    }
  }

  Future<void> _runCommand(Future<dynamic> Function() command, String success) async {
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await command();
      if (mounted) setState(() => _notice = success);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is _MasterFailure
            ? error.message : 'Não foi possível concluir a alteração.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> company) async {
    if (!_adminReady || _busy) return;
    final id = company['tenant_id'] as String;
    final current = company['status'] as String;
    final next = current == 'active' ? 'suspended' : 'active';
    final reason = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(title: Text(next == 'active' ? 'Ativar empresa?' : 'Suspender empresa?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${company['name']} · ${next == 'active' ? 'ficará visível quando houver loja e cardápio ativos.' : 'deixará de aparecer no catálogo público.'}'),
            const SizedBox(height: 16),
            TextField(controller: reason, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Motivo obrigatório')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: Text(next == 'active' ? 'Ativar' : 'Suspender')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      if (reason.text.trim().length < 8) {
        setState(() => _error = 'Informe um motivo com pelo menos 8 caracteres.');
        return;
      }
      await _runCommand(() => _request('/api/v1/master/companies/$id/status',
        method: 'PATCH', body: {'request_id': _requestId(), 'status': next,
          'reason': reason.text.trim()}),
        next == 'active' ? 'Empresa ativada.' : 'Empresa suspensa.');
    } finally { reason.dispose(); }
  }

  Future<void> _linkOwner(Map<String, dynamic> company) async {
    if (!_adminReady || _busy) return;
    final id = company['tenant_id'] as String;
    final email = TextEditingController();
    final reason = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(title: const Text('Vincular responsável'),
          content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Use uma conta Supabase já confirmada. Esta ação não envia convite.'),
              const SizedBox(height: 16),
              TextField(controller: email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail da conta confirmada')),
              const SizedBox(height: 12),
              TextField(controller: reason, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motivo do vínculo')),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Vincular')),
          ],
        ));
      if (confirmed != true || !mounted) return;
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim()) ||
          reason.text.trim().length < 8) {
        setState(() => _error = 'Informe um e-mail válido e um motivo com pelo menos 8 caracteres.');
        return;
      }
      await _runCommand(() => _request('/api/v1/master/companies/$id/owner',
        method: 'POST', body: {'request_id': _requestId(),
          'email': email.text.trim().toLowerCase(), 'reason': reason.text.trim()}),
        'Responsável vinculado à empresa.');
    } finally { email.dispose(); reason.dispose(); }
  }

  Future<void> _editCommission(Map<String, dynamic> company) async {
    if (!_adminReady || _busy) return;
    final id = company['tenant_id'] as String;
    Map<String, dynamic> policy;
    try {
      policy = (await _request('/api/v1/master/companies/$id/commission')) as Map<String, dynamic>;
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is _MasterFailure
            ? error.message : 'Não foi possível consultar a comissão.');
      }
      return;
    }
    if (!mounted) return;
    final percentage = TextEditingController(text: '${policy['percentage']}');
    final reason = TextEditingController();
    var enabled = policy['enabled'] == true;
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
        StatefulBuilder(builder: (context, redraw) => AlertDialog(
          title: Text('Comissão · ${company['name']}'),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              const Text('Esta configuração não realiza cobrança ou repasse automático.'),
              const SizedBox(height: 12),
              SwitchListTile(title: const Text('Configuração ativa'), value: enabled,
                onChanged: (value) => redraw(() => enabled = value)),
              TextField(controller: percentage, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Percentual sobre produtos', suffixText: '%')),
              const SizedBox(height: 12),
              TextField(controller: reason, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motivo da alteração')),
            ],
          ))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar política')),
          ],
        )));
      if (confirmed != true || !mounted) return;
      final rate = double.tryParse(percentage.text.trim().replaceAll(',', '.'));
      if (rate == null || rate < 0 || rate > 100 ||
          (rate * 100).roundToDouble() != rate * 100 || reason.text.trim().length < 8) {
        setState(() => _error = 'Informe percentual entre 0 e 100 com até duas casas e um motivo válido.');
        return;
      }
      await _runCommand(() => _request('/api/v1/master/companies/$id/commission',
        method: 'PATCH', body: {'request_id': _requestId(), 'enabled': enabled,
          'percentage': rate.toStringAsFixed(2), 'reason': reason.text.trim()}),
        'Política de comissão salva e registrada na auditoria.');
    } finally { percentage.dispose(); reason.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _client?.auth.currentSession != null;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: _graphite,
        surfaceTintColor: Colors.white, scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: _border)),
        title: const Text('gogdely.  Master', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_mfaReady) IconButton(onPressed: _busy ? null : _refresh,
              tooltip: 'Atualizar', icon: const Icon(Icons.refresh)),
          if (signedIn) IconButton(onPressed: _signOut,
              tooltip: 'Sair', icon: const Icon(Icons.logout_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(padding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 18 : 32, vertical: 28,
              ), children: [
                if (_error != null) _message(_error!, error: true),
                if (_notice != null) _message(_notice!),
                if (!signedIn) _loginCard(),
                if (signedIn && !_eligible) _message(
                    'Esta conta ainda não foi habilitada para administrar a plataforma.'),
                if (signedIn && _eligible && !_mfaReady) _mfaCard(),
                if (signedIn && _mfaReady) ...[
                  _heading('Sua plataforma', 'GOGDELY Homologação · sessão protegida'),
                  const SizedBox(height: 20),
                  if (_overview != null) _metrics(width),
                  const SizedBox(height: 24),
                  if (!_adminReady) ...[
                    _message('A visão geral está disponível. Ações de cadastro e gestão aguardam a migração auditada do banco.'),
                    const SizedBox(height: 12),
                  ],
                  SegmentedButton<int>(segments: const [
                    ButtonSegment(value: 0, label: Text('Empresas'), icon: Icon(Icons.storefront_outlined)),
                    ButtonSegment(value: 1, label: Text('Auditoria'), icon: Icon(Icons.history_outlined)),
                  ], selected: {_tab}, onSelectionChanged: (values) =>
                      setState(() => _tab = values.first)),
                  const SizedBox(height: 18),
                  if (_tab == 0) _companyList() else _governance(),
                ],
              ]))),
    );
  }

  Widget _message(String text, {bool error = false}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFE8E7) : const Color(0xFFE8F0FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: error ? const Color(0xFFF7B8B4) : const Color(0xFFBED4FF)),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Icon(error ? Icons.error_outline : Icons.info_outline,
          color: error ? const Color(0xFFB42318) : _blue),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(color: _graphite))),
      if (!error) IconButton(
        onPressed: () => setState(() => _notice = null),
        tooltip: 'Dispensar aviso', icon: const Icon(Icons.close, color: _graphite),
      ),
    ])),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
          color: _graphite)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
    ],
  );

  Widget _loginCard() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 460),
    child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.admin_panel_settings_outlined, color: _blue, size: 48),
        const SizedBox(height: 14),
        const Text('Administração da plataforma', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Acesso restrito ao proprietário com segundo fator de segurança.',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
            decoration: const InputDecoration(labelText: 'Senha')),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _signIn,
            child: Text(_busy ? 'Verificando…' : 'Entrar com segurança')),
      ],
    ))),
  ));

  Widget _mfaCard() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.verified_user_outlined, color: _blue, size: 44),
        const SizedBox(height: 12),
        const Text('Confirme o segundo fator', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_factor == null && _enrollment == null) ...[
          const Text('Configure um aplicativo autenticador antes de acessar os dados da plataforma.'),
          const SizedBox(height: 18),
          FilledButton(onPressed: _busy ? null : _enroll,
              child: const Text('Configurar autenticador')),
        ],
        if (_enrollment?.totp != null) ...[
          const Text('Adicione esta chave no seu aplicativo autenticador. Ela aparece apenas nesta etapa.'),
          const SizedBox(height: 12),
          SelectableText(_enrollment!.totp!.secret,
              style: const TextStyle(fontSize: 18, letterSpacing: 2,
                  fontWeight: FontWeight.w700)),
          TextButton.icon(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _enrollment!.totp!.secret));
            if (mounted) setState(() => _notice = 'Chave copiada. Guarde-a apenas no aplicativo autenticador.');
          }, icon: const Icon(Icons.copy), label: const Text('Copiar chave')),
        ],
        if (_factor != null || _enrollment != null) ...[
          const SizedBox(height: 12),
          TextField(controller: _code, keyboardType: TextInputType.number,
              maxLength: 6, decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
              onSubmitted: (_) => _verifyMfa()),
          FilledButton(onPressed: _busy ? null : _verifyMfa,
              child: Text(_busy ? 'Verificando…' : 'Confirmar código')),
        ],
      ],
    ))),
  ));

  Widget _metrics(double width) {
    final values = [
      ('Empresas', _overview!['companies'], Icons.storefront_outlined),
      ('Ativas', _overview!['active_companies'], Icons.verified_outlined),
      ('Filiais', _overview!['branches'], Icons.hub_outlined),
      ('Pedidos', _overview!['orders'], Icons.receipt_long_outlined),
    ];
    return Wrap(spacing: 14, runSpacing: 14, children: [
      for (final value in values) SizedBox(width: width < 660 ?
          (width - 50) / 2 : 250, child: Container(
            decoration: BoxDecoration(color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(20)),
            child: Padding(
            padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(value.$3, color: _blue)),
                const SizedBox(height: 18),
                Text('${value.$2}', style: const TextStyle(fontSize: 29,
                    fontWeight: FontWeight.w800, color: _graphite)),
                Text(value.$1, style: const TextStyle(color: _muted)),
              ],
            )))),
    ]);
  }

  Widget _companyList() => Card(child: Padding(
    padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Empresas', style: TextStyle(fontSize: 21,
              fontWeight: FontWeight.w800, color: _graphite))),
          FilledButton.icon(onPressed: _adminReady && !_busy ? _createCompany : null,
            icon: const Icon(Icons.add), label: const Text('Nova')),
        ]),
        const SizedBox(height: 8),
        Text('${_companies.length} cadastrada(s) · gestão com MFA e motivo registrado',
          style: const TextStyle(color: _muted)),
        const Divider(height: 30),
        if (_companies.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Column(children: [
              Icon(Icons.storefront_outlined, size: 42, color: _muted),
              SizedBox(height: 10),
              Text('Nenhuma empresa cadastrada nesta homologação.'),
            ]))),
        for (final company in _companies) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F0FF),
                child: Icon(Icons.storefront_outlined, color: _blue)),
            title: Text(company['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${company['branches']} filial(is) · ${company['owners']} responsável(is) · ${company['status']}'),
            trailing: _adminReady ? PopupMenuButton<String>(
              tooltip: 'Gerenciar empresa',
              onSelected: (action) {
                if (action == 'owner') { _linkOwner(company); }
                else if (action == 'status') { _changeStatus(company); }
                else { _editCommission(company); }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'owner',
                  enabled: company['status'] == 'draft' && (company['owners'] as int? ?? 0) == 0,
                  child: const Text('Vincular responsável')),
                PopupMenuItem(value: 'status',
                  enabled: company['status'] == 'active' || (company['owners'] as int? ?? 0) > 0,
                  child: Text(company['status'] == 'active'
                    ? 'Suspender empresa' : 'Ativar (após vincular responsável)')),
                const PopupMenuItem(value: 'commission', child: Text('Configurar comissão')),
              ],
            ) : null,
          ),
          const Divider(height: 1),
        ],
      ],
    )),
  );

  Widget _governance() => Card(child: Padding(
    padding: const EdgeInsets.all(22), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Histórico de alterações', style: TextStyle(fontSize: 21,
            fontWeight: FontWeight.w800, color: _graphite)),
        const SizedBox(height: 8),
        const Text('Ações administrativas registradas no banco com operador, motivo e horário.',
            style: TextStyle(color: _muted)),
        const Divider(height: 30),
        if (!_adminReady) const Text('Auditoria aguardando a migração do banco.'),
        if (_adminReady && _audit.isEmpty) const Text('Nenhuma alteração registrada.'),
        for (final event in _audit) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined, color: _blue),
          title: Text(event['action'] as String),
          subtitle: Text('${event['reason']} · ${event['created_at']}'),
        ),
        const SizedBox(height: 16),
        const Text('Convites por e-mail e cobrança automática permanecem indisponíveis até a configuração do envio e do provedor financeiro.',
          style: TextStyle(color: _muted)),
      ],
    )),
  );
}

class _MasterFailure implements Exception {
  const _MasterFailure(this.message);
  final String message;
}
