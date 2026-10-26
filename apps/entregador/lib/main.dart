import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';
import 'online_delivery.dart';

void main() => runApp(const EntregadorApp());

class EntregadorApp extends StatefulWidget {
  const EntregadorApp({super.key});
  @override
  State<EntregadorApp> createState() => _EntregadorAppState();
}

class _EntregadorAppState extends State<EntregadorApp> {
  ThemeMode mode = ThemeMode.light;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GOGDELY Entregador',
    debugShowCheckedModeBanner: false,
    theme: gogdelyTheme(Brightness.light),
    darkTheme: gogdelyTheme(Brightness.dark),
    themeMode: mode,
    home: !localDemoEnabled && kIsWeb &&
            const String.fromEnvironment('GOGDELY_API_BASE_URL').startsWith('https://')
        ? const OnlineCourierShell()
        : (defaultTargetPlatform == TargetPlatform.windows && !kIsWeb)
        ? Scaffold(
            backgroundColor: GogdelyColors.graphite,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: EntregadorHome(
                  themeMode: mode,
                  onThemeChanged: (value) => setState(() => mode = value),
                ),
              ),
            ),
          )
        : EntregadorHome(
            themeMode: mode,
            onThemeChanged: (value) => setState(() => mode = value),
          ),
  );
}

enum CourierPage {
  deliveries,
  route,
  details,
  status,
  complete,
  earnings,
  profile,
  login,
  splash,
}

