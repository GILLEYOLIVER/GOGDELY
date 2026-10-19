import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

// GOG-087/088: responsive operational preview. Financial figures are never
// presented as received money while payment and reconciliation are absent.
class ManagementDashboard extends StatefulWidget {
  const ManagementDashboard({
    super.key,
    required this.orders,
    required this.onOrders,
    required this.onMenu,
    required this.localMode,
  });
  final List<DemoOrder> orders;
  final VoidCallback onOrders;
  final VoidCallback onMenu;
  final bool localMode;

  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  int selectedDay = 6;

  @override
  Widget build(BuildContext context) {
    final active = widget.orders.where((o) => o.status != 'cancelled').toList();
    final count = widget.localMode ? active.length : 125;
    final estimated = widget.localMode
        ? active.fold<int>(0, (sum, o) => sum + o.totalCents)
        : 458000;
    final preparing = widget.localMode
        ? active.where((o) => o.status == 'preparing').length
        : 8;
    final ready =
        widget.localMode ? active.where((o) => o.status == 'ready').length : 4;
    final values = widget.localMode
        ? _lastSevenDays(widget.orders)
        : [11, 14, 17, 13, 19, 26, 25];
    final labels = widget.localMode
        ? _weekdayLabels()
        : ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        _pageHeading(
          context,
          'Visão geral',
          'Acompanhe o ritmo da operação em um só lugar.',
          widget.localMode ? 'AMOSTRA LOCAL' : 'PRÉVIA ILUSTRATIVA',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GogdelyColors.graphite,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 18,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BURGER HOUSE  ·  OPERAÇÃO',
                    style: TextStyle(
                      color: GogdelyColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tudo pronto para atender?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.localMode
                        ? 'Pedidos do laboratório local.'
                        : 'Explore os recursos com dados de exemplo.',
                    style: const TextStyle(
                      color: GogdelyColors.mutedDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: widget.onOrders,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: GogdelyColors.accent),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Ver pedidos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _sectionHeading(
          'Indicadores',
          widget.localMode ? 'Últimos pedidos locais' : 'Exemplo de 7 dias',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 900 ? 4 : 2;
            final gap = 12.0;
            final width = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: width,
                  child: _statCard(
                    context,
                    Icons.shopping_bag_outlined,
                    'Pedidos',
                    '$count',
                    'Na amostra',
                    colors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _statCard(
                    context,
                    Icons.payments_outlined,
                    'Volume previsto',
                    _money(estimated),
                    'Não recebido',
                    colors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _statCard(
                    context,
                    Icons.analytics_outlined,
                    'Ticket médio',
                    _money(count == 0 ? 0 : estimated ~/ count),
                    'Estimado',
                    colors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _statCard(
                    context,
                    Icons.restaurant_outlined,
                    'Em preparo',
                    '$preparing',
                    '$ready prontos',
                    colors.primary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _sectionHeading('Movimento de pedidos', 'Últimos 7 dias'),
        const SizedBox(height: 12),
        _panel(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: colors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Pedidos por dia',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${values[selectedDay]} pedidos',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 164,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Semantics(
                          label: '${labels[i]}: ${values[i]} pedidos',
                          button: true,
                          child: InkWell(
                            onTap: () => setState(() => selectedDay = i),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                          begin: .04,
                                          end: values.every((v) => v == 0)
                                              ? .04
                                              : (values[i] /
                                                      values.reduce(
                                                        (a, b) => a > b ? a : b,
                                                      ))
                                                  .clamp(.04, 1.0)),
                                      duration:
                                          const Duration(milliseconds: 520),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, fraction, child) =>
                                          FractionallySizedBox(
                                              heightFactor: fraction,
                                              child: child),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedDay == i
                                              ? colors.primary
                                              : colors.primary.withValues(
                                                  alpha: .25,
                                                ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(7),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selectedDay == i
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque em uma coluna para ver o total do dia.',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _sectionHeading('Fila de atendimento', 'Acesso rápido'),
        const SizedBox(height: 12),
        _panel(
          context,
          Column(
            children: [
              _actionRow(
                context,
                Icons.receipt_long_outlined,
                'Pedidos',
                'Acompanhar e atualizar etapas',
                widget.onOrders,
              ),
              const Divider(height: 1),
              _actionRow(
                context,
                Icons.restaurant_menu_outlined,
                'Cardápio',
                'Produtos, preços e disponibilidade',
                widget.onMenu,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _notice(
          context,
          widget.localMode
              ? 'Valores estimados dos pedidos locais. Nenhum pagamento foi liquidado.'
              : 'Números ilustrativos. Nenhum pedido ou pagamento real está conectado.',
        ),
      ],
    );
  }
}

class ManagementFinance extends StatefulWidget {
  const ManagementFinance({
    super.key,
    required this.orders,
    required this.localMode,
  });
  final List<DemoOrder> orders;
  final bool localMode;
  @override
  State<ManagementFinance> createState() => _ManagementFinanceState();
}

class _ManagementFinanceState extends State<ManagementFinance> {
  String selectedChannel = 'Todos';

  @override
  Widget build(BuildContext context) {
    final active = widget.orders.where((o) => o.status != 'cancelled').toList();
    final total = widget.localMode
        ? active.fold<int>(0, (sum, o) => sum + o.totalCents)
        : 458000;
    final channels = widget.localMode
        ? <String, int>{
            'Pix': active
                .where((o) => o.paymentMethod == 'pix')
                .fold(0, (s, o) => s + o.totalCents),
            'Cartão': active
                .where((o) => o.paymentMethod == 'card')
                .fold(0, (s, o) => s + o.totalCents),
            'Dinheiro': active
                .where((o) => o.paymentMethod == 'cash')
                .fold(0, (s, o) => s + o.totalCents),
            'Não definido': active
                .where(
                  (o) => !{'pix', 'card', 'cash'}.contains(o.paymentMethod),
                )
                .fold(0, (s, o) => s + o.totalCents),
          }
        : <String, int>{'Pix': 176000, 'Cartão': 158000, 'Dinheiro': 124000};
    final filtered = selectedChannel == 'Todos'
        ? channels.entries.toList()
        : channels.entries.where((e) => e.key == selectedChannel).toList();
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        _pageHeading(
          context,
          'Financeiro',
          'Entenda o volume dos pedidos e o que ainda precisa ser conciliado.',
          widget.localMode ? 'AMOSTRA LOCAL' : 'PRÉVIA ILUSTRATIVA',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            color: GogdelyColors.graphite,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: GogdelyColors.accent,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'VOLUME ESTIMADO',
                    style: TextStyle(
                      color: GogdelyColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                _money(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Soma de pedidos não cancelados. Não representa saldo disponível ou valor recebido.',
                style: TextStyle(color: GogdelyColors.mutedDark, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final width = (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: _statCard(
                    context,
                    Icons.receipt_long_outlined,
                    'Pedidos válidos',
                    '${widget.localMode ? active.length : 125}',
                    'Na amostra',
                    colors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _statCard(
                    context,
                    Icons.verified_outlined,
                    'Recebido',
                    '—',
                    'Sem integração',
                    colors.primary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 29),
        _sectionHeading(
          'Composição por forma de pagamento',
          'Valor pretendido',
        ),
        const SizedBox(height: 7),
        Text(
          'Esta visão não confirma cobrança, repasse nem liquidação.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final label in ['Todos', ...channels.keys])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selectedChannel == label,
                    onSelected: (_) => setState(() => selectedChannel = label),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          context,
          Column(
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                Row(
                  children: [
                    Container(
                      width: 37,
                      height: 37,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        _channelIcon(filtered[i].key),
                        color: colors.primary,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filtered[i].key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            total == 0
                                ? '0% do volume'
                                : '${(filtered[i].value * 100 / total).round()}% do volume',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(filtered[i].value),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : filtered[i].value / total,
                    minHeight: 5,
                    backgroundColor: colors.primary.withValues(alpha: .09),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 29),
        _sectionHeading('Conciliação', 'Ainda não conectada'),
        const SizedBox(height: 12),
        _panel(
          context,
          Column(
            children: [
              _infoRow(
                context,
                Icons.credit_card_off_outlined,
                'Captura e liquidação',
                'Aguardando provedor de pagamento',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                Icons.account_balance_outlined,
                'Repasse à loja',
                'Sem cálculo de taxas ou split',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                Icons.receipt_long_outlined,
                'Extrato e estornos',
                'Disponíveis após integração auditada',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _notice(
          context,
          widget.localMode
              ? 'Dados do laboratório local. Pagamentos marcados como simulados não são recebimentos reais.'
              : 'Prévia visual com valores fictícios. Nenhuma conta bancária ou transação está conectada.',
        ),
      ],
    );
  }
}

Widget _pageHeading(
  BuildContext context,
  String title,
  String subtitle,
  String badge,
) {
  final colors = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        badge,
        style: TextStyle(
          color: colors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
      ),
    ],
  );
}

Widget _sectionHeading(String title, String detail) => Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          detail,
          style: const TextStyle(fontSize: 11, color: GogdelyColors.mutedLight),
        ),
      ],
    );

Widget _panel(BuildContext context, Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: .5),
        ),
      ),
      child: child,
    );

Widget _statCard(
  BuildContext context,
  IconData icon,
  String label,
  String value,
  String detail,
  Color accent,
) {
  final colors = Theme.of(context).colorScheme;
  return Container(
    height: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: colors.outlineVariant.withValues(alpha: .5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
        ),
      ],
    ),
  );
}

Widget _actionRow(
  BuildContext context,
  IconData icon,
  String label,
  String subtitle,
  VoidCallback action,
) =>
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    );

Widget _infoRow(
  BuildContext context,
  IconData icon,
  String label,
  String subtitle,
) =>
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      isThreeLine: false,
    );

Widget _notice(BuildContext context, String text) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );

IconData _channelIcon(String channel) => switch (channel) {
      'Pix' => Icons.pix_outlined,
      'Cartão' => Icons.credit_card_outlined,
      'Dinheiro' => Icons.payments_outlined,
      _ => Icons.help_outline,
    };

String _money(int cents) =>
    'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

List<int> _lastSevenDays(List<DemoOrder> orders) {
  final today = DateTime.now();
  final result = List<int>.filled(7, 0);
  for (final order in orders) {
    final date = DateTime.tryParse(order.createdAt)?.toLocal();
    if (date == null || date.isAfter(today)) continue;
    final day = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (day >= 0 && day < 7) result[6 - day]++;
  }
  return result;
}

List<String> _weekdayLabels() {
  const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  final today = DateTime.now();
  return [
    for (var daysAgo = 6; daysAgo >= 0; daysAgo--)
      names[today.subtract(Duration(days: daysAgo)).weekday - 1],
  ];
}
