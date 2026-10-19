import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/screens/online_catalog_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('general app searches products and opens their store', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/discover')) {
        return http.Response(jsonEncode([{
          'slug': 'loja-a', 'store_name': 'Loja A', 'item_name': 'Pizza',
          'category_name': 'Pizzas', 'price_cents': 3200,
        }]), 200);
      }
      return http.Response(jsonEncode({'name': 'Loja A', 'items': []}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: OnlineCatalogScreen(
      slug: '', apiBaseUrl: 'https://api.example.test', client: client,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Explore os cardápios'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    await tester.tap(find.text('Pizza'));
    await tester.pumpAndSettle();
    expect(find.text('Loja A'), findsOneWidget);
    expect(find.text('Explorar outras lojas'), findsOneWidget);
    client.close();
  });

  test('QR link selects the store and valid table number', () {
    final screen = OnlineCatalogScreen.fromUri(
      Uri.parse('https://pwa.example.test/cliente/?loja=loja-a&mesa=12'),
    );
    expect(screen.slug, 'loja-a');
    expect(screen.tableNumber, 12);
    final invalid = OnlineCatalogScreen.fromUri(
      Uri.parse('https://pwa.example.test/cliente/?loja=loja-a&mesa=1000'),
    );
    expect(invalid.tableNumber, isNull);
  });

  testWidgets('table link reads public catalog and searches products', (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/catalog/stores/loja-a');
      return http.Response(jsonEncode({
        'name': 'Loja A',
        'items': [
          {'name': 'Pizza', 'description': 'Queijo', 'category_name': 'Pizzas',
           'price_cents': 3200, 'available': true},
          {'name': 'Suco', 'description': 'Laranja', 'category_name': 'Bebidas',
           'price_cents': 800, 'available': true},
          {'name': 'Oculto', 'description': '', 'category_name': 'Bebidas',
           'price_cents': 100, 'available': false},
        ],
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(MaterialApp(home: OnlineCatalogScreen(
      slug: 'loja-a', tableNumber: 2, apiBaseUrl: 'https://api.example.test',
      client: client,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Loja A'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Suco'), findsOneWidget);
    expect(find.text('Oculto'), findsNothing);
    expect(find.textContaining('Pedidos e pagamentos online ainda não'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump();
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Suco'), findsNothing);
    client.close();
  });

  testWidgets('invalid slug never makes a network call', (tester) async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(MaterialApp(home: OnlineCatalogScreen(
      slug: '../other', apiBaseUrl: 'https://api.example.test', client: client,
    )));
    await tester.pump();
    expect(called, isFalse);
    expect(find.text('Link da loja inválido.'), findsOneWidget);
    client.close();
  });
}
