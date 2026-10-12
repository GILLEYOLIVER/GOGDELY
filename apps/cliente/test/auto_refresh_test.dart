import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/screens/home_screen.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class FakeOrdersApi extends LocalDemoApi {
  String status = 'created';
  int reads = 0;

  @override
  Future<List<DemoOrder>> orders({String? storeId, String? status}) async {
    reads++;
    return [_order];
  }

  DemoOrder get _order => DemoOrder(903, 'burger-house', 'Burger House',
      'Rua das Flores', status, 2890, const []);

  @override
  Future<DemoOrder> order(int id) async => _order;

  @override
  void close() {}
}

void main() {
  testWidgets('client updates order history without manual refresh',
      (tester) async {
    expect(localDemoEnabled, isTrue);
    final api = FakeOrdersApi();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(localApi: api)));
    await tester.tap(find.text('Pedidos'));
    await tester.pump();
    expect(find.textContaining('Pedido local #903'), findsOneWidget);
    expect(find.textContaining('Recebido'), findsOneWidget);

    api.status = 'preparing';
    await tester.pump(localDemoRefreshInterval);
    await tester.pump();
    expect(find.textContaining('Em preparo'), findsOneWidget);
    expect(api.reads, greaterThanOrEqualTo(2));

    await tester.tap(find.textContaining('Pedido local #903'));
    await tester.pump();
    expect(find.textContaining('Status salvo: Em preparo'), findsOneWidget);

    api.status = 'ready';
    await tester.pump(localDemoRefreshInterval);
    await tester.pump();
    expect(find.textContaining('Status salvo: Pronto'),
        findsOneWidget);
  });
}
