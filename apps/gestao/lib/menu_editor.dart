import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

/// Local-only Burger House catalogue editor. No production credentials.
class MenuEditorPage extends StatefulWidget {
  const MenuEditorPage({super.key, required this.api});
  final LocalDemoApi api;

  @override
  State<MenuEditorPage> createState() => _MenuEditorPageState();
}

class _MenuEditorPageState extends State<MenuEditorPage> {
  List<DemoMenuItem> _items = const [];
  List<DemoIngredient> _ingredients = const [];
  String? _error;
  bool _loading = true;
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    if (localDemoEnabled) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.api.menu();
      final ingredients = await widget.api.ingredients();
      if (mounted)
        setState(() {
          _items = items;
          _ingredients = ingredients;
          _error = null;
        });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  String _changeLabel(String key) => switch (key) {
        'name' => 'Nome',
        'description' => 'Descrição',
        'category' => 'Categoria',
        'price_cents' => 'Preço',
        'image_ref' => 'Foto',
        'addons' => 'Adicionais',
        'recipe' => 'Ficha técnica',
        'available' => 'Disponibilidade',
        'stock_quantity' => 'Saldo do produto',
        'promo_percent' => 'Promoção',
        'sort_order' => 'Posição',
        _ => key,
      };

  String _changeValue(String key, dynamic value) {
    if (value == null) return '—';
    if (key == 'price_cents') return _money(value as int);
    if (key == 'promo_percent') return '$value%';
    if (key == 'available')
      return value == true ? 'Disponível' : 'Indisponível';
    if (key == 'stock_quantity') return '$value unidades';
    if (key == 'addons' && value is List) {
      if (value.isEmpty) return 'Nenhum';
      return value.map((item) => (item as Map)['name']).join(', ');
    }
    if (key == 'recipe' && value is List) {
      if (value.isEmpty) return 'Nenhuma';
      return value
          .map((part) =>
              '${(part as Map)['ingredient_id']}: ${part['quantity']}')
          .join(', ');
    }
    if (key == 'image_ref')
      return (value as String).isEmpty ? 'Sem foto' : value;
    if (key == 'sort_order') return '${(value as int) + 1}';
    return '$value';
  }

