import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connected homologation view. Every delivery and amount is fictitious.
class OnlineCourierShell extends StatefulWidget {
  const OnlineCourierShell({super.key});

  @override
  State<OnlineCourierShell> createState() => _OnlineCourierShellState();
}

class _OnlineCourierShellState extends State<OnlineCourierShell> {
  static const _api = String.fromEnvironment('GOGDELY_API_BASE_URL');
  final _email = TextEditingController();
  final _password = TextEditingController();
  SupabaseClient? _client;
  Timer? _timer;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic> _earnings = const {
    'completed_count': 0,
    'total_cents': 0,
    'stores': <Map<String, dynamic>>[],
  };
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_client?.auth.currentSession != null && !_busy) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<dynamic> _request(String path, {String method = 'GET'}) async {
    final token = _client?.auth.currentSession?.accessToken;
    if (token == null) throw const FormatException('Entre novamente.');
    final client = http.Client();
    try {
      final request = http.Request(method, Uri.parse('$_api$path'));
      request.headers['authorization'] = 'Bearer $token';
      final response = await client.send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException('Operação indisponível (${response.statusCode}).');
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } finally {
      client.close();
    }
  }

  Future<void> _bootstrap() async {
    try {
      if (!_api.startsWith('https://')) {
        throw const FormatException('API online não configurada.');
      }
      final response = await http.get(Uri.parse('$_api/api/v1/client-config'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const FormatException('Autenticação online indisponível.');
      }
      final config = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      await Supabase.initialize(
        url: config['supabase_url'] as String,
        publishableKey: config['supabase_publishable_key'] as String,
      );
      _client = Supabase.instance.client;
      if (_client!.auth.currentSession != null) await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message : 'Não foi possível iniciar o app.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    if (_client == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _client!.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text);
      _password.clear();
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Confira o e-mail, a senha e o vínculo com a loja.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final assignments = await _request('/api/v1/courier/assignments') as List<dynamic>;
      final earnings = await _request('/api/v1/courier/earnings') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _assignments = assignments.cast<Map<String, dynamic>>();
          _earnings = earnings;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message : 'Não foi possível atualizar as entregas.');
      }
    }
  }

  Future<void> _advance(Map<String, dynamic> assignment) async {
    final status = assignment['status'] as String;
    final action = switch (status) {
      'available' => 'accept',
      'accepted' => 'start',
      'in_delivery' => 'complete',
      _ => null,
    };
    if (action == null) return;
    if (action == 'complete') {
      final confirmed = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(
          title: const Text('Concluir entrega fictícia?'),
          content: const Text('Este registro serve apenas para testar o fluxo. '
              'Não representa uma entrega ou pagamento real.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar')),
            FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Concluir teste'))],
        ));
      if (confirmed != true) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _request('/api/v1/courier/assignments/${assignment['order_id']}/$action',
        method: 'POST');
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message : 'Não foi possível atualizar a entrega.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(Object? cents) {
    final value = cents is num ? cents : 0;
    return 'R\$ ${(value / 100).toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final signedIn = _client?.auth.currentSession != null;
    return Scaffold(
      appBar: AppBar(title: const Text('GOGDELY Entrega'), actions: [
        if (signedIn) IconButton(tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh), onPressed: _refresh),
        if (signedIn) IconButton(tooltip: 'Sair',
          icon: const Icon(Icons.logout), onPressed: () async {
            await _client!.auth.signOut();
            if (mounted) {
              setState(() {
                _assignments = [];
                _earnings = const {'completed_count': 0,
                  'total_cents': 0, 'stores': <Map<String, dynamic>>[]};
              });
            }
          }),
      ]),
      bottomNavigationBar: signedIn ? NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.two_wheeler), label: 'Entregas'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Ganhos'),
        ],
      ) : null,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (_error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!))),
          if (!signedIn && _client != null) Card(child: Padding(
            padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Acesse suas entregas', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Use a conta confirmada e vinculada pela loja.'),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail')),
                TextField(controller: _password, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha')),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _signIn,
                  child: const Text('Entrar')),
              ]),
            )),
          if (signedIn && _tab == 0) ...[
            Text('Entregas da loja', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Prévia com pedidos, destinos e valores fictícios.'),
            const SizedBox(height: 16),
            if (_assignments.isEmpty) const Card(child: Padding(
              padding: EdgeInsets.all(20), child: Text(
                'Nenhuma entrega disponível. Aguarde a loja marcar o pedido como pronto.'))),
            for (final assignment in _assignments) Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(padding: const EdgeInsets.all(16), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(assignment['store_name'] as String? ?? 'Loja de teste',
                    style: Theme.of(context).textTheme.titleLarge),
                  Text('Pedido #${(assignment['order_id'] as String).substring(0, 8)}'
                      ' · ${assignment['status']}'),
                  Text(assignment['address_label'] as String? ?? 'Destino fictício'),
                  const SizedBox(height: 8),
                  Text('Ganho nesta entrega: ${_money(assignment['earning_cents'])}'),
                  Text('Frete fictício: ${_money(assignment['delivery_fee_cents'])}'),
                  const SizedBox(height: 10),
                  if (assignment['status'] != 'completed')
                    SizedBox(width: double.infinity, child: FilledButton(
                      onPressed: _busy ? null : () => _advance(assignment),
                      child: Text(switch (assignment['status']) {
                        'available' => 'Aceitar entrega',
                        'accepted' => 'Iniciar entrega',
                        _ => 'Concluir entrega',
                      }),
                    )),
                ],
              )),
            ),
          ],
          if (signedIn && _tab == 1) ...[
            Text('Ganhos fictícios', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Somente entregas concluídas neste ambiente de teste.'),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_money(_earnings['total_cents']),
                  style: Theme.of(context).textTheme.headlineMedium),
                Text('${_earnings['completed_count'] ?? 0} entregas concluídas'),
              ]))),
            for (final store in (_earnings['stores'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>())
              Card(child: ListTile(title: Text(store['store_name'] as String? ?? ''),
                trailing: Text(_money(store['earned_cents'])))),
            const Padding(padding: EdgeInsets.all(8), child: Text(
              'Valores de simulação. Nenhum repasse ou folha é processado aqui.')),
          ],
        ]),
      )),
    );
  }
}
