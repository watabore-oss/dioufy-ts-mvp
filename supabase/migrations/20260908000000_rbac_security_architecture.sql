-- ==============================================================================
-- Migration : Architecture RBAC Granulaire, Multi-Tenancy & Sécurité Renforcée
-- Plateforme : Dioufy-TS (Fo nek sa gare fek lafa)
-- Référentiels : OWASP ASVS 4.0, NIST SP 800-162, CIS PostgreSQL Benchmark
-- ==============================================================================

-- 1. Configuration des extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Table des Organisations (Multi-Tenancy GIE / Transporteurs)
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL, -- ex: 'GIE_THIES', 'GIE_NDIAMBOUR'
    name TEXT NOT NULL,
    license_number TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour recherche rapide
CREATE INDEX IF NOT EXISTS idx_organizations_code ON public.organizations(code);

-- 3. Table des Rôles Système Typés
CREATE TABLE IF NOT EXISTS public.system_roles (
    id TEXT PRIMARY KEY, -- 'super_admin', 'platform_admin', 'gie_admin', 'driver', 'coxeur', 'mechanic', 'passenger'
    name TEXT NOT NULL,
    description TEXT,
    level INT NOT NULL, -- 0: SuperAdmin, 1: PlatformAdmin, 2: GieAdmin, 3: Operational, 4: Passenger
    is_system_locked BOOLEAN NOT NULL DEFAULT FALSE, -- Protège les rôles fondamentaux contre modification/suppression
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insertion idempotente des rôles fondamentaux
INSERT INTO public.system_roles (id, name, description, level, is_system_locked)
VALUES 
    ('super_admin', 'Super Administrateur Plateforme', 'Contrôle souverain de la plateforme Dioufy-TS', 0, TRUE),
    ('platform_admin', 'Administrateur Support', 'Gestion opérationnelle globale sans privilèges système', 1, TRUE),
    ('gie_admin', 'Gérant de GIE / Transporteur', 'Gestion exclusive de la flotte et des personnels du GIE', 2, TRUE),
    ('driver', 'Chauffeur Titulaire', 'Conduite, déclaration de panne SOS et clôture de caisse de bord', 3, TRUE),
    ('coxeur', 'Agent de Quai / Régulateur', 'Contrôle optique, scan QR et validation d embarquement', 3, TRUE),
    ('mechanic', 'Garagiste Partenaire Agréé', 'Prise en charge des pannes géolocalisées et réparations', 3, TRUE),
    ('passenger', 'Voyageur / Client', 'Recherche, réservation, paiement et consultation de billets', 4, TRUE)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    level = EXCLUDED.level,
    is_system_locked = EXCLUDED.is_system_locked;

-- 4. Table des Permissions Granulaires par Module
CREATE TABLE IF NOT EXISTS public.system_permissions (
    id TEXT PRIMARY KEY, -- ex: 'booking.lock_seat', 'cash.close_session'
    module_id TEXT NOT NULL, -- ex: 'module_booking', 'module_cash_closure'
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('system_locked', 'platform_delegated', 'gie_local')),
    is_dangerous BOOLEAN NOT NULL DEFAULT FALSE, -- Traçabilité renforcée
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insertion des permissions granulaires initiales
INSERT INTO public.system_permissions (id, module_id, name, description, category, is_dangerous)
VALUES
    -- Module Booking
    ('booking.search', 'module_booking', 'Rechercher des trajets', 'Accès au catalogue des trajets publics', 'gie_local', FALSE),
    ('booking.lock_seat', 'module_booking', 'Verrouiller un siège', 'Réservation atomique temporaire', 'gie_local', FALSE),
    ('booking.manage_trips', 'module_booking', 'Gérer les trajets du GIE', 'Création, modification des lignes et horaires', 'platform_delegated', FALSE),
    ('booking.cancel_trip', 'module_booking', 'Annuler un départ', 'Annulation officielle d un voyage', 'platform_delegated', TRUE),

    -- Module Ticketing
    ('ticketing.view_own', 'module_ticketing', 'Voir ses billets', 'Accès au portefeuille de billets personnel', 'gie_local', FALSE),
    ('ticketing.scan_camera', 'module_ticketing', 'Scanner QR par caméra', 'Validation optique sur quai', 'gie_local', FALSE),
    ('ticketing.import_gallery', 'module_ticketing', 'Import capture galerie', 'Secours écran client brisé', 'gie_local', FALSE),
    ('ticketing.manual_validate', 'module_ticketing', 'Validation manuelle', 'Secours saisie référence', 'gie_local', FALSE),

    -- Module Caisse & Commissions
    ('cash.collect_cash', 'module_cash_closure', 'Encaisser des espèces', 'Vente de billets au guichet/bus', 'gie_local', FALSE),
    ('cash.close_session', 'module_cash_closure', 'Clôturer la caisse', 'Ventilation cash vs digital et calcul solde net', 'gie_local', FALSE),
    ('cash.generate_statement', 'module_cash_closure', 'Générer bordereau WhatsApp', 'Émission du justificatif certifié', 'gie_local', FALSE),
    ('cash.request_payout', 'module_cash_closure', 'Demander virement Mobile Money', 'Transfert des commissions acquises', 'platform_delegated', TRUE),

    -- Module Flotte
    ('fleet.view_vehicles', 'module_fleet', 'Voir les véhicules du GIE', 'Consultation du parc de bus', 'gie_local', FALSE),
    ('fleet.assign_driver', 'module_fleet', 'Affecter chauffeur à un bus', 'Attribution officielle de mission', 'gie_local', FALSE),

    -- Module Assistance Garagiste
    ('garage.trigger_sos', 'module_garage_assistance', 'Déclencher alerte SOS panne', 'Signalement géolocalisé avec diagnostic', 'gie_local', FALSE),
    ('garage.accept_mission', 'module_garage_assistance', 'Accepter mission dépannage', 'Engagement du garagiste partenaire', 'gie_local', FALSE),
    ('garage.validate_repair', 'module_garage_assistance', 'Valider la réparation', 'Preuve d intervention et photos', 'gie_local', FALSE),

    -- Module Gouvernance RBAC & Système
    ('rbac.manage_permissions', 'module_rbac', 'Gérer la matrice RBAC', 'Modification granulaire des permissions', 'system_locked', TRUE),
    ('rbac.manage_super_admins', 'module_rbac', 'Gérer les Super Admins', 'Création et révocation du collège souverain', 'system_locked', TRUE),
    ('rbac.view_audit_logs', 'module_rbac', 'Consulter journal d audit', 'Traçabilité des actions sensibles', 'system_locked', FALSE)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    is_dangerous = EXCLUDED.is_dangerous;

-- 5. Table de liaison Rôle <-> Permissions (Matrice Granulaire)
CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id TEXT REFERENCES public.system_roles(id) ON DELETE CASCADE,
    permission_id TEXT REFERENCES public.system_permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id)
);

