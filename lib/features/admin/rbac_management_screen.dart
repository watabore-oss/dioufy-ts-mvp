import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/permissions/app_role.dart';
import '../../core/permissions/app_permission.dart';
import '../../core/permissions/rbac_service.dart';
import '../../core/permissions/permission_guard.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';

/// Écran d'administration de la Matrice RBAC Granulaire & Gestion des Rôles
/// Accessible uniquement aux utilisateurs détenant la permission [rbac.manage_permissions]
class RbacManagementScreen extends StatefulWidget {
  final bool showAppBar;

  const RbacManagementScreen({super.key, this.showAppBar = true});

  /// Méthode publique universelle pour ouvrir la modale de provisionnement de compte
  static void showCreateUserDialog(BuildContext context) {
    _RbacManagementScreenState.showCreateUserDialog(context);
  }

  @override
  State<RbacManagementScreen> createState() => _RbacManagementScreenState();
}

class _RbacManagementScreenState extends State<RbacManagementScreen> {
  AppRole _selectedRole = AppRole.gieAdmin;
  late Map<AppRole, Set<String>> _rolePermissionsMap;
  String _selectedModuleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _rolePermissionsMap = {};
    for (final role in AppRole.values) {
      _rolePermissionsMap[role] =
          Set<String>.from(AppPermission.getDefaultPermissions(role));
    }
  }

  void _togglePermission(String permissionId, AppPermission perm) {
    // 1. Protection Anti-Suicide & Anti-Élévation
    if (perm.category == PermissionCategory.systemLocked &&
        _selectedRole != AppRole.superAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sécurité : Cette permission est verrouillée système et ne peut être attribuée qu au Super Admin.'),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    // 2. Empêcher de dégrader le Super Admin sur ses permissions fondamentales
    if (_selectedRole == AppRole.superAdmin &&
        perm.category == PermissionCategory.systemLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Protection Anti-Suicide : Les permissions souveraines du Super Admin ne peuvent pas être révoquées.'),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    setState(() {
      final currentSet = _rolePermissionsMap[_selectedRole]!;
      if (currentSet.contains(permissionId)) {
        currentSet.remove(permissionId);
      } else {
        currentSet.add(permissionId);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Matrice RBAC mise à jour pour [${_selectedRole.name}] : $permissionId'),
        backgroundColor: DioufyColors.emerald,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Column(
      children: [
        // Barre de simulation de rôle (strictement restreinte au mode DEBUG)
        if (kDebugMode) _buildDebugRoleSwitcher(),

        // Sélecteur de rôle cible à configurer
        _buildRoleSelector(),

        // Filtres par module
        _buildModuleFilterChips(),

        // Matrice des permissions
        Expanded(
          child: _buildPermissionsList(),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return PermissionGuard(
        permissionId: AppPermission.rbacManagePermissions,
        actionLabel: 'Gouvernance RBAC & Permissions',
        child: Container(
          color: DioufyColors.backgroundLight,
          child: bodyContent,
        ),
      );
    }

    return PermissionGuard(
      permissionId: AppPermission.rbacManagePermissions,
      actionLabel: 'Gouvernance RBAC & Permissions',
      child: Scaffold(
        backgroundColor: DioufyColors.backgroundLight,
        appBar: AppBar(
          title: const Text(
            'Gouvernance RBAC & Matrice',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: DioufyColors.textPrimary),
          ),
          backgroundColor: Colors.white,
          foregroundColor: DioufyColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DioufyColors.textPrimary),
            tooltip: 'Retour',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => showCreateUserDialog(context),
              icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
              label: const Text(
                '+ Créer Compte',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user, size: 16, color: DioufyColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    RbacService.instance.currentRole.name,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: DioufyColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: bodyContent,
      ),
    );
  }

  Widget _buildDebugRoleSwitcher() {
    return Container(
      color: Colors.amber.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.bug_report, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          const Text(
            'Simulateur Profil (DEBUG) :',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AppRole.values.map((role) {
                  final isCurrent = RbacService.instance.currentRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(role.id, style: const TextStyle(fontSize: 11)),
                      selected: isCurrent,
                      selectedColor: DioufyColors.primary,
                      labelStyle: TextStyle(
                        color: isCurrent ? Colors.white : Colors.black87,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          RbacService.instance.switchRoleForTesting(role);
                          setState(() {});
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: DioufyColors.primaryDark),
          const SizedBox(width: 12),
          const Text(
            'Rôle Cible :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppRole>(
                value: _selectedRole,
                isExpanded: true,
                items: AppRole.values.map((role) {
                  return DropdownMenuItem<AppRole>(
                    value: role,
                    child: Text(
                      '${role.name} (Niveau ${role.level})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: role == AppRole.superAdmin ? FontWeight.bold : FontWeight.normal,
                        color: role == AppRole.superAdmin ? DioufyColors.coral : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newRole) {
                  if (newRole != null) {
                    setState(() => _selectedRole = newRole);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleFilterChips() {
    final modules = [
      {'id': 'all', 'label': 'Tous les modules'},
      {'id': 'module_booking', 'label': 'Réservation'},
      {'id': 'module_ticketing', 'label': 'Billetterie'},
      {'id': 'module_cash_closure', 'label': 'Caisse & Com.'},
      {'id': 'module_fleet', 'label': 'Flotte'},
      {'id': 'module_garage_assistance', 'label': 'Garagiste'},
      {'id': 'module_rbac', 'label': 'Système RBAC'},
    ];

    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: modules.map((m) {
            final isSelected = _selectedModuleFilter == m['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(m['label']!, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: DioufyColors.primary.withOpacity(0.15),
                checkmarkColor: DioufyColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? DioufyColors.primary : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  setState(() => _selectedModuleFilter = m['id']!);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPermissionsList() {
    final filtered = AppPermission.allPermissions.where((p) {
      if (_selectedModuleFilter == 'all') return true;
      return p.moduleId == _selectedModuleFilter;
    }).toList();

    final activePermissions = _rolePermissionsMap[_selectedRole]!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final perm = filtered[index];
        final isGranted = activePermissions.contains(perm.id);
        final isLocked = perm.category == PermissionCategory.systemLocked &&
            _selectedRole == AppRole.superAdmin;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildCategoryBadge(perm.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              perm.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: DioufyColors.primaryDark,
                              ),
                            ),
                          ),
                          if (perm.isDangerous)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Sensible',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        perm.description,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${perm.id} • Module: ${perm.moduleId}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLocked)
                  const Tooltip(
                    message: 'Permission vitale du Super Admin (Inaliénable)',
                    child: Icon(Icons.lock, color: DioufyColors.coral, size: 24),
                  )
                else
                  Switch.adaptive(
                    value: isGranted,
                    activeColor: DioufyColors.emerald,
                    onChanged: (val) => _togglePermission(perm.id, perm),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBadge(PermissionCategory category) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (category) {
      case PermissionCategory.systemLocked:
        bg = DioufyColors.coral.withOpacity(0.15);
        fg = DioufyColors.coral;
        label = 'Système';
        icon = Icons.lock_outline;
        break;
      case PermissionCategory.platformDelegated:
        bg = DioufyColors.accent.withOpacity(0.15);
        fg = DioufyColors.accent;
        label = 'Plateforme';
        icon = Icons.hub_outlined;
        break;
      case PermissionCategory.gieLocal:
        bg = DioufyColors.emerald.withOpacity(0.15);
        fg = DioufyColors.emerald;
        label = 'GIE';
        icon = Icons.location_city_outlined;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }

  static void showCreateUserDialog(BuildContext context) {
    final currentRole = AuthService.instance.currentRole;
    final eligibleRoles = AppRole.values.where((r) => currentRole.canManageRole(r)).toList();

    if (eligibleRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre rôle actuel ne vous autorise pas à provisionner de nouveaux comptes.', style: TextStyle(fontSize: 15)),
          backgroundColor: DioufyColors.coral,
        ),
      );
      return;
    }

    AppRole selectedRole = eligibleRoles.contains(AppRole.driver)
        ? AppRole.driver
        : eligibleRoles.first;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Dioufy@${Random().nextInt(9000) + 1000}!');
    final vehicleCtrl = TextEditingController();
    final stationCtrl = TextEditingController();
    String? selectedGieId = 'gie_thies';
    bool isSubmitting = false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isGieRelated = selectedRole == AppRole.gieAdmin ||
              selectedRole == AppRole.gieAgent ||
              selectedRole == AppRole.driver ||
              selectedRole == AppRole.coxeur;

          final isDriver = selectedRole == AppRole.driver;
          final isCoxeur = selectedRole == AppRole.coxeur;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1, color: Color(0xFF059669), size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Créer un Compte Utilisateur',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DioufyColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Provisionnement officiel RBAC Dioufy-TS',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Choix du Rôle
                      const Text(
                        'Rôle du Compte à Créer :',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<AppRole>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.shield_outlined, color: Color(0xFF1D4ED8), size: 22),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: eligibleRoles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(
                              role.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Nom complet
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nom et Prénom *',
                          hintText: 'Ex: Amadou Fall',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Veuillez renseigner le nom complet' : null,
                      ),
                      const SizedBox(height: 14),

                      // 3. Téléphone sénégalais (+221)
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Téléphone WhatsApp / Appel *',
                          hintText: '77 000 00 00',
                          prefixText: '+221 ',
                          prefixIcon: const Icon(Icons.phone_android, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) => (v == null || v.trim().length < 8) ? 'Numéro de téléphone requis' : null,
                      ),
                      const SizedBox(height: 14),

                      // 4. Email
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Adresse E-mail',
                          hintText: 'agent@dioufy-ts.sn',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Champs conditionnels GIE
                      if (isGieRelated) ...[
                        const Text(
                          'Coopérative GIE de Rattachement :',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedGieId,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF059669), size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'gie_thies', child: Text('GIE Thiès Transport Express')),
                            DropdownMenuItem(value: 'gie_ndiambour', child: Text('GIE Ndiambour Louga')),
                            DropdownMenuItem(value: 'gie_dakar_bm', child: Text('GIE Gare Baux Maraîchers Dakar')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedGieId = val);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 6. Si Chauffeur : Véhicule / Permis
                      if (isDriver) ...[
                        TextFormField(
                          controller: vehicleCtrl,
                          decoration: InputDecoration(
                            labelText: 'Immatriculation du Véhicule / Bus',
                            hintText: 'Ex: DK-1234-AZ',
                            prefixIcon: const Icon(Icons.directions_bus, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 7. Si Coxeur : Gare d'affectation
                      if (isCoxeur) ...[
                        TextFormField(
                          controller: stationCtrl,
                          decoration: InputDecoration(
                            labelText: 'Gare / Quai d\'affectation',
                            hintText: 'Ex: Quai Thiès - Baux Maraîchers',
                            prefixIcon: const Icon(Icons.storefront, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 8. Mot de passe initial
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: passCtrl,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe temporaire *',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 caractères' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                passCtrl.text = 'Dioufy@${Random().nextInt(9000) + 1000}!';
                              });
                            },
                            child: const Text('Générer', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Colors.black54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);

                        final res = await AuthService.instance.createManagedUser(
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          password: passCtrl.text.trim(),
                          role: selectedRole,
                          organizationId: isGieRelated ? selectedGieId : null,
                        );

                        setDialogState(() => isSubmitting = false);
                        if (!context.mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Compte [${selectedRole.name}] créé avec succès pour ${nameCtrl.text.trim()} !'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ?? 'Erreur lors de la création.'),
                              backgroundColor: DioufyColors.coral,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('CRÉER LE COMPTE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
