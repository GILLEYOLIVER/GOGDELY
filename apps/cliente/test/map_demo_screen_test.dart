import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/screens/location_types.dart';
import 'package:gogdely_cliente/screens/map_demo_screen.dart';

void main() {
  testWidgets('location button centers and selects a consented test position',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: MapDemoScreen(
        pickLocation: true,
        locationProvider: () async {
          requests++;
          return const DeviceLocation(-16.6869, -49.2648, accuracyMeters: 12);
        },
      ),
    ));
    expect(requests, 0);
    await tester.tap(find.text('Minha localização'));
    await tester.pump();
    await tester.pump();
    expect(requests, 1);
    expect(find.textContaining('Ponto: -16.68690, -49.26480'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Usar este ponto'))
            .onPressed,
        isNotNull);
  });
}
