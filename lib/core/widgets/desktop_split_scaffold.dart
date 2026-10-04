import 'package:flutter/material.dart';
import '../theme/dioufy_tokens.dart';
import '../../features/digital_display/presentation/digital_display_widget.dart';

/// ============================================================
/// DESKTOP SPLIT SCAFFOLD : Architecture adaptative universelle
/// ------------------------------------------------------------
/// - Mobile (< 600px)      : 1 colonne fluide tactile
/// - Tablette (600-1023px) : 1 colonne centrée avec marges (max 720px)
/// - Desktop (>= 1024px)   : Split Screen 2 volets (gauche applicatif + droit compagnon)
/// ============================================================
///
/// RÈGLE CONTEXTUELLE DU VOLET DROIT :
///   - Écrans de découverte (Login, Register, Home, Search)  -> DigitalDisplayWidget
///   - Écrans de transaction (SeatSelection, Payment)        -> TransactionSummaryPane
///   - Écrans de consultation (MyTickets, Ticket)           -> TicketSummaryPane
///
class DesktopSplitScaffold extends StatelessWidget {
  /// Contenu applicatif principal (volet gauche en desktop).
  final Widget child;

  /// Volet droit contextuel. Si null, le DigitalDisplayWidget par défaut est affiché.
  final Widget? rightPane;

  /// Titre de l'écran (AppBar). Si null, pas d'AppBar globale injectée.
  final String? title;

  /// Sous-titre optionnel dans l'AppBar (ex: "Dakar → Touba").
  final String? subtitle;

  /// Bouton retour. RÈGLE OBLIGATOIRE DU PROJET.
  final bool showBackButton;

  /// Callback de retour personnalisé (si nécessaire).
  final VoidCallback? onBack;

  /// Actions personnalisées à droite de l'AppBar.
  final List<Widget>? appBarActions;

  /// Couleur de fond de l'AppBar (par défaut : blanc pur lumineux).
  final Color? appBarBackgroundColor;

  /// Largeur minimale du volet gauche en desktop (défaut : 500px).
  final double leftPaneMinWidth;

  /// Largeur maximale du volet gauche en desktop (défaut : 580px).
  final double leftPaneMaxWidth;

  /// Ratio du split (par défaut : 48% / 52%).
  final int leftFlex;
  final int rightFlex;

  /// Background color du scaffold.
  final Color? backgroundColor;

  /// Floating Action Button optionnel.
  final Widget? floatingActionButton;

  const DesktopSplitScaffold({
    super.key,
    required this.child,
    this.rightPane,
    this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.appBarActions,
    this.appBarBackgroundColor,
    this.leftPaneMinWidth = 500,
    this.leftPaneMaxWidth = 580,
    this.leftFlex = 48,
    this.rightFlex = 52,
    this.backgroundColor,
    this.floatingActionButton,
  });

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // -------- DESKTOP (>= 1024px) : Split Screen --------
        if (width >= DioufyBreakpoints.tablet) {
          return _buildDesktopLayout(context);
        }

        // -------- TABLETTE (600-1023px) : Contenu centré --------
        if (width >= DioufyBreakpoints.mobile) {
          return _buildTabletLayout(context);
        }

        // -------- MOBILE (< 600px) : Plein écran fluide --------
        return _buildMobileLayout(context);
      },
    );
  }

  // ==================== DESKTOP (>= 1024px) ====================
  Widget _buildDesktopLayout(BuildContext context) {
    final effectiveBg = backgroundColor ?? DioufyColors.background;

    return Scaffold(
      backgroundColor: effectiveBg,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          // -------- VOLET GAUCHE : Zone Applicative Métier (520px) --------
          Container(
            width: 520,
            constraints: const BoxConstraints(minWidth: 460, maxWidth: 580),
            color: effectiveBg,
            child: Scaffold(
              backgroundColor: effectiveBg,
              appBar: _buildAppBar(context),
              body: child,
            ),
          ),

          // -------- SÉPARATEUR FIN 1.2px --------
          Container(
            width: 1.2,
            color: DioufyColors.border,
          ),

          // -------- VOLET DROIT : Compagnon Contextuel / Digital Display (Plein format) --------
          Expanded(
            child: Container(
              color: rightPane != null ? DioufyColors.surface : DioufyColors.darkBackground,
              child: rightPane ?? const DigitalDisplayWidget(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TABLETTE (600-1023px) ====================
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? DioufyColors.background,
      appBar: _buildAppBar(context),
      floatingActionButton: floatingActionButton,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    );
  }

  // ==================== MOBILE (< 600px) ====================
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? DioufyColors.background,
      appBar: _buildAppBar(context),
      floatingActionButton: floatingActionButton,
      body: child,
    );
  }

  // ==================== APPBAR LUMINEUSE HARMONISÉE ====================
  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (title == null) return null;

    final canGoBack = showBackButton;

    return AppBar(
      backgroundColor: appBarBackgroundColor ?? DioufyColors.white,
      foregroundColor: DioufyColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: DioufyColors.textPrimary,
              onPressed: () => _handleBack(context),
              tooltip: 'Retour',
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title!,
            style: const TextStyle(
              fontFamily: DioufyTypography.fontFamily,
              fontSize: 19,
              fontWeight: DioufyTypography.bold,
              color: DioufyColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: DioufyTypography.fontFamily,
                fontSize: DioufyTypography.microLabel,
                fontWeight: DioufyTypography.medium,
                color: DioufyColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: appBarActions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: DioufyColors.border),
      ),
    );
  }
}
