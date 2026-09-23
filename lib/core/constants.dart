import 'package:flutter/material.dart';

/// Constantes et référentiels du domaine Dioufy-TS
class AppConstants {
  static const String appName = "Dioufy-TS";
  static const String appSlogan = "Fo nek sa gare fek lafa";
  static const String currency = "FCFA";
  static const String currencyCode = "XOF";

  /// Villes et Gares de transport principales au Sénégal
  static const List<String> stations = [
    "Dakar (Baux Maraîchers)",
    "Thiès (Gare Centrale)",
    "Touba (Gare Ouest)",
    "Saint-Louis (Khor)",
    "Mbour (Gare Centrale)",
    "Kaolack (Garage Nioro)",
    "Ziguinchor (Gare de la Paix)",
  ];

  /// Noms courts des villes
  static const List<String> cityNames = [
    "Dakar",
    "Thiès",
    "Touba",
    "Saint-Louis",
    "Mbour",
    "Kaolack",
    "Ziguinchor",
  ];

  /// Compagnies partenaires pilotes
  static const List<String> partnerCompanies = [
    "Dioufy Trans",
    "Galsen Tour",
    "Touba Express",
    "Ndiambour Transport",
  ];

  /// Clés de stockage local (SharedPreferences / Offline)
  static const String prefsTicketsKey = "dioufy_local_tickets_v1";
  static const String prefsLastSearchKey = "dioufy_last_search_v1";
}

/// Widget réutilisable représentant le symbole monétaire officiel : cercle contenant "XOF"
class XofCurrencyBadge extends StatelessWidget {
  final double size;
  final Color textColor;
  final Color backgroundColor;

  const XofCurrencyBadge({
    super.key,
    this.size = 20,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0xFF059669),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        "XOF",
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
