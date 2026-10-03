import 'package:flutter/material.dart';

/// ============================================================
/// DIOUFY-TOKENS : Source de vérité unique du Design System
/// Charte « Dioufy Pure & Lumineuse »
/// ============================================================

/// ------------------------------------------------------------
/// 1. COULEURS
/// ------------------------------------------------------------
class DioufyColors {
  DioufyColors._();

  // --- Surfaces & Fonds (Luminosité & Clarté) ---
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC); // Ardoise Céleste
  static const Color backgroundLight = Color(0xFFF8FAFC); // Alias rétro-compatible
  static const Color surface = Color(0xFFF8FAFC); // Écran perle standard
  static const Color surfaceSoft = Color(0xFFF1F5F9); // Gris Perle Foncier
  static const Color border = Color(0xFFE2E8F0); // Bordures Subtiles
  static const Color borderSubtle = Color(0xFFE2E8F0); // Alias explicite

  // --- Identité & Actions ---
  static const Color primary = Color(0xFF1D4ED8); // Bleu Royal Dioufy
  static const Color primaryLight = Color(0xFF2563EB); // Bleu Azur Éclatant
  static const Color primarySoft = Color(0xFFEFF6FF); // Pilule active
  static const Color primaryDark = Color(0xFF0F172A); // Noir Ardoise (Textes principaux)
  static const Color accent = Color(0xFF1D4ED8); // Alias rétro-compatible

  // --- Textes (Inversion sémantique du Noir Ardoise) ---
  static const Color textPrimary = Color(0xFF0F172A); // Encre principale
  static const Color textSecondary = Color(0xFF475569); // Gris soutenu WCAG AA (ratio > 7:1)
  static const Color textMuted = Color(0xFF64748B); // Légendes discrètes
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // --- Accents Sénégal ---
  static const Color emerald = Color(0xFF059669); // Vert Émeraude FinTech
  static const Color emeraldLight = Color(0xFF10B981);
  static const Color emeraldSoft = Color(0xFFECFDF5);
  static const Color accentGreen = Color(0xFF059669); // Alias expressif

  static const Color gold = Color(0xFFF59E0B); // Or Teranga
  static const Color goldDark = Color(0xFFD97706);
  static const Color goldSoft = Color(0xFFFEF3C7);
  static const Color accentAmber = Color(0xFFF59E0B); // Alias expressif

  static const Color coral = Color(0xFFEF4444); // Rouge Corail Doux
  static const Color coralSoft = Color(0xFFFEF2F2);

  // --- Dark Mode (préparation trajets nocturnes de 3h du matin) ---
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
}

/// ------------------------------------------------------------
/// 2. TYPOGRAPHIE (Échelle mobile-first rehaussée)
/// ------------------------------------------------------------
class DioufyTypography {
  DioufyTypography._();

  static const String fontFamily = 'Inter';

  // Tailles minimales garanties sans fatigue visuelle
  static const double microLabel = 13.0; // Statuts, badges, étiquettes
  static const double caption = 14.0; // Stations, durées, métadonnées
  static const double body = 15.5; // Corps de texte standard
  static const double bodyLargeSize = 16.0; // Inputs, formulaires
  static const double buttonSize = 16.5; // Titres de boutons
  static const double cardTitle = 17.5; // Titres de cartes
  static const double priceSize = 22.0; // Prix FCFA
  static const double priceLarge = 24.0; // Heures de départ
  static const double screenTitle = 26.0; // Titres d'écrans
  static const double screenTitleLarge = 30.0; // Hero titles
  static const double amountHero = 32.0; // Montant paiement

  // Hauteurs de ligne ergonomiques (prévention stricte de l écrasement vertical)
  static const double heightTight = 1.35;
  static const double heightNormal = 1.45;
  static const double heightRelaxed = 1.6;

  // Poids
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;

  // --- Styles de texte prêts à l'emploi ---
  static const TextStyle h1 = TextStyle(
    fontSize: screenTitle,
    fontWeight: bold,
    color: DioufyColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: priceLarge,
    fontWeight: bold,
    color: DioufyColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: cardTitle,
    fontWeight: semiBold,
    color: DioufyColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: bodyLargeSize,
    fontWeight: regular,
    color: DioufyColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: body,
    fontWeight: regular,
    color: DioufyColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: caption,
    fontWeight: regular,
    color: DioufyColors.textSecondary,
    fontFamily: fontFamily,
  );

  static const TextStyle button = TextStyle(
    fontSize: buttonSize,
    fontWeight: bold,
    color: Colors.white,
    fontFamily: fontFamily,
  );

  static TextStyle price([double size = priceSize]) => TextStyle(
    fontSize: size,
    fontWeight: black,
    color: DioufyColors.emerald,
    fontFamily: fontFamily,
  );
}

/// ------------------------------------------------------------
/// 3. ESPACEMENTS (Grille 4pt)
/// ------------------------------------------------------------
class DioufySpacing {
  DioufySpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Padding de page standard
  static const EdgeInsets defaultPagePadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static EdgeInsets pagePadding([BuildContext? context]) => defaultPagePadding;

  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(20);
}

/// ------------------------------------------------------------
/// 4. RAYONS DE BORDURE
/// ------------------------------------------------------------
class DioufyRadius {
  DioufyRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double pill = 999.0;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  // Alias sémantiques prêts à l'emploi
  static const BorderRadius card = xlAll;
  static const BorderRadius button = lgAll;
  static const BorderRadius tag = smAll;
}

/// ------------------------------------------------------------
/// 5. OMBRES (Diffuses, douces, jamais de noir opaque brutal)
/// ------------------------------------------------------------
class DioufyShadows {
  DioufyShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A0F172A), // 4% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Color(0x140F172A), // 8% opacity
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> bottomBar = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 12,
      offset: Offset(0, -2),
    ),
  ];
}

/// ------------------------------------------------------------
/// 6. BREAKPOINTS (Seuil unique et cohérent)
/// ------------------------------------------------------------
class DioufyBreakpoints {
  DioufyBreakpoints._();

  static const double mobile = 600.0;
  static const double tablet = 960.0; // Seuil Desktop Split Screen harmonisé à 960px
  static const double desktop = 960.0;
}
