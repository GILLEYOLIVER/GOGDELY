import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_gestao/main.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class FakeOrdersApi extends LocalDemoApi {
  String status = 'created';
  int reads = 0;

  @override
  Future<List<DemoOrder>> orders({String? storeId, String? status}) async {
    reads++;
    return [
      DemoOrder(901, 'burger-house', 'Burger House', 'Rua das Flores',
          this.status, 2890, const [])
    ];
  }

  @override
  void close() {}
}

void main() {
  testWidgets('management updates an order status without manual refresh',
      (tester) async {
    expect(localDemoEnabled, isTrue);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeOrdersApi();
    await tester.pumpWidget(MaterialApp(
        home: GestaoHome(
            themeMode: ThemeMode.light,
            onThemeChanged: (_) {},
            localApi: api)));
    await tester.pump();
    expect(find.text('Iniciar preparo'), findsOneWidget);

    api.status = 'preparing';
    await tester.pump(localDemoRefreshInterval);
    await tester.pump();
    expect(find.text('Marcar pronto'), findsOneWidget);
    expect(api.reads, greaterThanOrEqualTo(2));
  });
}
