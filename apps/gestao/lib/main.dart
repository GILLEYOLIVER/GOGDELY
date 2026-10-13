import 'dart:async';
import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';
import 'stock_page.dart';
import 'menu_editor.dart';
import 'table_qr_page.dart';
import 'pos_page.dart';

void main() => runApp(const GestaoApp());

class GestaoApp extends StatefulWidget {
  const GestaoApp({super.key});
  @override
  State<GestaoApp> createState() => _GestaoAppState();
}

class _GestaoAppState extends State<GestaoApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GOGDELY Gestão',
        debugShowCheckedModeBanner: false,
        theme: gogdelyTheme(Brightness.light),
        darkTheme: gogdelyTheme(Brightness.dark),
        themeMode: mode,
        home: GestaoHome(
            themeMode: mode,
            onThemeChanged: (value) => setState(() => mode = value)),
      );
}

enum ManagementPage {
  dashboard,
  orders,
  menu,
  tables,
  kds,
  pos,
  stock,
  reports,
  finance,
  settings,
  login
}

class GestaoHome extends StatefulWidget {
  const GestaoHome(
      {super.key,
      required this.themeMode,
      required this.onThemeChanged,
      this.localApi});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final LocalDemoApi? localApi;
  @override
  State<GestaoHome> createState() => _GestaoHomeState();
}