  Future<void> _showHistory() async {
    try {
      final events = await widget.api.menuEvents();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Histórico do cardápio'),
          content: SizedBox(
            width: 600,
            height: 460,
            child: events.isEmpty
                ? const Center(
                    child: Text('Nenhuma alteração local registrada ainda.'))
                : ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final changes = event['changes'] as Map<String, dynamic>;
                      final action = switch (event['action']) {
                        'created' => 'Criado',
                        'reordered' => 'Reordenado',
                        'stock_deducted' => 'Baixa por pedido',
                        'stock_restored' => 'Reposição por cancelamento',
                        _ => 'Editado',
                      };
                      final timestamp =
                          DateTime.tryParse(event['created_at'] as String)
                                  ?.toLocal()
                                  .toString()
                                  .substring(0, 16) ??
                              '';
                      return ExpansionTile(
                        title: Text('$action · ${event['product_name']}'),
                        subtitle:
                            Text('$timestamp · ${event['actor']} (sem login)'),
                        children: [
                          for (final entry in changes.entries)
                            ListTile(
                              dense: true,
                              title: Text(_changeLabel(entry.key)),
                              subtitle: Text(
                                '${_changeValue(entry.key, (entry.value as Map)['before'])} → '
                                '${_changeValue(entry.key, (entry.value as Map)['after'])}',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'))
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _moveItem(int index, int offset) async {
    if (_reordering || index + offset < 0 || index + offset >= _items.length)
      return;
    final ids = _items.map((item) => item.productId).toList();
    final moved = ids.removeAt(index);
    ids.insert(index + offset, moved);
    setState(() => _reordering = true);
    try {
      final reordered = await widget.api.reorderMenu(ids);
      if (mounted)
        setState(() {
          _items = reordered;
          _error = null;
        });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  List<DemoAddon> _parseAddons(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length > 20)
      throw const FormatException('Use no máximo 20 adicionais.');
    final result = <DemoAddon>[];
    final names = <String>{};
    for (final line in lines) {
      final parts = line.split(';');
      if (parts.length != 2) {
        throw const FormatException('Use um adicional por linha: Nome; 4,00');
      }
      final name = parts[0].trim();
      final price = double.tryParse(parts[1].trim().replaceAll(',', '.'));
      if (name.length < 2 ||
          name.length > 60 ||
          price == null ||
          price < 0 ||
          price > 1000 ||
          !names.add(name.toLowerCase())) {
        throw const FormatException('Confira nomes e preços dos adicionais.');
      }
      result.add(DemoAddon(name, (price * 100).round()));
    }
    return result;
  }

  List<DemoRecipePart> _parseRecipe(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length > 20)
      throw const FormatException('Use no máximo 20 ingredientes.');
    final result = <DemoRecipePart>[];
    final ids = <String>{};
    final available =
        _ingredients.map((ingredient) => ingredient.ingredientId).toSet();
    for (final line in lines) {
      final parts = line.split(';');
      if (parts.length != 2)
        throw const FormatException(
            'Use uma linha por ingrediente: codigo; quantidade');
      final id = parts[0].trim();
      final quantity = int.tryParse(parts[1].trim());
      if (!available.contains(id) ||
          !ids.add(id) ||
          quantity == null ||
          quantity < 1 ||
          quantity > 1000000) {
        throw const FormatException(
            'Confira os códigos e quantidades da ficha técnica.');
      }
      result.add(DemoRecipePart(id, quantity));
    }
    return result;
  }

  Future<(List<int>, String)?> _pickImage() async {
    String? path;
    if (Platform.isWindows) {
      const script = r'''
Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Escolher foto do produto'
$dialog.Filter = 'Imagens (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp'
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Write($dialog.FileName)
}
''';
      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-Command', script],
        stdoutEncoding: utf8,
      );
      if (result.exitCode == 0) path = (result.stdout as String).trim();
    } else if (Platform.isMacOS) {
      final result = await Process.run('osascript', [
        '-e',
        'POSIX path of (choose file with prompt "Escolher foto do produto")'
      ]);
      if (result.exitCode == 0) path = (result.stdout as String).trim();
    }
    if (path == null || path.isEmpty) return null;
    final extension = path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => throw const FormatException('Escolha PNG, JPEG ou WebP.'),
    };
    return (await File(path).readAsBytes(), mimeType);
  }

  Future<void> _edit([DemoMenuItem? original]) async {
    final form = GlobalKey<FormState>();
    final id = TextEditingController(text: original?.productId ?? '');
    final name = TextEditingController(text: original?.name ?? '');
    final description =
        TextEditingController(text: original?.description ?? '');
    final category = TextEditingController(text: original?.category ?? '');
    final price = TextEditingController(
        text: original == null
            ? ''
            : (original.priceCents / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ','));
    final image = TextEditingController(text: original?.imageRef ?? '');
    final promo = TextEditingController(text: '${original?.promoPercent ?? 0}');
    final stock =
        TextEditingController(text: original?.stockQuantity?.toString() ?? '');
    final addons = TextEditingController(
      text: original?.addons
              .map((addon) =>
                  '${addon.name}; ${(addon.priceCents / 100).toStringAsFixed(2).replaceAll('.', ',')}')
              .join('\n') ??
          '',
    );
    final recipe = TextEditingController(
      text: original?.recipe
              .map((part) => '${part.ingredientId}; ${part.quantity}')
              .join('\n') ??
          '',
    );
    var available = original?.available ?? true;
    var uploading = false;
    final result = await showDialog<DemoMenuItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: Text(original == null ? 'Novo produto' : 'Editar produto'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: id,
                    readOnly: original != null,
                    decoration: const InputDecoration(
                        labelText: 'Código do produto (ex.: x-salada)'),
                    validator: (value) => RegExp(r'^[a-z0-9][a-z0-9-]{1,47}$')
                            .hasMatch(value ?? '')
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
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    validator: (value) => (value?.trim().length ?? 0) >= 2
                        ? null
                        : 'Informe a categoria.',
                  ),
                  TextFormField(
                    controller: price,
                    decoration: const InputDecoration(
                        labelText: 'Preço (R\$)', hintText: '28,90'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final amount =
                          double.tryParse((value ?? '').replaceAll(',', '.'));
                      return amount != null && amount > 0 && amount <= 100000
                          ? null
                          : 'Informe um preço válido.';
                    },
                  ),
                  TextFormField(
                    controller: promo,
                    decoration:
                        const InputDecoration(labelText: 'Promoção (%)'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      return number != null && number >= 0 && number <= 90
                          ? null
                          : 'Use de 0 a 90%.';
                    },
                  ),
                  TextFormField(
                    controller: stock,
                    readOnly: original != null,
                    decoration: InputDecoration(
                      labelText: 'Saldo em unidades (opcional)',
                      helperText: original == null
                          ? 'Vazio = sem controle de estoque neste produto.'
                          : 'Use Estoque para registrar entrada, perda ou contagem.',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) return null;
                      final amount = int.tryParse(trimmed);
                      return amount != null && amount >= 0 && amount <= 1000000
                          ? null
                          : 'Informe de 0 a 1.000.000 unidades.';
                    },
                  ),
                  TextFormField(
                    controller: image,
                    decoration: const InputDecoration(
                      labelText: 'Imagem (URL HTTPS ou imagem de demonstração)',
                      helperText: 'Ex.: assets/images/burger.png',
                    ),
                    validator: (value) {
                      final ref = value?.trim() ?? '';
                      return ref.isEmpty ||
                              ref.startsWith('/api/v1/local/uploads/') ||
                              ref.startsWith('https://') ||
                              {
                                'assets/images/burger.png',
                                'assets/images/pizza.png',
                                'assets/images/sushi.png'
                              }.contains(ref)
                          ? null
                          : 'Use URL HTTPS ou uma imagem interna.';
                    },
                  ),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            updateDialog(() => uploading = true);
                            try {
                              final picked = await _pickImage();
                              if (picked != null) {
                                final ref = await widget.api
                                    .uploadImage(picked.$1, picked.$2);
                                if (dialogContext.mounted) {
                                  updateDialog(() => image.text = ref);
                                }
                              }
                            } catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        'Não foi possível enviar a foto: $error')));
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                updateDialog(() => uploading = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(uploading
                        ? 'Enviando foto...'
                        : 'Escolher foto do computador'),
                  ),
                  TextFormField(
                    controller: addons,
                    decoration: const InputDecoration(
                      labelText: 'Adicionais e preços',
                      helperText: 'Um por linha: Bacon; 4,00',
                    ),
                    maxLines: 4,
                    validator: (value) {
                      try {
                        _parseAddons(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ficha técnica · consumo por 1 produto',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  SelectableText(_ingredients.isEmpty
                      ? 'Cadastre ingredientes em Estoque antes de montar a ficha.'
                      : _ingredients
                          .map((item) => '${item.ingredientId} (${item.unit})')
                          .join(' · ')),
                  TextFormField(
                    controller: recipe,
                    decoration: const InputDecoration(
                      labelText: 'Ingredientes e quantidades',
                      helperText: 'Uma linha: pao; 1 ou carne; 180',
                    ),
                    maxLines: 4,
                    validator: (value) {
                      try {
                        _parseRecipe(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Produto disponível'),
                    value: available,
                    onChanged: (value) => updateDialog(() => available = value),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: uploading
                  ? null
                  : () {
                      if (!form.currentState!.validate()) return;
                      final cents =
                          (double.parse(price.text.replaceAll(',', '.')) * 100)
                              .round();
                      Navigator.pop(
                          dialogContext,
                          DemoMenuItem(
                            productId: id.text.trim(),
                            name: name.text.trim(),
                            description: description.text.trim(),
                            category: category.text.trim(),
                            priceCents: cents,
                            imageRef: image.text.trim(),
                            available: available,
                            stockQuantity: stock.text.trim().isEmpty
                                ? null
                                : int.parse(stock.text.trim()),
                            updatedAt: original?.updatedAt ?? '',
                            promoPercent: int.parse(promo.text),
                            effectivePriceCents:
                                cents * (100 - int.parse(promo.text)) ~/ 100,
                            addons: _parseAddons(addons.text),
                            recipe: _parseRecipe(recipe.text),
                          ));
                    },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    id.dispose();
    name.dispose();
    description.dispose();
    category.dispose();
    price.dispose();
    image.dispose();
    promo.dispose();
    stock.dispose();
    addons.dispose();
    recipe.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.api.saveMenuItem(result, create: original == null);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cardápio salvo no banco local.')));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!localDemoEnabled) {
      return const Center(
          child: Text(
              'Abra com o perfil F5 de banco local para editar o cardápio.'));
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cardápio · Burger House',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(
                      'Edição local de teste. O Cliente atualiza automaticamente.'),
                ]),
            FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Novo produto')),
            OutlinedButton.icon(
                onPressed: _showHistory,
                icon: const Icon(Icons.history),
                label: const Text('Histórico')),
          ]),
      const SizedBox(height: 14),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_loading || _reordering) const LinearProgressIndicator(),
      Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Atualizar cardápio',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          )),
      for (var index = 0; index < _items.length; index++)
        _itemTile(_items[index], index),
    ]);
  }

