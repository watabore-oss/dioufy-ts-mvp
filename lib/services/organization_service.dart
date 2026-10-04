import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Modèle représentatif d'une Coopérative GIE partenaire (Dioufy-TS)
class GieOrganization {
  final String id;
  final String name;
  final String code;
  final String? contactPhone;
  final String? contactEmail;
  final String? licenseNumber;
  final bool isActive;
  final DateTime createdAt;
  final int vehicleCount;

  const GieOrganization({
    required this.id,
    required this.name,
    required this.code,
    this.contactPhone,
    this.contactEmail,
    this.licenseNumber,
    this.isActive = true,
    required this.createdAt,
    this.vehicleCount = 0,
  });

  GieOrganization copyWith({
    String? name,
    String? code,
    String? contactPhone,
    String? contactEmail,
    String? licenseNumber,
    bool? isActive,
    int? vehicleCount,
  }) {
    return GieOrganization(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      vehicleCount: vehicleCount ?? this.vehicleCount,
    );
  }

  factory GieOrganization.fromMap(Map<String, dynamic> map, {int vehicleCount = 0}) {
    return GieOrganization(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'GIE Sans Nom',
      code: map['code']?.toString() ?? '',
      contactPhone: map['contact_phone']?.toString(),
      contactEmail: map['contact_email']?.toString(),
      licenseNumber: map['license_number']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      vehicleCount: vehicleCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'license_number': licenseNumber,
      'is_active': isActive,
    };
  }
}

/// Service officiel de gouvernance des Coopératives GIE
/// SOURCE DE VÉRITÉ UNIQUE : Supabase table `public.organizations`.
class OrganizationService extends ChangeNotifier {
  static OrganizationService? _instance;
  final List<GieOrganization> _organizations = [];
  bool _isLoading = false;

  OrganizationService._();

  static OrganizationService get instance {
    _instance ??= OrganizationService._();
    return _instance!;
  }

  List<GieOrganization> get organizations => List.unmodifiable(_organizations);
  List<GieOrganization> get activeOrganizations =>
      _organizations.where((o) => o.isActive).toList();
  bool get isLoading => _isLoading;

  /// Chargement initial des GIE réels depuis Supabase
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final isSuperAdmin = AuthService.instance.isSuperAdmin;

      // 1. Récupération des organisations
      var query = client.from('organizations').select('*');
      if (!isSuperAdmin) {
        query = query.eq('is_active', true);
      }

      final res = await query.order('name', ascending: true);
      final List list = res as List;

      // 2. Comptage optionnel des véhicules associés
      Map<String, int> countsByOrg = {};
      try {
        final vehiclesRes = await client.from('vehicles').select('organization_id');
        for (var v in vehiclesRes as List) {
          final orgId = v['organization_id']?.toString();
          if (orgId != null) {
            countsByOrg[orgId] = (countsByOrg[orgId] ?? 0) + 1;
          }
        }
      } catch (_) {}

      _organizations.clear();
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final orgId = map['id']?.toString() ?? '';
        _organizations.add(GieOrganization.fromMap(map, vehicleCount: countsByOrg[orgId] ?? 0));
      }
    } catch (e) {
      debugPrint('[OrganizationService] Erreur lecture des organisations : $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Création souveraine d'une nouvelle coopérative GIE
  Future<GieOrganization> createOrganization({
    required String name,
    required String code,
    String? contactPhone,
    String? contactEmail,
    String? licenseNumber,
  }) async {
    final client = Supabase.instance.client;
    final cleanName = name.trim();
    final cleanCode = code.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

    // 1. Tenter via la RPC sécurisée create_organization
    try {
      final rpcRes = await client.rpc('create_organization', params: {
        'p_name': cleanName,
        'p_code': cleanCode,
        'p_contact_phone': contactPhone?.trim(),
        'p_contact_email': contactEmail?.trim(),
        'p_license_number': licenseNumber?.trim(),
      });

      if (rpcRes is Map && rpcRes['id'] != null) {
        final newOrg = GieOrganization(
          id: rpcRes['id'].toString(),
          name: cleanName,
          code: cleanCode,
          contactPhone: contactPhone?.trim(),
          contactEmail: contactEmail?.trim(),
          licenseNumber: licenseNumber?.trim(),
          isActive: true,
          createdAt: DateTime.now(),
        );
        _organizations.insert(0, newOrg);
        notifyListeners();
        return newOrg;
      }
    } catch (e) {
      debugPrint('[OrganizationService] RPC create_organization non dispo ou erreur, essai direct : $e');
    }

    // 2. Insertion directe de secours via client si les droits le permettent
    try {
      final insertData = {
        'name': cleanName,
        'code': cleanCode,
        if (contactPhone != null && contactPhone.trim().isNotEmpty)
          'contact_phone': contactPhone.trim(),
        if (contactEmail != null && contactEmail.trim().isNotEmpty)
          'contact_email': contactEmail.trim(),
        if (licenseNumber != null && licenseNumber.trim().isNotEmpty)
          'license_number': licenseNumber.trim(),
        'is_active': true,
      };

      final res = await client.from('organizations').insert(insertData).select().single();
      final newOrg = GieOrganization.fromMap(res);
      _organizations.insert(0, newOrg);
      notifyListeners();
      return newOrg;
    } catch (e) {
      debugPrint('[OrganizationService] Erreur création GIE direct Supabase : $e');
      rethrow;
    }
  }

  /// Activer ou désactiver une coopérative GIE
  Future<void> toggleOrganizationStatus(String organizationId, bool isActive) async {
    final client = Supabase.instance.client;

    // 1. Tenter via RPC
    try {
      await client.rpc('update_organization_status', params: {
        'p_organization_id': organizationId,
        'p_is_active': isActive,
      });
    } catch (_) {
      // 2. Fallback update direct
      await client
          .from('organizations')
          .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', organizationId);
    }

    final index = _organizations.indexWhere((o) => o.id == organizationId);
    if (index != -1) {
      _organizations[index] = _organizations[index].copyWith(isActive: isActive);
      notifyListeners();
    }
  }

  GieOrganization? getById(String id) {
    try {
      return _organizations.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }
}