class EntregadorHome extends StatefulWidget {
  const EntregadorHome({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    this.localApi,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final LocalDemoApi? localApi;
  @override
  State<EntregadorHome> createState() => _EntregadorHomeState();
}

class _EntregadorHomeState extends State<EntregadorHome> {
  late final LocalDemoApi _localApi = widget.localApi ?? LocalDemoApi();
  Timer? _localRefreshTimer;
  int _refreshRequest = 0;
  bool _refreshingOrders = false;
  List<DemoOrder> _localOrders = const [];
  String? _localError;
  int? _updatingId;
  int? _selectedLocalOrderId;

  DemoOrder? get _selectedLocalOrder => _localOrders
      .where((order) => order.id == _selectedLocalOrderId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    if (localDemoEnabled) {
      _refreshLocalOrders();
      _localRefreshTimer = Timer.periodic(localDemoRefreshInterval, (_) {
        if (page == CourierPage.deliveries) _refreshLocalOrders();
      });
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
      final orders = (await _localApi.orders())
          .where(
            (order) =>
                order.orderChannel == 'delivery' &&
                order.dispatchMode == 'internal',
          )
          .toList();
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
          current[i].status != incoming[i].status) {
        return false;
      }
    }
    return true;
  }

  Future<void> _advanceLocalOrder(DemoOrder order) async {
    final next = order.status == 'ready' ? 'in_delivery' : 'delivered';
    String? deliveryCode;
    String? proofNote;
    if (next == 'delivered') {
      final code = TextEditingController();
      final note = TextEditingController();
      final confirmation = await showDialog<({String code, String note})>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirmar entrega #${order.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de 6 dígitos mostrado ao cliente',
                  helperText: 'Peça o código somente ao entregar o pedido.',
                ),
              ),
              // GOG-046 local: comprovante textual opcional.
              TextField(
                controller: note,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Comprovante (opcional)',
                  helperText: 'Ex.: entregue em mãos ao responsável. Simulação local, sem foto ou assinatura.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () {
                if (RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
                  Navigator.pop(context, (
                    code: code.text.trim(),
                    note: note.text.trim(),
                  ));
                }
              },
              child: const Text('Confirmar entrega'),
            ),
          ],
        ),
      );
      code.dispose();
      note.dispose();
      if (confirmation == null || !mounted) return;
      deliveryCode = confirmation.code;
      proofNote = confirmation.note;
    }
    setState(() => _updatingId = order.id);
    try {
      await _localApi.updateStatus(
        order.id,
        next,
        'courier',
        deliveryCode: deliveryCode,
        proofNote: proofNote,
      );
      await _refreshLocalOrders();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  CourierPage page = CourierPage.deliveries;
  int step = 0;
  bool completed = false;
  void go(CourierPage target) {
    setState(() => page = target);
    if (localDemoEnabled && target == CourierPage.deliveries) {
      _refreshLocalOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkPage = page == CourierPage.splash || page == CourierPage.complete;
    final tab = page == CourierPage.deliveries
        ? 0
        : page == CourierPage.earnings
        ? 1
        : 2;
    return Scaffold(
      backgroundColor: darkPage ? GogdelyColors.darkBackground : null,
      appBar: darkPage
          ? null
          : AppBar(
              title: Text(
                _title(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              leading:
                  {
                    CourierPage.deliveries,
                    CourierPage.earnings,
                    CourierPage.profile,
                  }.contains(page)
                  ? null
                  : IconButton(
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () => go(CourierPage.deliveries),
                    ),
              actions: page == CourierPage.deliveries
                  ? [
                      IconButton(
                        tooltip: 'Perfil',
                        onPressed: () => go(CourierPage.profile),
                        icon: const Icon(Icons.person_outline),
                      ),
                    ]
                  : null,
            ),
      body: SafeArea(child: _body()),
      bottomNavigationBar:
          {
            CourierPage.deliveries,
            CourierPage.earnings,
            CourierPage.profile,
          }.contains(page)
          ? NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => go(
                [
                  CourierPage.deliveries,
                  CourierPage.earnings,
                  CourierPage.profile,
                ][i],
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.delivery_dining),
                  label: 'Entregas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: 'Ganhos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Perfil',
                ),
              ],
            )
          : null,
    );
  }

  String _title() => switch (page) {
    CourierPage.deliveries => 'Minhas entregas',
    CourierPage.route => 'Rota da entrega',
    CourierPage.details => 'Detalhes do pedido',
    CourierPage.status => 'Atualizar status',
    CourierPage.earnings => 'Meus ganhos',
    CourierPage.profile => 'Meu perfil',
    CourierPage.login => 'Entrar',
    _ => 'GOGDELY Entregador',
  };

  Widget _body() => switch (page) {
    CourierPage.deliveries => _deliveries(),
    CourierPage.route => _route(),
    CourierPage.details => _details(),
    CourierPage.status => _status(),
    CourierPage.complete => _complete(),
    CourierPage.earnings => _earnings(),
    CourierPage.profile => _profile(),
    CourierPage.login => _login(),
    CourierPage.splash => _splash(),
  };

  Widget _list(List<Widget> widgets) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: widgets,
  );

  Widget _deliveries() => _list([
    Text(
      localDemoEnabled ? 'AMOSTRA LOCAL' : 'PRÉVIA ILUSTRATIVA',
      style: const TextStyle(
        color: GogdelyColors.blue,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Sua jornada, em ordem',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 5),
    Text(
      'Acompanhe cada entrega com clareza.',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
    ),
    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GogdelyColors.graphite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: GogdelyColors.blue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.two_wheeler, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed ? 'Histórico de entregas' : 'Entregas em foco',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localDemoEnabled
                      ? 'Pedidos do laboratório local'
                      : 'Cenário demonstrativo',
                  style: const TextStyle(
                    color: GogdelyColors.mutedDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    if (localDemoEnabled) ...[
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _refreshLocalOrders,
        icon: const Icon(Icons.refresh),
        label: const Text('Atualizar do banco local'),
      ),
      if (_localError != null)
        Text(_localError!, style: const TextStyle(color: Colors.red)),
    ],
    const SizedBox(height: 22),
    SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Em andamento')),
        ButtonSegment(value: 1, label: Text('Concluídas')),
      ],
      selected: {completed ? 1 : 0},
      onSelectionChanged: (v) => setState(() => completed = v.first == 1),
    ),
    const SizedBox(height: 22),
    Row(
      children: [
        Expanded(
          child: Text(
            completed ? 'Concluídas' : 'Em andamento',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          localDemoEnabled
              ? '${_localOrders.where((order) => completed ? order.status == 'delivered' : {'ready', 'in_delivery'}.contains(order.status)).length} pedidos'
              : completed
              ? '1 pedido'
              : '2 pedidos',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    if (localDemoEnabled) ...[
      if (!_localOrders.any(
        (order) => completed
            ? order.status == 'delivered'
            : {'ready', 'in_delivery'}.contains(order.status),
      ))
        Text(
          completed ? 'Nenhuma entrega concluída no banco local.' : 'Nenhum pedido encaminhado ao entregador próprio. A loja precisa marcar como pronto e enviar ao Entregador.',
        ),
      for (final order in _localOrders)
        if (completed
            ? order.status == 'delivered'
            : {'ready', 'in_delivery'}.contains(order.status))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        color: GogdelyColors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        demoStatusLabel(order.status),
                        style: const TextStyle(
                          color: GogdelyColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'Pedido local #${order.id} · ${order.storeName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(order.addressLabel)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Valor do pedido de teste: R\$ ${(order.totalCents / 100).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  if (!completed)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _selectedLocalOrderId = order.id;
                        page = CourierPage.route;
                      }),
                      icon: const Icon(Icons.route),
                      label: const Text('Ver rota e pedido'),
                    ),
                  if (!completed)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _updatingId == order.id
                            ? null
                            : () => _advanceLocalOrder(order),
                        child: Text(
                          order.status == 'ready'
                              ? 'Iniciar entrega local'
                              : 'Concluir entrega local',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    ] else if (!completed) ...[
      _deliveryCard(
        'Pedido #12345',
        'Burger House',
        'Rua das Flores, 123',
        '2,5 km · 15 min',
        'assets/images/burger.png',
        () => go(CourierPage.route),
      ),
      _deliveryCard(
        'Pedido #12346',
        'Pizzaria Napoli',
        'Av. Paulista, 1000',
        '1,8 km · 12 min',
        'assets/images/pizza.png',
        () => go(CourierPage.route),
      ),
    ] else
      _deliveryCard(
        'Exemplo #12340',
        'Pizzaria Napoli',
        'Entrega fictícia',
        'Concluída na prévia',
        'assets/images/pizza.png',
        () => go(CourierPage.complete),
      ),
    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: GogdelyColors.blue, size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Nenhuma rota, atribuição ou entrega real é consultada.',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  ]);

  Widget _deliveryCard(
    String number,
    String place,
    String address,
    String distance,
    String image,
    VoidCallback action,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: GogdelyColors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'PRÓXIMA ENTREGA',
                style: TextStyle(
                  color: GogdelyColors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, size: 18),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  image,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      place,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                size: 17,
                color: GogdelyColors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                distance,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: action,
              child: const Text('Ver rota demonstrativa'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _route() => _list([
    Text(
      _selectedLocalOrder == null
          ? 'Rota demonstrativa'
          : 'Pedido #${_selectedLocalOrder!.id} · ${_selectedLocalOrder!.storeName}',
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
    ),
    const SizedBox(height: 12),
    Container(
      height: 310,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CourierMapPainter())),
          const Positioned(
            left: 25,
            top: 38,
            child: Icon(Icons.store, color: GogdelyColors.blue),
          ),
          const Positioned(
            right: 26,
            bottom: 42,
            child: Icon(Icons.place, color: GogdelyColors.blue),
          ),
          const Positioned(
            left: 12,
            bottom: 8,
            child: Text(
              'Mapa ilustrativo · sem GPS',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Card(
      child: ListTile(
        leading: Icon(Icons.place_outlined),
        title: Text(_selectedLocalOrder?.addressLabel ?? 'Rua das Flores, 123'),
        subtitle: const Text('Endereço do pedido de teste · rota ilustrativa'),
      ),
    ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: () => go(CourierPage.details),
      child: const Text('Ver detalhes do pedido'),
    ),
  ]);

  Widget _details() => _selectedLocalOrder == null
      ? _list([const Text('Selecione uma entrega na lista.')])
      : _list([
          Text(
            'Pedido #${_selectedLocalOrder!.id}',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          Text('${_selectedLocalOrder!.storeName} · dados locais de teste'),
          const SizedBox(height: 15),
          Card(
            child: Column(
              children: [
                for (final item in _selectedLocalOrder!.items)
                  ListTile(title: Text('${item.quantity} × ${item.name}')),
                const Divider(),
                ListTile(
                  title: const Text('Total de teste'),
                  trailing: Text(
                    'R\$ ${(_selectedLocalOrder!.totalCents / 100).toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(_selectedLocalOrder!.addressLabel),
              subtitle: const Text('Destino cadastrado no pedido local'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _advanceLocalOrder(_selectedLocalOrder!),
            child: Text(
              _selectedLocalOrder!.status == 'ready'
                  ? 'Iniciar entrega local'
                  : 'Concluir entrega local',
            ),
          ),
        ]);

  Widget _status() => _list([
    const Text(
      'Pedido #12345',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    for (var i = 0; i < 4; i++)
      ListTile(
        leading: Icon(
          i <= step ? Icons.check_circle : Icons.radio_button_unchecked,
          color: i <= step ? GogdelyColors.blue : null,
        ),
        title: Text(
          [
            'Coleta realizada',
            'Em trânsito',
            'A caminho do cliente',
            'Entregue',
          ][i],
        ),
      ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: () => setState(() {
        if (step < 3) {
          step++;
        } else {
          page = CourierPage.complete;
        }
      }),
      child: Text(
        step < 3 ? 'Avançar cenário fictício' : 'Concluir demonstração',
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Nenhum cliente, GPS ou sistema externo será atualizado.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11),
    ),
  ]);

  Widget _complete() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor: GogdelyColors.blue,
            child: Icon(Icons.check, color: Colors.white, size: 55),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cenário concluído!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta entrega é apenas uma simulação local.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => go(CourierPage.deliveries),
              child: const Text('Ver entregas de demonstração'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _earnings() => _list([
    const Text(
      'Ganhos ilustrativos',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Text(
              'R\$ 125,80',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
            ),
            Text('Hoje · valor fictício'),
          ],
        ),
      ),
    ),
    const Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.delivery_dining),
            title: Text('Entregas'),
            trailing: Text('8'),
          ),
          ListTile(
            leading: Icon(Icons.route),
            title: Text('Distância'),
            trailing: Text('32 km'),
          ),
          ListTile(
            leading: Icon(Icons.timer_outlined),
            title: Text('Tempo online'),
            trailing: Text('6h 20min'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 15),
    const Text(
      'Nenhum pagamento ou remuneração foi calculado.',
      style: TextStyle(fontSize: 11),
    ),
  ]);

  Widget _profile() => _list([
    Card(
      child: ListTile(
        leading: const CircleAvatar(
          radius: 24,
          backgroundColor: GogdelyColors.blue,
          child: Text('CS', style: TextStyle(color: Colors.white)),
        ),
        title: const Text('Carlos Silva'),
        subtitle: const Text('Entregador · perfil fictício'),
        trailing: const Icon(
          Icons.verified_outlined,
          color: GogdelyColors.blue,
        ),
      ),
    ),
    for (final (icon, title) in [
      (Icons.person_outline, 'Meus dados'),
      (Icons.two_wheeler, 'Veículo'),
      (Icons.description_outlined, 'Documentos'),
      (Icons.notifications_none, 'Notificações'),
      (Icons.help_outline, 'Ajuda e suporte'),
    ])
      Card(
        child: ListTile(
          leading: Icon(icon, color: GogdelyColors.blue),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: tela demonstrativa sem dados reais'),
            ),
          ),
        ),
      ),
    Card(
      child: ListTile(
        leading: const Icon(Icons.dark_mode_outlined),
        title: const Text('Tema escuro'),
        trailing: Switch(
          value: widget.themeMode == ThemeMode.dark,
          onChanged: (value) =>
              widget.onThemeChanged(value ? ThemeMode.dark : ThemeMode.light),
        ),
      ),
    ),
    TextButton(
      onPressed: () => go(CourierPage.login),
      child: const Text('Ver login demonstrativo'),
    ),
    TextButton(
      onPressed: () => go(CourierPage.splash),
      child: const Text('Ver apresentação'),
    ),
  ]);

  Widget _login() => _list([
    const SizedBox(height: 40),
    const Center(
      child: Text(
        'gogdely.',
        style: TextStyle(
          fontSize: 33,
          fontWeight: FontWeight.w900,
          color: GogdelyColors.blue,
        ),
      ),
    ),
    const SizedBox(height: 32),
    const Text(
      'Olá!',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
    ),
    const Text('Entre na sua conta'),
    const SizedBox(height: 22),
    const TextField(
      decoration: InputDecoration(labelText: 'E-mail ou telefone'),
    ),
    const SizedBox(height: 10),
    const TextField(
      obscureText: true,
      decoration: InputDecoration(labelText: 'Senha'),
    ),
    const SizedBox(height: 18),
    FilledButton(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login não conectado nesta prévia.')),
      ),
      child: const Text('Entrar'),
    ),
    TextButton(
      onPressed: () => go(CourierPage.deliveries),
      child: const Text('Explorar demonstração'),
    ),
  ]);

  Widget _splash() => Stack(
    children: [
      Positioned.fill(
        child: Image.asset('assets/images/city.png', fit: BoxFit.cover),
      ),
      Positioned.fill(
        child: Container(
          color: GogdelyColors.darkBackground.withValues(alpha: .55),
        ),
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Center(
            child: Text(
              'gogdely.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 43,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Text(
            'Entregue o que move histórias.',
            style: TextStyle(color: Colors.white),
          ),
          const Spacer(flex: 3),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => go(CourierPage.login),
                child: const Text('Começar'),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _CourierMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..strokeWidth = 9;
    for (var i = 1; i < 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x - 40, size.height), street);
    }
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), street);
    }
    final route = Path()
      ..moveTo(30, 45)
      ..lineTo(size.width * .3, 90)
      ..lineTo(size.width * .5, 150)
      ..lineTo(size.width * .83, size.height - 45);
    canvas.drawPath(
      route,
      Paint()
        ..color = GogdelyColors.blue
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
