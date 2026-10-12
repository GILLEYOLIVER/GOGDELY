import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key, required this.api, required this.onEditMenu});

  final LocalDemoApi api;
  final VoidCallback onEditMenu;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<DemoMenuItem> _items = const [];
  List<DemoIngredient> _ingredients = const [];

  @override
  void initState() {
    super.initState();
    if (localDemoEnabled) {
      _refresh();
      _timer = Timer.periodic(localDemoRefreshInterval, (_) => _refresh());
    }
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
      final items = await widget.api.menu();
      final ingredients = await widget.api.ingredients();
      if (mounted) {
        setState(() {
          _items = items;
          _ingredients = ingredients;
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _error = '$error';
          _loading = false;
        });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _editIngredient([DemoIngredient? original]) async {
    final form = GlobalKey<FormState>();
    final id = TextEditingController(text: original?.ingredientId ?? '');
    final name = TextEditingController(text: original?.name ?? '');
    final stock =
        TextEditingController(text: original?.stockQuantity.toString() ?? '0');
    var unit = original?.unit ?? 'un';
    final result = await showDialog<DemoIngredient>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
              original == null ? 'Novo ingrediente' : 'Editar ingrediente'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: id,
                  readOnly: original != null,
                  decoration:
                      const InputDecoration(labelText: 'Código (ex.: pao)'),
                  validator: (value) =>
                      RegExp(r'^[a-z0-9][a-z0-9-]{1,47}$').hasMatch(value ?? '')
                          ? null
                          : 'Use 2 a 48 letras minúsculas, números ou hífens.',
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => (value?.trim().length ?? 0) >= 2
                      ? null
                      : 'Informe o nome.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: const [
                    DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
                    DropdownMenuItem(value: 'g', child: Text('Gramas (g)')),
                    DropdownMenuItem(
                        value: 'ml', child: Text('Mililitros (ml)')),
                  ],
                  onChanged: original != null
                      ? null
                      : (value) => update(() => unit = value ?? 'un'),
                ),
                TextFormField(
                  controller: stock,
                  readOnly: original != null,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: original == null
                          ? 'Saldo inicial'
                          : 'Saldo (use Ajustar para alterar)'),
                  validator: (value) {
                    final number = int.tryParse((value ?? '').trim());
                    return number != null && number >= 0 && number <= 100000000
                        ? null
                        : 'Informe de 0 a 100.000.000.';
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(
                    context,
                    DemoIngredient(
                        id.text.trim(),
                        name.text.trim(),
                        unit,
                        int.parse(stock.text.trim()),
                        original?.updatedAt ?? ''));
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    id.dispose();
    name.dispose();
    stock.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.api.saveIngredient(result, create: original == null);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _adjust(
      String kind, String id, String name, String unit, int? balance) async {
    final form = GlobalKey<FormState>();
    final amount = TextEditingController();
    final reason = TextEditingController();
    var movement = balance == null ? 'count' : 'restock';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Ajustar estoque · $name'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'Saldo atual: ${balance == null ? 'sem limite' : '$balance $unit'}'),
                DropdownButtonFormField<String>(
                  initialValue: movement,
                  decoration: const InputDecoration(labelText: 'Movimento'),
                  items: [
                    if (balance != null) ...const [
                      DropdownMenuItem(
                          value: 'restock', child: Text('Entrada')),
                      DropdownMenuItem(value: 'loss', child: Text('Perda')),
                    ],
                    const DropdownMenuItem(
                        value: 'count',
                        child: Text('Contagem / saldo contado')),
                  ],
                  onChanged: (value) =>
                      update(() => movement = value ?? 'count'),
                ),
                TextFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: movement == 'count'
                          ? 'Saldo contado ($unit)'
                          : 'Quantidade ($unit)'),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    return parsed != null &&
                            parsed >= (movement == 'count' ? 0 : 1)
                        ? null
                        : 'Informe uma quantidade válida.';
                  },
                ),
                TextFormField(
                  controller: reason,
                  maxLength: 300,
                  decoration:
                      const InputDecoration(labelText: 'Motivo obrigatório'),
                  validator: (value) => (value?.trim().length ?? 0) >= 3
                      ? null
                      : 'Explique o motivo (mínimo 3 caracteres).',
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(context, true);
                },
                child: const Text('Registrar')),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await widget.api.adjustStock(
            itemKind: kind,
            itemId: id,
            movementType: movement,
            quantity: int.parse(amount.text.trim()),
            reason: reason.text.trim());
        await _refresh();
      } catch (error) {
        if (mounted) setState(() => _error = '$error');
      }
    }
    amount.dispose();
    reason.dispose();
  }

  Future<void> _showHistory() async {
    try {
      final movements = await widget.api.stockMovements();
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Movimentos de estoque'),
                content: SizedBox(
                    width: 650,
                    height: 480,
                    child: movements.isEmpty
                        ? const Center(
                            child: Text('Nenhum movimento registrado ainda.'))
                        : ListView.builder(
                            itemCount: movements.length,
                            itemBuilder: (context, index) {
                              final row = movements[index];
                              final delta = row['quantity_delta'] as int;
                              final action = switch (row['movement_type']) {
                                'restock' => 'Entrada',
                                'loss' => 'Perda',
                                'count' => 'Contagem',
                                'order_deduction' => 'Pedido',
                                'cancellation_restore' => 'Cancelamento',
                                'initial' => 'Saldo inicial',
                                _ => 'Edição',
                              };
                              return ListTile(
                                title: Text(
                                    '${row['item_name']} · $action · ${delta > 0 ? '+' : ''}$delta ${row['unit']}'),
                                subtitle: Text(
                                    '${row['reason']} · ${row['balance_before'] ?? 'sem limite'} → ${row['balance_after']} ${row['unit']} · ${row['created_at']}'),
                              );
                            })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'))
                ],
              ));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => !localDemoEnabled
      ? const Center(
          child: Text(
              'Abra com o perfil F5 de banco local para consultar o estoque.'))
      : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Estoque · Burger House',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Saldo local por produto. Pedidos baixam unidades; cancelamentos elegíveis repõem as unidades baixadas.'),
            const Text(
                'Fichas técnicas baixam ingredientes por pedido. Registre entradas, perdas e contagens com motivo; a conferência física é manual.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar saldo'),
              ),
              OutlinedButton.icon(
                onPressed: _showHistory,
                icon: const Icon(Icons.history),
                label: const Text('Movimentos'),
              ),
              FilledButton.icon(
                onPressed: widget.onEditMenu,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar no Cardápio'),
              ),
            ]),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            const Text('Ingredientes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Text(
                'Cadastre ingredientes e depois vincule-os à ficha técnica no Cardápio.'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _editIngredient(),
                icon: const Icon(Icons.add),
                label: const Text('Novo ingrediente'),
              ),
            ),
            if (_ingredients.isEmpty && !_loading)
              const Text('Nenhum ingrediente cadastrado.'),
            for (final ingredient in _ingredients)
              Card(
                  child: ListTile(
                onTap: () => _editIngredient(ingredient),
                leading: const Icon(Icons.kitchen_outlined),
                title: Text(ingredient.name),
                subtitle: Text(
                    'Código: ${ingredient.ingredientId} · toque para editar cadastro'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${ingredient.stockQuantity} ${ingredient.unit}'),
                  IconButton(
                      tooltip: 'Ajustar saldo',
                      icon: const Icon(Icons.tune),
                      onPressed: () => _adjust(
                          'ingredient',
                          ingredient.ingredientId,
                          ingredient.name,
                          ingredient.unit,
                          ingredient.stockQuantity)),
                ]),
              )),
            const SizedBox(height: 14),
            const Text('Produtos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            for (final item in _items)
              Card(
                child: ListTile(
                  leading: Icon(item.stockQuantity == 0
                      ? Icons.error_outline
                      : Icons.inventory_2_outlined),
                  title: Text(item.name),
                  subtitle: Text(
                      '${item.category} · ${item.orderable ? 'Vendável' : 'Indisponível'} · ${item.recipe.length} ingredientes na ficha'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.stockQuantity == null
                        ? 'Sem limite'
                        : '${item.stockQuantity} un.'),
                    IconButton(
                        tooltip: 'Ajustar saldo',
                        icon: const Icon(Icons.tune),
                        onPressed: () => _adjust('product', item.productId,
                            item.name, 'un', item.stockQuantity)),
                  ]),
                ),
              ),
          ],
        );
}
