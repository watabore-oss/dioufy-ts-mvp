import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dioufy_ts_mvp/core/permissions/app_role.dart';
import 'package:dioufy_ts_mvp/features/digital_display/services/digital_display_service.dart';
import 'package:dioufy_ts_mvp/features/digital_display/presentation/digital_display_widget.dart';
import 'package:dioufy_ts_mvp/features/digital_display/presentation/mobile_hero_slide_zone.dart';
import 'package:dioufy_ts_mvp/features/digital_display/presentation/mobile_promo_card.dart';
import 'package:dioufy_ts_mvp/features/landing/landing_screen.dart';
import 'package:dioufy_ts_mvp/features/navigation/main_navigation_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DigitalDisplayService Tests', () {
    test('Service returns rich default slides with required fields', () {
      final slides = DigitalDisplayService.instance.getSlides();
      expect(slides.isNotEmpty, isTrue);
      expect(slides.length, greaterThanOrEqualTo(3));

      for (final slide in slides) {
        expect(slide.id.isNotEmpty, isTrue);
        expect(slide.tag.isNotEmpty, isTrue);
        expect(slide.titlePrefix.isNotEmpty, isTrue);
        expect(slide.titleHighlight.isNotEmpty, isTrue);
        expect(slide.subtitle.isNotEmpty, isTrue);
        expect(slide.ctaText.isNotEmpty, isTrue);
        expect(slide.assetImage.isNotEmpty, isTrue);
        expect(slide.features.isNotEmpty, isTrue);
      }
    });

    test('getSlidesForRole provides customized contextual slides per role', () {
      final driverSlides = DigitalDisplayService.instance.getSlidesForRole(AppRole.driver);
      expect(driverSlides.any((s) => s.tag.contains('SÉCURITÉ') || s.tag.contains('CLÔTURE')), isTrue);

      final gieSlides = DigitalDisplayService.instance.getSlidesForRole(AppRole.gieAdmin);
      expect(gieSlides.any((s) => s.tag.contains('FLOTTE') || s.tag.contains('FINANCIÈRE')), isTrue);

      final coxeurSlides = DigitalDisplayService.instance.getSlidesForRole(AppRole.coxeur);
      expect(coxeurSlides.any((s) => s.tag.contains('QUAIS') || s.tag.contains('CONTRÔLE')), isTrue);

      final adminSlides = DigitalDisplayService.instance.getSlidesForRole(AppRole.superAdmin);
      expect(adminSlides.any((s) => s.tag.contains('SUPERVISION')), isTrue);
    });
  });

  group('Widget & Responsiveness Tests', () {
    testWidgets('DigitalDisplayWidget renders with pagination and controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: DigitalDisplayWidget(),
            ),
          ),
        ),
      );

      // Verify that controls exist
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.text('Mode Focus'), findsOneWidget);
    });

    testWidgets('MobilePromoCard renders compact carousel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: MobilePromoCard(),
            ),
          ),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    });

    testWidgets('LandingScreen renders desktop layout on wide viewport', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );

      // Verify presence of left pane and digital display widget
      expect(find.text('DIOUFY-TS'), findsOneWidget);
      expect(find.text('Rechercher un trajet'), findsOneWidget);
      expect(find.byType(DigitalDisplayWidget), findsOneWidget);
    });

    testWidgets('LandingScreen renders mobile layout on narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );

      // In mobile mode, DigitalDisplayWidget is integrated as background MobileHeroSlideZone
      expect(find.text('DIOUFY-TS'), findsOneWidget);
      expect(find.text('Rechercher un trajet'), findsOneWidget);
      expect(find.byType(MobileHeroSlideZone), findsOneWidget);
      expect(find.byType(DigitalDisplayWidget), findsNothing);
    });

    testWidgets('MainNavigationScaffold renders Desktop shell on desktop resolution', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScaffold(),
        ),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(DigitalDisplayWidget), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('MainNavigationScaffold renders Tablet shell on tablet resolution', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScaffold(),
        ),
      );

      // On tablet: NavigationRail is active, DigitalDisplay is not cluttering
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(DigitalDisplayWidget), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('MainNavigationScaffold renders Mobile shell on smartphone resolution', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationScaffold(),
        ),
      );

      // On mobile: NavigationBar is active, NavigationRail is omitted
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(DigitalDisplayWidget), findsNothing);
    });
  });
}
