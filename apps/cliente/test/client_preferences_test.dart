import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/screens/client_preferences.dart';
import 'package:gogdely_cliente/screens/home_screen.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class MemoryPreferencesStore implements ClientPreferencesStore {
  String? value;

  @override
  String? read() => value;

  @override
  bool write(String value) {
    this.value = value;
    return true;
  }
}

void main() {
  test('browser preference store writes and reads on the same origin', () {
    if (!kIsWeb) return;
    const store = DeviceClientPreferencesStore();
    const value = ClientPreferences(street: 'Rua Azul', number: '42');
    expect(store.write(value.encode()), isTrue);
    expect(ClientPreferences.decode(store.read()).addressLabel, 'Rua Azul, 42');
  });

  test(
      'saved manual address and favorites survive decoding; bad data falls back',
      () {
    const preferences = ClientPreferences(
      street: 'Rua Azul',
      number: '42',
      complement: 'Apto 3',
      reference: 'Portão azul',
      kind: 'Trabalho',
      favoriteStoreIds: {'burger-house', 'padaria-aurora'},
    );
    final restored = ClientPreferences.decode(preferences.encode());
    expect(restored.addressLabel,
        'Rua Azul, 42 · Apto 3 · Referência: Portão azul');
    expect(restored.kind, 'Trabalho');
    expect(restored.favoriteStoreIds, {'burger-house', 'padaria-aurora'});
    expect(ClientPreferences.decode('{broken').addressLabel,
        'Rua das Flores, 123');
  });

  testWidgets('address and favorite are restored when the PWA screen reopens',
      (tester) async {
    if (localDemoEnabled) return;
    final store = MemoryPreferencesStore();
    Widget app() => MaterialApp(home: HomeScreen(preferencesStore: store));

    await tester.pumpWidget(app());
    await tester.tap(find.text('Rua das Flores, 123'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rua Azul');
    await tester.enterText(find.byType(TextField).at(1), '42');
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Rua Azul, 42'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Busca'));
    await tester.pumpAndSettle();
    final favoriteButton = find.byWidgetPredicate((widget) =>
        widget is IconButton && widget.tooltip == 'Favoritar Burger House');
    await tester.scrollUntilVisible(favoriteButton, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(favoriteButton);
    await tester.pump();
    Finder removeFavoriteButton() => find.byWidgetPredicate((widget) =>
        widget is IconButton &&
        widget.tooltip == 'Remover Burger House dos favoritos');
    expect(removeFavoriteButton(), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    expect(find.text('Rua Azul, 42'), findsOneWidget);
    await tester.tap(find.text('Busca'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(removeFavoriteButton(), 180,
        scrollable: find.byType(Scrollable).first);
    expect(removeFavoriteButton(), findsOneWidget);
  });
}
