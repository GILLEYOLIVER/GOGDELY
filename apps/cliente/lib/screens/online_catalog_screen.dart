import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:http/http.dart' as http;

/// Public catalog entry for hosted links and table QR codes. No local demo
/// order or payment flow is reachable from this screen.
class OnlineCatalogScreen extends StatefulWidget {
  const OnlineCatalogScreen({
    super.key,
    required this.slug,
    this.tableNumber,
    this.apiBaseUrl = const String.fromEnvironment('GOGDELY_API_BASE_URL'),
    this.client,
  });

  factory OnlineCatalogScreen.fromUri(Uri uri) {
    final slug = uri.queryParameters['loja'] ?? '';
    final table = int.tryParse(uri.queryParameters['mesa'] ?? '');
    return OnlineCatalogScreen(
      slug: slug,
      tableNumber: table != null && table >= 1 && table <= 999 ? table : null,
    );
  }

  final String slug;
  final int? tableNumber;
  final String apiBaseUrl;
  final http.Client? client;

  @override
  State<OnlineCatalogScreen> createState() => _OnlineCatalogScreenState();
}

class _OnlineCatalogScreenState extends State<OnlineCatalogScreen> {
  final _search = TextEditingController();
  late String _activeSlug = widget.slug;
  Map<String, dynamic>? _catalog;
  List<Map<String, dynamic>> _discovery = const [];
  String? _error;
  bool _loading = false;
  bool _ordering = false;
  final Map<String, int> _cart = {};
  Map<String, dynamic>? _order;
  String? _requestKey;
  Timer? _orderTimer;

  bool get _validSlug =>
      RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(_activeSlug) &&
      _activeSlug.length <= 100;

  int? get _activeTableNumber =>
      _activeSlug == widget.slug ? widget.tableNumber : null;

  @override
  void initState() {
    super.initState();
    if (_activeSlug.isEmpty) {
      _loadDiscovery();
    } else if (_validSlug) {
      _load();
    }
  }

  @override
  void dispose() {
    _orderTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = widget.client ?? http.Client();
    try {
      if (!widget.apiBaseUrl.startsWith('https://')) {
        throw const FormatException('API indisponível');
      }
      final uri = Uri.parse(widget.apiBaseUrl).replace(
        path: '/api/v1/catalog/stores/$_activeSlug',
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw const FormatException('Loja não encontrada ou indisponível.');
      }
      if (response.statusCode != 200) {
        throw const FormatException('Cardápio temporariamente indisponível.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['name'] is! String || decoded['items'] is! List) {
        throw const FormatException('Resposta do cardápio inválida.');
      }
      if (mounted) setState(() => _catalog = decoded);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message
            : 'Não foi possível carregar o cardápio. Tente novamente.');
      }
    } finally {
      if (widget.client == null) client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDiscovery() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    final client = widget.client ?? http.Client();
    try {
      if (!widget.apiBaseUrl.startsWith('https://')) {
        throw const FormatException('API indisponível');
      }
      final uri = Uri.parse(widget.apiBaseUrl).replace(
        path: '/api/v1/catalog/discover',
        queryParameters: {'q': _search.text.trim()},
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const FormatException('Busca temporariamente indisponível.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const FormatException('Resposta da busca inválida.');
      }
      if (mounted) {
        setState(() => _discovery = decoded.whereType<Map<String, dynamic>>().toList());
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message : 'Não foi possível pesquisar. Tente novamente.');
      }
    } finally {
      if (widget.client == null) client.close();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _openStore(String slug) {
    setState(() { _activeSlug = slug; _catalog = null; _cart.clear();
      _search.clear(); _error = null; });
    _load();
  }

  void _showDiscovery() {
    setState(() { _activeSlug = ''; _catalog = null; _cart.clear();
      _search.clear(); _error = null; });
    _loadDiscovery();
  }

  String _newRequestKey() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _addItem(Map<String, dynamic> item) {
    final id = item['item_id'] as String;
    if ((_cart[id] ?? 0) >= 10) return;
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
  }

  int get _cartTotal {
    final items = (_catalog?['items'] as List<dynamic>? ?? const []);
    var total = 0;
    for (final item in items.whereType<Map<String, dynamic>>()) {
      total += (item['price_cents'] as int? ?? 0) *
          (_cart[item['item_id']] ?? 0);
    }
    return total + (_cart.isNotEmpty && _activeTableNumber == null ? 599 : 0);
  }

  Future<void> _placeOrder() async {
    if (_ordering || _cart.isEmpty || _catalog == null) return;
    setState(() { _ordering = true; _error = null; });
    _requestKey ??= _newRequestKey();
    final client = widget.client ?? http.Client();
    try {
      final uri = Uri.parse(widget.apiBaseUrl).replace(path: '/api/v1/demo/orders');
      final response = await client.post(uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'slug': _activeSlug,
          'idempotency_key': _requestKey,
          'channel': _activeTableNumber == null ? 'delivery' : 'table',
          'table_number': _activeTableNumber,
          'items': [for (final entry in _cart.entries)
            {'item_id': entry.key, 'quantity': entry.value}],
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 201) {
        throw const FormatException('Pedido fictício indisponível. Tente novamente.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['order_id'] is! String) {
        throw const FormatException('Resposta do pedido inválida.');
      }
      if (mounted) {
        setState(() {
          _order = decoded;
          _cart.clear();
          _requestKey = null;
        });
      }
      _orderTimer?.cancel();
      _orderTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshOrder());
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message : 'Não foi possível enviar o pedido fictício.');
      }
    } finally {
      if (widget.client == null) client.close();
      if (mounted) setState(() => _ordering = false);
    }
  }

