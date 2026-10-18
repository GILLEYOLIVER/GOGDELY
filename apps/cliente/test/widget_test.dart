import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/main.dart';
import 'package:gogdely_cliente/screens/client_components.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

void main() {
  testWidgets('home follows approved visual journey and filters categories',
      (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('Sabor que\nse aproxima.'), findsOneWidget);
    if (localDemoEnabled) {
      // The local section remains visible when the local API is unavailable.
      expect(find.text('Lojas do laboratório'), findsOneWidget);
      return;
    }
    await tester.scrollUntilVisible(find.text('Restaurantes'), 140,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(find.text('Restaurantes')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurantes'));
    await tester.pumpAndSettle();
    expect(find.text('Lojas para explorar'), findsOneWidget);
    expect(find.text('Pizzaria Napoli'), findsOneWidget);
  });

  testWidgets('home lists demonstration stores', (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    if (localDemoEnabled) {
      await tester.scrollUntilVisible(find.text('Lojas do laboratório'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Lojas do laboratório'), findsOneWidget);
      // Without a reachable local API no store is listed yet.
      expect(find.text('Burger House'), findsNothing);
      return;
    }
    await tester.scrollUntilVisible(find.text('Lojas para explorar'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Lojas para explorar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Burger House').first, 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Burger House'), findsWidgets);
  });

  testWidgets('search opens product and keeps cart to one store',
      (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Busca'));
    await tester.pump();
    if (localDemoEnabled) {
      expect(find.text('Busque lojas ou produtos locais'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'pizza');
      await tester.pump();
      expect(find.textContaining('Nenhuma loja ou produto encontrado'),
          findsOneWidget);
      return;
    }
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
    await tester.tap(find.textContaining('Adicionar ·'));
    await tester.pump();
    expect(find.text('SACOLA'), findsOneWidget);
    expect(find.text('Pizza Margherita'), findsOneWidget);
    expect(find.text('R\$ 32,90'), findsWidgets);
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.textContaining('A forma escolhida será salva'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Nenhum pagamento será processado'),
        findsOneWidget);
    await tester.tap(find.textContaining('Revisar pedido').first);
    await tester.pumpAndSettle();
    expect(find.text('Revise o seu pedido'), findsOneWidget);
    expect(find.text('Confirmar pedido fictício'), findsOneWidget);
    await tester.tap(find.text('Alterar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('REVISAR PEDIDO'), findsOneWidget);
  });

  testWidgets('search can open a matching product directly', (tester) async {
    if (localDemoEnabled) return;
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Busca'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'margherita');
    await tester.pump();
    expect(find.text('Produtos encontrados'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pizza Margherita'), 120,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        tester.element(find.text('Pizza Margherita')),
        alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pizza Margherita'));
    await tester.pump();
    expect(find.text('Escolha o tamanho'), findsOneWidget);
  });

  testWidgets('theme settings expose light dark and automatic modes',
      (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Aparência'), 160,
        scrollable: find.byType(Scrollable).first);
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

  testWidgets('profile payment screen saves the selected method',
      (tester) async {
    if (localDemoEnabled) return;
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.tap(find.text('Forma de pagamento'));
    await tester.pump();
    expect(find.text('Escolha como pagar'), findsOneWidget);
    await tester.tap(find.text('Pix').first);
    await tester.pump();
    await tester.tap(find.text('Usar Pix'));
    await tester.pump();
    expect(find.text('Forma de pagamento'), findsOneWidget);
  });

  testWidgets('search sort sheet and offers navigation are available',
      (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar'));
    await tester.pumpAndSettle();
    expect(find.text('Ordenar lojas'), findsOneWidget);
    await tester.tap(find.text('Avaliação'));
    await tester.pumpAndSettle();
    expect(find.text('Avaliação'), findsOneWidget);
    await tester.tap(find.text('Ofertas').last);
    await tester.pumpAndSettle();
    expect(find.text('Ofertas do cardápio'), findsOneWidget);
  });

  testWidgets('address form updates the home delivery label', (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    await tester.tap(find.text('Rua das Flores, 123'));
    await tester.pumpAndSettle();
    expect(find.text('ENDEREÇO DE ENTREGA'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Rua Azul');
    await tester.enterText(find.byType(TextField).at(1), '42');
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Rua Azul, 42'), findsOneWidget);
  });

  testWidgets('all five navigation actions fit a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const GogdelyApp());
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    expect(tester.getCenter(find.text('Perfil')).dx, lessThan(390));
    expect(tester.takeException(), isNull);
  });
}
