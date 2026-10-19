import 'dart:convert';

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

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  SupabaseClient? _client;
  AuthMFAEnrollResponse? _enrollment;
  Factor? _factor;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _companies = [];
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _busy = false;
  bool _eligible = false;
  bool _mfaReady = false;
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

  Future<dynamic> _request(String path) async {
    final token = _client?.auth.currentSession?.accessToken;
    if (token == null) throw const _MasterFailure('Entre novamente para continuar.');
    final response = await http.get(Uri.parse('$_api$path'), headers: {
      'accept': 'application/json', 'authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode == 403) {
      throw const _MasterFailure('Esta conta não tem permissão para acessar o Master ou precisa confirmar o segundo fator.');
    }
    if (response.statusCode == 503) {
      throw const _MasterFailure('O acesso Master ainda não foi configurado no servidor.');
    }
    if (response.statusCode != 200) {
      throw _MasterFailure('Não foi possível carregar os dados (${response.statusCode}).');
    }
    return jsonDecode(response.body);
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _client?.auth.currentSession != null;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FF),
      appBar: AppBar(
        backgroundColor: _graphite, foregroundColor: Colors.white,
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
                  _heading('Visão da plataforma', 'Dados reais da homologação · acesso protegido por MFA'),
                  const SizedBox(height: 20),
                  if (_overview != null) _metrics(width),
                  const SizedBox(height: 24),
                  SegmentedButton<int>(segments: const [
                    ButtonSegment(value: 0, label: Text('Empresas'), icon: Icon(Icons.storefront_outlined)),
                    ButtonSegment(value: 1, label: Text('Governança'), icon: Icon(Icons.security_outlined)),
                  ], selected: {_tab}, onSelectionChanged: (values) =>
                      setState(() => _tab = values.first)),
                  const SizedBox(height: 18),
                  if (_tab == 0) _companyList() else _governance(),
                ],
              ]))),
    );
  }

  Widget _message(String text, {bool error = false}) => Card(
    color: error ? const Color(0xFFFFE7E7) : const Color(0xFFE4EDFF),
    child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Icon(error ? Icons.error_outline : Icons.info_outline,
          color: error ? const Color(0xFFB42318) : _blue),
      const SizedBox(width: 12), Expanded(child: Text(text)),
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
          (width - 50) / 2 : 250, child: Card(child: Padding(
            padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(value.$3, color: _blue), const SizedBox(height: 15),
                Text('${value.$2}', style: const TextStyle(fontSize: 29,
                    fontWeight: FontWeight.w800, color: _graphite)),
                Text(value.$1, style: const TextStyle(color: Color(0xFF64748B))),
              ],
            )))),
    ]);
  }

  Widget _companyList() => Card(child: Padding(
    padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Empresas cadastradas', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Somente leitura até o fluxo de convites e ações auditadas estar pronto.'),
        const Divider(height: 30),
        if (_companies.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('Nenhuma empresa cadastrada nesta homologação.'))),
        for (final company in _companies) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(backgroundColor: Color(0xFFE4EDFF),
              child: Icon(Icons.storefront_outlined, color: _blue)),
          title: Text(company['name'] as String),
          subtitle: Text('${company['branches']} filial(is) · ${company['status']}'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    )),
  );

  Widget _governance() => Card(child: Padding(
    padding: const EdgeInsets.all(22), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('Acesso protegido', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w700)),
        SizedBox(height: 10),
        Text('Este painel exige conta autorizada e autenticação em dois fatores.'),
        SizedBox(height: 18),
        Text('Convites, suspensão de empresas e comissões exigem registro de auditoria, '
            'configuração de envio de e-mail e validação do banco antes de serem habilitados.'),
      ],
    )),
  );
}

class _MasterFailure implements Exception {
  const _MasterFailure(this.message);
  final String message;
}
