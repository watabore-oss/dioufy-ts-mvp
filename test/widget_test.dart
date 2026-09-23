import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/main.dart';

void main() {
  testWidgets('DioufyApp smoke test - Affiche la LandingPage avec les 3 options',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DioufyApp());
    await tester.pump();

    // Vérifie la présence du titre Dioufy-TS et du slogan
    expect(find.text('Dioufy-TS'), findsOneWidget);
    expect(find.text('Fo nek sa gare fek lafa'), findsOneWidget);

    // Vérifie la présence des 3 options de la Landing Page
    expect(find.text('CRÉER UN COMPTE'), findsOneWidget);
    expect(find.text('SE CONNECTER'), findsOneWidget);
    expect(find.text('Réserver sans compte (Voyageur direct)'), findsOneWidget);
  });
}
