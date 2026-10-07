-- ==============================================================================
-- 🚀 MIGRATION P0 : CRÉATION COMPTES MULTI-RÔLES, BILLETERIE RÉELLE, 
-- FLOTTE GIE & PARTAGE DES REVENUS SANS DONNÉES FACTICES
-- Fichier : 20261003_p0_fix_create_managed_user_and_real_ticketing.sql
-- Date : 03-10-2026
-- 
-- Objectifs :
-- 1. Résolution définitive de l'erreur SQL de création de compte :
--    "column 'id' is of type uuid but expression is of type text"
--    (auth.identities.id attend un UUID et non un text casté).
-- 2. Création des tables de données réelles pour la flotte et gares :
--    - public.vehicles (flotte par GIE/Organisation)
--    - public.stations (gares routières et quais officiels)
-- 3. Extension des colonnes trips et bookings pour lier le chauffeur et le véhicule.
-- 4. Partage des revenus et ventilation financière par billet :
--    - public.ticket_commissions (répartition réelle GIE, chauffeur, coxeur, plateforme)
-- 5. RPC confirm_payment corrigée et accessible aux clients pour valider les billets.
-- 6. RPC sell_ticket_cash pour l'émission immédiate de billets payés en espèces au quai.
-- ==============================================================================

-- 1. TABLES STRUCTURELLES RÉELLES (Élimination des mocks GIE et Quai)
-- ------------------------------------------------------------------------------

-- 1.1 Table des Véhicules de Flotte GIE
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    plate_number TEXT NOT NULL UNIQUE,
    model TEXT NOT NULL,
    capacity INT NOT NULL DEFAULT 36 CHECK (capacity > 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'in_trip', 'maintenance', 'retired')),
    current_driver_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_org ON public.vehicles(organization_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_driver ON public.vehicles(current_driver_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON public.vehicles(status);

-- 1.2 Table des Gares Routières Officielles
CREATE TABLE IF NOT EXISTS public.stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    city TEXT NOT NULL,
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.stations 
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Insertion idempotente des gares sénégalaises principales
INSERT INTO public.stations (name, city, address)
VALUES
    ('Gare des Baux Maraîchers (Dakar)', 'Dakar', 'Pikine / Baux Maraîchers'),
    ('Gare Routière de Thiès', 'Thiès', 'Quartier Dixième, Thiès'),
    ('Gare Routière de Touba', 'Touba', 'Touba Mosquée / Entrée Ouest'),
    ('Gare Routière de Saint-Louis', 'Saint-Louis', 'Khor, Saint-Louis'),
    ('Gare Routière de Mbour', 'Mbour', 'Route Nationale 1, Mbour'),
    ('Gare Routière de Kaolack', 'Kaolack', 'RN1 / Entrée Sud, Kaolack'),
    ('Gare Routière de Ziguinchor', 'Ziguinchor', 'Boulevard 54, Ziguinchor')
ON CONFLICT (name) DO UPDATE SET
    city = EXCLUDED.city,
    address = EXCLUDED.address,
    is_active = TRUE;

-- 1.3 Extension des colonnes trips
ALTER TABLE public.trips 
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS station_departure_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS station_arrival_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'boarding', 'in_transit', 'completed', 'cancelled'));

-- 1.4 Extension des colonnes bookings
ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS passenger_name TEXT,
    ADD COLUMN IF NOT EXISTS passenger_phone TEXT,
    ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

