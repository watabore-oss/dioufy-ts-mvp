/// Rôles officiels Dioufy-TS avec niveau hiérarchique et protection anti-suicide/anti-élévation
enum AppRole {
  superAdmin(
    id: 'super_admin',
    name: 'Super Administrateur Plateforme',
    level: 0,
    isSystemLocked: true,
  ),
  platformAdmin(
    id: 'platform_admin',
    name: 'Administrateur Support',
    level: 1,
    isSystemLocked: true,
  ),
  gieAdmin(
    id: 'gie_admin',
    name: 'Gérant de GIE / Transporteur',
    level: 2,
    isSystemLocked: true,
  ),
  gieAgent(
    id: 'gie_agent',
    name: "Agent d'Exploitation GIE",
    level: 3,
    isSystemLocked: true,
  ),
  driver(
    id: 'driver',
    name: 'Chauffeur Titulaire',
    level: 3,
    isSystemLocked: true,
  ),
  coxeur(
    id: 'coxeur',
    name: 'Agent de Quai / Régulateur',
    level: 3,
    isSystemLocked: true,
  ),
  mechanic(
    id: 'mechanic',
    name: 'Garagiste Partenaire Agréé',
    level: 3,
    isSystemLocked: true,
  ),
  passenger(
    id: 'passenger',
    name: 'Voyageur / Client',
    level: 4,
    isSystemLocked: true,
  );

  final String id;
  final String name;
  final int level;
  final bool isSystemLocked;

  const AppRole({
    required this.id,
    required this.name,
    required this.level,
    required this.isSystemLocked,
  });

  /// Parse depuis un identifiant texte (insensible à la casse)
  static AppRole fromId(String? id) {
    if (id == null) return AppRole.passenger;
    final cleanId = id.trim().toLowerCase();
    for (final role in AppRole.values) {
      if (role.id.toLowerCase() == cleanId) return role;
    }
    return AppRole.passenger;
  }

  /// Règle de sécurité stricte : un utilisateur ne peut administrer que des rôles
  /// de niveau strictement inférieur à lui, et JAMAIS un superAdmin sauf s'il est lui-même superAdmin.
  bool canManageRole(AppRole targetRole) {
    if (this == AppRole.superAdmin) {
      return true; // Le Super Admin peut tout administrer
    }
    if (targetRole == AppRole.superAdmin) {
      return false; // Anti-Élévation absolue : aucun non-superAdmin ne peut toucher au superAdmin
    }
    if (targetRole == AppRole.platformAdmin && level >= 1) {
      return false; // Seul le superAdmin peut gérer un admin plateforme
    }
    // Règle générale : niveau strictement supérieur numériquement (ex: level 2 peut gérer level 3 et 4)
    return level < targetRole.level;
  }
}
