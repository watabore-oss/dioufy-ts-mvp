import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Modèle d'une entrée de journal d'audit Dioufy-TS
class AuditEntry {
  final String id;
  final DateTime timestamp;
  final String? actorId;
  final String actorRole;
  final String? actorOrganizationId;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> details;

  const AuditEntry({
    required this.id,
    required this.timestamp,
    this.actorId,
    required this.actorRole,
    this.actorOrganizationId,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.details = const {},
  });

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    return AuditEntry(
      id: map['id']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      actorId: map['actor_id']?.toString(),
      actorRole: map['actor_role']?.toString() ?? 'unknown',
      actorOrganizationId: map['actor_organization_id']?.toString(),
      action: map['action']?.toString() ?? '',
      targetType: map['target_type']?.toString() ?? '',
      targetId: map['target_id']?.toString() ?? '',
      details: (map['details'] is Map<String, dynamic>)
          ? map['details'] as Map<String, dynamic>
          : {},
    );
  }
}

/// Service transverse de traçabilité immuable (AuditLog)
class AuditService {
  static final AuditService instance = AuditService._();
  AuditService._();

  final List<AuditEntry> _localBuffer = [];

  /// Enregistre une action sensible dans l'AuditLog
  Future<void> logAction({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic> details = const {},
  }) async {
    final user = AuthService.instance.currentUser;
    final role = user.role.id;
    final orgId = AuthService.instance.currentOrganizationId;

    final entry = AuditEntry(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      actorId: user.id.isNotEmpty ? user.id : null,
      actorRole: role,
      actorOrganizationId: orgId,
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
    );

    _localBuffer.insert(0, entry);
    if (_localBuffer.length > 200) _localBuffer.removeLast();

    try {
      final client = Supabase.instance.client;
      await client.from('audit_logs').insert({
        'actor_id': (user.id.isNotEmpty && user.id.length > 10) ? user.id : null,
        'actor_role': role,
        'actor_organization_id': (orgId != null && orgId.length > 10) ? orgId : null,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details,
      });
      debugPrint('[AuditLog] Événement tracé : $action sur $targetType #$targetId par $role');
    } catch (e) {
      debugPrint('[AuditLog] Enregistrement serveur différé (mode offline/local) : $e');
    }
  }

  /// Récupère la liste des derniers logs pour la Console d'administration
  Future<List<AuditEntry>> fetchRecentLogs({int limit = 50}) async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('audit_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);

      return res.map((item) => AuditEntry.fromMap(item)).toList();
    } catch (e) {
      debugPrint('[AuditLog] Lecture distante indisponible, affichage buffer local : $e');
    }
    return List.unmodifiable(_localBuffer);
  }
}
