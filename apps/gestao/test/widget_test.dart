import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_gestao/main.dart';

void main() {
  testWidgets('desktop management dashboard opens orders and KDS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GestaoApp());
    expect(find.text('Pedidos hoje'), findsOneWidget);
    await tester.tap(find.text('Pedidos').first);
    await tester.pump();
    expect(find.text('Pedidos de demonstração'), findsOneWidget);
    await tester.tap(find.text('KDS (Cozinha)').first);
    await tester.pump();
    expect(find.text('Fila ilustrativa por etapa'), findsOneWidget);
  });
}