-- 1.5 Table du Partage des Revenus (Bordereau financier par billet)
CREATE TABLE IF NOT EXISTS public.ticket_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
    payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    coxeur_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    gross_amount NUMERIC(12,2) NOT NULL, -- Montant total payé par le voyageur en FCFA
    platform_fee NUMERIC(12,2) NOT NULL DEFAULT 0.00, -- Frais de service Dioufy (ex: 3% ou min 150 FCFA)
    gie_share NUMERIC(12,2) NOT NULL DEFAULT 0.00, -- Revenu net Transporteur / GIE (ex: 87%)
    driver_share NUMERIC(12,2) NOT NULL DEFAULT 0.00, -- Commission Chauffeur (ex: 7%)
    coxeur_share NUMERIC(12,2) NOT NULL DEFAULT 0.00, -- Commission Coxeur / Régulateur de quai (ex: 3%)
    status TEXT NOT NULL DEFAULT 'allocated' CHECK (status IN ('allocated', 'settled', 'refunded')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_commissions_org ON public.ticket_commissions(organization_id);
CREATE INDEX IF NOT EXISTS idx_commissions_driver ON public.ticket_commissions(driver_id);
CREATE INDEX IF NOT EXISTS idx_commissions_coxeur ON public.ticket_commissions(coxeur_id);
CREATE INDEX IF NOT EXISTS idx_commissions_trip ON public.ticket_commissions(trip_id);

-- RLS sur ticket_commissions
ALTER TABLE public.ticket_commissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "commissions_read_policy" ON public.ticket_commissions;
CREATE POLICY "commissions_read_policy" ON public.ticket_commissions
    FOR SELECT TO authenticated
    USING (
        auth.uid() = driver_id
        OR auth.uid() = coxeur_id
        OR organization_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.is_active = TRUE
        )
        OR EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    );

-- RLS sur vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vehicles_select_policy" ON public.vehicles;
CREATE POLICY "vehicles_select_policy" ON public.vehicles
    FOR SELECT TO authenticated, anon
    USING (TRUE);

DROP POLICY IF EXISTS "vehicles_manage_policy" ON public.vehicles;
CREATE POLICY "vehicles_manage_policy" ON public.vehicles
    FOR ALL TO authenticated
    USING (
        organization_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.role_id IN ('gie_admin', 'gie_agent') AND om.is_active = TRUE
        )
        OR EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    );

-- RLS sur stations
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stations_read_all" ON public.stations;
CREATE POLICY "stations_read_all" ON public.stations
    FOR SELECT TO authenticated, anon
    USING (TRUE);