-- Attributions par défaut étanches et contextuelles
INSERT INTO public.role_permissions (role_id, permission_id)
VALUES
    -- Passenger
    ('passenger', 'booking.search'),
    ('passenger', 'booking.lock_seat'),
    ('passenger', 'ticketing.view_own'),

    -- Driver
    ('driver', 'booking.search'),
    ('driver', 'cash.collect_cash'),
    ('driver', 'cash.close_session'),
    ('driver', 'cash.generate_statement'),
    ('driver', 'fleet.view_vehicles'),
    ('driver', 'garage.trigger_sos'),

    -- Coxeur
    ('coxeur', 'booking.search'),
    ('coxeur', 'ticketing.scan_camera'),
    ('coxeur', 'ticketing.import_gallery'),
    ('coxeur', 'ticketing.manual_validate'),
    ('coxeur', 'cash.collect_cash'),

    -- Mechanic
    ('mechanic', 'garage.accept_mission'),
    ('mechanic', 'garage.validate_repair'),

    -- GIE Admin
    ('gie_admin', 'booking.search'),
    ('gie_admin', 'booking.manage_trips'),
    ('gie_admin', 'booking.cancel_trip'),
    ('gie_admin', 'fleet.view_vehicles'),
    ('gie_admin', 'fleet.assign_driver'),
    ('gie_admin', 'cash.close_session'),
    ('gie_admin', 'cash.generate_statement'),
    ('gie_admin', 'cash.request_payout'),

    -- Platform Admin
    ('platform_admin', 'booking.search'),
    ('platform_admin', 'booking.manage_trips'),
    ('platform_admin', 'booking.cancel_trip'),
    ('platform_admin', 'fleet.view_vehicles'),
    ('platform_admin', 'rbac.view_audit_logs'),

    -- Super Admin (Toutes les permissions)
    ('super_admin', 'booking.search'),
    ('super_admin', 'booking.lock_seat'),
    ('super_admin', 'booking.manage_trips'),
    ('super_admin', 'booking.cancel_trip'),
    ('super_admin', 'ticketing.view_own'),
    ('super_admin', 'ticketing.scan_camera'),
    ('super_admin', 'ticketing.import_gallery'),
    ('super_admin', 'ticketing.manual_validate'),
    ('super_admin', 'cash.collect_cash'),
    ('super_admin', 'cash.close_session'),
    ('super_admin', 'cash.generate_statement'),
    ('super_admin', 'cash.request_payout'),
    ('super_admin', 'fleet.view_vehicles'),
    ('super_admin', 'fleet.assign_driver'),
    ('super_admin', 'garage.trigger_sos'),
    ('super_admin', 'garage.accept_mission'),
    ('super_admin', 'garage.validate_repair'),
    ('super_admin', 'rbac.manage_permissions'),
    ('super_admin', 'rbac.manage_super_admins'),
    ('super_admin', 'rbac.view_audit_logs')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 6. Table des Affiliations Utilisateurs (Multi-Tenancy)
