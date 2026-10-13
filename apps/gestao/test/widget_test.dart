import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_gestao/main.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

void main() {
  testWidgets('desktop management dashboard opens orders and KDS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GestaoApp());
    await tester.pump();
    if (localDemoEnabled) {
      // Local pilot dashboard: Burger House metrics replace fictional numbers.
      expect(find.textContaining('Burger House · empresa piloto'),
          findsOneWidget);
      await tester.tap(find.text('Pedidos').first);
      await tester.pump();
      expect(find.text('Pedidos salvos no banco local'), findsOneWidget);
      await tester.tap(find.text('KDS (Cozinha)').first);
      await tester.pump();
      expect(find.text('Fila da cozinha'), findsOneWidget);
      return;
    }
    expect(find.text('Pedidos hoje'), findsOneWidget);
    await tester.tap(find.text('Pedidos').first);
    await tester.pump();
    expect(find.text('Pedidos de demonstração'), findsOneWidget);
    await tester.tap(find.text('KDS (Cozinha)').first);
    await tester.pump();
    expect(find.text('Fila ilustrativa por etapa'), findsOneWidget);
  });
}
