import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestock/app/gestock_app.dart';
void main(){
 testWidgets('GeStock sign-in experience renders', (tester) async {
  await tester.pumpWidget(const ProviderScope(child:GeStockApp()));
  await tester.pumpAndSettle();
  expect(find.text('GeStock'),findsNothing); // The brand mark is icon-led on the sign-in surface.
  expect(find.text('Votre activité,'),findsOneWidget);
  expect(find.text('Se connecter'),findsOneWidget);
 });
}
