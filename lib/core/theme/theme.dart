import 'package:flutter/material.dart';
import 'dioufy_tokens.dart';

/// ============================================================
/// DIOUFY-THEME : Configuration ThemeData Light & Dark
/// Charte « Dioufy Pure & Lumineuse »
/// ============================================================
class DioufyTheme {
  DioufyTheme._();

  // Alias statiques de rétrocompatibilité
  static const Color deepBlue = DioufyColors.primaryDark;
  static const Color trustBlue = DioufyColors.primaryDark;
  static const Color actionBlue = DioufyColors.primary;
  static const Color gold = DioufyColors.gold;
  static const Color emerald = DioufyColors.emerald;

  // ==================== LIGHT THEME (Par défaut) ====================
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: DioufyColors.background,
      primaryColor: DioufyColors.primary,
      colorScheme: const ColorScheme.light(
        primary: DioufyColors.primary,
        onPrimary: DioufyColors.textOnPrimary,
        secondary: DioufyColors.emerald,
        onSecondary: DioufyColors.white,
        surface: DioufyColors.white,
        onSurface: DioufyColors.textPrimary,
        error: DioufyColors.coral,
        outline: DioufyColors.border,
      ),

      // --- AppBar LUMINEUSE BLANCHE ÉPURÉE ---
      appBarTheme: const AppBarTheme(
        backgroundColor: DioufyColors.white,
        foregroundColor: DioufyColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: DioufyColors.textPrimary,
          size: 24,
        ),
        titleTextStyle: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          color: DioufyColors.textPrimary,
          fontSize: 19,
          fontWeight: DioufyTypography.bold,
        ),
      ),

      // --- TEXT THEME ÉTAGÉ ---
      textTheme: const TextTheme(
        // Grands titres
        displayLarge: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.screenTitleLarge,
          fontWeight: DioufyTypography.black,
          color: DioufyColors.textPrimary,
          height: DioufyTypography.heightTight,
        ),
        displayMedium: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.screenTitle,
          fontWeight: DioufyTypography.black,
          color: DioufyColors.textPrimary,
          height: DioufyTypography.heightTight,
        ),
        // Titres de cartes et sections
        titleLarge: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.cardTitle,
          fontWeight: DioufyTypography.bold,
          color: DioufyColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.buttonSize,
          fontWeight: DioufyTypography.semiBold,
          color: DioufyColors.textPrimary,
        ),
        // Corps de texte
        bodyLarge: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.bodyLargeSize,
          fontWeight: DioufyTypography.regular,
          color: DioufyColors.textPrimary,
          height: DioufyTypography.heightNormal,
        ),
        bodyMedium: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.body,
          fontWeight: DioufyTypography.regular,
          color: DioufyColors.textPrimary,
          height: DioufyTypography.heightNormal,
        ),
        // Légendes et badges (toujours >= 13px)
        bodySmall: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.caption,
          fontWeight: DioufyTypography.medium,
          color: DioufyColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.microLabel,
          fontWeight: DioufyTypography.medium,
          color: DioufyColors.textMuted,
        ),
      ),

      // --- BOUTONS PRIMAIRES & SECONDAIRES ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DioufyColors.primary,
          foregroundColor: DioufyColors.textOnPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
          textStyle: const TextStyle(
            fontFamily: DioufyTypography.fontFamily,
            fontSize: DioufyTypography.buttonSize,
            fontWeight: DioufyTypography.bold,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DioufyColors.textPrimary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: DioufyColors.border, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: DioufyRadius.mdAll),
          textStyle: const TextStyle(
            fontFamily: DioufyTypography.fontFamily,
            fontSize: DioufyTypography.buttonSize,
            fontWeight: DioufyTypography.semiBold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DioufyColors.primary,
          textStyle: const TextStyle(
            fontFamily: DioufyTypography.fontFamily,
            fontSize: DioufyTypography.body,
            fontWeight: DioufyTypography.semiBold,
          ),
        ),
      ),

      // --- INPUTS & FORMULAIRES ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DioufyColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DioufySpacing.md,
          vertical: DioufySpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: DioufyRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: DioufyRadius.mdAll,
          borderSide: BorderSide(color: DioufyColors.border, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: DioufyRadius.mdAll,
          borderSide: BorderSide(color: DioufyColors.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: DioufyRadius.mdAll,
          borderSide: BorderSide(color: DioufyColors.coral, width: 1),
        ),
        hintStyle: const TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.body,
          color: DioufyColors.textMuted,
        ),
        labelStyle: const TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.caption,
          color: DioufyColors.textSecondary,
          fontWeight: DioufyTypography.medium,
        ),
      ),

      // --- CARDS ---
      cardTheme: const CardThemeData(
        color: DioufyColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: DioufyRadius.lgAll,
          side: BorderSide(color: DioufyColors.border, width: 1),
        ),
      ),

      // --- DIVIDER ---
      dividerTheme: const DividerThemeData(
        color: DioufyColors.border,
        thickness: 1,
        space: 1,
      ),

      // --- NAVIGATION BOTTOM BAR ---
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: DioufyColors.white,
        selectedItemColor: DioufyColors.primary,
        unselectedItemColor: DioufyColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.microLabel,
          fontWeight: DioufyTypography.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: DioufyTypography.fontFamily,
          fontSize: DioufyTypography.microLabel,
          fontWeight: DioufyTypography.medium,
        ),
      ),
    );
  }

  // ==================== DARK THEME (Préparation Trajets de nuit) ====================
  /// ⚠️ RÈGLE ABSOLUE : Ne JAMAIS réduire les tailles de police en Dark Mode.
  static ThemeData get dark {
    final base = DioufyTheme.light;

    return base.copyWith(
      scaffoldBackgroundColor: DioufyColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: DioufyColors.primaryLight,
        onPrimary: DioufyColors.white,
        surface: DioufyColors.darkSurface,
        onSurface: DioufyColors.white,
        outline: DioufyColors.darkBorder,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: DioufyColors.darkSurface,
        foregroundColor: DioufyColors.white,
        iconTheme: const IconThemeData(color: DioufyColors.white, size: 24),
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: DioufyColors.white,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: DioufyColors.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: DioufyRadius.lgAll,
          side: BorderSide(color: DioufyColors.darkBorder, width: 1),
        ),
      ),
    );
  }
}
