import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/lab/device_lab.dart';

void main() {
  testWidgets('device lab exposes device and scenario controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: DeviceLab(child: Scaffold(body: Text('Conteúdo de teste'))),
    ));
    expect(find.text('GOGDELY • Laboratório'), findsOneWidget);
    expect(find.text('Dispositivo'), findsOneWidget);
    expect(find.text('Cenário de pedido'), findsOneWidget);
    expect(find.text('Conteúdo de teste'), findsOneWidget);
    await tester.tap(find.text('Girar'));
    await tester.pump();
    expect(find.text('Conteúdo de teste'), findsOneWidget);
  });
}
