import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_flags/feature_flag_service.dart';
import '../core/permissions/rbac_service.dart';
import '../services/payment_config_service.dart';
import '../services/trip_management_service.dart';
import '../services/auth_service.dart';
import 'module_registry.dart';
import '../modules/booking/booking_module.dart';
import '../modules/ticketing/ticketing_module.dart';
import '../modules/payments/payments_module.dart';
import '../modules/commissions/commissions_module.dart';
import '../modules/fleet/fleet_module.dart';
import '../modules/garage_assistance/garage_assistance_module.dart';

/// Initialisation sécurisée et modulaire de l'application Dioufy-TS
class AppBootstrap {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialisation Supabase sécurisée (tolérante aux coupures réseau)
    try {
      await Supabase.initialize(
        url: 'https://yrarlatdoulyfyjpqzlp.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlyYXJsYXRkb3VseWZ5anBxemxwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0MTg2NjgsImV4cCI6MjA4Nzk5NDY2OH0.OTg9l-nIRyffeUqkTG6DKhPquB7dPPj0_70FwWQXszM',
      );
    } catch (e) {
      debugPrint('Mode offline / Initialisation Supabase en arrière-plan : $e');
    }

    // 2. Initialiser le cache local des Feature Flags (instantané)
    await FeatureFlagService.instance.initialize();

    // 3. Initialiser le service d'autorisation contextuelle RBAC
    await RbacService.instance.initialize();

    // 4. Initialiser les passerelles de paiement (Wave 774691379, PayDunya, Flutterwave, PayTech, etc.)
    await PaymentConfigService.instance.initialize();

    // 5. Initialiser la gestion des trajets et tarification FCFA
    await TripManagementService.instance.initialize();

    // 6. Initialiser le service d'authentification et session utilisateur (écoute Supabase Auth active)
    await AuthService.instance.initialize();

    // 7. Enregistrer tous les modules compilés
    ModuleRegistry.instance.register(BookingModule());
    ModuleRegistry.instance.register(TicketingModule());
    ModuleRegistry.instance.register(PaymentsModule());
    ModuleRegistry.instance.register(CommissionsModule());
    ModuleRegistry.instance.register(FleetModule());
    ModuleRegistry.instance.register(GarageAssistanceModule());

    // 8. Initialisation en arrière-plan des modules disponibles
    await ModuleRegistry.instance.initializeAll();
  }
}