-- ------------------------------------------------------------------------------
-- 2. CORRECTION DÉFINITIVE DE CREATE_MANAGED_USER (Résolution du Bug P0 UUID)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_managed_user(
    p_email TEXT,
    p_phone TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role TEXT,
    p_organization_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, auth
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_org UUID;
    v_target_org UUID;
    v_target_level INT;
    v_caller_level INT;
    v_new_user_id UUID;
    v_clean_email TEXT;
    v_clean_phone TEXT;
    v_raw_phone TEXT;
    v_encrypted_password TEXT;
    v_sanitized_role TEXT := TRIM(p_role);
    v_provider TEXT;
    v_provider_id TEXT;
BEGIN
    -- Normalisation des alias historiques
    IF v_sanitized_role = 'controller' THEN
        v_sanitized_role := 'coxeur';
    END IF;

    -- A. Authentification de l'appelant
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Session expirée ou utilisateur non authentifié.');
    END IF;

    -- B. Rôle et organisation de l'appelant
    SELECT om.role_id, om.organization_id, COALESCE(sr.level, 99)
    INTO v_caller_role, v_caller_org, v_caller_level
    FROM public.organization_memberships om
    LEFT JOIN public.system_roles sr ON sr.id = om.role_id
    WHERE om.user_id = v_caller_id AND om.is_active = TRUE
    ORDER BY sr.level ASC
    LIMIT 1;

    IF v_caller_role IS NULL THEN
        SELECT u.role, u.organization_id, COALESCE(sr.level, 99)
        INTO v_caller_role, v_caller_org, v_caller_level
        FROM public.app_users u
        LEFT JOIN public.system_roles sr ON sr.id = u.role
        WHERE u.id = v_caller_id;
    END IF;

    IF v_caller_role IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Profil ou privilèges introuvables.');
    END IF;

    -- C. Contrôle de validité du rôle cible
    SELECT level INTO v_target_level FROM public.system_roles WHERE id = v_sanitized_role;
    IF v_target_level IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Rôle cible invalide : ' || COALESCE(v_sanitized_role, 'indéfini'));
    END IF;

    -- D. Cloisonnement Anti-Élévation de Privilèges
    IF v_caller_role = 'super_admin' THEN
        v_target_org := p_organization_id;
    ELSIF v_caller_role = 'platform_admin' THEN
        IF v_sanitized_role IN ('super_admin', 'platform_admin') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Le rôle Platform Admin ne peut pas provisionner d administrateurs système.');
        END IF;
        v_target_org := p_organization_id;
    ELSIF v_caller_role = 'gie_admin' THEN
        IF v_sanitized_role NOT IN ('gie_agent', 'driver', 'coxeur', 'mechanic') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Un gérant de GIE ne peut créer que des agents GIE, chauffeurs, coxeurs ou mécaniciens.');
        END IF;
        -- Règle stricte : Le GIE Admin force son organisation
        v_target_org := v_caller_org;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Votre rôle ne dispose pas de l autorisation de provisionner des comptes.');
    END IF;

    -- E. Validation du mot de passe
    IF p_password IS NULL OR LENGTH(TRIM(p_password)) < 6 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Le mot de passe initial doit contenir au minimum 6 caractères.');
    END IF;

    -- F. Nettoyage de l'e-mail et du numéro de téléphone
    v_clean_email := LOWER(NULLIF(TRIM(p_email), ''));
    v_raw_phone := REGEXP_REPLACE(COALESCE(p_phone, ''), '[^0-9+]', '', 'g');

    IF v_raw_phone <> '' THEN
        IF v_raw_phone LIKE '+%' THEN
            v_clean_phone := v_raw_phone;
        ELSIF v_raw_phone LIKE '221%' THEN
            v_clean_phone := '+' || v_raw_phone;
        ELSE
            v_clean_phone := '+221' || v_raw_phone;
        END IF;
    ELSE
        v_clean_phone := NULL;
    END IF;

    IF v_clean_email IS NULL AND v_clean_phone IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un e-mail ou un numéro de téléphone valide est obligatoire.');
    END IF;

    -- Déterminer provider et provider_id
    IF v_clean_email IS NOT NULL THEN
        v_provider := 'email';
        v_provider_id := v_clean_email;
    ELSE
        v_provider := 'phone';
        v_provider_id := v_clean_phone;
        -- Générer un alias e-mail technique unique pour le moteur GoTrue
        v_clean_email := 'user.' || REGEXP_REPLACE(v_clean_phone, '[^0-9]', '', 'g') || '@dioufy-ts.sn';
    END IF;

    -- G. Contrôle d'unicité explicite avec messages conviviaux
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un compte avec l e-mail "' || v_clean_email || '" existe déjà.');
    END IF;

    IF v_clean_phone IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE phone = v_clean_phone) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un compte avec le numéro "' || v_clean_phone || '" existe déjà.');
    END IF;

    -- H. Création de l'identité cryptographique
    v_new_user_id := gen_random_uuid();
    v_encrypted_password := extensions.crypt(p_password, extensions.gen_salt('bf', 10));

    -- I. Insertion officielle dans auth.users
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        phone,
        phone_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token,
        email_change_token_new,
        email_change,
        is_super_admin
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000'::uuid,
        v_new_user_id,
        'authenticated',
        'authenticated',
        v_clean_email,
        v_encrypted_password,
        NOW(),
        v_clean_phone,
        CASE WHEN v_clean_phone IS NOT NULL THEN NOW() ELSE NULL END,
        jsonb_build_object(
            'provider', v_provider,
            'providers', ARRAY[v_provider]
        ),
        jsonb_build_object(
            'full_name', p_full_name,
            'name', p_full_name,
            'role', v_sanitized_role,
            'email', v_clean_email,
            'phone', v_clean_phone,
            'email_verified', TRUE,
            'phone_verified', (v_clean_phone IS NOT NULL)
        ),
        NOW(),
        NOW(),
        '',
        '',
        '',
        '',
        FALSE
    );

    -- J. Insertion de la correspondance dans auth.identities
    -- ⚠️ ATTENTION : La colonne "id" de auth.identities est de type UUID dans Supabase !
    -- On passe impérativement un UUID valide (gen_random_uuid()) sans cast ::text.
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    )
    VALUES (
        gen_random_uuid(),
        v_new_user_id,
        jsonb_build_object(
            'sub', v_new_user_id::text,
            'email', v_clean_email,
            'phone', v_clean_phone
        ),
        v_provider,
        v_provider_id,
        NOW(),
        NOW(),
        NOW()
    );

    -- K. Synchronisation du profil métier dans public.app_users
    INSERT INTO public.app_users (
        id, email, phone, full_name, role, organization_id, is_active, created_at, updated_at
    )
    VALUES (
        v_new_user_id,
        v_clean_email,
        v_clean_phone,
        p_full_name,
        v_sanitized_role,
        v_target_org,
        TRUE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        phone = COALESCE(EXCLUDED.phone, public.app_users.phone),
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        organization_id = EXCLUDED.organization_id,
        is_active = TRUE,
        updated_at = NOW();

    -- L. Enregistrement de l'affectation organisationnelle
    DELETE FROM public.organization_memberships WHERE user_id = v_new_user_id;

    INSERT INTO public.organization_memberships (
        user_id, organization_id, role_id, is_active, created_at, updated_at
    )
    VALUES (
        v_new_user_id,
        v_target_org,
        v_sanitized_role,
        TRUE,
        NOW(),
        NOW()
    );

    -- M. Journal d'Audit Immuable
    INSERT INTO public.rbac_audit_logs (
        action, target_user_id, target_role_id, target_organization_id, performed_by, metadata
    )
    VALUES (
        'CREATE_MANAGED_USER',
        v_new_user_id,
        v_sanitized_role,
        v_target_org,
        v_caller_id,
        jsonb_build_object(
            'full_name', p_full_name,
            'email', v_clean_email,
            'phone', v_clean_phone,
            'role', v_sanitized_role,
            'organization_id', v_target_org,
            'created_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', v_clean_email,
        'phone', v_clean_phone,
        'role', v_sanitized_role,
        'message', 'Compte [' || v_sanitized_role || '] créé avec succès pour ' || p_full_name || '.'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur serveur : ' || SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. CONFIRM_PAYMENT AVEC VENTILATION DES COMMISSIONS RÉELLES
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_payment(
    p_booking_id UUID,
    p_provider TEXT DEFAULT 'Wave',
    p_provider_ref TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 0,
    p_ticket_signature TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_booking RECORD;
    v_trip RECORD;
    v_payment_id UUID;
    v_idempotency_key TEXT;
    v_ticket_id UUID;
    v_gross NUMERIC(12,2);
    v_platform_fee NUMERIC(12,2);
    v_gie_share NUMERIC(12,2);
    v_driver_share NUMERIC(12,2);
    v_coxeur_share NUMERIC(12,2);
    v_driver_id UUID;
    v_org_id UUID;
BEGIN
    v_caller_id := auth.uid();

    -- 1. Récupération et vérification du booking
    SELECT b.*, t.price as trip_price, t.id as t_id, t.driver_id as t_driver, t.organization_id as t_org
    INTO v_booking
    FROM public.bookings b
    LEFT JOIN public.trips t ON t.id = b.trip_id
    WHERE b.id = p_booking_id;

    IF v_booking.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservation introuvable.');
    END IF;

    -- Sécurité : Seul le titulaire, un agent/admin ou service_role peut confirmer
    IF v_caller_id IS NOT NULL AND v_booking.user_id IS NOT NULL AND v_caller_id <> v_booking.user_id THEN
        -- Vérifier si le caller est un rôle staff
        IF NOT EXISTS (
            SELECT 1 FROM public.app_users 
            WHERE id = v_caller_id AND role IN ('gie_admin', 'gie_agent', 'driver', 'coxeur', 'super_admin', 'platform_admin')
        ) THEN
            RETURN jsonb_build_object('success', false, 'message', 'Non autorisé à confirmer cette réservation.');
        END IF;
    END IF;

    v_idempotency_key := COALESCE(p_provider_ref, 'pay_' || p_booking_id::text);
    v_gross := GREATEST(COALESCE(p_amount, 0), COALESCE(v_booking.trip_price, 0));

    -- 2. Insérer le paiement de façon idempotente
    INSERT INTO public.payments (booking_id, amount, provider, provider_ref, status, idempotency_key)
    VALUES (p_booking_id, v_gross::integer, p_provider, p_provider_ref, 'successful', v_idempotency_key)
    ON CONFLICT (idempotency_key) DO UPDATE SET status = 'successful'
    RETURNING id INTO v_payment_id;

    IF v_payment_id IS NULL THEN
        SELECT id INTO v_payment_id FROM public.payments WHERE idempotency_key = v_idempotency_key;
    END IF;

    -- 3. Mettre à jour le booking à 'paid'
    UPDATE public.bookings 
    SET status = 'paid', paid_at = NOW() 
    WHERE id = p_booking_id;

    -- 4. Mettre à jour les sièges associés à 'sold'
    UPDATE public.seats 
    SET status = 'sold', lock_until = NULL 
    WHERE locked_by = p_booking_id;

    -- 5. Générer le billet officiel dans public.tickets si non existant
    INSERT INTO public.tickets (booking_id, payload, signature, issued_at)
    VALUES (
        p_booking_id,
        jsonb_build_object(
            'booking_id', p_booking_id,
            'payment_id', v_payment_id,
            'provider', p_provider,
            'amount', v_gross,
            'issued_at', NOW()
        ),
        COALESCE(NULLIF(p_ticket_signature, ''), md5(p_booking_id::text || v_gross::text)),
        NOW()
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_ticket_id;

    -- 6. Calcul bancaire et enregistrement du partage des revenus
    -- Règle économique standard Dioufy-TS :
    --   Plateforme : 5% (avec un minimum de 150 FCFA)
    --   Transporteur GIE : 85%
    --   Chauffeur : 7%
    --   Coxeur / Régulateur de quai : 3%
    v_platform_fee := round(v_gross * 0.05, 2);
    IF v_platform_fee < 150.00 AND v_gross > 500.00 THEN
        v_platform_fee := 150.00;
    END IF;

    v_driver_share := round(v_gross * 0.07, 2);
    v_coxeur_share := round(v_gross * 0.03, 2);
    v_gie_share := v_gross - v_platform_fee - v_driver_share - v_coxeur_share;

    v_driver_id := v_booking.t_driver;
    v_org_id := v_booking.t_org;

    INSERT INTO public.ticket_commissions (
        booking_id, payment_id, trip_id, organization_id, driver_id, coxeur_id,
        gross_amount, platform_fee, gie_share, driver_share, coxeur_share, status
    )
    VALUES (
        p_booking_id,
        v_payment_id,
        v_booking.trip_id,
        v_org_id,
        v_driver_id,
        v_caller_id, -- Agent qui a encaissé / régulateur
        v_gross,
        v_platform_fee,
        v_gie_share,
        v_driver_share,
        v_coxeur_share,
        'allocated'
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        payment_id = EXCLUDED.payment_id,
        gross_amount = EXCLUDED.gross_amount,
        platform_fee = EXCLUDED.platform_fee,
        gie_share = EXCLUDED.gie_share,
        driver_share = EXCLUDED.driver_share,
        coxeur_share = EXCLUDED.coxeur_share;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'payment_id', v_payment_id,
        'ticket_id', v_ticket_id,
        'gross_amount', v_gross,
        'commissions', jsonb_build_object(
            'platform_fee', v_platform_fee,
            'gie_share', v_gie_share,
            'driver_share', v_driver_share,
            'coxeur_share', v_coxeur_share
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur confirm_payment : ' || SQLERRM);
END;
$$;

-- Permissions pour confirm_payment : autoriser les utilisateurs connectés et le service_role
GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. VENTE DIRECTE DE BILLET EN ESPÈCES AU GUICHET / QUAI (sell_ticket_cash)
-- Permet à un coxeur ou agent GIE de vendre un billet réel sans passer par une passerelle externe
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sell_ticket_cash(
    p_trip_id UUID,
    p_seat_number TEXT,
    p_passenger_name TEXT,
    p_passenger_phone TEXT,
    p_amount INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_trip RECORD;
    v_seat_id UUID;
    v_booking_id UUID;
    v_payment_id UUID;
    v_effective_amount INT;
    v_ref TEXT;
    v_res JSONB;
BEGIN
    v_caller_id := auth.uid();

    -- 1. Vérification des autorisations de l'agent
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('coxeur', 'gie_admin', 'gie_agent', 'driver', 'super_admin', 'platform_admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Seuls les agents de quai, coxeurs ou gestionnaires peuvent encaisser un billet au guichet.');
    END IF;

    -- 2. Vérification du trajet
    SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id;
    IF v_trip.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Trajet introuvable.');
    END IF;

    v_effective_amount := COALESCE(p_amount, v_trip.price);

    -- 3. Vérification de disponibilité du siège
    SELECT id INTO v_seat_id 
    FROM public.seats 
    WHERE trip_id = p_trip_id AND seat_number = p_seat_number AND status = 'available'
    FOR UPDATE;

    IF v_seat_id IS NULL THEN
        -- Si le siège n'existe pas encore dans la table seats, on le crée
        IF NOT EXISTS (SELECT 1 FROM public.seats WHERE trip_id = p_trip_id AND seat_number = p_seat_number) THEN
            INSERT INTO public.seats (trip_id, seat_number, status)
            VALUES (p_trip_id, p_seat_number, 'available')
            RETURNING id INTO v_seat_id;
        ELSE
            RETURN jsonb_build_object('success', false, 'message', 'Le siège ' || p_seat_number || ' n est plus disponible.');
        END IF;
    END IF;

    -- 4. Création atomique de la réservation
    v_booking_id := gen_random_uuid();
    v_ref := 'CASH-' || SUBSTRING(v_booking_id::text, 1, 8);

    INSERT INTO public.bookings (
        id, user_id, trip_id, seats, status, passenger_name, passenger_phone, agency_id, paid_at
    )
    VALUES (
        v_booking_id,
        v_caller_id, -- Encaissé par l'agent
        p_trip_id,
        jsonb_build_array(p_seat_number),
        'paid',
        p_passenger_name,
        p_passenger_phone,
        v_trip.agency_id,
        NOW()
    );

    -- 5. Verrouiller et vendre le siège
    UPDATE public.seats 
    SET status = 'sold', locked_by = v_booking_id, lock_until = NULL 
    WHERE id = v_seat_id;

    -- 6. Confirmer le paiement et ventiler les commissions via confirm_payment
    v_res := public.confirm_payment(
        p_booking_id := v_booking_id,
        p_provider := 'Espèces Guichet',
        p_provider_ref := v_ref,
        p_amount := v_effective_amount
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'ticket_ref', v_ref,
        'seat_number', p_seat_number,
        'amount', v_effective_amount,
        'trip_id', p_trip_id,
        'passenger_name', p_passenger_name,
        'passenger_phone', p_passenger_phone,
        'message', 'Billet #' || v_ref || ' émis avec succès pour ' || p_passenger_name || ' (Siège ' || p_seat_number || ').'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur sell_ticket_cash : ' || SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sell_ticket_cash(UUID, TEXT, TEXT, TEXT, INTEGER) TO authenticated, service_role;
