import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/main.dart';

void main() {
  testWidgets('DioufyApp smoke test - Affiche la LandingPage avec les 3 options',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DioufyApp());
    await tester.pump();

    // Vérifie la présence du titre Dioufy-TS et du slogan
    expect(find.textContaining('DIOUFY-TS'), findsOneWidget);
    expect(find.textContaining('Fo nek sa gare fek lafa'), findsOneWidget);

    // Vérifie la présence des options d'accueil de la Landing Page
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Acheter un billet sans compte'), findsOneWidget);
  });
}
