import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/screens/home_screen.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class FakeCatalogApi extends LocalDemoApi {
  @override
  Future<List<Map<String, dynamic>>> catalog() async => [
        _store('burger-house', 'Burger House', 'Restaurantes',
            'x-tudo', 'X-Tudo'),
        _store('padaria-aurora', 'Padaria Aurora', 'Padaria',
            'pao-queijo', 'Pão de Queijo'),
      ];

  Map<String, dynamic> _store(String id, String name, String category,
          String productId, String productName) =>
      {
        'id': id, 'name': name, 'category': category,
        'description': 'Loja fictícia', 'eta': '15–25 min',
        'image': '',
        'products': [
          {
            'product_id': productId, 'name': productName,
            'description': 'Produto de teste', 'category': category,
            'price_cents': 1290, 'effective_price_cents': 1290,
            'image_ref': '', 'available': true, 'orderable': true,
            'stock_quantity': null, 'promo_percent': 0,
            'updated_at': 'test', 'addons': [], 'recipe': [],
          }
        ],
      };

  @override
  void close() {}
}

void main() {
  testWidgets('local catalog exposes different establishments and menus',
      (tester) async {
    if (!localDemoEnabled) return;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(localApi: FakeCatalogApi())));
    await tester.pump();
    await tester.tap(find.text('Busca'));
    await tester.pump();
    expect(find.text('Burger House'), findsWidgets);
    expect(find.text('Padaria Aurora'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Pão de Queijo');
    await tester.pump();
    expect(find.text('Padaria Aurora'), findsWidgets);
    expect(find.text('Burger House'), findsNothing);
  });
}
