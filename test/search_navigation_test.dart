import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/main.dart';
import 'package:dioufy_ts_mvp/features/search/search_results_screen.dart';
import 'package:dioufy_ts_mvp/features/home/home_screen.dart';
import 'package:dioufy_ts_mvp/features/landing/landing_screen.dart';

void main() {
  testWidgets('Test direct rendering of SearchResultsScreen on Desktop (> 960px)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SearchResultsScreen), findsOneWidget);
    expect(find.text('Dakar → Touba'), findsOneWidget);
  });

  testWidgets('Test direct rendering of SearchResultsScreen on Mobile (< 600px)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SearchResultsScreen), findsOneWidget);
    expect(find.text('Dakar → Touba'), findsOneWidget);
  });

  testWidgets('Test clicking search on LandingScreen in Desktop split view', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: LandingScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find the button "Rechercher un trajet"
    final searchButton = find.text('Rechercher un trajet');
    expect(searchButton, findsOneWidget);

    await tester.ensureVisible(searchButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(searchButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SearchResultsScreen), findsOneWidget);
  });

  testWidgets('Test clicking RECHERCHER button on HomeScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The RECHERCHER button
    final searchBtn = find.text('RECHERCHER');
    expect(searchBtn, findsOneWidget);

    await tester.ensureVisible(searchBtn);
    await tester.pump();
    await tester.tap(searchBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SearchResultsScreen), findsOneWidget);
  });
}
