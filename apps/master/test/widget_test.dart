import 'package:flutter_test/flutter_test.dart';
import 'package:gogdely_master/main.dart';

void main() {
  testWidgets('master shows the simulated MFA gate before the panel',
      (tester) async {
    await tester.pumpWidget(const MasterApp());
    expect(find.text('Acesso Master'), findsOneWidget);
    expect(find.text('Gerar código MFA simulado'), findsOneWidget);
    // The governance panel stays hidden until the simulated MFA step passes.
    expect(find.text('Empresas'), findsNothing);
  });
}
