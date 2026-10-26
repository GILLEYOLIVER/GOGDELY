import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

import 'client_components.dart';
import 'client_preferences.dart';
import 'brand_motion.dart';
import 'demo_catalog.dart';
import 'map_demo_screen.dart';
import 'local_location.dart';
import 'qr_demo_screen.dart';

enum _Page {
  home,
  categories,
  search,
  offers,
  store,
  product,
  cart,
  checkout,
  payment,
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
  help,
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
      this.localApi,
      this.preferencesStore});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final LocalDemoApi? localApi;
  final ClientPreferencesStore? preferencesStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LocalDemoApi _localApi = widget.localApi ?? LocalDemoApi();
  late final ClientPreferencesStore _preferencesStore =
      widget.preferencesStore ?? const DeviceClientPreferencesStore();
  ClientPreferences _savedPreferences = const ClientPreferences();
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
  bool _savingPayment = false;
  String? _paymentRequestKey;
  DemoStore? _pilotStore;
  List<DemoStore> _pilotStores = const [];
  bool _refreshingMenu = false;
  String? _menuError;
  String _menuFingerprint = '';
  String _catalogFingerprint = '';
  _Page page = _Page.home;
  _Page _addressReturnPage = _Page.home;
  _Page _paymentReturnPage = _Page.checkout;
  DeviceLocation? _selectedLocation;
  DemoStore store = demoStores.first;
  DemoStore? cartStore;
  DemoProduct product = demoStores.first.products.first;
  final List<_CartLine> cart = [];
  String category = 'Todos';
  String search = '';
  String _storeSort = 'Padrão';
  bool _promotionsOnly = false;
  final Set<String> _favoriteStoreIds = {};
  final TextEditingController _searchController = TextEditingController();
  final PageController _promoController = PageController(viewportFraction: .94);
  int _promoPageIndex = 0;
  String _storeSearch = '';
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
  final TextEditingController _addressStreetController =
      TextEditingController(text: 'Rua das Flores');
  final TextEditingController _addressNumberController =
      TextEditingController(text: '123');
  final TextEditingController _addressComplementController =
      TextEditingController();
  final TextEditingController _addressReferenceController =
      TextEditingController();
  String _addressKind = 'Casa';
  bool demoOrderCreated = false;
  int lastOrderTotal = 0;
  bool _notifyOrderStatus = true;
  bool _notifyPromotions = false;
  bool _refreshingNotifications = false;
  List<
      ({
        int orderId,
        String? fromStatus,
        String toStatus,
        String actor,
        String reason,
        String createdAt
      })> _notificationEvents = const [];

  Iterable<DemoStore> get visibleStores =>
      localDemoEnabled ? _pilotStores : demoStores;

  List<DemoProduct> get _visibleStoreProducts => store.products
      .where((product) =>
          _storeSearch.isEmpty ||
          product.name.toLowerCase().contains(_storeSearch) ||
          product.category.toLowerCase().contains(_storeSearch))
      .toList();

  @override
  void initState() {
    super.initState();
    _restoreClientPreferences();
    if (localDemoEnabled) {
      _refreshMenu();
      _localRefreshTimer = Timer.periodic(localDemoRefreshInterval, (_) {
        if ({_Page.home, _Page.search, _Page.store, _Page.product}
            .contains(page)) {
          _refreshMenu();
        }
        if (page == _Page.orders) _refreshOrders();
        if (page == _Page.tracking) _refreshOrder();
        if (page == _Page.checkout || page == _Page.payment) {
          _refreshPaymentMethods();
        }
      });
    }
  }

  void _restoreClientPreferences() {
    _savedPreferences = ClientPreferences.decode(_preferencesStore.read());
    _favoriteStoreIds.addAll(_savedPreferences.favoriteStoreIds);
    _addressStreetController.text = _savedPreferences.street;
    _addressNumberController.text = _savedPreferences.number;
    _addressComplementController.text = _savedPreferences.complement;
    _addressReferenceController.text = _savedPreferences.reference;
    _addressKind = _savedPreferences.kind;
    addressLabel = _savedPreferences.addressLabel;
  }

  void open(_Page target) {
    if (target == _Page.address && page != _Page.address) {
      _addressReturnPage = page;
    }
    setState(() => page = target);
    if (localDemoEnabled &&
        {_Page.home, _Page.search, _Page.store}.contains(target)) {
      _refreshMenu();
    }
    if (localDemoEnabled && target == _Page.orders) _refreshOrders();
    if (localDemoEnabled && target == _Page.notifications) {
      _refreshOrders().then((_) {
        if (mounted) _refreshNotifications();
      });
    }
    if (localDemoEnabled && target == _Page.tracking) {
      _refreshOrder();
      _refreshRatings();
    }
    if (localDemoEnabled && target == _Page.store) _refreshRatings();
    if (localDemoEnabled &&
        (target == _Page.checkout || target == _Page.payment)) {
      _refreshPaymentMethods();
    }
  }

  void _openPaymentPage() {
    _paymentReturnPage = page;
    open(_Page.payment);
  }

  Future<void> _openMap({bool pickLocation = false}) async {
    final selected = await Navigator.of(context).push<DeviceLocation>(
      MaterialPageRoute(
        builder: (routeContext) => MapDemoScreen(
          stores: visibleStores.toList(),
          initialLocation: _selectedLocation,
          pickLocation: pickLocation,
          onStoreSelected: pickLocation
              ? null
              : (value) {
                  Navigator.of(routeContext).pop();
                  openStore(value);
                },
        ),
      ),
    );
    if (mounted && selected != null) {
      setState(() => _selectedLocation = selected);
    }
  }

  Future<void> _simulateLocalPayment() async {
    final order = _savedOrder;
    if (!localDemoEnabled ||
        order == null ||
        _savingPayment ||
        order.paymentStatus != 'not_processed' ||
        order.status == 'cancelled') {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar pagamento de teste?'),
        content:
            Text('Pedido #${order.id} · ${formatDemoPrice(order.totalCents)}. '
                'Isto registra somente uma simulação no banco local. '
                'Nenhuma cobrança, Pix ou liquidação acontece.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Registrar teste')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _savingPayment = true;
      _localError = null;
    });
    _paymentRequestKey ??= newDemoRequestKey();
    try {
      final updated = await _localApi.simulatePayment(
        orderId: order.id,
        requestKey: _paymentRequestKey!,
        reason: 'Simulação solicitada pelo cliente no laboratório local',
      );
      if (mounted) setState(() => _savedOrder = updated);
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _savingPayment = false);
    }
  }

  Future<void> _refreshPaymentMethods() async {
    if (_refreshingPaymentMethods) return;
    _refreshingPaymentMethods = true;
    try {
      final methods =
          await _localApi.paymentMethods(storeId: cartStore?.id ?? store.id);
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
    if (store.id != localDemoPilotStoreId) {
      if (mounted) setState(() => _storeRatings = null);
      return;
    }
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
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var star = 1; star <= 5; star++)
                        IconButton(
                            onPressed: () => setDialogState(() => stars = star),
                            icon: Icon(
                                stars >= star ? Icons.star : Icons.star_border),
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
    _searchController.dispose();
    _promoController.dispose();
    _addressStreetController.dispose();
    _addressNumberController.dispose();
    _addressComplementController.dispose();
    _addressReferenceController.dispose();
    _localApi.close();
    super.dispose();
  }

  Future<void> _refreshMenu() async {
    if (_refreshingMenu) return;
    _refreshingMenu = true;
    try {
      final catalog = await _localApi.catalog();
      if (!mounted) return;
      final fingerprint = catalog
          .map((entry) =>
              '${entry['id']}:${(entry['products'] as List).map((item) => '${item['product_id']}:${item['updated_at']}:${item['effective_price_cents']}:${item['stock_quantity']}:${item['orderable']}').join(',')}')
          .join('|');
      if (fingerprint == _menuFingerprint && _menuError == null) return;
      final stores = catalog.map((entry) {
        final products = (entry['products'] as List)
            .map((item) => DemoMenuItem.fromJson(item as Map<String, dynamic>))
            .where((item) => item.orderable)
            .map((item) => DemoProduct(
                  item.productId,
                  item.name,
                  item.description,
                  item.effectivePriceCents,
                  image: item.imageRef,
                  badge:
                      item.promoPercent > 0 ? '${item.promoPercent}% OFF' : '',
                  category: item.category,
                  stockQuantity: item.stockQuantity,
                  addons: item.addons,
                  originalPriceCents:
                      item.promoPercent > 0 ? item.priceCents : null,
                ))
            .toList();
        return DemoStore(
            entry['id'] as String,
            entry['name'] as String,
            entry['category'] as String,
            entry['description'] as String,
            products,
            image: entry['image'] as String? ?? '',
            eta: entry['eta'] as String? ?? '25–35 min',
            latitude: (entry['latitude'] as num?)?.toDouble(),
            longitude: (entry['longitude'] as num?)?.toDouble());
      }).toList();
      final updated = stores.firstWhere((value) => value.id == store.id,
          orElse: () => stores.first);
      final cartCatalog =
          catalog.where((entry) => entry['id'] == cartStore?.id).firstOrNull;
      final cartFingerprint = cartCatalog == null
          ? ''
          : '${cartCatalog['id']}:${(cartCatalog['products'] as List).map((item) => '${item['product_id']}:${item['updated_at']}:${item['effective_price_cents']}:${item['stock_quantity']}:${item['orderable']}').join(',')}';
      final cartCleared = cart.isNotEmpty &&
          ((_catalogFingerprint.isNotEmpty &&
                  _catalogFingerprint != cartFingerprint) ||
              cartCatalog == null ||
              cart.any((line) => !stores
                  .firstWhere((value) => value.id == cartStore?.id,
                      orElse: () => updated)
                  .products
                  .any((item) => item.id == line.product.id)));
      setState(() {
        if (cartCleared) {
          cart.clear();
          cartStore = null;
          _requestKey = null;
        }
        _pilotStores = stores;
        _pilotStore = stores
            .where((value) => value.id == localDemoPilotStoreId)
            .firstOrNull;
        if (store.id == updated.id) store = updated;
        final selected = updated.products
            .where((value) => value.id == product.id)
            .firstOrNull;
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
        _catalogFingerprint = cartFingerprint;
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
      final orders = (await _localApi.orders())
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
        _paymentRequestKey = null;
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
        _storeSearch = '';
        page = _Page.store;
      });

  void openProduct(DemoProduct value) => setState(() {
        product = value;
        selectedSize = 'Tradicional';
        extras.clear();
        productQuantity = 1;
        page = _Page.product;
      });

  void _searchFor(String term) {
    _searchController.text = term;
    setState(() {
      search = term;
      category = 'Todos';
      page = _Page.search;
    });
  }

  void _openSearchProduct(DemoStore owner, DemoProduct value) {
    store = owner;
    _storeSearch = '';
    openProduct(value);
  }

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
      _Page.offers,
      _Page.orders,
      _Page.profile
    }.contains(page);
    return Scaffold(
      backgroundColor: darkPage
          ? GogdelyColors.darkBackground
          : dark
              ? null
              : Colors.white,
      appBar: _appBar(darkPage),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, _) =>
              currentChild ?? const SizedBox.shrink(),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(.035, .015), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(page), child: _pageBody()),
        ),
      ),
      bottomNavigationBar:
          showNav ? _navigation(darkPage || dark) : _checkoutActionBar(),
    );
  }

  Widget? _checkoutActionBar() {
    if (page == _Page.product) {
      return _bottomAction(
        label:
            'Adicionar · ${formatDemoPrice(selectedPrice * productQuantity)}',
        onPressed: addSelectedProduct,
        leading: _quantityControl(),
      );
    }
    if (page == _Page.cart && cart.isNotEmpty) {
      return _bottomAction(
        label: 'Continuar',
        onPressed: () => open(_Page.checkout),
        leading: _bottomTotal(),
      );
    }
    if (page == _Page.checkout && cart.isNotEmpty) {
      return _bottomAction(
        label: _savingOrder
            ? 'Salvando no banco local...'
            : 'Revisar pedido · ${formatDemoPrice(total)}',
        onPressed: _savingOrder ||
                (localDemoEnabled &&
                    (!_paymentMethodsLoaded || _paymentMethodsError != null))
            ? null
            : _reviewAndSubmitOrder,
        leading: _bottomTotal(),
      );
    }
    if (page == _Page.payment) {
      return _bottomAction(
          label: 'Usar ${demoPaymentLabel(paymentMethod)}',
          onPressed: () => open(_paymentReturnPage));
    }
    if (page == _Page.address) {
      return _bottomAction(label: 'Salvar endereço', onPressed: _saveAddress);
    }
    return null;
  }

  void _createFictionalOrder() => setState(() {
        lastOrderTotal = total;
        demoOrderCreated = true;
        trackingStep = 0;
        cart.clear();
        cartStore = null;
        page = _Page.tracking;
      });

  Future<void> _reviewAndSubmitOrder() async {
    if (cart.isEmpty || _savingOrder) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Revise o seu pedido',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(cartStore?.name ?? store.name),
              subtitle: Text('$itemCount ${itemCount == 1 ? 'item' : 'itens'}'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_orderChannel == 'pickup'
                  ? Icons.store_mall_directory_outlined
                  : Icons.location_on_outlined),
              title: Text(_orderChannel == 'pickup'
                  ? 'Retirada na loja'
                  : 'Entrega em $addressLabel'),
              subtitle: Text(_scheduleEnabled && _scheduledAt != null
                  ? _formatSchedule(_scheduledAt!)
                  : 'Assim que possível'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(demoPaymentLabel(paymentMethod)),
              subtitle: const Text('Forma pretendida; sem cobrança no app'),
            ),
            const Divider(),
            Row(children: [
              const Expanded(
                  child: Text('Total estimado',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              Text(formatDemoPrice(total),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Confirmar pedido fictício'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Alterar pedido'),
            ),
          ]),
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    if (localDemoEnabled) {
      await _submitLocalOrder();
    } else {
      _createFictionalOrder();
    }
  }

  Widget _bottomTotal() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total estimado', style: TextStyle(fontSize: 11)),
          Text(formatDemoPrice(total),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );

  Widget _quantityControl() => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: productQuantity > 1
                ? () => setState(() => productQuantity--)
                : null,
            icon: const Icon(Icons.remove, size: 19)),
        Text('$productQuantity'),
        IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: product.stockQuantity != null &&
                    productQuantity >= product.stockQuantity!
                ? null
                : () => setState(() => productQuantity++),
            icon: const Icon(Icons.add, size: 19)),
      ]);

  Widget _bottomAction({
    required String label,
    required VoidCallback? onPressed,
    Widget? leading,
  }) =>
      Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 12)
            ]),
        child: Row(children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
              child: FilledButton(
                  onPressed: onPressed, child: Text(label, maxLines: 1))),
        ]),
      );

  PreferredSizeWidget? _appBar(bool darkPage) {
    if ({_Page.splash, _Page.onboarding, _Page.complete}.contains(page)) {
      return null;
    }
    if (page == _Page.home) {
      return AppBar(
        toolbarHeight: 82,
        titleSpacing: 16,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AnimatedBrandLogo(),
          const SizedBox(height: 4),
          InkWell(
              onTap: () => open(_Page.address),
              child: Row(children: [
                const Icon(Icons.location_on_outlined,
                    color: GogdelyColors.blue, size: 17),
                const SizedBox(width: 4),
                Flexible(
                    child: Text(addressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700))),
                const Icon(Icons.keyboard_arrow_down, size: 17),
              ])),
        ]),
        actions: [
          IconButton(
              tooltip: 'Sacola',
              onPressed: () => open(_Page.cart),
              icon: _cartIcon()),
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
      _Page.offers: 'Ofertas',
      _Page.store: store.name,
      _Page.product: product.name,
      _Page.cart: 'SACOLA',
      _Page.checkout: 'REVISAR PEDIDO',
      _Page.payment: 'PAGAMENTO',
      _Page.tracking: 'Acompanhamento',
      _Page.orders: 'Meus pedidos',
      _Page.review: 'Avaliar pedido',
      _Page.profile: 'Minha área',
      _Page.notifications: 'Notificações',
      _Page.address: 'ENDEREÇO DE ENTREGA',
      _Page.login: 'Entrar',
      _Page.settings: 'Configurações',
    };
    return AppBar(
      backgroundColor: darkPage ? GogdelyColors.darkBackground : null,
      foregroundColor: darkPage ? Colors.white : null,
      leading: {
        _Page.categories,
        _Page.search,
        _Page.offers,
        _Page.orders,
        _Page.profile
      }.contains(page)
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
          : page == _Page.cart && cart.isNotEmpty
              ? [
                  TextButton(
                      onPressed: () => setState(() {
                            cart.clear();
                            cartStore = null;
                          }),
                      child: const Text('Limpar'))
                ]
              : null,
    );
  }

  _Page _backPage() => switch (page) {
        _Page.product => _Page.store,
        _Page.cart => _Page.store,
        _Page.checkout => _Page.cart,
        _Page.payment => _paymentReturnPage,
        _Page.tracking || _Page.review => _Page.orders,
        _Page.store => _Page.home,
        _Page.address => _addressReturnPage,
        _Page.notifications || _Page.settings || _Page.login => _Page.profile,
        _ => _Page.home,
      };

  Widget _cartIcon() => Badge(
        isLabelVisible: itemCount > 0,
        label: Text('$itemCount'),
        child: const Icon(Icons.shopping_bag_outlined),
      );

  Widget _navigation(bool dark) => BottomNavigationBar(
        backgroundColor: dark ? GogdelyColors.darkBackground : Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: dark ? Colors.white : GogdelyColors.graphite,
        unselectedItemColor: dark ? Colors.white70 : GogdelyColors.mutedLight,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: switch (page) {
          _Page.search || _Page.categories => 1,
          _Page.offers => 2,
          _Page.orders => 3,
          _Page.profile => 4,
          _ => 0,
        },
        onTap: (index) => open([
          _Page.home,
          _Page.search,
          _Page.offers,
          _Page.orders,
          _Page.profile
        ][index]),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Busca'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer_outlined),
              activeIcon: Icon(Icons.local_offer),
              label: 'Ofertas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      );

  Widget _pageBody() => switch (page) {
        _Page.home => _home(),
        _Page.categories => _categories(),
        _Page.search => _searchPage(),
        _Page.offers => _offersPage(),
        _Page.store => _storePage(),
        _Page.product => _productPage(),
        _Page.cart => _cartPage(),
        _Page.checkout => _checkoutPage(),
        _Page.payment => _paymentPage(),
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
        _Page.help => _helpPage(),
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
        _mainCategoryRail(),
        const SizedBox(height: 14),
        TextField(
          readOnly: true,
          onTap: () => open(_Page.search),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Busque lojas ou pratos'),
        ),
        const SizedBox(height: 18),
        _promoCarousel(),
        _quickDiscovery(),
        _featuredProducts(),
        _filterBar(),
        _sectionTitle(
            localDemoEnabled ? 'Lojas do laboratório' : 'Lojas para explorar',
            onMore: () => open(_Page.search)),
        for (final value in visibleStores.take(4))
          DemoStoreCard(value,
              localPreview: localDemoEnabled,
              isFavorite: _favoriteStoreIds.contains(value.id),
              onFavorite: () => _toggleFavorite(value.id),
              onTap: () => openStore(value)),
        if (localDemoEnabled && _pilotStore == null)
          Text(_menuError ?? 'Carregando cardápio local da Burger House...'),
        if (localDemoEnabled &&
            _pilotStore != null &&
            _pilotStore!.products
                .any((product) => product.badge.isNotEmpty)) ...[
          _sectionTitle('Promoções da Burger House',
              onMore: () => openStore(_pilotStore!)),
          for (final product in _pilotStore!.products
              .where((product) => product.badge.isNotEmpty)
              .take(3))
            Card(
                child: ListTile(
              onTap: () => openProduct(product),
              leading: const Icon(Icons.local_offer_outlined,
                  color: GogdelyColors.blue),
              title: Text(product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${product.badge} · de ${formatDemoPrice(product.originalPriceCents ?? product.priceCents)} '
                  'por ${formatDemoPrice(product.priceCents)}'),
              trailing: const Icon(Icons.chevron_right),
            )),
          const Text(
              'Promoções configuradas pela empresa no laboratório local; a API calcula o preço salvo no pedido.',
              style: TextStyle(fontSize: 11)),
        ],
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
              child:
                  _resourceTile(Icons.map_outlined, 'Mapa', () => _openMap())),
        ]),
        const SizedBox(height: 8),
        const Text(
            'Prévia local com dados fictícios. Sem pedidos ou pagamentos reais.',
            style: TextStyle(fontSize: 11)),
      ]);

  Widget _promoCarousel() {
    final available = visibleStores.toList();
    final source = available.isEmpty ? demoStores : available;
    DemoStore pick(String type, int fallback) => source.firstWhere(
          (candidate) => candidate.category == type,
          orElse: () => source[fallback % source.length],
        );
    final promotions = [
      (
        store: source.first,
        title: 'Sabor que\nse aproxima.',
        action: 'Ver cardápio'
      ),
      (
        store: pick('Mercado', 1),
        title: 'Seu dia a dia\nmais simples.',
        action: 'Explorar loja'
      ),
      (
        store: pick('Farmácia', 2),
        title: 'Cuidado que\nchega até você.',
        action: 'Ver produtos'
      ),
    ];
    return Column(children: [
      SizedBox(
        height: 204,
        child: PageView.builder(
          controller: _promoController,
          itemCount: promotions.length,
          onPageChanged: (index) => setState(() => _promoPageIndex = index),
          itemBuilder: (context, index) {
            final promotion = promotions[index];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Material(
                  color: GogdelyColors.graphite,
                  child: InkWell(
                    onTap: localDemoEnabled && available.isEmpty
                        ? null
                        : () => openStore(promotion.store),
                    child: Stack(fit: StackFit.expand, children: [
                      DemoPhoto(promotion.store.image, height: 204, radius: 0),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xE5151B2B), Color(0x10151B2B)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(promotion.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05)),
                            const SizedBox(height: 6),
                            Text(
                                localDemoEnabled && available.isEmpty
                                    ? 'Carregando lojas locais...'
                                    : promotion.store.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            const Spacer(),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                  color: GogdelyColors.blue,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Text(promotion.action,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 9),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var index = 0; index < promotions.length; index++)
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            width: index == _promoPageIndex ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == _promoPageIndex
                  ? GogdelyColors.blue
                  : GogdelyColors.accent.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
      ]),
    ]);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favoriteStoreIds.add(id)) _favoriteStoreIds.remove(id);
    });
    _savedPreferences = ClientPreferences(
      street: _savedPreferences.street,
      number: _savedPreferences.number,
      complement: _savedPreferences.complement,
      reference: _savedPreferences.reference,
      kind: _savedPreferences.kind,
      favoriteStoreIds: _favoriteStoreIds,
    );
    if (!_preferencesStore.write(_savedPreferences.encode())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Favorito apenas nesta sessão; armazenamento indisponível.')));
    }
  }

  Widget _mainCategoryRail() {
    final available = visibleStores.map((store) => store.category).toSet();
    final entries = demoCategories.where((entry) =>
        !localDemoEnabled ||
        available.isEmpty ||
        available.contains(entry.$1) ||
        entry.$1 == 'Mais');
    return SizedBox(
      height: 54,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final (name, icon, _) in entries)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(icon,
                    size: 19,
                    color:
                        category == name ? Colors.white : GogdelyColors.blue),
                label: Text(name),
                selected: category == name,
                selectedColor: GogdelyColors.blue,
                labelStyle: TextStyle(
                    color: category == name ? Colors.white : null,
                    fontWeight: FontWeight.w600),
                onSelected: (_) {
                  if (name == 'Mais') {
                    open(_Page.categories);
                    return;
                  }
                  setState(() => category = name);
                  open(_Page.search);
                },
              )),
      ]),
    );
  }

  Widget _quickDiscovery() {
    final labels = localDemoEnabled
        ? (_pilotStores
            .expand((store) => store.products)
            .map((product) => product.category.trim())
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList())
        : ['Lanches', 'Pizza', 'Sushi', 'Promoções'];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(
          localDemoEnabled ? 'Explore os cardápios' : 'O que você procura?'),
      SizedBox(
          height: 103,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final label in labels)
              Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                      onTap: () => label == 'Promoções'
                          ? open(_Page.offers)
                          : _searchFor(label),
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                          width: 88,
                          child: Column(children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                  color:
                                      GogdelyColors.blue.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(18)),
                              child: Icon(
                                  label == 'Promoções'
                                      ? Icons.local_offer_outlined
                                      : _discoveryIcon(label),
                                  color: GogdelyColors.blue,
                                  size: 31),
                            ),
                            const SizedBox(height: 6),
                            Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12)),
                          ])))),
          ])),
    ]);
  }

  IconData _discoveryIcon(String label) {
    final value = label.toLowerCase();
    if (value.contains('pizza')) return Icons.local_pizza_outlined;
    if (value.contains('açaí') || value.contains('sobremesa')) {
      return Icons.icecream_outlined;
    }
    if (value.contains('bebida')) return Icons.local_drink_outlined;
    if (value.contains('saúde') || value.contains('farmácia')) {
      return Icons.medical_services_outlined;
    }
    if (value.contains('pet')) return Icons.pets_outlined;
    if (value.contains('pão') || value.contains('padaria')) {
      return Icons.bakery_dining_outlined;
    }
    if (value.contains('mercado') || value.contains('horti')) {
      return Icons.shopping_basket_outlined;
    }
    return Icons.restaurant_menu;
  }

  List<({DemoStore store, DemoProduct product})> get _offerProducts => [
        for (final value in visibleStores)
          for (final item in value.products)
            if (item.badge.isNotEmpty) (store: value, product: item),
      ];

  Widget _featuredProducts() {
    final items = _offerProducts.isNotEmpty
        ? _offerProducts
        : [
            for (final value in visibleStores)
              for (final item in value.products.take(1))
                (store: value, product: item),
          ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(
          _offerProducts.isNotEmpty ? 'Ofertas do cardápio' : 'Em destaque',
          onMore: _offerProducts.isNotEmpty ? () => open(_Page.offers) : null),
      SizedBox(
          height: 218,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final entry in items.take(6))
              Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                      width: 148,
                      child: InkWell(
                          onTap: () =>
                              _openSearchProduct(entry.store, entry.product),
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    height: 138,
                                    child: DemoPhoto(entry.product.image,
                                        height: 138, radius: 16)),
                                const SizedBox(height: 6),
                                Text(entry.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                Text(formatDemoPrice(entry.product.priceCents),
                                    style: const TextStyle(
                                        color: GogdelyColors.blue,
                                        fontWeight: FontWeight.w800)),
                                Text(entry.store.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                              ])))),
          ])),
    ]);
  }

  Widget _filterBar() => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 2),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ActionChip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(_storeSort == 'Padrão' ? 'Ordenar' : _storeSort),
                  onPressed: _openSortSheet),
              const SizedBox(width: 8),
              FilterChip(
                  label: const Text('Ofertas'),
                  selected: _promotionsOnly,
                  onSelected: (value) => setState(() {
                        _promotionsOnly = value;
                        page = _Page.search;
                      })),
              const SizedBox(width: 8),
              ActionChip(
                  label: const Text('Categorias'),
                  onPressed: () => open(_Page.categories)),
            ])),
      );

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Ordenar lojas',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  for (final value in ['Padrão', 'Avaliação', 'Tempo estimado'])
                    ListTile(
                        title: Text(value),
                        leading: Icon(
                            _storeSort == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: GogdelyColors.blue),
                        onTap: () => Navigator.pop(context, value)),
                ]))));
    if (selected != null && mounted) setState(() => _storeSort = selected);
  }

  Widget _offersPage() {
    final items = _offerProducts;
    return _list([
      const Text('Ofertas do cardápio',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const Text('Valores da prévia; confira o total antes de salvar o pedido.',
          style: TextStyle(fontSize: 12)),
      const SizedBox(height: 14),
      if (items.isEmpty)
        const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Nenhuma oferta cadastrada neste cardápio.')),
      for (final entry in items)
        DemoProductTile(entry.product,
            onTap: () => _openSearchProduct(entry.store, entry.product)),
    ]);
  }

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

  List<DemoStore> get searchResults {
    final term = search.trim().toLowerCase();
    final matches = visibleStores.where((value) {
      final matchCategory = category == 'Todos' || value.category == category;
      return matchCategory &&
          (!_promotionsOnly ||
              value.products.any((item) => item.badge.isNotEmpty)) &&
          (term.isEmpty ||
              value.name.toLowerCase().contains(term) ||
              value.category.toLowerCase().contains(term) ||
              value.products.any((p) => p.name.toLowerCase().contains(term)));
    }).toList();
    if (_storeSort == 'Avaliação') {
      matches.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_storeSort == 'Tempo estimado') {
      int minutes(DemoStore value) =>
          int.tryParse(RegExp(r'\d+').firstMatch(value.eta)?.group(0) ?? '') ??
          999;
      matches.sort((a, b) => minutes(a).compareTo(minutes(b)));
    }
    return matches;
  }

  List<({DemoStore store, DemoProduct product})> get productSearchResults {
    final term = search.trim().toLowerCase();
    if (term.isEmpty) return const [];
    return [
      for (final value in visibleStores)
        if (category == 'Todos' || value.category == category)
          for (final item in value.products)
            if ((!_promotionsOnly || item.badge.isNotEmpty) &&
                (item.name.toLowerCase().contains(term) ||
                    item.category.toLowerCase().contains(term)))
              (store: value, product: item),
    ];
  }

  Widget _searchPage() => _list([
        TextField(
          autofocus: false,
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: localDemoEnabled
                  ? 'Busque lojas ou produtos locais'
                  : 'Busque lojas ou produtos',
              suffixIcon: search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => search = '');
                      },
                      icon: const Icon(Icons.close))),
          onChanged: (value) => setState(() => search = value),
        ),
        const SizedBox(height: 10),
        _mainCategoryRail(),
        if (search.isEmpty &&
            category == 'Todos' &&
            visibleStores.length > 3) ...[
          _sectionTitle('Buscas rápidas'),
          Wrap(spacing: 8, runSpacing: 3, children: [
            for (final term in ['Pizza', 'Hambúrguer', 'Açaí', 'Farmácia'])
              ActionChip(
                avatar: Icon(_discoveryIcon(term),
                    size: 17, color: GogdelyColors.blue),
                label: Text(term),
                onPressed: () => _searchFor(term),
              ),
          ]),
        ],
        _filterBar(),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final label in localDemoEnabled
                  ? [
                      'Todos',
                      ..._pilotStores.map((store) => store.category).toSet()
                    ]
                  : ['Todos', 'Restaurantes', 'Mercado', 'Farmácia'])
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                        label: Text(label),
                        selected: category == label,
                        onSelected: (_) => setState(() => category = label))),
            ])),
        _sectionTitle(
            search.isEmpty ? 'Lojas para explorar' : 'Lojas encontradas'),
        if (searchResults.isEmpty && productSearchResults.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  'Nenhuma loja ou produto encontrado. Tente outra busca ou categoria.')),
        for (final value in searchResults)
          DemoStoreCard(value,
              localPreview: localDemoEnabled,
              isFavorite: _favoriteStoreIds.contains(value.id),
              onFavorite: () => _toggleFavorite(value.id),
              onTap: () => openStore(value)),
        if (productSearchResults.isNotEmpty) ...[
          _sectionTitle('Produtos encontrados'),
          for (final result in productSearchResults)
            DemoProductTile(result.product,
                onTap: () => _openSearchProduct(result.store, result.product)),
        ],
      ]);

  Widget _storePage() => _list([
        DemoPhoto(store.image, height: 220, radius: 18),
        const SizedBox(height: 12),
        Text(store.name,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(store.description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
            localDemoEnabled
                ? 'Loja piloto · entrega estimada na prévia: ${store.eta}'
                : '⭐ ${store.rating} · ${store.eta} · Aberto',
            style: Theme.of(context).textTheme.bodySmall),
        if (localDemoEnabled && (_storeRatings?['count'] as int? ?? 0) > 0)
          Text(
              '⭐ ${_storeRatings!['average_stars']} · ${_storeRatings!['count']} avaliações locais',
              style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar no cardápio desta loja'),
            onChanged: (value) =>
                setState(() => _storeSearch = value.trim().toLowerCase())),
        const SizedBox(height: 4),
        if (store.products.any((item) => item.badge.isNotEmpty))
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                  avatar: const Icon(Icons.local_offer_outlined,
                      size: 17, color: GogdelyColors.blue),
                  label: const Text('Ofertas no cardápio'))),
        _sectionTitle('Cardápio'),
        if (localDemoEnabled && _menuError != null) Text(_menuError!),
        if (localDemoEnabled && store.products.isEmpty)
          const Text('Nenhum produto disponível no momento. Consulte a loja.'),
        if (_storeSearch.isNotEmpty && _visibleStoreProducts.isEmpty)
          Text('Nenhum produto encontrado para "$_storeSearch".'),
        if (!localDemoEnabled)
          for (final value in _visibleStoreProducts)
            DemoProductTile(value, onTap: () => openProduct(value)),
        // GOG-016: as subcategorias da empresa guiam a navegação do cardápio.
        if (localDemoEnabled)
          for (final category in _visibleStoreProducts
              .map((product) => product.category)
              .toSet()
              .toList()) ...[
            _sectionTitle(category),
            for (final value in _visibleStoreProducts
                .where((product) => product.category == category))
              DemoProductTile(value, onTap: () => openProduct(value)),
          ],
        const SizedBox(height: 16),
        if (itemCount > 0)
          FilledButton.icon(
              onPressed: () => open(_Page.cart),
              icon: _cartIcon(),
              label: Text('Ver carrinho · ${formatDemoPrice(total)}')),
      ]);

  Widget _productPage() => _list([
        DemoPhoto(product.image, height: 290, radius: 18),
        const SizedBox(height: 12),
        Text(product.name,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(product.description),
        const SizedBox(height: 12),
        if (product.originalPriceCents != null &&
            product.originalPriceCents! > product.priceCents) ...[
          Row(children: [
            Text('De ${formatDemoPrice(product.originalPriceCents!)} por ',
                style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: GogdelyColors.mutedLight,
                    fontSize: 14)),
            Text(formatDemoPrice(product.priceCents),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text(product.badge,
                style: const TextStyle(
                    color: GogdelyColors.blue, fontWeight: FontWeight.w700)),
          ]),
        ] else
          Text(formatDemoPrice(product.priceCents),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (localDemoEnabled && product.stockQuantity != null)
          Text('Saldo local: ${product.stockQuantity} unidades'),
        if (!localDemoEnabled || store.category == 'Restaurantes') ...[
          _sectionTitle('Escolha o tamanho'),
          const Text('Escolha 1 opção', style: TextStyle(fontSize: 12)),
          for (final (value, extraPrice) in [
            ('Tradicional', 0),
            ('Média', 400),
            ('Grande', 800),
          ])
            Card(
                child: ListTile(
              title: Text(value),
              subtitle: extraPrice > 0
                  ? Text('+ ${formatDemoPrice(extraPrice)}')
                  : null,
              trailing: Icon(
                  selectedSize == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selectedSize == value
                      ? GogdelyColors.blue
                      : GogdelyColors.mutedLight),
              onTap: () => setState(() => selectedSize = value),
            )),
        ],
        if (!localDemoEnabled || product.addons.isNotEmpty)
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
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
        const SizedBox(height: 24),
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
          Row(children: [
            SizedBox(
                width: 48,
                height: 48,
                child: DemoPhoto(cartStore!.image, height: 48, radius: 24)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(cartStore!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('${cartStore!.eta} · valores de demonstração',
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
          ]),
          TextButton(
              onPressed: () => openStore(cartStore!),
              child: const Text('Adicionar mais itens')),
          _sectionTitle('Itens adicionados'),
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
          if (localDemoEnabled) ...[
            _sectionTitle('Entrega ou retirada'),
            for (final channel in ['delivery', 'pickup'])
              Card(
                  child: ListTile(
                title: Text(channel == 'pickup'
                    ? 'Retirar na Burger House'
                    : 'Entregar no endereço'),
                subtitle: Text(channel == 'pickup'
                    ? 'Sem taxa de entrega'
                    : 'Taxa estimada: ${formatDemoPrice(599)}'),
                trailing: Icon(
                    _orderChannel == channel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: GogdelyColors.blue),
                onTap: () => setState(() => _orderChannel = channel),
              )),
          ],
          if (!localDemoEnabled || _orderChannel == 'delivery')
            Card(
                child: ListTile(
              leading:
                  const Icon(Icons.place_outlined, color: GogdelyColors.blue),
              title: const Text('Endereço de entrega'),
              subtitle: Text(addressLabel,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(_Page.address),
            )),
          const SizedBox(height: 9),
          Card(
              child: ListTile(
            leading: const Icon(Icons.local_offer_outlined,
                color: GogdelyColors.blue),
            title: const Text('Cupons'),
            subtitle: const Text('Nenhum cupom disponível nesta prévia.'),
          )),
          const SizedBox(height: 14),
          _moneyRow('Subtotal', subtotal),
          _moneyRow(
              localDemoEnabled && _orderChannel == 'pickup'
                  ? 'Retirada na loja'
                  : 'Entrega demonstrativa',
              deliveryFee),
          const Divider(),
          _moneyRow('Total estimado', total, bold: true),
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
              title: Text(immediate ? 'Assim que possível' : 'Agendar horário'),
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
        _sectionTitle('Pagamento'),
        if (localDemoEnabled &&
            !_paymentMethodsLoaded &&
            _paymentMethodsError == null)
          const Text('Carregando formas aceitas pela loja...'),
        if (localDemoEnabled && _paymentMethodsError != null)
          Text(_paymentMethodsError!,
              style: const TextStyle(color: Colors.red)),
        Card(
            child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined,
                    color: GogdelyColors.blue),
                title: Text(demoPaymentLabel(paymentMethod)),
                subtitle: const Text('Escolher forma de pagamento'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openPaymentPage)),
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
        const SizedBox(height: 16),
      ]);

  Widget _paymentPage() => _list([
        const Text('Escolha como pagar',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
            'A escolha é registrada no pedido local. Este laboratório não cobra, gera Pix ou confirma liquidação.',
            style: TextStyle(fontSize: 12)),
        if (cart.isNotEmpty) ...[
          const SizedBox(height: 18),
          _moneyRow('Total estimado', total, bold: true),
        ],
        _sectionTitle('Formas aceitas pela loja'),
        if (localDemoEnabled && !_paymentMethodsLoaded)
          const Center(child: CircularProgressIndicator()),
        if (_paymentMethodsError != null)
          Text(_paymentMethodsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        for (final value in localDemoEnabled
            ? (_paymentMethodsLoaded ? _availablePaymentMethods : <String>[])
            : ['cash', 'pix', 'card'])
          Card(
              child: ListTile(
                  title: Text(demoPaymentLabel(value)),
                  subtitle: Text(value == 'cash'
                      ? 'Pagamento na entrega, sujeito à loja'
                      : value == 'pix'
                          ? 'Pix previsto, sem QR ou cobrança nesta prévia'
                          : 'Cartão previsto, sem captura de dados nesta prévia'),
                  leading: Icon(
                      value == 'pix'
                          ? Icons.pix
                          : value == 'card'
                              ? Icons.credit_card_outlined
                              : Icons.payments_outlined,
                      color: GogdelyColors.blue),
                  trailing: Icon(
                      paymentMethod == value
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: GogdelyColors.blue),
                  onTap: () => setState(() => paymentMethod = value))),
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
          if (_savedOrder!.paymentStatus == 'not_processed' &&
              _savedOrder!.status != 'cancelled')
            OutlinedButton.icon(
                onPressed: _savingPayment ? null : _simulateLocalPayment,
                icon: const Icon(Icons.science_outlined),
                label: Text(_savingPayment
                    ? 'Registrando teste...'
                    : 'Registrar pagamento de teste')),
          if ({'delivered', 'served', 'picked_up'}
                  .contains(_savedOrder!.status) &&
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
          _mapEntry(pickLocation: false),
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

  Widget _mapEntry({required bool pickLocation}) => Card(
        child: ListTile(
          leading: const Icon(Icons.map_outlined, color: GogdelyColors.blue),
          title: Text(pickLocation ? 'Marcar ponto no mapa' : 'Abrir mapa'),
          subtitle: Text(_selectedLocation == null
              ? 'Lojas de teste e localização do aparelho, se permitida'
              : 'Ponto escolhido: ${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                  '${_selectedLocation!.longitude.toStringAsFixed(5)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openMap(pickLocation: pickLocation),
        ),
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
                _paymentRequestKey = null;
                lastOrderTotal = order.totalCents;
                store = [..._pilotStores, ...demoStores]
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
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            CircleAvatar(
                radius: 25,
                backgroundColor: GogdelyColors.blue,
                child: Icon(Icons.person_outline, color: Colors.white)),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Sua área',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('Explorando o laboratório local',
                      style: TextStyle(fontSize: 12)),
                ])),
          ]),
        ),
        _sectionTitle('Pedidos e preferências'),
        _profileTile(
            Icons.receipt_long_outlined, 'Pedidos', () => open(_Page.orders)),
        _profileTile(Icons.place_outlined, 'Endereço de entrega',
            () => open(_Page.address)),
        _profileTile(Icons.account_balance_wallet_outlined,
            'Forma de pagamento', _openPaymentPage),
        _profileTile(Icons.notifications_none, 'Notificações',
            () => open(_Page.notifications)),
        _sectionTitle('Explorar'),
        _profileTile(Icons.map_outlined, 'Mapa de lojas', () => _openMap()),
        _profileTile(
            Icons.qr_code_scanner,
            'Ler QR de mesa',
            () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const QrDemoScreen()))),
        _sectionTitle('Configurações e suporte'),
        _profileTile(
            Icons.palette_outlined, 'Aparência', () => open(_Page.settings)),
        _profileTile(
            Icons.help_outline, 'Ajuda e como pedir', () => open(_Page.help)),
        const SizedBox(height: 12),
        const Text('Prévia local. Nenhuma conta ou pagamento real conectado.',
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
        const Text('Notificações',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
            'Canais do laboratório local: eventos dos seus pedidos no SQLite. '
            'Não há push, e-mail ou SMS; as preferências valem só nesta prévia.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        _sectionTitle('Preferências (GOG-102 local)'),
        SwitchListTile(
            secondary:
                const Icon(Icons.receipt_long, color: GogdelyColors.blue),
            title: const Text('Mudanças de status dos meus pedidos'),
            value: _notifyOrderStatus,
            onChanged: (value) => setState(() => _notifyOrderStatus = value)),
        SwitchListTile(
            secondary: const Icon(Icons.local_offer_outlined,
                color: GogdelyColors.blue),
            title: const Text('Promoções da plataforma e das lojas'),
            subtitle: const Text('Ilustrativo: nenhuma promoção real existe.'),
            value: _notifyPromotions,
            onChanged: (value) => setState(() => _notifyPromotions = value)),
        const Divider(),
        if (!localDemoEnabled) ...[
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
              leading:
                  CircleAvatar(child: Icon(icon, color: GogdelyColors.blue)),
              title: Text(title),
              subtitle: Text(subtitle),
            )),
        ] else ...[
          _sectionTitle('Eventos dos meus pedidos'),
          if (_refreshingNotifications)
            const Text('Carregando eventos do banco local...'),
          if (_localError != null)
            Text(_localError!, style: const TextStyle(color: Colors.red)),
          if (!_refreshingNotifications && _notificationEvents.isEmpty)
            const Text('Nenhum evento nos seus pedidos locais ainda.'),
          for (final entry in _notificationEvents)
            Card(
                child: ListTile(
              leading: CircleAvatar(
                  child: Icon(_notificationIcon(entry.toStatus),
                      color: GogdelyColors.blue)),
              title: Text(entry.fromStatus == entry.toStatus
                  ? entry.reason
                  : 'Pedido #${entry.orderId}: ${demoStatusLabel(entry.toStatus)}'),
              subtitle: Text(
                  '${demoActorLabel(entry.actor)} · ${_whenLabel(entry.createdAt)}'),
            )),
        ],
      ]);

  IconData _notificationIcon(String status) => switch (status) {
        'created' => Icons.receipt_long,
        'preparing' => Icons.kitchen_outlined,
        'ready' => Icons.task_alt,
        'in_delivery' => Icons.delivery_dining,
        'delivered' => Icons.home_outlined,
        'served' => Icons.table_restaurant,
        'picked_up' => Icons.storefront,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.event_note,
      };

  String _whenLabel(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
  }

  /// GOG-101 no laboratório: notificações derivadas dos eventos dos pedidos.
  Future<void> _refreshNotifications() async {
    if (_refreshingNotifications || _savedOrders.isEmpty) return;
    _refreshingNotifications = true;
    try {
      final recent = _savedOrders.take(5).toList();
      final batches = await Future.wait(
          [for (final order in recent) _localApi.orderEvents(order.id)]);
      if (!mounted) return;
      final entries = <({
        int orderId,
        String? fromStatus,
        String toStatus,
        String actor,
        String reason,
        String createdAt
      })>[];
      for (var i = 0; i < recent.length; i++) {
        for (final event in batches[i]) {
          if (event.fromStatus == event.toStatus && event.reason.isEmpty) {
            continue;
          }
          entries.add((
            orderId: recent[i].id,
            fromStatus: event.fromStatus,
            toStatus: event.toStatus,
            actor: event.actor,
            reason: event.reason,
            createdAt: event.createdAt,
          ));
        }
      }
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _notificationEvents = entries.take(30).toList());
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _refreshingNotifications = false);
    }
  }

  Widget _addressPage() => _list([
        const Text('Onde você quer receber?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _mapEntry(pickLocation: true),
        const SizedBox(height: 8),
        const Text('Marque o ponto no mapa e confirme rua e número abaixo.',
            style: TextStyle(fontSize: 12, color: GogdelyColors.mutedLight)),
        const SizedBox(height: 12),
        TextField(
            controller: _addressStreetController,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Rua *')),
        TextField(
            controller: _addressNumberController,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Número *')),
        TextField(
            controller: _addressComplementController,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Complemento')),
        TextField(
            controller: _addressReferenceController,
            maxLength: 100,
            decoration:
                const InputDecoration(labelText: 'Ponto de referência')),
        _sectionTitle('Favoritar endereço'),
        Wrap(spacing: 8, children: [
          for (final kind in ['Casa', 'Trabalho'])
            ChoiceChip(
                label: Text(kind),
                avatar:
                    Icon(kind == 'Casa' ? Icons.home : Icons.work, size: 17),
                selected: _addressKind == kind,
                onSelected: (_) => setState(() => _addressKind = kind)),
        ]),
        const SizedBox(height: 16),
        const SizedBox(height: 8),
        const Text(
            'Endereço digitado salvo neste aparelho no PWA. O ponto do mapa não é salvo nem calcula rotas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11)),
      ]);

  /// GOG-015/018 no laboratório: o endereço salvo é usado pelo checkout local.
  void _saveAddress() {
    final street = _addressStreetController.text.trim();
    final number = _addressNumberController.text.trim();
    if (street.length < 3 || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Informe a rua e o número para salvar o endereço.')));
      return;
    }
    final complement = _addressComplementController.text.trim();
    final reference = _addressReferenceController.text.trim();
    final label = [
      '$street, $number',
      if (complement.isNotEmpty) complement,
      if (reference.isNotEmpty) 'Referência: $reference',
    ].join(' · ');
    if (label.length > 160) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Encurte o endereço para até 160 caracteres.')));
      return;
    }
    _savedPreferences = ClientPreferences(
      street: street,
      number: number,
      complement: complement,
      reference: reference,
      kind: _addressKind,
      favoriteStoreIds: _favoriteStoreIds,
    );
    setState(() => addressLabel = label);
    final persisted = _preferencesStore.write(_savedPreferences.encode());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(persisted
            ? 'Endereço salvo neste aparelho para os próximos pedidos.'
            : 'Endereço mantido apenas nesta sessão; armazenamento indisponível.')));
    open(_addressReturnPage);
  }

  /// GOG-136 local: onboarding e ajuda do laboratório.
  Widget _helpPage() => _list([
        const Text('Ajuda e como pedir',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
            'Guia da prévia local. Nada aqui envolve cobrança, GPS ou conta real.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        _sectionTitle('Como pedir na Burger House'),
        for (final (index, step) in [
          'Escolha os produtos pelo cardápio agrupado por categorias.',
          'Adicione ao carrinho — um estabelecimento por pedido.',
          'No checkout, escolha entrega ou retirada, pagamento pretendido e, se quiser, agende a data/hora.',
          'Acompanhe o status e avalie ao concluir.',
        ].indexed)
          ListTile(
              leading: CircleAvatar(
                  backgroundColor: GogdelyColors.blue,
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700))),
              title: Text(step)),
        _sectionTitle('Pagamento'),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'A forma escolhida (dinheiro, Pix ou cartão) é salva apenas '
                    'como pretendida. Nenhuma cobrança é processada nesta prévia.',
                    style: TextStyle(fontSize: 13)))),
        _sectionTitle('Mesa com QR'),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Escaneie o QR da mesa para abrir o cardápio no navegador, '
                    'sem instalar aplicativo. O pedido vai para a fila da cozinha '
                    'com mesa, data e hora.',
                    style: TextStyle(fontSize: 13)))),
        _sectionTitle('Códigos de conferência'),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Retirada e entrega usam um código de 6 dígitos exibido no '
                    'acompanhamento. Informe somente ao receber o pedido.',
                    style: TextStyle(fontSize: 13)))),
        _sectionTitle('Privacidade do laboratório'),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Todos os dados são fictícios e gravados apenas no SQLite '
                    'deste computador. Sem contas, GPS, notificações push ou '
                    'serviços externos.',
                    style: TextStyle(fontSize: 13)))),
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