  Widget _itemTile(DemoMenuItem item, int index) => Card(
        child: ListTile(
          leading: _thumbnail(item),
          title: Text(item.name),
          subtitle: Text(
              '${item.category} · ${_money(item.effectivePriceCents)}'
              '${item.promoPercent > 0 ? ' · ${item.promoPercent}% OFF' : ''}'
              ' · ${item.addons.length} adicionais'
              ' · ${item.recipe.length} ingredientes'
              ' · ${item.stockQuantity == null ? 'Saldo não controlado' : '${item.stockQuantity} un. em estoque'}'
              '${item.available && !item.orderable ? ' · Faltam insumos ou produto esgotado' : ''}'
              '${item.available ? '' : ' · Indisponível'}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Mover ${item.name} para cima',
              onPressed:
                  _reordering || index == 0 ? null : () => _moveItem(index, -1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Mover ${item.name} para baixo',
              onPressed: _reordering || index == _items.length - 1
                  ? null
                  : () => _moveItem(index, 1),
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: 'Editar ${item.name}',
              onPressed: () => _edit(item),
              icon: const Icon(Icons.edit_outlined),
            ),
          ]),
          onTap: () => _edit(item),
        ),
      );

  Widget _thumbnail(DemoMenuItem item) {
    if (item.imageRef.isEmpty) {
      return const Icon(Icons.restaurant_menu, color: GogdelyColors.blue);
    }
    final image = item.imageRef.startsWith('/')
        ? '$localDemoBaseUrl${item.imageRef}'
        : item.imageRef;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
          width: 50,
          height: 50,
          child: image.startsWith('http')
              ? Image.network(image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined))
              : Image.asset(image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined))),
    );
  }
}
