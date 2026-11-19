import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestock/app/gestock_app.dart';

void main() {
  testWidgets('GeStock sign-in experience renders without overflow', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GeStockApp()));
    await tester.pumpAndSettle();

    expect(find.text('GeStock'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign-in screen adapts to a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: GeStockApp()));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