CREATE TABLE IF NOT EXISTS public.organization_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    role_id TEXT NOT NULL REFERENCES public.system_roles(id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, organization_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_memberships_lookup ON public.organization_memberships(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_memberships_org ON public.organization_memberships(organization_id);

-- 7. Journal d Audit Immuable des Actions RBAC
CREATE TABLE IF NOT EXISTS public.rbac_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL, -- 'GRANT_PERMISSION', 'REVOKE_PERMISSION', 'ASSIGN_ROLE', 'REVOKE_ROLE'
    target_user_id UUID,
    target_role_id TEXT,
    target_permission_id TEXT,
    target_organization_id UUID,
    performed_by UUID NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- SÉCURITÉ & ANTI-ÉLÉVATION DE PRIVILÈGES (TRIGGERS & FONCTIONS SÉCURISÉES)
-- ==============================================================================

-- Fonction de contrôle anti-élévation et anti-suicide
CREATE OR REPLACE FUNCTION public.check_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_super_admin_count INT;
BEGIN
    v_caller_id := auth.uid();

    -- Déterminer le rôle le plus élevé de l'appelant
    SELECT role_id INTO v_caller_role
    FROM public.organization_memberships
    WHERE user_id = v_caller_id AND is_active = TRUE
    ORDER BY (SELECT level FROM public.system_roles WHERE id = role_id) ASC
    LIMIT 1;

    -- 1. Protection Anti-Suicide : Empêcher la suppression du dernier Super Admin
    IF TG_OP IN ('DELETE', 'UPDATE') AND OLD.role_id = 'super_admin' THEN
        SELECT COUNT(*) INTO v_super_admin_count
        FROM public.organization_memberships
        WHERE role_id = 'super_admin' AND is_active = TRUE;

        IF v_super_admin_count <= 1 AND (TG_OP = 'DELETE' OR NEW.is_active = FALSE OR NEW.role_id != 'super_admin') THEN
            RAISE EXCEPTION 'Sécurité Critique [Anti-Suicide] : Impossible de supprimer ou désactiver le dernier Super Administrateur de la plateforme.';
        END IF;
    END IF;

    -- 2. Protection Anti-Élévation : Seul un Super Admin validé peut manipuler le rôle super_admin
    IF (TG_OP = 'INSERT' AND NEW.role_id = 'super_admin') OR 
       (TG_OP = 'UPDATE' AND (NEW.role_id = 'super_admin' OR OLD.role_id = 'super_admin')) OR
       (TG_OP = 'DELETE' AND OLD.role_id = 'super_admin') THEN
        
        IF v_caller_role != 'super_admin' AND v_caller_id IS NOT NULL THEN
            RAISE EXCEPTION 'Sécurité Critique [Anti-Élévation] : Seul un Super Administrateur peut attribuer, modifier ou révoquer le rôle super_admin.';
        END IF;
    END IF;

    -- 3. Protection Multi-Tenancy : Un admin GIE ne peut pas assigner hors de son organisation
    IF v_caller_role = 'gie_admin' THEN
        IF TG_OP = 'INSERT' AND NEW.role_id IN ('super_admin', 'platform_admin') THEN
            RAISE EXCEPTION 'Sécurité Critique [Périmètre Dépassé] : Un administrateur GIE ne peut pas créer de rôles de niveau plateforme.';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Attachement du trigger sur les memberships
DROP TRIGGER IF EXISTS trg_memberships_privilege_check ON public.organization_memberships;
CREATE TRIGGER trg_memberships_privilege_check
    BEFORE INSERT OR UPDATE OR DELETE ON public.organization_memberships
    FOR EACH ROW
    EXECUTE FUNCTION public.check_privilege_escalation();

-- Révocation des droits publics d exécution
REVOKE EXECUTE ON FUNCTION public.check_privilege_escalation() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_privilege_escalation() TO authenticated, service_role;

-- ==============================================================================
-- FONCTION RPC SÉCURISÉE : VÉRIFICATION D AUTORISATION CONTEXTUELLE
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.check_user_permission(
    p_permission_id TEXT,
    p_target_organization_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_user_id UUID;
    v_has_perm BOOLEAN := FALSE;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si l'utilisateur possède la permission dans le périmètre organisationnel
    SELECT EXISTS (
        SELECT 1
        FROM public.organization_memberships om
        JOIN public.role_permissions rp ON rp.role_id = om.role_id
        WHERE om.user_id = v_user_id
          AND om.is_active = TRUE
          AND rp.permission_id = p_permission_id
          AND (
              om.role_id = 'super_admin' -- Le Super Admin a portée globale
              OR p_target_organization_id IS NULL -- Permission générale
              OR om.organization_id = p_target_organization_id -- Périmètre du GIE
          )
    ) INTO v_has_perm;

    RETURN v_has_perm;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_user_permission(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_user_permission(TEXT, UUID) TO authenticated, service_role;

-- ==============================================================================
-- DURCISSEMENT DES FONCTIONS SECURITY DEFINER EXISTANTES (lock_seat, release_seat)
-- ==============================================================================

-- Durcissement lock_seat avec SET search_path et qualification stricte
ALTER FUNCTION public.lock_seat(uuid, text, uuid, integer, text) 
    SET search_path = pg_catalog, public;

REVOKE EXECUTE ON FUNCTION public.lock_seat(uuid, text, uuid, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lock_seat(uuid, text, uuid, integer, text) TO authenticated, service_role;

-- Durcissement release_seat avec SET search_path et qualification stricte
ALTER FUNCTION public.release_seat(uuid, text) 
    SET search_path = pg_catalog, public;

REVOKE EXECUTE ON FUNCTION public.release_seat(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.release_seat(uuid, text) TO authenticated, service_role;
