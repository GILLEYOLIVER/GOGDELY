import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_entregador/main.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

void main() {
  testWidgets('local courier route and status are navigable', (tester) async {
    await tester.pumpWidget(const EntregadorApp());
    expect(find.text('Minhas entregas'), findsOneWidget);
    if (localDemoEnabled) {
      // Without a reachable local API the courier queue shows its empty state.
      expect(find.text('Atualizar do banco local'), findsOneWidget);
      expect(find.textContaining('Nenhum pedido encaminhado ao entregador'),
          findsOneWidget);
      return;
    }
    await tester.scrollUntilVisible(
        find.text('Ver rota demonstrativa').first, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ver rota demonstrativa').first);
    await tester.pump();
    expect(find.text('Rota da entrega'), findsOneWidget);
    await tester.tap(find.text('Ver detalhes do pedido'));
    await tester.pump();
    expect(find.text('Detalhes do pedido'), findsOneWidget);
  });
}
