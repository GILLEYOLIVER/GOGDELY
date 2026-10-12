import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_entregador/main.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class FakeOrdersApi extends LocalDemoApi {
  String status = 'ready';
  int reads = 0;

  @override
  Future<List<DemoOrder>> orders({String? storeId, String? status}) async {
    reads++;
    return [
      DemoOrder(902, 'burger-house', 'Burger House', 'Rua das Flores',
          this.status, 2890, const [])
    ];
  }

  @override
  void close() {}
}

void main() {
  testWidgets('courier updates an order status without manual refresh',
      (tester) async {
    expect(localDemoEnabled, isTrue);
    final api = FakeOrdersApi();
    await tester.pumpWidget(MaterialApp(
        home: EntregadorHome(
            themeMode: ThemeMode.light,
            onThemeChanged: (_) {},
            localApi: api)));
    await tester.pump();
    expect(find.text('Iniciar entrega local'), findsOneWidget);

    api.status = 'in_delivery';
    await tester.pump(localDemoRefreshInterval);
    await tester.pump();
    expect(find.text('Concluir entrega local'), findsOneWidget);
    expect(api.reads, greaterThanOrEqualTo(2));
  });
}
