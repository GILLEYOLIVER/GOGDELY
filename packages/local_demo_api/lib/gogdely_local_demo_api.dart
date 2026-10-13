import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

const localDemoEnabled = bool.fromEnvironment('GOGDELY_LOCAL_API');
// One-store local pilot. Other demo stores and their saved orders remain intact.
const localDemoPilotStoreId = 'burger-house';
const localDemoRefreshInterval = Duration(seconds: 3);
const _overrideUrl = String.fromEnvironment('GOGDELY_LOCAL_API_URL');

String get localDemoBaseUrl {
  if (_overrideUrl.isNotEmpty) return _overrideUrl;
  return 'http://127.0.0.1:8765';
}

String newDemoRequestKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class DemoOrder {
  const DemoOrder(
    this.id,
    this.storeId,
    this.storeName,
    this.addressLabel,
    this.status,
    this.totalCents,
    this.items, {
    this.tableCode,
    this.orderChannel = 'delivery',
    this.paymentMethod = 'unselected',
    this.paymentStatus = 'not_processed',
    this.kitchenPriority = 'normal',
    this.paymentSettlement = 'none',
    this.pickupCode,
    this.deliveryCode,
    this.dispatchMode = 'internal',
    this.subtotalCents = 0,
    this.deliveryFeeCents = 0,
    this.createdAt = '',
    this.scheduledFor,
  });
  final int id;
  final String storeId;
  final String storeName;
  final String addressLabel;
  final String status;
  final int totalCents;
  final List<DemoOrderItem> items;
  final String? tableCode;
  final String orderChannel;
  final String paymentMethod;
  final String paymentStatus;
  final String kitchenPriority;
  final String paymentSettlement;
  final String? pickupCode;
  final String? deliveryCode;
  final String dispatchMode;
  final int subtotalCents;
  final int deliveryFeeCents;
  final String createdAt;
  final String? scheduledFor;

  factory DemoOrder.fromJson(Map<String, dynamic> json) => DemoOrder(
    json['id'] as int,
    json['store_id'] as String,
    json['store_name'] as String,
    json['address_label'] as String,
    json['status'] as String,
    json['total_cents'] as int,
    (json['items'] as List)
        .map((item) => DemoOrderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    tableCode: json['table_code'] as String?,
    orderChannel: json['order_channel'] as String? ?? 'delivery',
    paymentMethod: json['payment_method'] as String? ?? 'unselected',
    paymentStatus: json['payment_status'] as String? ?? 'not_processed',
    kitchenPriority: json['kitchen_priority'] as String? ?? 'normal',
    paymentSettlement: json['payment_settlement'] as String? ?? 'none',
    pickupCode: json['pickup_code'] as String?,
    deliveryCode: json['delivery_code'] as String?,
    dispatchMode: json['dispatch_mode'] as String? ?? 'internal',
    subtotalCents: json['subtotal_cents'] as int? ?? 0,
    deliveryFeeCents: json['delivery_fee_cents'] as int? ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    scheduledFor: json['scheduled_for'] as String?,
  );

  /// True only for laboratory declarations; never a real financial settlement.
  bool get paymentSimulated => paymentStatus == 'simulated';
}

class DemoOrderItem {
  const DemoOrderItem(
    this.productId,
    this.name,
    this.quantity,
    this.unitCents, {
    this.size = 'Tradicional',
    this.extras = const [],
  });
  final String productId;
  final String name;
  final int quantity;
  final int unitCents;
  final String size;
  final List<String> extras;

  factory DemoOrderItem.fromJson(Map<String, dynamic> json) => DemoOrderItem(
    json['product_id'] as String,
    json['name'] as String,
    json['quantity'] as int,
    json['unit_cents'] as int,
    size: json['size'] as String? ?? 'Tradicional',
    extras: ((json['extras'] as List?) ?? []).cast<String>(),
  );
}

class DemoOrderEvent {
  const DemoOrderEvent(
    this.fromStatus,
    this.toStatus,
    this.actor,
    this.reason,
    this.createdAt,
  );
  final String? fromStatus;
  final String toStatus;
  final String actor;
  final String reason;
  final String createdAt;

  factory DemoOrderEvent.fromJson(Map<String, dynamic> json) => DemoOrderEvent(
    json['from_status'] as String?,
    json['to_status'] as String,
    json['actor'] as String,
    json['reason'] as String,
    json['created_at'] as String,
  );
}

class DemoMenuItem {
  const DemoMenuItem({
    required this.productId,
    required this.name,
    required this.description,
    required this.category,
    required this.priceCents,
    required this.imageRef,
    required this.available,
    this.orderable = true,
    this.stockQuantity,
    this.updatedAt = '',
    required this.promoPercent,
    required this.effectivePriceCents,
    this.addons = const [],
    this.recipe = const [],
  });

  final String productId;
  final String name;
  final String description;
  final String category;
  final int priceCents;
  final String imageRef;
  final bool available;
  final bool orderable;
  final int? stockQuantity;
  final String updatedAt;
  final int promoPercent;
  final int effectivePriceCents;
  final List<DemoAddon> addons;
  final List<DemoRecipePart> recipe;

  factory DemoMenuItem.fromJson(Map<String, dynamic> json) => DemoMenuItem(
    productId: json['product_id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    priceCents: json['price_cents'] as int,
    imageRef: json['image_ref'] as String,
    available: json['available'] as bool,
    orderable: json['orderable'] as bool? ?? (json['available'] as bool),
    stockQuantity: json['stock_quantity'] as int?,
    updatedAt: json['updated_at'] as String? ?? '',
    promoPercent: json['promo_percent'] as int,
    effectivePriceCents: json['effective_price_cents'] as int,
    addons: ((json['addons'] as List?) ?? [])
        .map((entry) => DemoAddon.fromJson(entry as Map<String, dynamic>))
        .toList(),
    recipe: ((json['recipe'] as List?) ?? [])
        .map((entry) => DemoRecipePart.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'description': description,
    'category': category,
    'price_cents': priceCents,
    'image_ref': imageRef,
    'available': available,
    'stock_quantity': stockQuantity,
    if (updatedAt.isNotEmpty) 'expected_updated_at': updatedAt,
    'promo_percent': promoPercent,
    'addons': addons.map((addon) => addon.toJson()).toList(),
    'recipe': recipe.map((part) => part.toJson()).toList(),
  };
}

class DemoRecipePart {
  const DemoRecipePart(this.ingredientId, this.quantity);
  final String ingredientId;
  final int quantity;

  factory DemoRecipePart.fromJson(Map<String, dynamic> json) =>
      DemoRecipePart(json['ingredient_id'] as String, json['quantity'] as int);

  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    'quantity': quantity,
  };
}

class DemoIngredient {
  const DemoIngredient(
    this.ingredientId,
    this.name,
    this.unit,
    this.stockQuantity,
    this.updatedAt,
  );
  final String ingredientId;
  final String name;
  final String unit;
  final int stockQuantity;
  final String updatedAt;

  factory DemoIngredient.fromJson(Map<String, dynamic> json) => DemoIngredient(
    json['ingredient_id'] as String,
    json['name'] as String,
    json['unit'] as String,
    json['stock_quantity'] as int,
    json['updated_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    'name': name,
    'unit': unit,
    'stock_quantity': stockQuantity,
    if (updatedAt.isNotEmpty) 'expected_updated_at': updatedAt,
  };
}

class DemoAddon {
  const DemoAddon(this.name, this.priceCents);
  final String name;
  final int priceCents;

  factory DemoAddon.fromJson(Map<String, dynamic> json) =>
      DemoAddon(json['name'] as String, json['price_cents'] as int);

  Map<String, dynamic> toJson() => {'name': name, 'price_cents': priceCents};
}

class DemoPlan {
  const DemoPlan(
    this.planId,
    this.name,
    this.monthlyFeeCents,
    this.commissionPercent,
    this.trialDays,
    this.notes,
  );
  final String planId;
  final String name;
  final int monthlyFeeCents;
  final int commissionPercent;
  final int trialDays;
  final String notes;

  factory DemoPlan.fromJson(Map<String, dynamic> json) => DemoPlan(
    json['plan_id'] as String,
    json['name'] as String,
    json['monthly_fee_cents'] as int,
    json['commission_percent'] as int,
    json['trial_days'] as int,
    json['notes'] as String,
  );
}

class DemoCompany {
  const DemoCompany(
    this.storeId,
    this.name,
    this.category,
    this.status,
    this.plan,
  );
  final String storeId;
  final String name;
  final String category;
  final String status;
  final DemoPlan? plan;

  factory DemoCompany.fromJson(Map<String, dynamic> json) => DemoCompany(
    json['store_id'] as String,
    json['name'] as String,
    json['category'] as String,
    json['status'] as String,
    json['plan'] == null
        ? null
        : DemoPlan.fromJson(json['plan'] as Map<String, dynamic>),
  );

  bool get pending => status == 'pending';
  bool get approved => status == 'approved';
}

class DemoAuditEntry {
  const DemoAuditEntry(
    this.source,
    this.ref,
    this.actor,
    this.detail,
    this.createdAt,
  );
  final String source;
  final String ref;
  final String actor;
  final String detail;
  final String createdAt;

  factory DemoAuditEntry.fromJson(Map<String, dynamic> json) => DemoAuditEntry(
    json['source'] as String,
    json['ref'] as String,
    json['actor'] as String,
    json['detail'] as String,
    json['created_at'] as String,
  );
}

class LocalDemoApi {
  LocalDemoApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? localDemoBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api/v1/local$path').replace(queryParameters: query);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final uri = _uri(path, query);
      final headers = {'content-type': 'application/json'};
      final response = await (switch (method) {
        'GET' => _client.get(uri),
        'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => _client.patch(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body)),
        _ => throw ArgumentError('Unsupported method'),
      }).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'API local: HTTP ${response.statusCode} — ${response.body}',
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError('API local indisponível em $_baseUrl: $error');
    }
  }

  Future<List<DemoOrder>> orders({String? storeId, String? status}) async {
    final result = await _request(
      'GET',
      '/orders',
      query: {
        if (storeId != null) 'store_id': storeId,
        if (status != null) 'status': status,
      },
    ) as List;
    return result
        .map((entry) => DemoOrder.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<DemoMenuItem>> menu() async {
    final result = await _request('GET', '/stores/burger-house/menu') as List;
    return result
        .map((entry) => DemoMenuItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<DemoIngredient>> ingredients() async {
    final result =
        await _request('GET', '/stores/burger-house/ingredients') as List;
    return result
        .map((entry) => DemoIngredient.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<DemoIngredient> saveIngredient(
    DemoIngredient ingredient, {
    required bool create,
  }) async => DemoIngredient.fromJson(
    await _request(
      create ? 'POST' : 'PUT',
      '/stores/burger-house/ingredients${create ? '' : '/${ingredient.ingredientId}'}',
      body: ingredient.toJson(),
    ) as Map<String, dynamic>,
  );

  Future<List<Map<String, dynamic>>> stockMovements() async {
    final result =
        await _request('GET', '/stores/burger-house/stock-movements') as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adjustStock({
    required String itemKind,
    required String itemId,
    required String movementType,
    required int quantity,
    required String reason,
  }) async => await _request(
    'POST',
    '/stores/burger-house/stock-adjustments',
    body: {
      'item_kind': itemKind,
      'item_id': itemId,
      'movement_type': movementType,
      'quantity': quantity,
      'reason': reason,
    },
  ) as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> menuEvents() async {
    final result =
        await _request('GET', '/stores/burger-house/menu-events') as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<List<DemoMenuItem>> reorderMenu(List<String> productIds) async {
    final result = await _request(
      'PUT',
      '/stores/burger-house/menu-order',
      body: {'product_ids': productIds},
    ) as List;
    return result
        .map((entry) => DemoMenuItem.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> paymentMethods() async {
    final result = await _request(
      'GET',
      '/stores/burger-house/payment-methods',
    ) as Map<String, dynamic>;
    return (result['methods'] as List).cast<String>();
  }

  Future<List<String>> savePaymentMethods(List<String> methods) async {
    final result = await _request(
      'PUT',
      '/stores/burger-house/payment-methods',
      body: {'methods': methods},
    ) as Map<String, dynamic>;
    return (result['methods'] as List).cast<String>();
  }

  Future<DemoMenuItem> saveMenuItem(
    DemoMenuItem item, {
    required bool create,
  }) async => DemoMenuItem.fromJson(
    await _request(
      create ? 'POST' : 'PUT',
      '/stores/burger-house/menu${create ? '' : '/${item.productId}'}',
      body: item.toJson(),
    ) as Map<String, dynamic>,
  );

  Future<String> uploadImage(List<int> bytes, String mimeType) async {
    if (bytes.isEmpty || bytes.length > 5000000) {
      throw StateError('A imagem deve ter no máximo 5 MB.');
    }
    final result = await _request(
      'POST',
      '/uploads/images',
      body: {'data_base64': base64Encode(bytes), 'mime_type': mimeType},
      timeout: const Duration(seconds: 30),
    ) as Map<String, dynamic>;
    return result['image_ref'] as String;
  }

  Future<DemoOrder> order(int id) async => DemoOrder.fromJson(
    await _request('GET', '/orders/$id') as Map<String, dynamic>,
  );

  Future<DemoOrder> createOrder({
    required String requestKey,
    required String storeId,
    required String addressLabel,
    required List<Map<String, dynamic>> items,
    String orderChannel = 'delivery',
    String paymentMethod = 'unselected',
    String? scheduledFor,
  }) async => DemoOrder.fromJson(
    await _request(
      'POST',
      '/orders',
      body: {
        'request_key': requestKey,
        'store_id': storeId,
        'address_label': addressLabel,
        'items': items,
        'order_channel': orderChannel,
        'payment_method': paymentMethod,
        'scheduled_for': scheduledFor,
      },
    ) as Map<String, dynamic>,
  );

  Future<DemoOrder> createPosSale({
    required String requestKey,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
  }) async => DemoOrder.fromJson(
    await _request(
      'POST',
      '/stores/burger-house/pos-sales',
      body: {
        'request_key': requestKey,
        'items': items,
        'payment_method': paymentMethod,
      },
    ) as Map<String, dynamic>,
  );

  Future<Map<String, dynamic>> posRegister() async =>
      await _request('GET', '/stores/burger-house/pos-register')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> openPosRegister({
    required String requestKey,
    required int openingCents,
    required String reason,
  }) async => await _request(
    'POST',
    '/stores/burger-house/pos-register/open',
    body: {
      'request_key': requestKey,
      'opening_cents': openingCents,
      'reason': reason,
    },
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> recordPosCashMovement({
    required String requestKey,
    required String movementType,
    required int amountCents,
    required String reason,
  }) async => await _request(
    'POST',
    '/stores/burger-house/pos-register/movements',
    body: {
      'request_key': requestKey,
      'movement_type': movementType,
      'amount_cents': amountCents,
      'reason': reason,
    },
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> closePosRegister({
    required String requestKey,
    required int countedCents,
    required String reason,
  }) async => await _request(
    'POST',
    '/stores/burger-house/pos-register/close',
    body: {
      'request_key': requestKey,
      'counted_cents': countedCents,
      'reason': reason,
    },
  ) as Map<String, dynamic>;

  Future<DemoOrder> updateStatus(
    int id,
    String status,
    String actor, {
    String? pickupCode,
    String? deliveryCode,
  }) async => DemoOrder.fromJson(
    await _request(
      'PATCH',
      '/orders/$id/status',
      body: {
        'status': status,
        'actor': actor,
        if (pickupCode != null) 'pickup_code': pickupCode,
        if (deliveryCode != null) 'delivery_code': deliveryCode,
      },
    ) as Map<String, dynamic>,
  );

  Future<List<DemoOrderEvent>> orderEvents(int id) async {
    final result = await _request('GET', '/orders/$id/events') as List;
    return result
        .map((entry) => DemoOrderEvent.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  /// Declares a simulated payment for the local pilot. Never a real charge:
  /// the API only records the explicit laboratory declaration for audit.
  Future<DemoOrder> simulatePayment({
    required int orderId,
    required String requestKey,
    required String reason,
  }) async => DemoOrder.fromJson(
    await _request(
      'POST',
      '/orders/$orderId/simulate-payment',
      body: {'request_key': requestKey, 'reason': reason},
    ) as Map<String, dynamic>,
  );

  /// Rates a finished order in the local pilot (GOG-022).
  Future<Map<String, dynamic>> rateOrder({
    required int orderId,
    required int stars,
    String comment = '',
  }) async => await _request(
    'POST',
    '/orders/$orderId/rating',
    body: {'stars': stars, 'comment': comment},
  ) as Map<String, dynamic>;

  /// Ratings summary for the pilot store (GOG-022).
  Future<Map<String, dynamic>> storeRatings() async =>
      await _request('GET', '/stores/burger-house/ratings')
          as Map<String, dynamic>;

  /// Active Burger House promotions (GOG-021).
  Future<List<Map<String, dynamic>>> promotions() async {
    final result =
        await _request('GET', '/stores/burger-house/promotions') as List;
    return result.cast<Map<String, dynamic>>();
  }

  Future<DemoOrder> cancelOrder(int id, String actor, String reason) async =>
      DemoOrder.fromJson(
        await _request(
          'POST',
          '/orders/$id/cancel',
          body: {'actor': actor, 'reason': reason},
        ) as Map<String, dynamic>,
      );

  Future<DemoOrder> setKitchenPriority({
    required int orderId,
    required String priority,
    required String reason,
  }) async => DemoOrder.fromJson(
    await _request('PUT', '/orders/$orderId/kitchen-priority',
        body: {'priority': priority, 'reason': reason}) as Map<String, dynamic>,
  );

  Future<DemoOrder> dispatchInternal(int id) async => DemoOrder.fromJson(
    await _request('POST', '/orders/$id/dispatch-internal')
        as Map<String, dynamic>,
  );

  // ==== Master (laboratório local; ações críticas são simulações) ====

  Future<Map<String, dynamic>> masterOverview() async =>
      await _request('GET', '/master/overview') as Map<String, dynamic>;

  Future<List<DemoCompany>> masterCompanies() async {
    final result = await _request('GET', '/master/companies') as List;
    return result
        .map((entry) => DemoCompany.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<DemoPlan>> masterPlans() async {
    final result = await _request('GET', '/master/plans') as List;
    return result
        .map((entry) => DemoPlan.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<DemoCompany> masterCompanyApproval({
    required String storeId,
    required String actor,
    required bool approve,
    required String reason,
  }) async => DemoCompany.fromJson(
    await _request(
      'POST',
      '/master/companies/$storeId/approval',
      body: {
        'actor': actor,
        'decision': approve ? 'approve' : 'reject',
        'reason': reason,
      },
    ) as Map<String, dynamic>,
  );

  Future<List<DemoAuditEntry>> masterAudit() async {
    final result = await _request('GET', '/master/audit') as List;
    return result
        .map((entry) => DemoAuditEntry.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> masterPaymentMethods() async =>
      await _request('GET', '/master/payment-methods')
          as Map<String, dynamic>;

  void close() => _client.close();
}

String demoStatusLabel(String value) => switch (value) {
  'created' => 'Recebido',
  'preparing' => 'Em preparo',
  'ready' => 'Pronto',
  'picked_up' => 'Retirado na loja',
  'in_delivery' => 'Em entrega',
  'delivered' => 'Entregue',
  'served' => 'Servido na mesa',
  'cancelled' => 'Cancelado',
  _ => value,
};

String demoActorLabel(String value) => switch (value) {
  'customer' => 'Cliente',
  'management' => 'Gestão',
  'management_kds' => 'Gestão · cozinha',
  'courier' => 'Entregador',
  'table_guest' => 'Cliente na mesa',
  _ => value,
};

String demoPaymentLabel(String value) => switch (value) {
  'cash' => 'Dinheiro',
  'pix' => 'Pix',
  'card' => 'Cartão de crédito',
  _ => 'Não escolhido',
};

String demoPaymentStatusLabel(String value) => switch (value) {
  'simulated' => 'simulado no laboratório (sem cobrança real)',
  _ => 'não processado',
};
