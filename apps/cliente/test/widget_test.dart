import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/main.dart';
import 'package:gogdely_cliente/screens/client_components.dart';

void main() {
  testWidgets('home follows approved visual journey and filters categories',
      (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('Sabor que\nse aproxima.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Categorias'), 140,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Restaurantes'));
    await tester.pumpAndSettle();
    expect(find.text('Resultados'), findsOneWidget);
    expect(find.text('Pizzaria Napoli'), findsOneWidget);
  });

  testWidgets('home lists demonstration stores', (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.scrollUntilVisible(find.text('Estabelecimentos próximos'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Estabelecimentos próximos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Burger House'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Burger House'), findsOneWidget);
  });

  testWidgets('search opens product and keeps cart to one store', (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Busca'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump();
    expect(find.text('Pizzaria Napoli'), findsOneWidget);
    expect(find.text('Burger House'), findsNothing);
    await tester.tap(find.text('Pizzaria Napoli'));
    await tester.pumpAndSettle();
    expect(find.text('Cardápio'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('Pizza Margherita'), findsOneWidget);
    await tester.tap(find.text('Pizza Margherita'));
    await tester.pump();
    await tester.scrollUntilVisible(find.textContaining('Adicionar ·'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Adicionar ·'));
    await tester.pump();
    expect(find.text('Carrinho'), findsOneWidget);
    expect(find.text('Pizza Margherita'), findsOneWidget);
    expect(find.text('R\$ 32,90'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Continuar para checkout'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continuar para checkout'));
    await tester.pump();
    await tester.scrollUntilVisible(find.textContaining('A forma escolhida será salva'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Nenhum pagamento será processado'), findsOneWidget);
  });

  testWidgets('theme settings expose light dark and automatic modes',
      (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.tap(find.text('Aparência'));
    await tester.pump();
    expect(find.text('Automático'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Tema do aplicativo'))).brightness,
        Brightness.dark);
  });
}
