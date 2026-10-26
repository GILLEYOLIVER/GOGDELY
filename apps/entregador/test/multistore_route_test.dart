import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_entregador/main.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class FakeCourierApi extends LocalDemoApi {
  @override
  Future<List<DemoOrder>> orders({String? storeId, String? status}) async => [
        const DemoOrder(910, 'pizzaria-napoli', 'Pizzaria Napoli',
            'Rua de Teste, 10', 'ready', 3889,
            [DemoOrderItem('margherita', 'Pizza Margherita', 1, 3290)],
            dispatchMode: 'internal'),
      ];

  @override
  void close() {}
}

void main() {
  testWidgets('courier opens the selected store order and local route',
      (tester) async {
    if (!localDemoEnabled) return;
    await tester.pumpWidget(MaterialApp(home: EntregadorHome(
      themeMode: ThemeMode.light,
      onThemeChanged: (_) {},
      localApi: FakeCourierApi(),
    )));
    await tester.pump();
    expect(find.textContaining('Pizzaria Napoli'), findsWidgets);
    await tester.ensureVisible(find.text('Ver rota e pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver rota e pedido'));
    await tester.pump();
    expect(find.text('Pedido #910 · Pizzaria Napoli'), findsOneWidget);
    expect(find.text('Rua de Teste, 10'), findsOneWidget);
    await tester.tap(find.text('Ver detalhes do pedido'));
    await tester.pump();
    expect(find.text('1 × Pizza Margherita'), findsOneWidget);
  });
}
