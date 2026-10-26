import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'online_qr_print_stub.dart'
    if (dart.library.html) 'online_qr_print_web.dart' as qr_print;

/// Hosted management entry point. Never uses the local demo's fake orders.
class OnlineManagementShell extends StatefulWidget {
  const OnlineManagementShell({super.key});

  @override
  State<OnlineManagementShell> createState() => _OnlineManagementShellState();
}

class _OnlineManagementShellState extends State<OnlineManagementShell> {
  static const _api = String.fromEnvironment('GOGDELY_API_BASE_URL');
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  SupabaseClient? _client;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _branch;
  bool _allowTablePayment = false;
  bool _tablePaymentAvailable = false;
  bool _tableSettingsLoaded = false;
  Map<String, dynamic>? _tableQr;
  int _tableNumber = 1;
  bool _loadingQr = false;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _couriers = [];
  Map<String, dynamic> _compensation = const {'mode': 'salary', 'fixed_cents': 0, 'percent': 0};
  Timer? _ordersTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _ordersTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_branch != null && !_busy) _loadOperations();
    });
  }

  @override
  void dispose() {
    _ordersTimer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<dynamic> _request(String path, {String method = 'GET', Object? body}) async {
    final token = _client?.auth.currentSession?.accessToken;
    final request = http.Request(method, Uri.parse('$_api$path'));
    request.headers.addAll({
        'accept': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        if (body != null) 'content-type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    final client = http.Client();
    late final http.Response result;
    try {
      result = await client.send(request).then(http.Response.fromStream);
    } finally {
      client.close();
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw Exception('A operação não foi concluída (${result.statusCode}).');
    }
    return jsonDecode(result.body);
  }

  Future<void> _bootstrap() async {
    try {
      if (!_api.startsWith('https://')) {
        throw Exception('A API de gestão online não foi configurada.');
      }
      final config = await http.get(Uri.parse('$_api/api/v1/client-config'));
      if (config.statusCode != 200) {
        throw Exception('A autenticação online está indisponível.');
      }
      final data = jsonDecode(config.body) as Map<String, dynamic>;
      await Supabase.initialize(
        url: data['supabase_url'] as String,
        publishableKey: data['supabase_publishable_key'] as String,
      );
      _client = Supabase.instance.client;
      if (_client!.auth.currentSession != null) await _loadStores();
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    if (_client == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _client!.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text,
      );
      _password.clear();
    } catch (_) {
      if (mounted) setState(() => _error = 'Confira seu e-mail, sua senha e seu convite.');
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await _loadStores();
    } catch (_) {
      if (mounted) setState(() => _error = 'A conta entrou, mas não foi possível carregar suas lojas.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadStores() async {
    final stores = await _request('/api/v1/auth/memberships') as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _stores = stores.cast<Map<String, dynamic>>();
      _branch = null;
      _items = [];
    });
    for (final store in _stores) {
      final branches = store['branches'] as List<dynamic>;
      if (branches.isNotEmpty) {
        await _selectBranch({
          'tenant_id': store['tenant_id'], 'tenant_name': store['name'],
          'role': store['role'], ...branches.first as Map<String, dynamic>,
        });
        break;
      }
    }
  }

  Future<void> _selectBranch(Map<String, dynamic> branch) async {
    setState(() { _busy = true; _error = null; _tableQr = null;
      _tableSettingsLoaded = false; });
    try {
      final tenant = branch['tenant_id'];
      final id = branch['branch_id'];
      final catalog = await _request(
        '/api/v1/management/tenants/$tenant/branches/$id/catalog',
      ) as Map<String, dynamic>;
      if (mounted) setState(() {
        _branch = {...branch, 'slug': catalog['slug']};
        _items = (catalog['items'] as List<dynamic>).cast<Map<String, dynamic>>();
      });
      await _loadOperations();
      try {
        final settings = await _request(
          '/api/v1/management/tenants/$tenant/branches/$id/table-payment',
        ) as Map<String, dynamic>;
        if (mounted) setState(() {
          _allowTablePayment = settings['allow_online_payment'] == true;
          _tablePaymentAvailable = settings['online_payment_available'] == true;
          _tableSettingsLoaded = true;
        });
      } catch (_) {
        if (mounted) setState(() => _tableSettingsLoaded = false);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível carregar o cardápio desta loja.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadOperations() async {
    final branch = _branch;
    if (branch == null) return;
    final path = '/api/v1/management/tenants/${branch['tenant_id']}'
        '/branches/${branch['branch_id']}';
    try {
      final orders = await _request('$path/orders') as List<dynamic>;
      if (mounted && _branch?['branch_id'] == branch['branch_id']) {
        setState(() => _orders = orders.cast<Map<String, dynamic>>());
      }
      if ({'owner', 'manager'}.contains(branch['role'])) {
        final couriers = await _request('$path/couriers') as List<dynamic>;
        final pay = await _request('$path/compensation') as Map<String, dynamic>;
        if (mounted && _branch?['branch_id'] == branch['branch_id']) {
          setState(() { _couriers = couriers.cast<Map<String, dynamic>>();
            _compensation = pay; });
        }
      }
    } catch (_) {
      // The catalog remains available if the test-order module is not deployed.
    }
  }

  Future<void> _advanceOrder(Map<String, dynamic> order) async {
    if (_branch == null) return;
    final before = order['status'] as String;
    final next = switch (before) {
      'created' => 'accepted',
      'accepted' => 'preparing',
      'preparing' => 'ready',
      'ready' when order['channel'] != 'delivery' => 'completed',
      _ => null,
    };
    final dispatch = before == 'ready' && order['channel'] == 'delivery';
    if (next == null && !dispatch) return;
    setState(() { _busy = true; _error = null; });
    try {
      final base = '/api/v1/management/tenants/${_branch!['tenant_id']}'
          '/branches/${_branch!['branch_id']}/orders/${order['order_id']}';
      await _request(dispatch ? '$base/dispatch' : '$base/status',
        method: dispatch ? 'POST' : 'PATCH',
        body: dispatch ? null : {'status': next});
      await _loadOperations();
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível atualizar o pedido fictício.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkCourier() async {
    if (_branch == null) return;
    final email = TextEditingController();
    final result = await showDialog<String>(context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular entregador de teste'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('A conta deve existir e estar confirmada no Supabase Auth.'),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail do entregador')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, email.text.trim()),
            child: const Text('Vincular'))],
      ));
    email.dispose();
    if (result == null || result.isEmpty || _branch == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _request('/api/v1/management/tenants/${_branch!['tenant_id']}'
          '/branches/${_branch!['branch_id']}/couriers',
          method: 'PUT', body: {'email': result, 'active': true});
      await _loadOperations();
    } catch (_) {
      if (mounted) setState(() => _error = 'Entregador não encontrado ou vínculo indisponível.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCourierActive(Map<String, dynamic> courier, bool active) async {
    if (_branch == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _request('/api/v1/management/tenants/${_branch!['tenant_id']}'
          '/branches/${_branch!['branch_id']}/couriers',
          method: 'PUT', body: {'email': courier['email'], 'active': active});
      await _loadOperations();
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível alterar o entregador.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCompensation() async {
    if (_branch == null) return;
    var mode = _compensation['mode'] as String? ?? 'salary';
    final fixed = TextEditingController(text: '${(_compensation['fixed_cents'] as num? ?? 0) / 100}');
    final percent = TextEditingController(text: '${_compensation['percent'] ?? 0}');
    final result = await showDialog<Map<String, dynamic>>(context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
        title: const Text('Pagamento fictício por entrega'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: mode,
            decoration: const InputDecoration(labelText: 'Modelo'),
            items: const [
              DropdownMenuItem(value: 'fixed', child: Text('Valor fixo')),
              DropdownMenuItem(value: 'percent', child: Text('Percentual do frete')),
              DropdownMenuItem(value: 'salary', child: Text('Contratado mensalmente · R\$ 0 no app')),
            ], onChanged: (value) => update(() => mode = value ?? 'salary')),
          if (mode == 'fixed') TextField(controller: fixed,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Valor por entrega (R\$)')),
          if (mode == 'percent') TextField(controller: percent,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Percentual do frete')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final cents = ((double.tryParse(fixed.text.replaceAll(',', '.')) ?? -1) * 100).round();
            final rate = double.tryParse(percent.text.replaceAll(',', '.')) ?? -1;
            if (mode == 'fixed' && cents < 0 || mode == 'percent' && (rate < 0 || rate > 100)) return;
            Navigator.pop(context, {'mode': mode,
              'fixed_cents': mode == 'fixed' ? cents : 0,
              'percent': mode == 'percent' ? rate : 0});
          }, child: const Text('Salvar'))],
      )));
    fixed.dispose(); percent.dispose();
    if (result == null || _branch == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _request('/api/v1/management/tenants/${_branch!['tenant_id']}'
          '/branches/${_branch!['branch_id']}/compensation',
          method: 'PUT', body: result);
      await _loadOperations();
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível salvar a remuneração fictícia.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(Object? cents) {
    final value = cents is num ? cents : 0;
    return 'R\$ ${(value / 100).toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _loadTableQr() async {
    if (_branch == null || _loadingQr) return;
    setState(() { _loadingQr = true; _error = null; });
    try {
      final data = await _request(
        '/api/v1/management/tenants/${_branch!['tenant_id']}'
        '/branches/${_branch!['branch_id']}/tables/$_tableNumber/qr',
      ) as Map<String, dynamic>;
      if (mounted) setState(() => _tableQr = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível gerar o QR da mesa.');
    } finally {
      if (mounted) setState(() => _loadingQr = false);
    }
  }

  Future<void> _setTablePayment(bool enabled) async {
    if (_branch == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final settings = await _request(
        '/api/v1/management/tenants/${_branch!['tenant_id']}'
        '/branches/${_branch!['branch_id']}/table-payment',
        method: 'PUT', body: {'allow_online_payment': enabled},
      ) as Map<String, dynamic>;
      if (mounted) setState(() {
        _allowTablePayment = settings['allow_online_payment'] == true;
        _tablePaymentAvailable = settings['online_payment_available'] == true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível salvar a opção de pagamento das mesas.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editItem([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name'] as String? ?? '');
    final description = TextEditingController(text: item?['description'] as String? ?? '');
    final category = TextEditingController(text: item?['category_name'] as String? ?? '');
    final price = TextEditingController(
      text: item == null ? '' : ((item['price_cents'] as int) / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    var available = item?['available'] as bool? ?? false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
        title: Text(item == null ? 'Novo produto' : 'Editar produto'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Categoria')),
            TextField(controller: price, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Preço (R\$)')),
            SwitchListTile(value: available,
                onChanged: (value) => update(() => available = value),
                title: const Text('Disponível para venda')),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final cents = (double.tryParse(price.text.replaceAll(',', '.')) ?? -1) * 100;
            if (name.text.trim().isEmpty || category.text.trim().isEmpty || cents < 0) return;
            Navigator.pop(context, {
              'name': name.text.trim(), 'description': description.text.trim(),
              'category_name': category.text.trim(), 'price_cents': cents.round(),
              'available': available, 'sort_order': item?['sort_order'] ?? 0,
              'image_path': item?['image_path'],
              if (item != null) 'expected_updated_at': item['updated_at'],
            });
          }, child: const Text('Salvar')),
        ],
      )),
    );
    name.dispose(); description.dispose(); category.dispose(); price.dispose();
    if (result == null || _branch == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final base = '/api/v1/management/tenants/${_branch!['tenant_id']}'
          '/branches/${_branch!['branch_id']}/catalog';
      await _request(item == null ? base : '$base/${item['item_id']}',
          method: item == null ? 'POST' : 'PUT', body: result);
      await _selectBranch(_branch!);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível salvar. Atualize o cardápio e tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final signedIn = _client?.auth.currentSession != null;
    return Scaffold(
      appBar: AppBar(title: const Text('GOGDELY Gestão'), actions: [
        if (signedIn) IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout),
            onPressed: () async {
              await _client!.auth.signOut();
              if (mounted) setState(() { _stores = []; _branch = null; _items = []; });
            }),
      ]),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (_error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!))),
          if (!signedIn && _client != null) Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Acesse sua loja', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Use o e-mail do convite e a senha da sua conta.'),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: _password, obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Senha')),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _signIn, child: const Text('Entrar')),
            ]),
          )),
          if (signedIn) ...[
            Text('Sua operação', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (_stores.isEmpty) const Card(child: Padding(
              padding: EdgeInsets.all(20), child: Text('Sua conta ainda não foi vinculada a uma loja.'),
            )),
            if (_stores.isNotEmpty) DropdownButtonFormField<String>(
              initialValue: _branch?['branch_id'] as String?,
              decoration: const InputDecoration(labelText: 'Loja'),
              items: [for (final store in _stores)
                for (final branch in store['branches'] as List<dynamic>)
                  DropdownMenuItem(value: branch['branch_id'] as String,
                    child: Text('${store['name']} · ${branch['name']}'))],
              onChanged: _busy ? null : (value) {
                for (final store in _stores) {
                  for (final branch in store['branches'] as List<dynamic>) {
                    if (branch['branch_id'] == value) {
                      _selectBranch({'tenant_id': store['tenant_id'],
                        'tenant_name': store['name'], 'role': store['role'],
                        ...branch as Map<String, dynamic>});
                    }
                  }
                }
              },
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_branch != null) ...[
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Painel de teste', style: Theme.of(context).textTheme.titleLarge),
                  const Text('Dados fictícios da loja. Nenhuma venda é cobrada.'),
                  const SizedBox(height: 12),
                  Wrap(spacing: 18, runSpacing: 10, children: [
                    Text('${_orders.length} pedidos'),
                    Text('${_orders.where((order) => order['status'] == 'completed').length} concluídos'),
                    Text('Total concluído: ${_money(_orders.where((order) => order['status'] == 'completed').fold<int>(0, (sum, order) => sum + (order['total_cents'] as int? ?? 0)))}'),
                  ]),
                  TextButton.icon(onPressed: _loadOperations,
                    icon: const Icon(Icons.refresh), label: const Text('Atualizar pedidos')),
                ],
              ))),
              const SizedBox(height: 16),
              Text('Pedidos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_orders.isEmpty) const Card(child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum pedido fictício recebido ainda. Abra o Cliente e escolha produtos desta loja.'),
              )),
              for (final order in _orders) Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(padding: const EdgeInsets.all(12), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Pedido #${(order['order_id'] as String).substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleMedium),
                    Text('${order['channel']} · ${order['status']} · ${_money(order['total_cents'])}'),
                    if (order['table_code'] != null) Text('Mesa ${order['table_code']}'),
                    if ({'created', 'accepted', 'preparing', 'ready'}.contains(order['status']) &&
                        (order['status'] != 'ready' || order['channel'] != 'delivery' ||
                         {'owner', 'manager'}.contains(_branch!['role'])))
                      Align(alignment: Alignment.centerRight, child: FilledButton(
                        onPressed: _busy ? null : () => _advanceOrder(order),
                        child: Text(switch (order['status']) {
                          'created' => 'Aceitar',
                          'accepted' => 'Iniciar preparo',
                          'preparing' => 'Marcar pronto',
                          'ready' when order['channel'] == 'delivery' => 'Oferecer ao entregador',
                          _ => 'Concluir',
                        }),
                      )),
                  ],
                )),
              ),
              if ({'owner', 'manager'}.contains(_branch!['role'])) ...[
                const SizedBox(height: 16),
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Entregadores da loja', style: Theme.of(context).textTheme.titleLarge),
                    const Text('Vincule uma conta confirmada para receber pedidos fictícios disponíveis.'),
                    TextButton.icon(onPressed: _busy ? null : _linkCourier,
                      icon: const Icon(Icons.person_add_alt), label: const Text('Vincular entregador')),
                    for (final courier in _couriers)
                      SwitchListTile(contentPadding: EdgeInsets.zero,
                        title: Text(courier['email'] as String? ?? ''),
                        subtitle: Text(courier['active'] == true ? 'Ativo' : 'Inativo'),
                        value: courier['active'] == true,
                        onChanged: _busy ? null : (active) => _setCourierActive(courier, active)),
                    const Divider(),
                    Text('Remuneração: ${_compensation['mode'] == 'fixed' ? _money(_compensation['fixed_cents']) + ' por entrega' : _compensation['mode'] == 'percent' ? '${_compensation['percent']}% do frete' : 'salário mensal · R\$ 0 no app'}'),
                    TextButton.icon(onPressed: _busy ? null : _editCompensation,
                      icon: const Icon(Icons.tune), label: const Text('Configurar remuneração')),
                  ]))),
              ],
              const SizedBox(height: 16),
              Text('Cardápio', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pedidos nas mesas', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('Com a cobrança desligada, o cliente envia apenas o pedido e paga no fechamento no caixa.'),
                  if (_tableSettingsLoaded) SwitchListTile(
                    title: const Text('Permitir pagamento no app'),
                    subtitle: Text(_tablePaymentAvailable
                        ? 'Opção habilitada para esta loja.'
                        : 'Preferência salva. O pagamento no app depende da integração Pix e ainda não está disponível.'),
                    value: _allowTablePayment,
                    onChanged: _busy || !{'owner', 'manager'}.contains(_branch!['role'])
                        ? null : _setTablePayment,
                  ) else const Text('Configuração das mesas indisponível no momento.'),
                ],
              ))),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Link da mesa', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('O QR abre esta loja, identifica a mesa e permite pedidos fictícios.'),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(width: 130, child: DropdownButtonFormField<int>(
                        initialValue: _tableNumber,
                        decoration: const InputDecoration(labelText: 'Mesa'),
                        items: [for (var n = 1; n <= 30; n++)
                          DropdownMenuItem(value: n, child: Text('$n'))],
                        onChanged: _loadingQr ? null : (value) => setState(() {
                          _tableNumber = value ?? 1; _tableQr = null;
                        }),
                      )),
                      FilledButton.icon(onPressed: _loadingQr ? null : _loadTableQr,
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Gerar QR')),
                    ],
                  ),
                  if (_loadingQr) const Padding(padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator()),
                  if (_tableQr != null) ...[
                    const SizedBox(height: 16),
                    Center(child: SizedBox(width: 240, height: 240,
                      child: CustomPaint(painter: _QrPainter(_tableQr!['matrix'] as List<dynamic>)))),
                    const SizedBox(height: 12),
                    SelectableText(_tableQr!['url'] as String),
                    TextButton.icon(onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _tableQr!['url'] as String));
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link da mesa copiado.')));
                    }, icon: const Icon(Icons.copy), label: const Text('Copiar link')),
                    TextButton.icon(onPressed: () {
                      final opened = qr_print.openPrintableTableQr(
                        storeName: _branch!['tenant_name'] as String,
                        tableNumber: _tableNumber,
                        url: _tableQr!['url'] as String,
                        matrix: _tableQr!['matrix'] as List<dynamic>,
                      );
                      if (!opened) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abra a Gestão no navegador para imprimir ou salvar o QR em PDF.')));
                    }, icon: const Icon(Icons.print_outlined),
                      label: const Text('Imprimir / salvar PDF')),
                  ],
                ],
              ))),
              if ({'owner', 'manager'}.contains(_branch!['role']))
                Align(alignment: Alignment.centerRight,
                    child: FilledButton.icon(onPressed: _busy ? null : () => _editItem(),
                      icon: const Icon(Icons.add), label: const Text('Novo produto'))),
              if (_items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20),
                child: Text('Nenhum produto cadastrado nesta loja.'))),
              for (final item in _items) Card(child: ListTile(
                title: Text(item['name'] as String),
                subtitle: Text('${item['category_name']} · '
                    'R\$ ${((item['price_cents'] as int) / 100).toStringAsFixed(2).replaceAll('.', ',')}'
                    '${item['available'] == true ? '' : ' · indisponível'}'),
                trailing: {'owner', 'manager'}.contains(_branch!['role'])
                    ? const Icon(Icons.edit_outlined) : null,
                onTap: {'owner', 'manager'}.contains(_branch!['role']) && !_busy
                    ? () => _editItem(item) : null,
              )),
            ],
          ],
        ]),
      )),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.matrix);
  final List<dynamic> matrix;

  @override
  void paint(Canvas canvas, Size size) {
    if (matrix.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final side = matrix.length;
    final cell = size.width / side;
    final ink = Paint()..color = const Color(0xFF151B2B);
    for (var y = 0; y < side; y++) {
      final row = matrix[y] as List<dynamic>;
      for (var x = 0; x < row.length; x++) {
        if (row[x] == true) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + .2, cell + .2), ink);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => matrix != oldDelegate.matrix;
}
