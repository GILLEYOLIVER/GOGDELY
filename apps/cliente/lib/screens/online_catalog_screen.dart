import 'dart:convert';

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

  bool get _validSlug =>
      RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(_activeSlug) &&
      _activeSlug.length <= 100;

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
    setState(() { _activeSlug = slug; _catalog = null; _search.clear(); _error = null; });
    _load();
  }

  void _showDiscovery() {
    setState(() { _activeSlug = ''; _catalog = null; _search.clear(); _error = null; });
    _loadDiscovery();
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
            if (widget.tableNumber != null)
              Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Chip(avatar: const Icon(Icons.table_restaurant_outlined),
                  label: Text('Mesa ${widget.tableNumber}'))),
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
                    title: Text(item['name'] as String? ?? ''),
                    subtitle: Text('${item['category_name'] ?? ''}\n${item['description'] ?? ''}'),
                    isThreeLine: (item['description'] as String? ?? '').isNotEmpty,
                    trailing: Text(_price(item['price_cents']),
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          color: GogdelyColors.blue)),
                  )),
              const SizedBox(height: 16),
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text(
                'Pedidos e pagamentos online ainda não estão disponíveis nesta loja. '
                'Consulte o estabelecimento para comprar.',
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
