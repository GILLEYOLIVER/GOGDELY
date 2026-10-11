import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/main.dart';

void main() {
  testWidgets('home shows demo components', (tester) async {
    await tester.pumpWidget(const GogdelyApp());
    expect(find.text('GOGDELY • Laboratório'), findsOneWidget);
    expect(find.text('Leitor QR Code'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
  });
}