class _GestaoHomeState extends State<GestaoHome> {
  late final LocalDemoApi _localApi = widget.localApi ?? LocalDemoApi();
  Timer? _localRefreshTimer;
  int _refreshRequest = 0;
  bool _refreshingOrders = false;
  List<DemoOrder> _localOrders = const [];
  String? _localError;
  int? _updatingId;
  List<String> _paymentMethods = const ['cash', 'pix', 'card'];
  List<String> _paymentMethodsDraft = const ['cash', 'pix', 'card'];
  String? _paymentSettingsError;
  bool _savingPaymentSettings = false;
  Map<String, dynamic>? _ratingsSummary;
  bool _refreshingRatings = false;
  ManagementPage page = ManagementPage.dashboard;
  final List<String> saleItems = [];
  final List<int> kitchenSteps = [0, 1, 2];
  String orderFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    if (localDemoEnabled) {
      _refreshLocalOrders();
      _refreshRatings();
      _localRefreshTimer = Timer.periodic(localDemoRefreshInterval, (_) {
        if ({
          ManagementPage.dashboard,
          ManagementPage.orders,
          ManagementPage.kds,
          ManagementPage.reports
        }.contains(page)) _refreshLocalOrders();
        if ({ManagementPage.dashboard, ManagementPage.reports}.contains(page))
          _refreshRatings();
      });
    }
  }

  void go(ManagementPage value) {
    setState(() => page = value);
    if (localDemoEnabled &&
        {ManagementPage.orders, ManagementPage.kds, ManagementPage.reports}
            .contains(value))
      _refreshLocalOrders();
    if (localDemoEnabled &&
        {ManagementPage.dashboard, ManagementPage.reports}.contains(value))
      _refreshRatings();
    if (localDemoEnabled && value == ManagementPage.settings)
      _refreshPaymentMethods();
  }

  Future<void> _refreshRatings() async {
    if (_refreshingRatings) return;
    _refreshingRatings = true;
    try {
      final summary = await _localApi.storeRatings();
      if (mounted &&
          ((summary['count'] as int?) != (_ratingsSummary?['count'] as int?) ||
              summary['average_stars'] != _ratingsSummary?['average_stars'])) {
        setState(() => _ratingsSummary = summary);
      }
    } catch (_) {
      // Avaliação é complemento; falha não bloqueia o painel local.
    } finally {
      _refreshingRatings = false;
    }
  }

  Future<void> _refreshPaymentMethods() async {
    try {
      final methods = await _localApi.paymentMethods();
      if (mounted)
        setState(() {
          _paymentMethods = methods;
          _paymentMethodsDraft = List.of(methods);
          _paymentSettingsError = null;
        });
    } catch (error) {
      if (mounted) setState(() => _paymentSettingsError = '$error');
    }
  }

  Future<void> _savePaymentMethods() async {
    if (_savingPaymentSettings) return;
    setState(() => _savingPaymentSettings = true);
    try {
      final methods = await _localApi.savePaymentMethods(_paymentMethodsDraft);
      if (mounted)
        setState(() {
          _paymentMethods = methods;
          _paymentMethodsDraft = List.of(methods);
          _paymentSettingsError = null;
        });
    } catch (error) {
      if (mounted) setState(() => _paymentSettingsError = '$error');
    } finally {
      if (mounted) setState(() => _savingPaymentSettings = false);
    }
  }

  @override
  void dispose() {
    _localRefreshTimer?.cancel();
    _localApi.close();
    super.dispose();
  }

  Future<void> _refreshLocalOrders() async {
    if (_refreshingOrders) return;
    _refreshingOrders = true;
    final request = ++_refreshRequest;
    try {
      final orders = await _localApi.orders(storeId: localDemoPilotStoreId);
      if (mounted &&
          request == _refreshRequest &&
          (_localError != null || !_sameOrders(_localOrders, orders))) {
        setState(() {
          _localOrders = orders;
          _localError = null;
        });
      }
    } catch (error) {
      if (mounted && request == _refreshRequest && _localError != '$error') {
        setState(() => _localError = '$error');
      }
    } finally {
      _refreshingOrders = false;
    }
  }

  bool _sameOrders(List<DemoOrder> current, List<DemoOrder> incoming) {
    if (current.length != incoming.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != incoming[i].id ||
          current[i].status != incoming[i].status ||
          current[i].dispatchMode != incoming[i].dispatchMode ||
          current[i].kitchenPriority != incoming[i].kitchenPriority ||
          current[i].paymentStatus != incoming[i].paymentStatus) {
        return false;
      }
    }
    return true;
  }

  Future<void> _advanceLocalOrder(DemoOrder order) async {
    final next = order.status == 'created'
        ? 'preparing'
        : order.status == 'preparing'
            ? 'ready'
            : order.orderChannel == 'pickup'
                ? 'picked_up'
                : 'served';
    String? pickupCode;
    if (next == 'picked_up') {
      final controller = TextEditingController();
      pickupCode = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Conferir retirada #${order.id}'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos mostrado ao cliente',
                    helperText:
                        'Conferência local; não substitui identificação real.',
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Voltar')),
                  FilledButton(
                      onPressed: () {
                        if (RegExp(r'^\d{6}$')
                            .hasMatch(controller.text.trim())) {
                          Navigator.pop(context, controller.text.trim());
                        }
                      },
                      child: const Text('Confirmar retirada')),
                ],
              ));
      controller.dispose();
      if (pickupCode == null || !mounted) return;
    }
    setState(() => _updatingId = order.id);
    try {
      await _localApi.updateStatus(order.id, next, 'management',
          pickupCode: pickupCode);
      await _refreshLocalOrders();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _dispatchLocalOrder(DemoOrder order) async {
    setState(() => _updatingId = order.id);
    try {
      await _localApi.dispatchInternal(order.id);
      await _refreshLocalOrders();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _showOrderHistory(DemoOrder order) async {
    try {
      final events = await _localApi.orderEvents(order.id);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Histórico do pedido #${order.id}'),
                content: SizedBox(
                    width: 420,
                    child: events.isEmpty
                        ? const Text(
                            'Histórico anterior indisponível para este pedido.')
                        : ListView(shrinkWrap: true, children: [
                            for (final event in events)
                              ListTile(
                                title: Text(
                                    event.fromStatus == event.toStatus &&
                                            event.reason.isNotEmpty
                                        ? event.reason
                                        : demoStatusLabel(event.toStatus)),
                                subtitle: Text(
                                    '${demoActorLabel(event.actor)} · ${event.createdAt.replaceFirst('T', ' ').split('.').first}'
                                    '${event.reason.isEmpty || event.fromStatus == event.toStatus ? '' : '\nMotivo: ${event.reason}'}'),
                              ),
                          ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'))
                ],
              ));
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    }
  }

  Future<void> _cancelLocalOrder(DemoOrder order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Cancelar pedido #${order.id}?'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 300,
                  decoration: const InputDecoration(
                      labelText: 'Motivo do cancelamento')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().length >= 3)
                        Navigator.pop(context, controller.text.trim());
                    },
                    child: const Text('Confirmar cancelamento')),
              ],
            ));
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _updatingId = order.id);
    try {
      await _localApi.cancelOrder(order.id, 'management', reason);
      await _refreshLocalOrders();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _setKitchenPriority(DemoOrder order) async {
    final priority = order.kitchenPriority == 'urgent' ? 'normal' : 'urgent';
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(priority == 'urgent'
                  ? 'Priorizar pedido #${order.id}'
                  : 'Voltar pedido #${order.id} à ordem normal'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 300,
                decoration: const InputDecoration(
                    labelText: 'Motivo da mudança de prioridade'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().length >= 3) {
                        Navigator.pop(context, controller.text.trim());
                      }
                    },
                    child: const Text('Salvar prioridade')),
              ],
            ));
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _updatingId = order.id);
    try {
      await _localApi.setKitchenPriority(
          orderId: order.id, priority: priority, reason: reason);
      await _refreshLocalOrders();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  /// Explicit laboratory declaration only: no provider, charge or settlement.
  Future<void> _simulateLocalPayment(DemoOrder order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Registrar pagamento simulado #${order.id}?'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'Declaração local de teste para ${demoPaymentLabel(order.paymentMethod)} · '
                    '${money(order.totalCents)}. Nada é cobrado, transferido ou confirmado '
                    'financeiramente; nenhum provedor de pagamento é acionado.',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 300,
                    decoration: const InputDecoration(
                        labelText: 'Motivo da declaração',
                        helperText:
                            'Registro de laboratório; fica no histórico do pedido.')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().length >= 3)
                        Navigator.pop(context, controller.text.trim());
                    },
                    child: const Text('Registrar simulação')),
              ],
            ));
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _updatingId = order.id);
    try {
      await _localApi.simulatePayment(
          orderId: order.id, requestKey: newDemoRequestKey(), reason: reason);
      await _refreshLocalOrders();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  /// GOG-031 local: opens the printable kitchen ticket in the default browser.
  void _openComanda(DemoOrder order) {
    final url = '$localDemoBaseUrl/api/v1/local/orders/${order.id}/comanda';
    unawaited(_launchUrl(url));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Comanda #${order.id} aberta no navegador para impressão local. $url')));
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      }
    } catch (_) {
      // Abrir o navegador é best-effort; a URL também é exibida no aviso.
    }
  }

  String _localOrderTime(DemoOrder order) {
    final date = DateTime.tryParse(order.createdAt)?.toLocal();
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)} · ';
  }

  String _scheduleLabel(DemoOrder order) {
    final slot = DateTime.tryParse(order.scheduledFor ?? '')?.toLocal();
    if (slot == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return ' · agendado ${two(slot.day)}/${two(slot.month)} ${two(slot.hour)}:${two(slot.minute)}';
  }

  int _countLocalStatuses(Set<String> statuses) =>
      _localOrders.where((order) => statuses.contains(order.status)).length;

  Widget _localOrdersPanel(
      {bool oldestFirst = false, bool kitchenOnly = false, int? maxItems}) {
    final ordered = oldestFirst ? _localOrders.reversed : _localOrders;
    final visible = ordered
        .where((order) =>
            !kitchenOnly ||
            {'created', 'preparing'}.contains(order.status) ||
            (order.status == 'ready' &&
                (order.orderChannel != 'delivery' ||
                    order.dispatchMode == 'pending')))
        .toList();
    if (kitchenOnly) {
      visible.sort((a, b) {
        final urgency = (b.kitchenPriority == 'urgent' ? 1 : 0)
            .compareTo(a.kitchenPriority == 'urgent' ? 1 : 0);
        return urgency != 0 ? urgency : a.id.compareTo(b.id);
      });
    }
    if (maxItems != null && visible.length > maxItems) {
      visible.removeRange(maxItems, visible.length);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                kitchenOnly
                    ? 'Fila da cozinha'
                    : 'Pedidos salvos no banco local',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800))),
        IconButton(
            tooltip: 'Atualizar pedidos locais',
            onPressed: _refreshLocalOrders,
            icon: const Icon(Icons.refresh)),
      ]),
      if (_localError != null)
        Text(_localError!, style: const TextStyle(color: Colors.red)),
      if (visible.isEmpty)
        Text(kitchenOnly
            ? 'Nenhum pedido aguardando preparo ou retirada da cozinha.'
            : 'Nenhum pedido local salvo. Crie no Cliente ou pelo QR de uma mesa.'),
      for (final order in visible)
        Card(
            child: ListTile(
          title: Text(
              '${order.kitchenPriority == 'urgent' ? 'PRIORITÁRIO · ' : ''}#${order.id} · ${order.storeName}'
              '${order.tableCode != null ? ' · Mesa ${order.tableCode}' : order.orderChannel == 'pickup' ? ' · Retirada' : order.orderChannel == 'counter' ? ' · Balcão' : ' · Entrega'}'),
          subtitle: Text(
              '${order.items.map((item) => '${item.quantity} × ${item.name}').join(', ')}\n'
              '${_localOrderTime(order)}${demoStatusLabel(order.status)}${_scheduleLabel(order)} · ${money(order.totalCents)}\n'
              '${demoPaymentLabel(order.paymentMethod)} · pagamento ${demoPaymentStatusLabel(order.paymentStatus)}'),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            ({'created', 'preparing'}.contains(order.status) ||
                    ({'table', 'pickup', 'counter'}
                            .contains(order.orderChannel) &&
                        order.status == 'ready') ||
                    (order.orderChannel == 'delivery' &&
                        order.status == 'ready' &&
                        order.dispatchMode == 'pending'))
                ? FilledButton(
                    onPressed: _updatingId == order.id
                        ? null
                        : () => order.orderChannel == 'delivery' &&
                                order.status == 'ready'
                            ? _dispatchLocalOrder(order)
                            : _advanceLocalOrder(order),
                    child: Text(order.status == 'created'
                        ? 'Iniciar preparo'
                        : order.status == 'preparing'
                            ? 'Marcar pronto'
                            : order.orderChannel == 'delivery'
                                ? 'Enviar ao Entregador'
                                : order.orderChannel == 'pickup'
                                    ? 'Entregar na loja'
                                    : order.orderChannel == 'counter'
                                        ? 'Entregar no balcão'
                                        : 'Servir mesa'),
                  )
                : _statusPill(order.status == 'ready' &&
                        order.orderChannel == 'delivery' &&
                        order.dispatchMode == 'internal'
                    ? 'Enviado ao entregador'
                    : demoStatusLabel(order.status)),
            PopupMenuButton<String>(
              tooltip: 'Ações do pedido',
              onSelected: (action) => switch (action) {
                    'history' => _showOrderHistory(order),
                    'comanda' => _openComanda(order),
                    'priority' => _setKitchenPriority(order),
                    'simulate' => _simulateLocalPayment(order),
                    _ => _cancelLocalOrder(order),
                  },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'history', child: Text('Ver histórico')),
                const PopupMenuItem(
                    value: 'comanda', child: Text('Imprimir comanda')),
                if (kitchenOnly &&
                    {'created', 'preparing'}.contains(order.status))
                  PopupMenuItem(
                      value: 'priority',
                      child: Text(order.kitchenPriority == 'urgent'
                          ? 'Voltar à ordem normal'
                          : 'Marcar prioritário')),
                if (order.status != 'cancelled' &&
                    order.paymentMethod != 'unselected' &&
                    !order.paymentSimulated)
                  const PopupMenuItem(
                      value: 'simulate',
                      child: Text('Registrar pagamento simulado')),
                if ({'created', 'preparing'}.contains(order.status))
                  const PopupMenuItem(
                      value: 'cancel', child: Text('Cancelar pedido')),
              ],
            ),
          ]),
        )),
      const Divider(),
    ]);
  }

  int get saleTotal => saleItems.fold(
      0,
      (sum, value) =>
          sum +
          switch (value) {
            'X-Tudo' => 2890,
            'Batata Especial' => 1890,
            'Refrigerante Lata' => 690,
            _ => 0,
          });
  String money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (page == ManagementPage.login) return _login();
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: Text(_title()),
              leading: Builder(
                  builder: (context) => IconButton(
                      tooltip: 'Abrir menu',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer()))),
      drawer: wide ? null : Drawer(child: _menuContent()),
      body: Row(children: [
        if (wide) SizedBox(width: 205, child: _menuContent()),
        Expanded(
            child: Column(children: [
          if (wide) _topBar(),
          Expanded(child: _content()),
        ])),
      ]),
    );
  }

  String _title() => switch (page) {
        ManagementPage.dashboard => 'Dashboard',
        ManagementPage.orders => 'Pedidos',
        ManagementPage.menu => 'Cardápio',
        ManagementPage.tables => 'Mesas QR',
        ManagementPage.kds => 'KDS (Cozinha)',
        ManagementPage.pos => 'PDV',
        ManagementPage.stock => 'Estoque',
        ManagementPage.reports => 'Relatórios',
        ManagementPage.finance => 'Financeiro',
        ManagementPage.settings => 'Configurações',
        ManagementPage.login => 'Entrar',
      };

  Widget _menuContent() => Container(
        color: GogdelyColors.graphite,
        child: SafeArea(
            child: Column(children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 22, 16, 14),
              child: Text('gogdely.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900))),
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Sistema de Gestão',
                  style: TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(
              child: ListView(children: [
            _menuItem(ManagementPage.dashboard, Icons.dashboard_outlined),
            _menuItem(ManagementPage.orders, Icons.receipt_long_outlined),
            _menuItem(ManagementPage.menu, Icons.restaurant_menu_outlined),
            _menuItem(ManagementPage.tables, Icons.qr_code_2_outlined),
            _menuItem(ManagementPage.kds, Icons.kitchen_outlined),
            _menuItem(ManagementPage.pos, Icons.point_of_sale_outlined),
            _menuItem(ManagementPage.stock, Icons.inventory_2_outlined),
            _menuItem(ManagementPage.reports, Icons.bar_chart_outlined),
            _menuItem(
                ManagementPage.finance, Icons.account_balance_wallet_outlined),
            _menuItem(ManagementPage.settings, Icons.settings_outlined),
          ])),
          const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Prévia local · dados fictícios',
                  style: TextStyle(color: Colors.white60, fontSize: 10))),
        ])),
      );

  Widget _menuItem(ManagementPage target, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
            color: page == target ? GogdelyColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            child: ListTile(
              dense: true,
              leading: Icon(icon, color: Colors.white, size: 18),
              title: Text(
                  target == ManagementPage.kds
                      ? 'KDS (Cozinha)'
                      : _name(target),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              onTap: () {
                go(target);
                if (MediaQuery.sizeOf(context).width < 720) {
                  Navigator.pop(context);
                }
              },
            )),
      );

  String _name(ManagementPage target) => switch (target) {
        ManagementPage.dashboard => 'Dashboard',
        ManagementPage.orders => 'Pedidos',
        ManagementPage.menu => 'Cardápio',
        ManagementPage.tables => 'Mesas QR',
        ManagementPage.stock => 'Estoque',
        ManagementPage.reports => 'Relatórios',
        ManagementPage.finance => 'Financeiro',
        ManagementPage.settings => 'Configurações',
        ManagementPage.pos => 'PDV',
        ManagementPage.kds => 'KDS (Cozinha)',
        ManagementPage.login => 'Entrar',
      };

  Widget _topBar() => Container(
        height: 57,
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text(_title(),
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const Spacer(),
          const Text('Unidade Centro · demonstração',
              style: TextStyle(fontSize: 11)),
          const SizedBox(width: 12),
          const CircleAvatar(
              radius: 16,
              backgroundColor: GogdelyColors.blue,
              child: Text('A', style: TextStyle(color: Colors.white))),
        ]),
      );

  Widget _content() => switch (page) {
        ManagementPage.dashboard => _dashboard(),
        ManagementPage.orders => _orders(),
        ManagementPage.menu => MenuEditorPage(api: _localApi),
        ManagementPage.tables => const TableQrPage(),
        ManagementPage.kds => _kds(),
        ManagementPage.pos => _pos(),
        ManagementPage.stock =>
          StockPage(api: _localApi, onEditMenu: () => go(ManagementPage.menu)),
        ManagementPage.reports => _reports(),
        ManagementPage.finance => _finance(),
        ManagementPage.settings => _settings(),
        ManagementPage.login => _login(),
      };

  Widget _scroll(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(18), children: children);

  Widget _label(String value) => Padding(
      padding: const EdgeInsets.only(top: 17, bottom: 10),
      child: Text(value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));

  Widget _metric(String label, String value, IconData icon, String detail) =>
      Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: GogdelyColors.blue),
                const Spacer(),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 10, color: GogdelyColors.blue))
              ]),
              const SizedBox(height: 10),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w900)),
            ])),
      );

  Widget _dashboard() => localDemoEnabled
      ? _scroll([
          const Text(
              'Burger House · empresa piloto. Últimos 100 pedidos locais; nenhum pagamento foi processado.'),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
                width: 170,
                child: _metric('Novos', '${_countLocalStatuses({'created'})}',
                    Icons.new_releases_outlined, 'Agora')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Em preparo',
                    '${_countLocalStatuses({'preparing'})}',
                    Icons.kitchen_outlined,
                    'Agora')),
            SizedBox(
                width: 170,
                child: _metric('Prontos', '${_countLocalStatuses({'ready'})}',
                    Icons.task_alt_outlined, 'Agora')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Em rota',
                    '${_countLocalStatuses({'in_delivery'})}',
                    Icons.delivery_dining,
                    'Agora')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Concluídos',
                    '${_countLocalStatuses({
                          'delivered',
                          'served',
                          'picked_up'
                        })}',
                    Icons.check_circle_outline,
                    'Local')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Cancelados',
                    '${_countLocalStatuses({'cancelled'})}',
                    Icons.cancel_outlined,
                    'Local')),
          ]),
          SizedBox(
              width: 350,
              child: _metric(
                  'Soma estimada sem cancelados',
                  money(_localOrders
                      .where((order) => order.status != 'cancelled')
                      .fold(0, (sum, order) => sum + order.totalCents)),
                  Icons.receipt_long_outlined,
                  'Não recebido')),
          SizedBox(
              width: 170,
              child: _metric(
                  'Avaliação média',
                  (_ratingsSummary?['count'] as int? ?? 0) > 0
                      ? '⭐ ${_ratingsSummary!['average_stars']}'
                      : 'Sem notas',
                  Icons.star_outline,
                  '${_ratingsSummary?['count'] ?? 0} locais')),
          _localOrdersPanel(maxItems: 10),
        ])
      : _scroll([
          const Text('Bom dia! Confira sua operação.',
              style: TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                      crossAxisCount: constraints.maxWidth > 780 ? 4 : 2,
                      childAspectRatio: constraints.maxWidth > 780 ? 1.4 : 1.2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _metric('Pedidos hoje', '125',
                            Icons.shopping_bag_outlined, '+12%'),
                        _metric('Faturamento fictício', 'R\$ 4.580',
                            Icons.payments_outlined, '+8%'),
                        _metric('Ticket médio', 'R\$ 36,64',
                            Icons.analytics_outlined, '+5%'),
                        _metric(
                            'Em preparo', '8', Icons.kitchen_outlined, 'Agora'),
                      ])),
          _label('Pedidos nas últimas 24h'),
          Card(
              child: SizedBox(
                  height: 170,
                  child: CustomPaint(
                      painter: _DashboardChartPainter(),
                      child: const Center(child: Text(''))))),
          _label('Pedidos recentes'),
          for (final (number, name, state) in [
            ('#12345', 'João Silva', 'Em preparo'),
            ('#12344', 'Maria Souza', 'Pronto'),
            ('#12343', 'Pedro Lima', 'Entrega'),
          ])
            Card(
                child: ListTile(
                    title: Text('$number · $name'),
                    trailing: _statusPill(state),
                    onTap: () => go(ManagementPage.orders))),
          const SizedBox(height: 12),
          const Text(
              'Indicadores exclusivamente fictícios; sem acesso a dados de empresas.',
              style: TextStyle(fontSize: 11)),
        ]);

  Widget _statusPill(String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xFFDDE8FF),
            borderRadius: BorderRadius.circular(20)),
        child: Text(value,
            style: const TextStyle(
                color: GogdelyColors.blue,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      );

  Widget _orders() => localDemoEnabled
      ? _scroll([_localOrdersPanel()])
      : _scroll([
          Wrap(spacing: 7, children: [
            for (final name in ['Todos', 'Em preparo', 'Prontos', 'Entregues'])
              ChoiceChip(
                  label: Text(name),
                  selected: orderFilter == name,
                  onSelected: (_) => setState(() => orderFilter = name)),
          ]),
          _label('Pedidos de demonstração'),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: const [
                DataColumn(label: Text('Pedido')),
                DataColumn(label: Text('Cliente')),
                DataColumn(label: Text('Itens')),
                DataColumn(label: Text('Valor')),
                DataColumn(label: Text('Status')),
              ], rows: [
                for (final (number, name, count, value, status) in [
                  ('#12345', 'João Silva', '3', 'R\$ 67,69', 'Em preparo'),
                  ('#12344', 'Maria Souza', '2', 'R\$ 45,00', 'Pronto'),
                  ('#12343', 'Pedro Lima', '4', 'R\$ 86,25', 'Entrega'),
                  ('#12342', 'Ana Costa', '1', 'R\$ 32,90', 'Entregue'),
                ])
                  if (orderFilter == 'Todos' ||
                      (orderFilter == 'Em preparo' && status == 'Em preparo') ||
                      (orderFilter == 'Prontos' && status == 'Pronto') ||
                      (orderFilter == 'Entregues' && status == 'Entregue'))
                    DataRow(cells: [
                      DataCell(Text(number)),
                      DataCell(Text(name)),
                      DataCell(Text(count)),
                      DataCell(Text(value)),
                      DataCell(_statusPill(status))
                    ]),
              ])),
        ]);

  Widget _kds() => localDemoEnabled
      ? _scroll([_localOrdersPanel(oldestFirst: true, kitchenOnly: true)])
      : _scroll([
          const Text('Fila ilustrativa por etapa',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                    itemCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth > 750 ? 3 : 1,
                        childAspectRatio:
                            constraints.maxWidth > 750 ? 1.0 : 1.65,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10),
                    itemBuilder: (context, i) => Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text('#${12345 - i}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    const Spacer(),
                                    _statusPill([
                                      'Novo',
                                      'Em preparo',
                                      'Pronto'
                                    ][kitchenSteps[i]])
                                  ]),
                                  const SizedBox(height: 10),
                                  Text([
                                    'João Silva',
                                    'Maria Souza',
                                    'Pedro Lima'
                                  ][i]),
                                  const SizedBox(height: 9),
                                  Text([
                                    '1 × X-Tudo\n1 × Batata Especial',
                                    '1 × Pizza Margherita\n1 × Refrigerante',
                                    '1 × Sushi Combo'
                                  ][i]),
                                  const Spacer(),
                                  SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: kitchenSteps[i] >= 2
                                            ? null
                                            : () => setState(
                                                () => kitchenSteps[i]++),
                                        child: Text(kitchenSteps[i] == 0
                                            ? 'Iniciar preparo'
                                            : kitchenSteps[i] == 1
                                                ? 'Marcar pronto'
                                                : 'Pronto'),
                                      )),
                                ]))),
                  )),
          const SizedBox(height: 12),
          const Text(
              'Mudanças somente nesta sessão; não alteram pedidos reais.',
              style: TextStyle(fontSize: 11)),
        ]);

  Widget _pos() => localDemoEnabled
      ? PosPage(api: _localApi, onSaleCreated: _refreshLocalOrders)
      : _scroll([
          const Text('Ponto de venda demonstrativo',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (name, image, price) in [
              ('X-Tudo', 'assets/images/burger.png', 'R\$ 28,90'),
              ('Batata Especial', '', 'R\$ 18,90'),
              ('Refrigerante Lata', '', 'R\$ 6,90'),
            ])
              SizedBox(
                  width: 135,
                  child: Card(
                      child: InkWell(
                    onTap: () => setState(() => saleItems.add(name)),
                    child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Column(children: [
                          image.isEmpty
                              ? const SizedBox(
                                  height: 65,
                                  child: Icon(Icons.shopping_bag_outlined,
                                      size: 35, color: GogdelyColors.blue))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(image,
                                      width: 115,
                                      height: 65,
                                      fit: BoxFit.cover)),
                          const SizedBox(height: 5),
                          Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(price, style: const TextStyle(fontSize: 11)),
                        ])),
                  ))),
          ]),
          _label('Venda local'),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(children: [
                    if (saleItems.isEmpty)
                      const Text('Selecione um produto para começar'),
                    for (final item in saleItems)
                      ListTile(
                          title: Text(item),
                          trailing: IconButton(
                              tooltip: 'Remover $item',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => saleItems.remove(item)))),
                    const Divider(),
                    Row(children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text(money(saleTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800))
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: saleItems.isEmpty
                                ? null
                                : () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text(
                                            'PDV fictício: nenhuma venda ou pagamento foi registrado.'))),
                            child: const Text('Revisar venda fictícia'))),
                  ]))),
        ]);

  Widget _reports() => localDemoEnabled
      ? _scroll([
          const Text(
              'Relatórios do SQLite local · volume estimado, sem faturamento recebido',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          if (_localError != null)
            Text(_localError!, style: const TextStyle(color: Colors.red)),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
                width: 170,
                child: _metric('Pedidos totais', '${_localOrders.length}',
                    Icons.receipt_long_outlined, 'Local')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Ativos',
                    '${_localOrders.where((order) => order.status != 'cancelled').length}',
                    Icons.pending_outlined,
                    'Local')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Volume estimado',
                    money(_localOrders
                        .where((order) => order.status != 'cancelled')
                        .fold(0, (sum, order) => sum + order.totalCents)),
                    Icons.payments_outlined,
                    'Não recebido')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Ticket médio',
                    money(_localOrders
                                .where((order) => order.status != 'cancelled')
                                .isEmpty
                        ? 0
                        : _localOrders
                                .where((order) => order.status != 'cancelled')
                                .fold(0, (sum, order) => sum + order.totalCents) ~/
                            _localOrders
                                .where((order) => order.status != 'cancelled')
                                .length),
                    Icons.analytics_outlined,
                    'Local')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Pagamentos simulados',
                    '${_localOrders.where((order) => order.paymentSimulated).length}',
                    Icons.payments,
                    'Sem cobrança')),
            SizedBox(
                width: 170,
                child: _metric(
                    'Avaliação média',
                    (_ratingsSummary?['count'] as int? ?? 0) > 0
                        ? '⭐ ${_ratingsSummary!['average_stars']}'
                        : 'Sem notas',
                    Icons.star_outline,
                    '${_ratingsSummary?['count'] ?? 0} locais')),
          ]),
          _label('Pedidos por canal'),
          Card(
              child: Column(children: [
            for (final (label, channel) in [
              ('Entrega', 'delivery'),
              ('Retirada', 'pickup'),
              ('Mesa', 'table'),
              ('Balcão', 'counter'),
            ])
              ListTile(
                  dense: true,
                  title: Text(label),
                  trailing: Text(
                      '${_localOrders.where((order) => order.orderChannel == channel && order.status != 'cancelled').length}'),
                  subtitle: Text(
                      'cancelados: ${_localOrders.where((order) => order.orderChannel == channel && order.status == 'cancelled').length}')),
          ])),
          _label('Formas pretendidas de pagamento'),
          Card(
              child: Column(children: [
            for (final method in ['cash', 'pix', 'card', 'unselected'])
              ListTile(
                  dense: true,
                  title: Text(demoPaymentLabel(method)),
                  trailing: Text(
                      '${_localOrders.where((order) => order.paymentMethod == method && order.status != 'cancelled').length}'),
                  subtitle: method == 'unselected'
                      ? const Text('mesa e canais sem escolha')
                      : null),
          ])),
          const SizedBox(height: 6),
          const Text(
              'Consulta dos últimos 100 pedidos do banco local. Não há recebimento, conciliação financeira ou emisso fiscal.',
              style: TextStyle(fontSize: 11)),
        ])
      : _scroll([
          const Text('Relatórios ilustrativos', style: TextStyle(fontSize: 12)),
          _label('Vendas da semana'),
          Card(
              child: SizedBox(
                  height: 210,
                  child: CustomPaint(painter: _DashboardChartPainter()))),
          const SizedBox(height: 10),
          _metric(
              'Faturamento fictício', 'R\$ 24.580', Icons.trending_up, '+12%'),
          _metric('Pedidos fictícios', '680', Icons.receipt_long_outlined, '+8%'),
        ]);

  Widget _finance() => _scroll([
        const Text('Valores demonstrativos · sem conciliação ou transações',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        _metric('Saldo total fictício', 'R\$ 12.450',
            Icons.account_balance_wallet_outlined, 'Exemplo'),
        _metric('Entradas fictícias', 'R\$ 28.900', Icons.arrow_downward,
            'Exemplo'),
        _metric(
            'Saídas fictícias', 'R\$ 16.450', Icons.arrow_upward, 'Exemplo'),
        _label('Atividade de demonstração'),
        Card(
            child: SizedBox(
                height: 170,
                child: CustomPaint(painter: _DashboardChartPainter()))),
      ]);

  Widget _settings() => _scroll([
        if (localDemoEnabled) ...[
          _label('Pagamentos da Burger House · teste local'),
          const Text(
              'Escolha quais opções aparecem ao Cliente. Nenhum pagamento é processado.'),
          if (_paymentSettingsError != null)
            Text(_paymentSettingsError!,
                style: const TextStyle(color: Colors.red)),
          for (final method in ['cash', 'pix', 'card'])
            CheckboxListTile(
              title: Text(demoPaymentLabel(method)),
              value: _paymentMethodsDraft.contains(method),
              onChanged: (enabled) {
                if (enabled == false && _paymentMethodsDraft.length == 1)
                  return;
                setState(() {
                  final selected = _paymentMethodsDraft.toSet();
                  if (enabled == true) {
                    selected.add(method);
                  } else {
                    selected.remove(method);
                  }
                  _paymentMethodsDraft =
                      ['cash', 'pix', 'card'].where(selected.contains).toList();
                });
              },
            ),
          FilledButton.icon(
            onPressed: _savingPaymentSettings ||
                    _paymentMethodsDraft.join(',') == _paymentMethods.join(',')
                ? null
                : _savePaymentMethods,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar formas de pagamento'),
          ),
          const Divider(),
        ],
        _label('Aparência'),
        for (final (mode, label) in [
          (ThemeMode.system, 'Automático'),
          (ThemeMode.light, 'Claro'),
          (ThemeMode.dark, 'Escuro'),
        ])
          ListTile(
              title: Text(label),
              trailing: Icon(
                  widget.themeMode == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: GogdelyColors.blue),
              onTap: () => widget.onThemeChanged(mode)),
        _label('Empresa'),
        const Card(
            child: ListTile(
                leading: Icon(Icons.storefront),
                title: Text('Nome do estabelecimento'),
                subtitle: Text('Configuração fictícia'))),
        const Card(
            child: ListTile(
                leading: Icon(Icons.devices),
                title: Text('Dispositivos'),
                subtitle: Text('Sem conexão a dispositivos reais'))),
        TextButton(
            onPressed: () => go(ManagementPage.login),
            child: const Text('Ver login demonstrativo')),
      ]);

  Widget _login() => Scaffold(
        backgroundColor: GogdelyColors.graphite,
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(25),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('gogdely.',
                              style: TextStyle(
                                  fontSize: 31,
                                  color: GogdelyColors.blue,
                                  fontWeight: FontWeight.w900)),
                          const Text('Sistema de Gestão'),
                          const SizedBox(height: 22),
                          const TextField(
                              decoration: InputDecoration(labelText: 'E-mail')),
                          const SizedBox(height: 8),
                          const TextField(
                              obscureText: true,
                              decoration: InputDecoration(labelText: 'Senha')),
                          const SizedBox(height: 15),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Login não conectado nesta prévia.'))),
                                  child: const Text('Entrar'))),
                          TextButton(
                              onPressed: () => go(ManagementPage.dashboard),
                              child: const Text('Explorar demonstração')),
                        ]))))),
      );
}

class _DashboardChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = GogdelyColors.blue.withValues(alpha: .10)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), grid);
    }
    final line = Path()
      ..moveTo(12, size.height * .75)
      ..lineTo(size.width * .17, size.height * .63)
      ..lineTo(size.width * .31, size.height * .68)
      ..lineTo(size.width * .46, size.height * .39)
      ..lineTo(size.width * .62, size.height * .48)
      ..lineTo(size.width * .79, size.height * .26)
      ..lineTo(size.width - 12, size.height * .32);
    canvas.drawPath(
        line,
        Paint()
          ..color = GogdelyColors.blue
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
