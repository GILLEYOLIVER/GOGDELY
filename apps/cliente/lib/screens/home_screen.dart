import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

import 'client_components.dart';
import 'demo_catalog.dart';
import 'map_demo_screen.dart';
import 'qr_demo_screen.dart';

enum _Page {
  home,
  categories,
  search,
  store,
  product,
  cart,
  checkout,
  tracking,
  orders,
  review,
  profile,
  notifications,
  address,
  login,
  onboarding,
  splash,
  complete,
  settings,
}

class _CartLine {
  _CartLine(this.product, this.unitCents, this.details, this.quantity);
  final DemoProduct product;
  final int unitCents;
  final String details;
  int quantity;
  int get subtotal => unitCents * quantity;
}

/// GOG-016–024, GOG-087–100: visual local prototype based on the approved
/// reference. No authentication, price authority, payment or real order writes.
class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key,
      this.themeMode = ThemeMode.system,
      this.onThemeChanged,
      this.localApi});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final LocalDemoApi? localApi;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LocalDemoApi _localApi = widget.localApi ?? LocalDemoApi();
  Timer? _localRefreshTimer;
  int _ordersRefreshRequest = 0;
  int _orderRefreshRequest = 0;
  bool _refreshingOrders = false;
  bool _refreshingOrder = false;
  DemoOrder? _savedOrder;
  List<DemoOrder> _savedOrders = const [];
  String? _localError;
  String? _requestKey;
  bool _savingOrder = false;
  DemoStore? _pilotStore;
  bool _refreshingMenu = false;
  String? _menuError;
  String _menuFingerprint = '';
  String _catalogFingerprint = '';
  _Page page = _Page.home;
  DemoStore store = demoStores.first;
  DemoStore? cartStore;
  DemoProduct product = demoStores.first.products.first;
  final List<_CartLine> cart = [];
  String category = 'Todos';
  String search = '';
  String selectedSize = 'Tradicional';
  final Set<String> extras = {};
  int productQuantity = 1;
  int trackingStep = 0;
  int reviewStars = 0;
  String paymentMethod = 'cash';
  List<String> _availablePaymentMethods = const ['cash', 'pix', 'card'];
  bool _refreshingPaymentMethods = false;
  bool _paymentMethodsLoaded = false;
  String? _paymentMethodsError;
  Map<String, dynamic>? _storeRatings;
  bool _refreshingRatings = false;
  final Set<int> _ratedOrderIds = {};
  String deliveryLabel = 'Padrão (25–35 min)';
  String _orderChannel = 'delivery';
  bool _scheduleEnabled = false;
  DateTime? _scheduledAt;
  String addressLabel = 'Rua das Flores, 123';
  bool demoOrderCreated = false;
  int lastOrderTotal = 0;

  Iterable<DemoStore> get visibleStores =>
      localDemoEnabled ? [_pilotStore].whereType<DemoStore>() : demoStores;

  @override
  void initState() {
    super.initState();
    if (localDemoEnabled) {
      _refreshMenu();
      _localRefreshTimer = Timer.periodic(localDemoRefreshInterval, (_) {
        if ({_Page.home, _Page.search, _Page.store, _Page.product}
            .contains(page)) {
          _refreshMenu();
        }
        if (page == _Page.orders) _refreshOrders();
        if (page == _Page.tracking) _refreshOrder();
        if (page == _Page.checkout) _refreshPaymentMethods();
      });
    }
  }

  void open(_Page target) {
    setState(() => page = target);
    if (localDemoEnabled &&
        {_Page.home, _Page.search, _Page.store}.contains(target)) {
      _refreshMenu();
    }
    if (localDemoEnabled && target == _Page.orders) _refreshOrders();
    if (localDemoEnabled && target == _Page.tracking) {
      _refreshOrder();
      _refreshRatings();
    }
    if (localDemoEnabled && target == _Page.store) _refreshRatings();
    if (localDemoEnabled && target == _Page.checkout) _refreshPaymentMethods();
  }

  Future<void> _refreshPaymentMethods() async {
    if (_refreshingPaymentMethods) return;
    _refreshingPaymentMethods = true;
    try {
      final methods = await _localApi.paymentMethods();
      if (mounted &&
          (methods.join(',') != _availablePaymentMethods.join(',') ||
              !methods.contains(paymentMethod) ||
              _paymentMethodsError != null ||
              !_paymentMethodsLoaded)) {
        setState(() {
          _availablePaymentMethods = methods;
          if (!methods.contains(paymentMethod)) paymentMethod = methods.first;
          _paymentMethodsError = null;
          _paymentMethodsLoaded = true;
        });
      }
    } catch (error) {
      if (mounted && _paymentMethodsError != '$error') {
        setState(() => _paymentMethodsError = '$error');
      }
    } finally {
      _refreshingPaymentMethods = false;
    }
  }

  Future<void> _refreshRatings() async {
    if (_refreshingRatings) return;
    _refreshingRatings = true;
    try {
      final ratings = await _localApi.storeRatings();
      if (!mounted) return;
      setState(() {
        _storeRatings = ratings;
        _ratedOrderIds
          ..clear()
          ..addAll((ratings['recent'] as List)
              .whereType<Map<String, dynamic>>()
              .map((entry) => entry['order_id'] as int));
      });
    } catch (_) {
      // A avaliação é complemento no piloto; falha não bloqueia a navegação.
    } finally {
      _refreshingRatings = false;
    }
  }

  /// GOG-022 no laboratório local: avalia um pedido concluído.
  Future<void> _rateOrder(DemoOrder order) async {
    var stars = 0;
    final comment = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
                  title: Text('Avaliar pedido #${order.id}'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var star = 1; star <= 5; star++)
                            IconButton(
                                onPressed: () =>
                                    setDialogState(() => stars = star),
                                icon: Icon(stars >= star
                                    ? Icons.star
                                    : Icons.star_border),
                                color: GogdelyColors.blue),
                        ]),
                    TextField(
                        controller: comment,
                        maxLength: 500,
                        decoration: const InputDecoration(
                            labelText: 'Comentário (opcional)')),
                    const Text(
                        'Avaliação do laboratório local, visível na Gestão.',
                        style: TextStyle(fontSize: 12)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Voltar')),
                    FilledButton(
                        onPressed: stars == 0
                            ? null
                            : () => Navigator.pop(dialogContext, true),
                        child: const Text('Enviar avaliação')),
                  ],
                )));
    if (confirmed != true) {
      comment.dispose();
      return;
    }
    try {
      final summary = await _localApi.rateOrder(
          orderId: order.id, stars: stars, comment: comment.text.trim());
      if (!mounted) return;
      setState(() {
        _storeRatings = summary;
        _ratedOrderIds.add(order.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado! Avaliação registrada.')));
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      comment.dispose();
    }
  }

  @override
  void dispose() {
    _localRefreshTimer?.cancel();
    _localApi.close();
    super.dispose();
  }

  Future<void> _refreshMenu() async {
    if (_refreshingMenu) return;
    _refreshingMenu = true;
    try {
      final items = await _localApi.menu();
      if (!mounted) return;
      final catalogFingerprint = items
          .map((item) =>
              '${item.productId}|${item.name}|${item.description}|${item.category}|${item.effectivePriceCents}|${item.promoPercent}|${item.imageRef}|${item.available}|${item.addons.map((addon) => '${addon.name}:${addon.priceCents}').join(',')}')
          .join('\n');
      final fingerprint =
          '$catalogFingerprint|${items.map((item) => '${item.productId}:${item.stockQuantity}:${item.orderable}').join(',')}';
      if (fingerprint == _menuFingerprint && _menuError == null) return;
      final base = demoStores.first;
      final products = items
          .where((item) => item.orderable)
          .map((item) => DemoProduct(
                item.productId,
                item.name,
                item.description,
                item.effectivePriceCents,
                image: item.imageRef,
                badge: item.promoPercent > 0 ? '${item.promoPercent}% OFF' : '',
                category: item.category,
                stockQuantity: item.stockQuantity,
                addons: item.addons,
              ))
          .toList();
      final updated = DemoStore(
          base.id, base.name, base.category, base.description, products,
          image: base.image, rating: base.rating, eta: base.eta);
      final cartCleared = cart.isNotEmpty &&
          ((_catalogFingerprint.isNotEmpty &&
                  _catalogFingerprint != catalogFingerprint) ||
              cart.any((line) =>
                  !products.any((item) => item.id == line.product.id)));
      setState(() {
        if (cartCleared) {
          cart.clear();
          cartStore = null;
          _requestKey = null;
        }
        _pilotStore = updated;
        if (store.id == updated.id) store = updated;
        final selected =
            products.where((value) => value.id == product.id).firstOrNull;
        if (selected != null) {
          product = selected;
          if (selected.stockQuantity != null &&
              productQuantity > selected.stockQuantity!) {
            productQuantity = selected.stockQuantity!;
          }
          extras.removeWhere(
              (name) => !selected.addons.any((addon) => addon.name == name));
        } else if (page == _Page.product) {
          page = _Page.store;
        }
        _menuFingerprint = fingerprint;
        _catalogFingerprint = catalogFingerprint;
        _menuError = null;
      });
      if (cartCleared) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('O cardápio mudou. Monte o carrinho novamente.')));
      }
    } catch (error) {
      if (mounted && _menuError != '$error') {
        setState(() => _menuError = '$error');
      }
    } finally {
      _refreshingMenu = false;
    }
  }

  Future<void> _refreshOrders() async {
    if (_refreshingOrders) return;
    _refreshingOrders = true;
    final request = ++_ordersRefreshRequest;
    try {
      final orders = (await _localApi.orders(storeId: localDemoPilotStoreId))
          .where((order) => order.orderChannel != 'counter')
          .toList();
      if (mounted &&
          request == _ordersRefreshRequest &&
          (_localError != null || !_sameOrders(_savedOrders, orders))) {
        setState(() {
          _savedOrders = orders;
          _localError = null;
        });
      }
    } catch (error) {
      if (mounted &&
          request == _ordersRefreshRequest &&
          _localError != '$error') {
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

  Future<void> _refreshOrder() async {
    if (_savedOrder == null || _refreshingOrder) return;
    _refreshingOrder = true;
    final id = _savedOrder!.id;
    final request = ++_orderRefreshRequest;
    try {
      final order = await _localApi.order(id);
      if (mounted &&
          request == _orderRefreshRequest &&
          _savedOrder?.id == id &&
          (_localError != null ||
              _savedOrder?.status != order.status ||
              _savedOrder?.dispatchMode != order.dispatchMode)) {
        setState(() {
          _savedOrder = order;
          _localError = null;
        });
      }
    } catch (error) {
      if (mounted &&
          request == _orderRefreshRequest &&
          _localError != '$error') {
        setState(() => _localError = '$error');
      }
    } finally {
      _refreshingOrder = false;
    }
  }

  Future<void> _showOrderHistory() async {
    final order = _savedOrder;
    if (order == null) return;
    try {
      final events = await _localApi.orderEvents(order.id);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Histórico do pedido #${order.id}'),
                content: SizedBox(
                    width: 380,
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

  Future<void> _cancelSavedOrder() async {
    final order = _savedOrder;
    if (order == null || order.status != 'created') return;
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
                      if (controller.text.trim().length >= 3) {
                        Navigator.pop(context, controller.text.trim());
                      }
                    },
                    child: const Text('Confirmar')),
              ],
            ));
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      final cancelled =
          await _localApi.cancelOrder(order.id, 'customer', reason);
      if (mounted) setState(() => _savedOrder = cancelled);
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
      await _refreshOrder();
    }
  }

  Future<void> _submitLocalOrder() async {
    if (_savingOrder || cart.isEmpty || cartStore == null) return;
    setState(() {
      _savingOrder = true;
      _localError = null;
    });
    _requestKey ??= newDemoRequestKey();
    try {
      final order = await _localApi.createOrder(
        requestKey: _requestKey!,
        storeId: cartStore!.id,
        addressLabel: addressLabel,
        orderChannel: _orderChannel,
        paymentMethod: paymentMethod,
        scheduledFor: _scheduleEnabled && _scheduledAt != null
            ? _scheduledAt!.toUtc().toIso8601String()
            : null,
        items: cart.map((line) {
          final options = line.details.split(' · ');
          return {
            'product_id': line.product.id,
            'quantity': line.quantity,
            'size': options.first,
            'extras': options.skip(1).toList(),
          };
        }).toList(),
      );
      if (!mounted) return;
      setState(() {
        store = cartStore!;
        _savedOrder = order;
        lastOrderTotal = order.totalCents;
        demoOrderCreated = true;
        cart.clear();
        cartStore = null;
        _requestKey = null;
        page = _Page.tracking;
      });
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  /// GOG-024 no laboratório local: escolhe o horário agendado do pedido.
  Future<void> _pickScheduleDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(minutes: 45)),
        firstDate: now.add(const Duration(minutes: 30)),
        lastDate: now.add(const Duration(days: 14)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(now.add(const Duration(minutes: 45))));
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatSchedule(DateTime value) {
    String two(int input) => input.toString().padLeft(2, '0');
    return 'Agendado: ${two(value.day)}/${two(value.month)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  void openStore(DemoStore value) => setState(() {
        store = value;
        page = _Page.store;
      });

  void openProduct(DemoProduct value) => setState(() {
        product = value;
        selectedSize = 'Tradicional';
        extras.clear();
        productQuantity = 1;
        page = _Page.product;
      });

  int get itemCount => cart.fold(0, (sum, line) => sum + line.quantity);
  int get subtotal => cart.fold(0, (sum, line) => sum + line.subtotal);
  int get deliveryFee =>
      cart.isEmpty || (localDemoEnabled && _orderChannel == 'pickup') ? 0 : 599;
  int get total => subtotal + deliveryFee;
  int get selectedPrice =>
      product.priceCents +
      (selectedSize == 'Grande'
          ? 800
          : selectedSize == 'Média'
              ? 400
              : 0) +
      extras.fold<int>(
          0,
          (sum, name) =>
              sum +
              (localDemoEnabled
                  ? (product.addons
                          .where((addon) => addon.name == name)
                          .firstOrNull
                          ?.priceCents ??
                      0)
                  : 300));

  Future<void> addSelectedProduct() async {
    if (cart.isNotEmpty && cartStore?.id != store.id) {
      final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Trocar de loja?'),
                content: const Text(
                    'Cada pedido reúne produtos de uma loja. O carrinho atual será substituído.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Trocar loja')),
                ],
              ));
      if (!mounted || replace != true) return;
      cart.clear();
    }
    setState(() {
      cartStore = store;
      final details = [selectedSize, ...extras.toList()..sort()].join(' · ');
      final existing = cart
          .where((line) =>
              line.product.id == product.id && line.details == details)
          .firstOrNull;
      if (existing == null) {
        cart.add(_CartLine(product, selectedPrice, details, productQuantity));
      } else {
        existing.quantity += productQuantity;
      }
      page = _Page.cart;
    });
  }

  void changeCartQuantity(_CartLine line, int delta) => setState(() {
        line.quantity += delta;
        if (line.quantity <= 0) cart.remove(line);
        if (cart.isEmpty) cartStore = null;
      });

  @override
  Widget build(BuildContext context) {
    final darkPage = page == _Page.categories ||
        page == _Page.splash ||
        page == _Page.onboarding ||
        page == _Page.complete;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showNav = {
      _Page.home,
      _Page.categories,
      _Page.search,
      _Page.orders,
      _Page.profile
    }.contains(page);
    return Scaffold(
      backgroundColor: darkPage ? GogdelyColors.darkBackground : null,
      appBar: _appBar(darkPage),
      body: SafeArea(child: _pageBody()),
      bottomNavigationBar: showNav ? _navigation(darkPage || dark) : null,
    );
  }

  PreferredSizeWidget? _appBar(bool darkPage) {
    if ({_Page.splash, _Page.onboarding, _Page.complete}.contains(page)) {
      return null;
    }
    if (page == _Page.home) {
      return AppBar(
        toolbarHeight: 70,
        titleSpacing: 16,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const BrandWordmark(size: 23),
          Text(addressLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          IconButton(
              tooltip: 'Notificações',
              onPressed: () => open(_Page.notifications),
              icon: const Icon(Icons.notifications_none)),
        ],
      );
    }
    final titles = <_Page, String>{
      _Page.categories: 'Categorias',
      _Page.search: 'Busca',
      _Page.store: store.name,
      _Page.product: product.name,
      _Page.cart: 'Carrinho',
      _Page.checkout: 'Checkout',
      _Page.tracking: 'Acompanhamento',
      _Page.orders: 'Meus pedidos',
      _Page.review: 'Avaliar pedido',
      _Page.profile: 'Meu perfil',
      _Page.notifications: 'Notificações',
      _Page.address: 'Endereço',
      _Page.login: 'Entrar',
      _Page.settings: 'Configurações',
    };
    return AppBar(
      backgroundColor: darkPage ? GogdelyColors.darkBackground : null,
      foregroundColor: darkPage ? Colors.white : null,
      leading: {_Page.categories, _Page.search, _Page.orders, _Page.profile}
              .contains(page)
          ? null
          : IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => open(_backPage())),
      title: Text(titles[page] ?? 'GOGDELY',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      actions: page == _Page.store
          ? [
              IconButton(
                  tooltip: 'Carrinho',
                  onPressed: () => open(_Page.cart),
                  icon: _cartIcon())
            ]
          : null,
    );
  }

  _Page _backPage() => switch (page) {
        _Page.product => _Page.store,
        _Page.cart => _Page.store,
        _Page.checkout => _Page.cart,
        _Page.tracking || _Page.review => _Page.orders,
        _Page.store => _Page.home,
        _Page.address ||
        _Page.notifications ||
        _Page.settings ||
        _Page.login =>
          _Page.profile,
        _ => _Page.home,
      };

  Widget _cartIcon() => Badge(
        isLabelVisible: itemCount > 0,
        label: Text('$itemCount'),
        child: const Icon(Icons.shopping_bag_outlined),
      );

  Widget _navigation(bool dark) => NavigationBar(
        backgroundColor: dark ? GogdelyColors.darkBackground : Colors.white,
        indicatorColor: dark
            ? GogdelyColors.blue.withValues(alpha: .22)
            : const Color(0xFFDDE8FF),
        selectedIndex: switch (page) {
          _Page.search || _Page.categories => 1,
          _Page.orders => 2,
          _Page.profile => 3,
          _ => 0,
        },
        onDestinationSelected: (index) => open(
            [_Page.home, _Page.search, _Page.orders, _Page.profile][index]),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Busca'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      );

  Widget _pageBody() => switch (page) {
        _Page.home => _home(),
        _Page.categories => _categories(),
        _Page.search => _searchPage(),
        _Page.store => _storePage(),
        _Page.product => _productPage(),
        _Page.cart => _cartPage(),
        _Page.checkout => _checkoutPage(),
        _Page.tracking => _trackingPage(),
        _Page.orders => _ordersPage(),
        _Page.review => _reviewPage(),
        _Page.profile => _profilePage(),
        _Page.notifications => _notificationsPage(),
        _Page.address => _addressPage(),
        _Page.login => _loginPage(),
        _Page.onboarding => _onboardingPage(),
        _Page.splash => _splashPage(),
        _Page.complete => _completePage(),
        _Page.settings => _settingsPage(),
      };

  Widget _list(List<Widget> children, {EdgeInsets? padding}) => ListView(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: children,
      );

  Widget _sectionTitle(String title, {VoidCallback? onMore}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800))),
          if (onMore != null)
            TextButton(onPressed: onMore, child: const Text('Ver todos')),
        ]),
      );

  Widget _home() => _list([
        TextField(
          readOnly: true,
          onTap: () => open(_Page.search),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'O que você procura hoje?',
              suffixIcon: Icon(Icons.tune)),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            if (!localDemoEnabled || _pilotStore != null) {
              openStore(_pilotStore ?? demoStores.first);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            const DemoPhoto('assets/images/burger.png', height: 154),
            Container(
              height: 154,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                      colors: [Colors.black87, Colors.transparent])),
              padding: const EdgeInsets.all(15),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sabor que\nse aproxima.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.05)),
                    const SizedBox(height: 5),
                    const Text('Confira o cardápio',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    const Spacer(),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            color: GogdelyColors.blue,
                            borderRadius: BorderRadius.circular(9)),
                        child: const Text('Ver ofertas',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                  ]),
            ),
          ]),
        ),
        if (!localDemoEnabled) _categoryGrid(compact: true),
        _sectionTitle(
            localDemoEnabled ? 'Empresa piloto' : 'Estabelecimentos próximos',
            onMore: () => open(_Page.search)),
        for (final value in visibleStores.take(4))
          DemoStoreCard(value, onTap: () => openStore(value)),
        if (localDemoEnabled && _pilotStore == null)
          Text(_menuError ?? 'Carregando cardápio local da Burger House...'),
        _sectionTitle('Explore mais'),
        Row(children: [
          Expanded(
              child: _resourceTile(
                  Icons.qr_code_scanner,
                  'Ler QR',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const QrDemoScreen())))),
          const SizedBox(width: 8),
          Expanded(
              child: _resourceTile(
                  Icons.map_outlined,
                  'Mapa',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const MapDemoScreen())))),
        ]),
        const SizedBox(height: 8),
        const Text(
            'Prévia local com dados fictícios. Sem pedidos ou pagamentos reais.',
            style: TextStyle(fontSize: 11)),
      ]);

  Widget _resourceTile(IconData icon, String label, VoidCallback action) =>
      Card(
        child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Icon(icon, color: GogdelyColors.blue),
                  const SizedBox(height: 5),
                  Text(label)
                ]))),
      );

  Widget _categoryGrid({bool compact = false}) {
    final children = compact ? demoCategories.take(8).toList() : demoCategories;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (compact)
        _sectionTitle('Categorias', onMore: () => open(_Page.categories)),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: compact ? 4 : 3,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: compact ? .82 : .93,
        ),
        itemBuilder: (context, index) {
          final (name, icon, color) = children[index];
          return Card(
            color: page == _Page.categories ? Colors.white : null,
            child: InkWell(
              onTap: () => setState(() {
                category = name == 'Mais' ? 'Todos' : name;
                page = _Page.search;
              }),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: compact ? 22 : 28),
                    const SizedBox(height: 5),
                    Text(name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.w700,
                            color: page == _Page.categories
                                ? GogdelyColors.lightText
                                : null)),
                  ]),
            ),
          );
        },
      ),
    ]);
  }

  Widget _categories() => _list([
        const Text('Explore por tipo de loja',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        _categoryGrid(),
      ]);

  List<DemoStore> get searchResults => visibleStores.where((value) {
        final matchCategory = category == 'Todos' || value.category == category;
        final term = search.trim().toLowerCase();
        return matchCategory &&
            (term.isEmpty ||
                value.name.toLowerCase().contains(term) ||
                value.category.toLowerCase().contains(term) ||
                value.products.any((p) => p.name.toLowerCase().contains(term)));
      }).toList();

  Widget _searchPage() => _list([
        TextField(
          autofocus: false,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: localDemoEnabled
                  ? 'Busque no cardápio da Burger House'
                  : 'Busque lojas ou produtos'),
          onChanged: (value) => setState(() => search = value),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final label in localDemoEnabled
                  ? ['Todos', 'Restaurantes']
                  : ['Todos', 'Restaurantes', 'Mercado', 'Farmácia'])
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                        label: Text(label),
                        selected: category == label,
                        onSelected: (_) => setState(() => category = label))),
            ])),
        _sectionTitle('Resultados'),
        if (searchResults.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  'Nenhuma loja encontrada. Tente outra busca ou categoria.')),
        for (final value in searchResults)
          DemoStoreCard(value, onTap: () => openStore(value)),
      ]);

  Widget _storePage() => _list([
        DemoPhoto(store.image, height: 190, radius: 14),
        const SizedBox(height: 12),
        Text(store.name,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text('⭐ ${store.rating} · ${store.eta} · Aberto',
            style: Theme.of(context).textTheme.bodySmall),
        if (localDemoEnabled && (_storeRatings?['count'] as int? ?? 0) > 0)
          Text(
              '⭐ ${_storeRatings!['average_stars']} · ${_storeRatings!['count']} avaliações locais',
              style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 6, children: [
          for (final label in ['Cardápio', 'Avaliações', 'Sobre'])
            ActionChip(
                label: Text(label),
                onPressed: () {
                  if (label != 'Cardápio') {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$label: conteúdo fictício da prévia')));
                  }
                }),
        ]),
        _sectionTitle('Destaques'),
        if (localDemoEnabled && _menuError != null) Text(_menuError!),
        if (localDemoEnabled && store.products.isEmpty)
          const Text('Nenhum produto disponível no momento. Consulte a loja.'),
        for (final value in store.products)
          DemoProductTile(value, onTap: () => openProduct(value)),
        const SizedBox(height: 16),
        if (itemCount > 0)
          FilledButton.icon(
              onPressed: () => open(_Page.cart),
              icon: _cartIcon(),
              label: Text('Ver carrinho · ${formatDemoPrice(total)}')),
      ]);

  Widget _productPage() => _list([
        DemoPhoto(product.image, height: 210, radius: 14),
        const SizedBox(height: 12),
        Text(product.name,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(product.description),
        const SizedBox(height: 12),
        Text(formatDemoPrice(product.priceCents),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (localDemoEnabled && product.stockQuantity != null)
          Text('Saldo local: ${product.stockQuantity} unidades'),
        _sectionTitle('Escolha o tamanho'),
        Wrap(spacing: 6, children: [
          for (final value in ['Tradicional', 'Média', 'Grande'])
            ChoiceChip(
                label: Text(value),
                selected: selectedSize == value,
                onSelected: (_) => setState(() => selectedSize = value)),
        ]),
        _sectionTitle('Adicionais'),
        for (final addon in localDemoEnabled
            ? product.addons
            : const [
                DemoAddon('Borda recheada', 300),
                DemoAddon('Mussarela extra', 300),
                DemoAddon('Manjericão extra', 300),
              ])
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(addon.name),
            subtitle: Text('+ ${formatDemoPrice(addon.priceCents)}'),
            value: extras.contains(addon.name),
            onChanged: (checked) => setState(() {
              if (checked == true) {
                extras.add(addon.name);
              } else {
                extras.remove(addon.name);
              }
            }),
          ),
        const SizedBox(height: 8),
        const TextField(
            maxLines: 2,
            decoration: InputDecoration(
                labelText: 'Observações',
                hintText: 'Ex.: sem cebola, bem passada...')),
        const SizedBox(height: 16),
        Row(children: [
          IconButton(
              tooltip: 'Diminuir quantidade',
              onPressed: productQuantity > 1
                  ? () => setState(() => productQuantity--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$productQuantity',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
              tooltip: 'Aumentar quantidade',
              onPressed: product.stockQuantity != null &&
                      productQuantity >= product.stockQuantity!
                  ? null
                  : () => setState(() => productQuantity++),
              icon: const Icon(Icons.add_circle_outline)),
          const SizedBox(width: 8),
          Expanded(
              child: FilledButton(
                  onPressed: addSelectedProduct,
                  child: Text(
                      'Adicionar · ${formatDemoPrice(selectedPrice * productQuantity)}'))),
        ]),
      ]);

  Widget _cartPage() => _list([
        if (cart.isEmpty) ...[
          const SizedBox(height: 80),
          const Center(child: Icon(Icons.shopping_bag_outlined, size: 52)),
          const SizedBox(height: 12),
          const Center(child: Text('Seu carrinho está vazio')),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: () => open(_Page.home),
              child: const Text('Explorar lojas')),
        ] else ...[
          Text(cartStore!.name,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text('${cartStore!.eta} · valores de demonstração',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final line in cart)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Row(children: [
                      SizedBox(
                          width: 55,
                          height: 55,
                          child: DemoPhoto(line.product.image,
                              height: 55, radius: 9)),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(line.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(line.details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall),
                            Text(formatDemoPrice(line.subtotal)),
                          ])),
                      Column(children: [
                        IconButton(
                            tooltip: 'Adicionar ${line.product.name}',
                            onPressed: () => changeCartQuantity(line, 1),
                            icon: const Icon(Icons.add_circle_outline)),
                        Text('${line.quantity}'),
                        IconButton(
                            tooltip: 'Remover ${line.product.name}',
                            onPressed: () => changeCartQuantity(line, -1),
                            icon: const Icon(Icons.remove_circle_outline)),
                      ]),
                    ]))),
          const SizedBox(height: 9),
          const TextField(
              decoration: InputDecoration(
                  labelText: 'Cupom de desconto',
                  suffixIcon: Icon(Icons.local_offer_outlined))),
          const SizedBox(height: 14),
          _moneyRow('Subtotal', subtotal),
          _moneyRow(
              localDemoEnabled && _orderChannel == 'pickup'
                  ? 'Retirada na loja'
                  : 'Entrega demonstrativa',
              deliveryFee),
          const Divider(),
          _moneyRow('Total estimado', total, bold: true),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => open(_Page.checkout),
              child: const Text('Continuar para checkout')),
          const SizedBox(height: 8),
          const Text('Nenhum pedido ou pagamento real será enviado.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
        ],
      ]);

  Widget _moneyRow(String label, int cents, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(formatDemoPrice(cents),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ]),
      );

  Widget _checkoutPage() => _list([
        const Text('Recebimento   •   Revisão',
            style: TextStyle(
                color: GogdelyColors.blue, fontWeight: FontWeight.w700)),
        if (localDemoEnabled) ...[
          _sectionTitle('Como receber?'),
          for (final channel in ['delivery', 'pickup'])
            ListTile(
              title: Text(channel == 'pickup'
                  ? 'Retirar na Burger House'
                  : 'Receber no endereço'),
              subtitle: Text(channel == 'pickup'
                  ? 'Sem taxa de entrega'
                  : 'Entrega demonstrativa'),
              leading: Icon(
                  _orderChannel == channel
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: GogdelyColors.blue),
              onTap: () => setState(() => _orderChannel = channel),
            ),
        ],
        if (localDemoEnabled) ...[
          _sectionTitle('Quando receber?'),
          for (final immediate in [true, false])
            ListTile(
              title: Text(
                  immediate ? 'Assim que possível' : 'Agendar horário'),
              subtitle: Text(immediate
                  ? 'O pedido entra na fila imediatamente'
                  : 'Data e hora futuras; mínimo 30 minutos, máximo 14 dias'),
              leading: Icon(
                  (_scheduleEnabled != immediate)
                      ? Icons.radio_button_unchecked
                      : Icons.radio_button_checked,
                  color: GogdelyColors.blue),
              onTap: () => setState(() {
                _scheduleEnabled = !immediate;
                if (immediate) _scheduledAt = null;
              }),
            ),
          if (_scheduleEnabled)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: _pickScheduleDate,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(_scheduledAt == null
                                    ? 'Escolher data e hora'
                                    : _formatSchedule(_scheduledAt!)))),
                      ]),
                      const SizedBox(height: 4),
                      const Text(
                          'Agendamento do laboratório local; a loja vê o horário no pedido.',
                          style: TextStyle(fontSize: 11)),
                    ]))),
        ],
        if (!localDemoEnabled || _orderChannel == 'delivery') ...[
          _sectionTitle('Endereço de entrega'),
          Card(
              child: ListTile(
            leading:
                const Icon(Icons.place_outlined, color: GogdelyColors.blue),
            title: Text(addressLabel),
            subtitle: const Text('Centro · São Paulo, SP · fictício'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(_Page.address),
          )),
        ],
        if (!localDemoEnabled) ...[
          _sectionTitle('Entrega'),
          for (final value in ['Padrão (25–35 min)', 'Agendada'])
            ListTile(
                title: Text(value),
                leading: Icon(
                    deliveryLabel == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: GogdelyColors.blue),
                onTap: () => setState(() => deliveryLabel = value)),
        ],
        _sectionTitle('Pagamento demonstrativo'),
        if (localDemoEnabled &&
            !_paymentMethodsLoaded &&
            _paymentMethodsError == null)
          const Text('Carregando formas aceitas pela loja...'),
        if (localDemoEnabled && _paymentMethodsError != null)
          Text(_paymentMethodsError!,
              style: const TextStyle(color: Colors.red)),
        for (final value in localDemoEnabled
            ? (_paymentMethodsLoaded ? _availablePaymentMethods : <String>[])
            : ['cash', 'pix', 'card'])
          ListTile(
              title: Text(demoPaymentLabel(value)),
              leading: Icon(
                  paymentMethod == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: GogdelyColors.blue),
              onTap: () => setState(() => paymentMethod = value)),
        const Text(
            'A forma escolhida será salva no pedido local. Nenhum pagamento será processado ou confirmado.',
            style: TextStyle(fontSize: 11)),
        _sectionTitle('Resumo'),
        _moneyRow('Produtos', subtotal),
        _moneyRow(
            localDemoEnabled && _orderChannel == 'pickup'
                ? 'Retirada na loja'
                : 'Entrega demonstrativa',
            deliveryFee),
        const Divider(),
        _moneyRow('Total estimado', total, bold: true),
        const SizedBox(height: 12),
        if (localDemoEnabled && _localError != null)
          Text(_localError!, style: const TextStyle(color: Colors.red)),
        FilledButton(
            onPressed: _savingOrder ||
                    (localDemoEnabled &&
                        (!_paymentMethodsLoaded ||
                            _paymentMethodsError != null))
                ? null
                : localDemoEnabled
                    ? _submitLocalOrder
                    : () => setState(() {
                          lastOrderTotal = total;
                          demoOrderCreated = true;
                          trackingStep = 0;
                          cart.clear();
                          cartStore = null;
                          page = _Page.tracking;
                        }),
            child: Text(_savingOrder
                ? 'Salvando no banco local...'
                : localDemoEnabled
                    ? 'Salvar pedido no banco local'
                    : 'Criar pedido fictício')),
      ]);

  Widget _savedOrderSummary(DemoOrder order) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Resumo do pedido salvo',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantity} × ${item.name}'),
                          Text([item.size, ...item.extras].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      )),
                      Text(formatDemoPrice(item.unitCents * item.quantity)),
                    ]),
              ),
            const Divider(),
            _moneyRow('Produtos', order.subtotalCents),
            _moneyRow(
                order.orderChannel == 'delivery' ? 'Entrega' : 'Sem frete',
                order.deliveryFeeCents),
            _moneyRow('Total do pedido', order.totalCents, bold: true),
            const SizedBox(height: 7),
            Text(
                '${demoPaymentLabel(order.paymentMethod)} · pagamento ${demoPaymentStatusLabel(order.paymentStatus)}',
                style: Theme.of(context).textTheme.bodySmall),
            if (order.paymentSimulated)
              Text(
                  'Declaração de laboratório: nenhuma cobrança ou transferência real aconteceu.',
                  style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _trackingPage() => _list([
        Text(
            localDemoEnabled && _savedOrder != null
                ? 'Pedido local #${_savedOrder!.id}'
                : 'Pedido de teste #12345',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(store.name),
        const SizedBox(height: 8),
        if (!localDemoEnabled || _savedOrder == null)
          Text('Total estimado: ${formatDemoPrice(lastOrderTotal)}'),
        const SizedBox(height: 6),
        const Text('Teste local. Não há pagamento, entregador ou GPS real.',
            style: TextStyle(fontSize: 11)),
        if (localDemoEnabled && _savedOrder != null) ...[
          _savedOrderSummary(_savedOrder!),
          Text(_savedOrder!.orderChannel == 'pickup'
              ? 'Retirada na Burger House · sem frete'
              : 'Entrega no endereço: ${_savedOrder!.addressLabel}'),
          if (_savedOrder!.scheduledFor != null)
            Text(
                _formatSchedule(
                    DateTime.parse(_savedOrder!.scheduledFor!).toLocal()),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_savedOrder!.orderChannel == 'pickup' &&
              _savedOrder!.status != 'cancelled' &&
              _savedOrder!.pickupCode != null)
            SelectableText('Código para retirada: ${_savedOrder!.pickupCode}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (_savedOrder!.orderChannel == 'delivery' &&
              _savedOrder!.status == 'in_delivery' &&
              _savedOrder!.deliveryCode != null) ...[
            SelectableText(
                'Código para confirmar entrega: ${_savedOrder!.deliveryCode}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const Text(
                'Informe o código ao entregador somente ao receber o pedido. Conferência de teste local.',
                style: TextStyle(fontSize: 12)),
          ],
          Text('Status salvo: ${demoStatusLabel(_savedOrder!.status)}'),
          if (_savedOrder!.paymentSimulated)
            const Text(
                'Pagamento simulado no laboratório local. Nenhuma cobrança real foi feita.',
                style: TextStyle(fontSize: 12)),
          if ({'delivered', 'served', 'picked_up'}.contains(_savedOrder!.status) &&
              !_ratedOrderIds.contains(_savedOrder!.id))
            OutlinedButton.icon(
                onPressed: () => _rateOrder(_savedOrder!),
                icon: const Icon(Icons.star_outline),
                label: const Text('Avaliar pedido')),
          if (_ratedOrderIds.contains(_savedOrder!.id))
            const Text('Pedido avaliado. Obrigado!',
                style: TextStyle(fontSize: 12)),
          if (_savedOrder!.orderChannel == 'delivery' &&
              _savedOrder!.status == 'ready')
            Text(_savedOrder!.dispatchMode == 'internal'
                ? 'Encaminhado ao entregador próprio da Burger House'
                : 'Aguardando a loja chamar o entregador'),
          if (_localError != null)
            Text(_localError!, style: const TextStyle(color: Colors.red)),
          OutlinedButton.icon(
              onPressed: _refreshOrder,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar do banco local')),
          OutlinedButton.icon(
              onPressed: _showOrderHistory,
              icon: const Icon(Icons.history),
              label: const Text('Ver histórico')),
          if (_savedOrder!.status == 'created')
            TextButton.icon(
                onPressed: _cancelSavedOrder,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar pedido')),
        ],
        if (localDemoEnabled && _savedOrder?.status == 'cancelled')
          const ListTile(
            leading: Icon(Icons.cancel_outlined),
            title: Text('Pedido cancelado'),
            subtitle: Text('Consulte o histórico para ver o motivo.'),
          ),
        if (localDemoEnabled &&
            _savedOrder?.orderChannel == 'pickup' &&
            _savedOrder?.status != 'cancelled') ...[
          _sectionTitle('Retirada na loja'),
          for (final step in ['created', 'preparing', 'ready', 'picked_up'])
            ListTile(
              dense: true,
              leading: Icon(
                ['created', 'preparing', 'ready', 'picked_up'].indexOf(step) <=
                        ['created', 'preparing', 'ready', 'picked_up']
                            .indexOf(_savedOrder!.status)
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: GogdelyColors.blue,
              ),
              title: Text(step == 'ready'
                  ? 'Pronto para retirada'
                  : demoStatusLabel(step)),
            ),
        ],
        if ((!localDemoEnabled || _savedOrder?.status != 'cancelled') &&
            (!localDemoEnabled || _savedOrder?.orderChannel != 'pickup'))
          _sectionTitle('Acompanhamento'),
        if ((!localDemoEnabled || _savedOrder?.status != 'cancelled') &&
            (!localDemoEnabled || _savedOrder?.orderChannel != 'pickup'))
          for (var i = 0; i < 4; i++)
            ListTile(
              dense: true,
              leading: Icon(
                  i <=
                          (localDemoEnabled
                              ? switch (_savedOrder?.status) {
                                  'created' => 0,
                                  'preparing' => 1,
                                  'ready' => 1,
                                  'in_delivery' => 2,
                                  'delivered' => 3,
                                  _ => 0
                                }
                              : trackingStep)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: i <=
                          (localDemoEnabled
                              ? switch (_savedOrder?.status) {
                                  'created' => 0,
                                  'preparing' => 1,
                                  'ready' => 1,
                                  'in_delivery' => 2,
                                  'delivered' => 3,
                                  _ => 0
                                }
                              : trackingStep)
                      ? GogdelyColors.blue
                      : null),
              title: Text([
                'Pedido recebido',
                'Em preparação',
                'A caminho',
                'Entregue'
              ][i]),
              subtitle: i == trackingStep
                  ? const Text('Etapa atual da simulação')
                  : null,
            ),
        const SizedBox(height: 12),
        if ((!localDemoEnabled || _savedOrder?.status != 'cancelled') &&
            (!localDemoEnabled || _savedOrder?.orderChannel != 'pickup'))
          _demoMap(),
        const SizedBox(height: 16),
        if (!localDemoEnabled)
          FilledButton(
            onPressed: () => setState(() {
              if (trackingStep < 3) {
                trackingStep++;
              } else {
                page = _Page.complete;
              }
            }),
            child: Text(trackingStep < 3
                ? 'Avançar cenário fictício'
                : 'Ver conclusão fictícia'),
          ),
      ]);

  Widget _demoMap() => Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
          const Positioned(
              top: 25,
              left: 22,
              child: Icon(Icons.storefront, color: GogdelyColors.blue)),
          const Positioned(
              bottom: 22,
              right: 34,
              child: Icon(Icons.place, color: GogdelyColors.blue)),
          const Positioned(
              bottom: 10,
              left: 12,
              child: Text('Mapa ilustrativo · sem GPS',
                  style: TextStyle(fontSize: 10))),
        ]),
      );

  Widget _ordersPage() => _list([
        if (localDemoEnabled) ...[
          OutlinedButton.icon(
              onPressed: _refreshOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar pedidos do banco local')),
          if (_localError != null)
            Text(_localError!, style: const TextStyle(color: Colors.red)),
          if (_savedOrders.isEmpty)
            const Text('Nenhum pedido salvo neste banco local.'),
          for (final order in _savedOrders)
            _orderTile(
                '${order.storeName} · ${order.orderChannel == 'pickup' ? 'Retirada' : order.orderChannel == 'table' ? 'Mesa' : 'Entrega'}',
                'Pedido local #${order.id}',
                formatDemoPrice(order.totalCents),
                demoStatusLabel(order.status), () {
              setState(() {
                _savedOrder = order;
                lastOrderTotal = order.totalCents;
                store = [_pilotStore, ...demoStores]
                    .whereType<DemoStore>()
                    .firstWhere((s) => s.id == order.storeId,
                        orElse: () => demoStores.first);
                page = _Page.tracking;
              });
              _refreshOrder();
            }),
        ] else ...[
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final label in ['Todos', 'Em andamento', 'Concluídos'])
                  Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                          label: Text(label),
                          selected: category == label,
                          onSelected: (_) => setState(() => category = label))),
              ])),
          const SizedBox(height: 10),
          if (demoOrderCreated)
            _orderTile(
                store.name,
                'Pedido #12345',
                formatDemoPrice(lastOrderTotal),
                trackingStep == 3 ? 'Concluído (demo)' : 'Em andamento (demo)',
                () => open(_Page.tracking)),
          _orderTile('Pizzaria Napoli', 'Exemplo #12344', 'R\$ 44,90',
              'Exemplo concluído', () => open(_Page.review)),
          _orderTile('Burger House', 'Exemplo #12343', 'R\$ 67,69',
              'Exemplo concluído', () => open(_Page.review)),
          const SizedBox(height: 16),
          const Text(
              'Histórico ilustrativo. Nenhum pedido foi consultado na API.',
              style: TextStyle(fontSize: 11)),
        ],
      ]);

  Widget _orderTile(String name, String number, String value, String status,
          VoidCallback action) =>
      Card(
          child: ListTile(
        onTap: action,
        leading: SizedBox(
            width: 52,
            height: 52,
            child: DemoPhoto(
                name.contains('Pizza')
                    ? 'assets/images/pizza.png'
                    : 'assets/images/burger.png',
                height: 52,
                radius: 9)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$number · $value\n$status'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ));

  Widget _reviewPage() => _list([
        const SizedBox(height: 28),
        const Center(child: DemoPhoto('assets/images/pizza.png', height: 110)),
        const SizedBox(height: 14),
        const Center(
            child: Text('Como foi sua experiência?',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$i estrelas',
              icon: Icon(i <= reviewStars ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF59E0B), size: 30),
              onPressed: () => setState(() => reviewStars = i),
            ),
        ]),
        const SizedBox(height: 12),
        const TextField(
            maxLines: 4,
            decoration: InputDecoration(
                labelText: 'Conte mais sobre seu pedido fictício')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: reviewStars == 0
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Avaliação fictícia registrada apenas nesta sessão.')));
                    open(_Page.orders);
                  },
            child: const Text('Enviar avaliação de demonstração')),
      ]);

  Widget _profilePage() => _list([
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const CircleAvatar(
                      radius: 26,
                      backgroundColor: GogdelyColors.blue,
                      child: Text('JS',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('João Silva',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Text('Perfil de demonstração',
                            style: TextStyle(fontSize: 12)),
                      ]),
                ]))),
        const SizedBox(height: 10),
        _profileTile(
            Icons.place_outlined, 'Meus endereços', () => open(_Page.address)),
        _profileTile(Icons.receipt_long_outlined, 'Meus pedidos',
            () => open(_Page.orders)),
        _profileTile(Icons.notifications_none, 'Notificações',
            () => open(_Page.notifications)),
        _profileTile(
            Icons.palette_outlined, 'Aparência', () => open(_Page.settings)),
        _profileTile(
            Icons.qr_code_scanner,
            'Ler QR de mesa',
            () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const QrDemoScreen()))),
        _profileTile(Icons.login, 'Ver tela de login', () => open(_Page.login)),
        _profileTile(Icons.auto_awesome_outlined, 'Ver apresentação',
            () => open(_Page.splash)),
        const SizedBox(height: 10),
        const Text('Dados fictícios; nenhuma conta está conectada.',
            style: TextStyle(fontSize: 11)),
      ]);

  Widget _profileTile(IconData icon, String label, VoidCallback action) => Card(
          child: ListTile(
        leading: Icon(icon, color: GogdelyColors.blue),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: action,
      ));

  Widget _notificationsPage() => _list([
        for (final (icon, title, subtitle) in [
          (
            Icons.receipt_long,
            'Seu pedido de teste está a caminho',
            'Agora · cenário fictício'
          ),
          (
            Icons.local_offer_outlined,
            'Oferta especial',
            'Exemplo · sem cupom ativo'
          ),
          (
            Icons.notifications_active_outlined,
            'Bem-vindo ao GOGDELY',
            'Prévia local'
          ),
        ])
          Card(
              child: ListTile(
            leading: CircleAvatar(child: Icon(icon, color: GogdelyColors.blue)),
            title: Text(title),
            subtitle: Text(subtitle),
          )),
      ]);

  Widget _addressPage() => _list([
        const Text('Onde você quer receber?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const TextField(
            decoration: InputDecoration(
                hintText: 'Buscar endereço de demonstração',
                prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 12),
        _demoMap(),
        const SizedBox(height: 12),
        Card(
            child: ListTile(
          leading: const Icon(Icons.place, color: GogdelyColors.blue),
          title: Text(addressLabel),
          subtitle: const Text('Centro, São Paulo · endereço fictício'),
        )),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => open(page == _Page.address && cart.isNotEmpty
                ? _Page.checkout
                : _Page.home),
            child: const Text('Confirmar endereço fictício')),
        const SizedBox(height: 8),
        const Text('Sem geolocalização ou geocodificação real.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
      ]);

  Widget _settingsPage() => _list([
        const Text('Tema do aplicativo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        for (final (mode, label, icon) in [
          (ThemeMode.system, 'Automático', Icons.brightness_auto),
          (ThemeMode.light, 'Claro', Icons.light_mode_outlined),
          (ThemeMode.dark, 'Escuro', Icons.dark_mode_outlined),
        ])
          ListTile(
              title: Text(label),
              leading: Icon(icon),
              trailing: Icon(
                  widget.themeMode == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: GogdelyColors.blue),
              onTap: () => widget.onThemeChanged?.call(mode)),
        const SizedBox(height: 12),
        const Text(
            'A preferência vale apenas para esta sessão de demonstração.',
            style: TextStyle(fontSize: 11)),
      ]);

  Widget _loginPage() => _list([
        const SizedBox(height: 30),
        const Center(child: BrandWordmark(size: 33, center: true)),
        const SizedBox(height: 20),
        const Text('Olá!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const Text('Entre para continuar'),
        const SizedBox(height: 22),
        const TextField(
            decoration: InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                labelText: 'E-mail ou telefone')),
        const SizedBox(height: 10),
        const TextField(
            obscureText: true,
            decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline), labelText: 'Senha')),
        const SizedBox(height: 15),
        FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Login não conectado. Explore a prévia sem cadastro.'))),
            child: const Text('Entrar')),
        TextButton(
            onPressed: () => open(_Page.home),
            child: const Text('Explorar sem cadastro')),
        const SizedBox(height: 8),
        const Text(
            'Login social e criação de conta serão ligados após autenticação homologada.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11)),
      ]);

  Widget _splashPage() => Stack(children: [
        const Positioned.fill(
            child: DemoPhoto('assets/images/city.png',
                height: double.infinity, radius: 0)),
        Positioned.fill(
            child: Container(
                color: GogdelyColors.darkBackground.withValues(alpha: .48))),
        Column(children: [
          const Spacer(),
          const BrandWordmark(size: 42, center: true),
          const Text('Tudo mais perto de você.',
              style: TextStyle(color: Colors.white)),
          const Spacer(flex: 3),
          Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => open(_Page.onboarding),
                      child: const Text('Começar')))),
        ]),
      ]);

  Widget _onboardingPage() => Stack(children: [
        const Positioned.fill(
            child: DemoPhoto('assets/images/pizza.png',
                height: double.infinity, radius: 0)),
        Positioned.fill(
            child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
              Colors.black54,
              Colors.transparent,
              GogdelyColors.darkBackground
            ])))),
        Column(children: [
          const Spacer(),
          const Padding(
              padding: EdgeInsets.all(22),
              child: Text('Tudo o que você precisa, em um só app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900))),
          const Text('Comida, mercado, farmácia, lojas e muito mais.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 30),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => open(_Page.login),
                      child: const Text('Continuar')))),
          TextButton(
              onPressed: () => open(_Page.home),
              child: const Text('Pular e explorar',
                  style: TextStyle(color: Colors.white))),
          const SizedBox(height: 20),
        ]),
      ]);

  Widget _completePage() => Center(
          child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircleAvatar(
              radius: 42,
              backgroundColor: GogdelyColors.blue,
              child: Icon(Icons.check, size: 50, color: Colors.white)),
          const SizedBox(height: 22),
          const Text('Cenário concluído!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Esta entrega foi apenas uma simulação local.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 38),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => open(_Page.review),
                  child: const Text('Avaliar demonstração'))),
          TextButton(
              onPressed: () => open(_Page.orders),
              child: const Text('Ver pedidos fictícios',
                  style: TextStyle(color: Colors.white))),
        ]),
      ));
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()
      ..color = Colors.white.withValues(alpha: .75)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (i + 1) / 7;
      canvas.drawLine(Offset(x, 0), Offset(x - 35, size.height), street);
    }
    for (var i = 0; i < 4; i++) {
      final y = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 13), street);
    }
    final route = Path()
      ..moveTo(25, 35)
      ..lineTo(size.width * .35, 55)
      ..lineTo(size.width * .47, 112)
      ..lineTo(size.width * .8, 150);
    canvas.drawPath(
        route,
        Paint()
          ..color = GogdelyColors.blue
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
