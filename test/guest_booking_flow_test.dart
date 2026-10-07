import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/features/search/search_results_screen.dart';
import 'package:dioufy_ts_mvp/features/seat_selection/seat_selection_screen.dart';
import 'package:dioufy_ts_mvp/features/search/trip.dart';
import 'package:dioufy_ts_mvp/services/auth_service.dart';

void main() {
  testWidgets('Test Guest Checkout flow: click on ticket card navigates to seat selection without account', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. S'assurer que le mode Guest est actif (sans compte connecté)
    AuthService.instance.continueAsGuest();
    expect(AuthService.instance.isGuest, isTrue);
    expect(AuthService.instance.currentUser?.id, equals('guest_traveler'));

    // 2. Afficher SearchResultsScreen
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultsScreen(
          departure: 'Dakar',
          destination: 'Touba',
          travelDate: '2026-10-04',
          passengerCount: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 3. Vérifier la présence du bouton d'action du billet
    final chooseButton = find.text('Choisir ce car');
    expect(chooseButton, findsWidgets);

    // 4. Cliquer sur le premier billet disponible
    await tester.ensureVisible(chooseButton.first);
    await tester.tap(chooseButton.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 5. Vérifier que la sélection de sièges s'affiche sans bloquer pour compte
    expect(find.byType(SeatSelectionScreen), findsOneWidget);
    expect(find.textContaining('Choix des Sièges'), findsOneWidget);
  });
}
