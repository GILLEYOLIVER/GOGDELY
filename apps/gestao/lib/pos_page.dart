import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';
import 'pos_register_panel.dart';

/// One-store, opt-in local counter orders. Payment is never confirmed here.
class PosPage extends StatefulWidget {
  const PosPage({super.key, required this.api, required this.onSaleCreated});

  final LocalDemoApi api;
  final Future<void> Function() onSaleCreated;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  Timer? _timer;
  bool _refreshing = false;
  bool _saving = false;
  List<DemoMenuItem> _menu = const [];
  List<String> _paymentMethods = const [];
  final Map<String, int> _cart = {};
  String? _paymentMethod;
  String? _requestKey;
  String? _error;
  DemoOrder? _lastSale;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(localDemoRefreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final menu = await widget.api.menu();
      final methods = await widget.api.paymentMethods();
      if (mounted) {
        setState(() {
          _menu = menu;
          _paymentMethods = methods;
          if (!methods.contains(_paymentMethod))
            _paymentMethod = methods.firstOrNull;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _refreshing = false;
    }
  }

  void _changeQuantity(String productId, int delta) {
    if (_saving) return;
    setState(() {
      final quantity = (_cart[productId] ?? 0) + delta;
      if (quantity <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = quantity;
      }
      _requestKey = null;
      _lastSale = null;
    });
  }

  int get _totalCents => _menu.fold(
      0,
      (sum, item) =>
          sum + (_cart[item.productId] ?? 0) * item.effectivePriceCents);

  String _money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_saving || _cart.isEmpty || _paymentMethod == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _requestKey ??= newDemoRequestKey();
    });
    try {
      final sale = await widget.api.createPosSale(
        requestKey: _requestKey!,
        paymentMethod: _paymentMethod!,
        items: [
          for (final entry in _cart.entries)
            {'product_id': entry.key, 'quantity': entry.value},
        ],
      );
      if (!mounted) return;
      setState(() {
        _lastSale = sale;
        _cart.clear();
        _requestKey = null;
      });
      await widget.onSaleCreated();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('PDV · Burger House',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
              'Venda de balcão no banco local. O pedido entra na cozinha e baixa o estoque.'),
          const Text(
              'A forma escolhida é apenas uma intenção; nenhum pagamento é processado ou confirmado.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          PosRegisterPanel(api: widget.api),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar cardápio'),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_lastSale != null)
            Card(
                child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text('Pedido de balcão #${_lastSale!.id} salvo'),
              subtitle: Text(
                  '${_money(_lastSale!.totalCents)} · enviado para Pedidos/KDS · pagamento não processado'),
            )),
          const SizedBox(height: 12),
          const Text('Produtos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (_menu.isEmpty) const Text('Carregando cardápio local...'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in _menu)
              SizedBox(
                  width: 170,
                  child: Card(
                      child: InkWell(
                    onTap: item.orderable
                        ? () => _changeQuantity(item.productId, 1)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lunch_dining_outlined),
                            const SizedBox(height: 8),
                            Text(item.name,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(_money(item.effectivePriceCents)),
                            Text(item.orderable ? 'Adicionar' : 'Indisponível',
                                style: const TextStyle(fontSize: 11)),
                          ]),
                    ),
                  ))),
          ]),
          const SizedBox(height: 16),
          const Text('Venda local',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (_cart.isEmpty) const Text('Selecione um produto para começar.'),
          for (final entry in _cart.entries)
            if (_menu.where((item) => item.productId == entry.key).firstOrNull
                case final item?)
              Card(
                  child: ListTile(
                title: Text(item.name),
                subtitle: Text(
                    '${entry.value} × ${_money(item.effectivePriceCents)}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      onPressed: () => _changeQuantity(entry.key, -1),
                      tooltip: 'Diminuir',
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('${entry.value}'),
                  IconButton(
                      onPressed: item.orderable
                          ? () => _changeQuantity(entry.key, 1)
                          : null,
                      tooltip: 'Aumentar',
                      icon: const Icon(Icons.add_circle_outline)),
                ]),
              )),
          const SizedBox(height: 8),
          Text('Total estimado: ${_money(_totalCents)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('${_paymentMethods.join(',')}:$_paymentMethod'),
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Forma pretendida'),
            items: [
              for (final method in _paymentMethods)
                DropdownMenuItem(
                    value: method, child: Text(demoPaymentLabel(method)))
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() {
                      _paymentMethod = value;
                      _requestKey = null;
                    }),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _cart.isEmpty || _paymentMethod == null || _saving
                ? null
                : _submit,
            icon: const Icon(Icons.point_of_sale),
            label: Text(_saving ? 'Salvando...' : 'Salvar pedido de balcão'),
          ),
        ],
      );
}
