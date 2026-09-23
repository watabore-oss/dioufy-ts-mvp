import 'package:flutter/material.dart';

/// Badge d'atout ou caractéristique affiché au bas d'un slide
class SlideFeatureBadge {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBgColor;
  final Color iconColor;

  const SlideFeatureBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBgColor = const Color(0xFF059669),
    this.iconColor = Colors.white,
  });
}

/// Modèle représentant une diapositive du Digital Display Dioufy-TS
class SlideItem {
  final String id;
  final String tag;
  final String titlePrefix;
  final String titleHighlight;
  final String subtitle;
  final String ctaText;
  final String assetImage;
  final String? targetRoute;
  final List<SlideFeatureBadge> features;

  const SlideItem({
    required this.id,
    required this.tag,
    required this.titlePrefix,
    required this.titleHighlight,
    required this.subtitle,
    required this.ctaText,
    required this.assetImage,
    this.targetRoute,
    this.features = const [],
  });
}
