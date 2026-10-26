import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_cliente/screens/brand_motion.dart';

void main() {
  testWidgets('animated opening can be skipped', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: BrandIntro(onFinished: () => finished++),
    ));
    expect(find.text('gogdely.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Pular'));
    expect(finished, 1);
  });

  testWidgets('animated opening respects reduced motion', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: BrandIntro(onFinished: () => finished++),
      ),
    ));
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('motorcycle leaves the right edge before opening ends',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: BrandIntro(onFinished: () => finished++),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4950));
    expect(tester.getTopLeft(find.byKey(const Key('intro-motorcycle'))).dx,
        greaterThan(390));
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(finished, 1);
  });

  testWidgets('motorcycle stops, sounds twice, then rides on', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var horns = 0;
    await tester.pumpWidget(MaterialApp(
      home: BrandIntro(onFinished: () {}, onHorn: () => horns++),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1950));
    final stoppedAt =
        tester.getTopLeft(find.byKey(const Key('intro-motorcycle'))).dx;
    expect(horns, 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(horns, 1);
    expect(find.byKey(const Key('intro-horn-1')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(horns, 2);
    expect(find.byKey(const Key('intro-horn-2')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('intro-motorcycle'))).dx,
        closeTo(stoppedAt, 1));
    await tester.pump(const Duration(milliseconds: 1700));
    expect(tester.getTopLeft(find.byKey(const Key('intro-motorcycle'))).dx,
        greaterThan(stoppedAt));
  });

  testWidgets('tap enables two audible horn calls during the stop',
      (tester) async {
    var horns = 0;
    await tester.pumpWidget(MaterialApp(
      home: BrandIntro(onFinished: () {}, onHorn: () => horns++),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.tap(find.text('Toque para ouvir as buzinas'));
    expect(horns, 1);
    await tester.pump(const Duration(milliseconds: 630));
    expect(horns, 2);
    await tester.pump(const Duration(milliseconds: 700));
    expect(horns, 2);
  });
}
