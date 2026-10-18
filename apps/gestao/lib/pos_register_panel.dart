import 'package:flutter/material.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

/// Manual cash declarations for the local pilot, never payment settlement.
class PosRegisterPanel extends StatefulWidget {
  const PosRegisterPanel({super.key, required this.api});

  final LocalDemoApi api;

  @override
  State<PosRegisterPanel> createState() => _PosRegisterPanelState();
}

class _PosRegisterPanelState extends State<PosRegisterPanel> {
  Map<String, dynamic>? _active;
  List<Map<String, dynamic>> _recent = const [];
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String? _pendingKey;
  String? _pendingFingerprint;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final result = await widget.api.posRegister();
      if (!mounted) return;
      setState(() {
        _active = result['active'] as Map<String, dynamic>?;
        _recent = (result['recent'] as List).cast<Map<String, dynamic>>();
        _loaded = true;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  String _money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  int? _parseCents(String input) {
    final value = input.trim();
    final match = RegExp(r'^(\d{1,8})(?:[,.](\d{1,2}))?$').firstMatch(value);
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = int.parse((match.group(2) ?? '0').padRight(2, '0'));
    final cents = whole * 100 + fraction;
    return cents <= 10000000 ? cents : null;
  }

  Future<(int, String)?> _details(String title, String amountLabel,
      {bool allowZero = false}) async {
    final form = GlobalKey<FormState>();
    final amount = TextEditingController();
    final reason = TextEditingController();
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '$amountLabel (R\$)'),
                validator: (value) {
                  final cents = _parseCents(value ?? '');
                  return cents != null && (allowZero || cents > 0)
                      ? null
                      : 'Informe um valor válido.';
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                      context, (_parseCents(amount.text)!, reason.text.trim()));
                }
              },
              child: const Text('Registrar')),
        ],
      ),
    );
    amount.dispose();
    reason.dispose();
    return result;
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    final title = switch (action) {
      'open' => 'Abrir caixa local',
      'supply' => 'Registrar suprimento',
      'withdrawal' => 'Registrar sangria',
      _ => 'Fechar caixa local',
    };
    final label = switch (action) {
      'open' => 'Valor inicial declarado',
      'close' => 'Dinheiro contado no fechamento',
      _ => 'Valor movimentado',
    };
    final details = await _details(title, label,
        allowZero: action == 'open' || action == 'close');
    if (details == null || !mounted) return;
    final (amount, reason) = details;
    final fingerprint = '$action|$amount|$reason';
    if (_pendingFingerprint != fingerprint) {
      _pendingFingerprint = fingerprint;
      _pendingKey = newDemoRequestKey();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == 'open') {
        await widget.api.openPosRegister(
            requestKey: _pendingKey!, openingCents: amount, reason: reason);
      } else if (action == 'close') {
        await widget.api.closePosRegister(
            requestKey: _pendingKey!, countedCents: amount, reason: reason);
      } else {
        await widget.api.recordPosCashMovement(
            requestKey: _pendingKey!,
            movementType: action,
            amountCents: amount,
            reason: reason);
      }
      _pendingKey = null;
      _pendingFingerprint = null;
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Caixa local',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: _refresh,
                  tooltip: 'Atualizar caixa',
                  icon: const Icon(Icons.refresh)),
            ]),
            const Text(
                'Apenas valores declarados manualmente. Pedidos do PDV não são recebimentos confirmados.',
                style: TextStyle(fontSize: 12)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            if (!_loaded) ...[
              const Text('Carregando caixa local...'),
            ] else if (_active == null) ...[
              const Text('Nenhum caixa aberto.'),
              FilledButton.icon(
                  onPressed: _busy ? null : () => _act('open'),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Abrir caixa')),
            ] else ...[
              Text(
                  'Caixa #${_active!['id']} · aberto em ${_active!['opened_at']}'),
              Text('Abertura: ${_money(_active!['opening_cents'] as int)}'),
              Text(
                  'Saldo declarado: ${_money(_active!['expected_cash_cents'] as int)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                    onPressed: _busy ? null : () => _act('supply'),
                    child: const Text('Suprimento')),
                OutlinedButton(
                    onPressed: _busy ? null : () => _act('withdrawal'),
                    child: const Text('Sangria')),
                FilledButton(
                    onPressed: _busy ? null : () => _act('close'),
                    child: const Text('Fechar caixa')),
              ]),
              for (final row in (_active!['movements'] as List).reversed)
                ListTile(
                  dense: true,
                  title: Text(row['movement_type'] == 'supply'
                      ? 'Suprimento'
                      : 'Sangria'),
                  subtitle: Text('${row['reason']} · ${row['created_at']}'),
                  trailing: Text(_money(row['amount_cents'] as int)),
                ),
            ],
            if (_recent.isNotEmpty) ...[
              const Divider(),
              const Text('Últimos fechamentos',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              for (final session in _recent)
                ListTile(
                  dense: true,
                  title: Text(
                      'Caixa #${session['id']} · contado ${_money(session['counted_cents'] as int)}'),
                  subtitle: Text(
                      'Esperado ${_money(session['expected_cash_cents'] as int)} · diferença ${_money(session['difference_cents'] as int)} · ${session['closing_reason']}'),
                ),
            ],
          ]),
        ),
      );
}