  Future<void> _refreshOrder() async {
    final id = _order?['order_id'];
    if (id is! String) return;
    final client = widget.client ?? http.Client();
    try {
      final uri = Uri.parse(widget.apiBaseUrl).replace(path: '/api/v1/demo/orders/$id');
      final response = await client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) setState(() => _order = decoded);
        if (decoded is Map<String, dynamic> && decoded['status'] == 'completed') {
          _orderTimer?.cancel();
        }
      }
    } catch (_) {
      // Keep the last known status visible while the network is unavailable.
    } finally {
      if (widget.client == null) client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = (_catalog?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((item) => item['available'] == true)
        .where((item) {
          if (query.isEmpty) return true;
          return '${item['name']} ${item['description']} ${item['category_name']}'
              .toLowerCase().contains(query);
        }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('gogdely.'), centerTitle: false),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (_activeSlug.isEmpty) ...[
            Text('Explore os cardápios', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Encontre produtos disponíveis nas lojas do GOGDELY.'),
            const SizedBox(height: 18),
            TextField(controller: _search,
                onSubmitted: (_) => _loadDiscovery(),
                decoration: InputDecoration(labelText: 'Pesquisar produtos ou lojas',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Pesquisar', onPressed: _loading ? null : _loadDiscovery))),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Text(_error!))),
            if (!_loading && _error == null && _discovery.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20),
                child: Text('Nenhum produto disponível para esta busca.'))),
            for (final item in _discovery)
              Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                leading: const Icon(Icons.storefront_outlined, color: GogdelyColors.blue),
                title: Text(item['item_name'] as String? ?? ''),
                subtitle: Text('${item['store_name'] ?? ''} · ${item['category_name'] ?? ''}'),
                trailing: Text(_price(item['price_cents']),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => _openStore(item['slug'] as String),
              )),
          ] else if (!_validSlug) ...[
            const SizedBox(height: 80),
            const Icon(Icons.storefront_outlined, size: 64, color: GogdelyColors.blue),
            const SizedBox(height: 20),
            const Text('Link da loja inválido.', textAlign: TextAlign.center),
            TextButton(onPressed: _showDiscovery, child: const Text('Explorar lojas')),
          ] else ...[
            if (_activeTableNumber != null)
              Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Chip(avatar: const Icon(Icons.table_restaurant_outlined),
                  label: Text('Mesa $_activeTableNumber'))),
            Text(_catalog?['name'] as String? ?? 'Cardápio da loja',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Produtos e preços informados pela loja.'),
            TextButton(onPressed: _showDiscovery,
                child: const Text('Explorar outras lojas')),
            const SizedBox(height: 22),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Tentar novamente')),
              ]),
            )),
            if (_catalog != null) ...[
              TextField(controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar produtos',
                    prefixIcon: Icon(Icons.search),
                  )),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(padding: EdgeInsets.all(20),
                    child: Text('Nenhum produto encontrado.')),
              for (final item in items)
                Card(margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: item['image_path'] is String
                        ? ClipRRect(borderRadius: BorderRadius.circular(9),
                            child: Image.network(item['image_path'] as String,
                              width: 54, height: 54, fit: BoxFit.cover,
                              errorBuilder: (_, error, stackTrace) =>
                                  const Icon(Icons.fastfood)))
                        : const Icon(Icons.fastfood_outlined),
                    title: Text(item['name'] as String? ?? ''),
                    subtitle: Text('${item['category_name'] ?? ''} · ${_price(item['price_cents'])}'
                        '\n${item['description'] ?? ''}'),
                    isThreeLine: (item['description'] as String? ?? '').isNotEmpty,
                    trailing: IconButton(onPressed: () => _addItem(item),
                      tooltip: 'Adicionar ${item['name']}',
                      icon: const Icon(Icons.add_circle_outline,
                        color: GogdelyColors.blue)),
                  )),
              const SizedBox(height: 16),
              if (_cart.isNotEmpty) Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Sacola de teste', style: Theme.of(context).textTheme.titleLarge),
                  for (final entry in _cart.entries)
                    ListTile(dense: true,
                      title: Text(((_catalog!['items'] as List<dynamic>)
                          .whereType<Map<String, dynamic>>()
                          .firstWhere((item) => item['item_id'] == entry.key))['name'] as String),
                      subtitle: Text('${entry.value} unidade(s)'),
                      trailing: IconButton(tooltip: 'Remover unidade',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (entry.value <= 1) { _cart.remove(entry.key); }
                          else { _cart[entry.key] = entry.value - 1; }
                        })),
                    ),
                  Text('Total fictício: ${_price(_cartTotal)}'),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _ordering ? null : _placeOrder,
                    child: Text(_ordering ? 'Enviando...' : 'Fazer pedido fictício')),
                ]),
              )),
              if (_order != null) Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pedido de teste #${(_order!['order_id'] as String).substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium),
                  Text('Situação: ${_order!['status']}'),
                  Text('Total fictício: ${_price(_order!['total_cents'])}'),
                  const Text('Sem cobrança ou entrega real.'),
                  TextButton.icon(onPressed: _refreshOrder,
                    icon: const Icon(Icons.refresh), label: const Text('Atualizar pedido')),
                ]),
              )),
              if (_cart.isEmpty && _order == null)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text(
                  'Escolha produtos para enviar um pedido fictício à Gestão.',
                ))),
            ],
          ],
        ]),
      )),
    );
  }

  String _price(Object? cents) {
    if (cents is! int || cents < 0) return 'Preço indisponível';
    return 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
