// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dioufy_ts_mvp/main.dart';

void main() {
  testWidgets('DioufyApp smoke test - HomeScreen affiche Dioufy-TS et le formulaire',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DioufyApp());

    // Verifie la presence du titre Dioufy-TS et du slogan
    expect(find.text('Dioufy-TS'), findsOneWidget);
    expect(find.text('Fo nek sa gare fek lafa'), findsOneWidget);

    // Verifie la presence du bouton de recherche
    expect(find.text('RECHERCHER'), findsOneWidget);

    // Verifie le bouton Chef de bord
    expect(find.text('Chef de bord'), findsOneWidget);
  });
}

