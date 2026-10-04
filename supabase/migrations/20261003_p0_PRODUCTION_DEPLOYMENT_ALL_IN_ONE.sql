-- ==============================================================================
-- 🚀 DIOUFY-TS : SCRIPT MAÎTRE DE DÉPLOIEMENT PRODUCTION (ALL-IN-ONE)
-- Fichier : 20261003_p0_PRODUCTION_DEPLOYMENT_ALL_IN_ONE.sql
-- Date : 03 Octobre 2026
-- 
-- Ce script est 100% idempotent et purge les anciennes signatures de fonctions
-- pour éviter toute collision PostgreSQL 42P13 sur les noms de paramètres.
-- ==============================================================================

BEGIN;

-- 0. PURGE DES ANCIENNES SIGNATURES DE FONCTIONS
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID);
DROP FUNCTION IF EXISTS public.confirm_payment(UUID, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS public.sell_ticket_cash(UUID, TEXT, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.refund_or_cancel_booking(UUID, TEXT);
DROP FUNCTION IF EXISTS public.refund_or_cancel_booking(UUID);


-- 1. TABLES MATÉRIELLES & INFRASTRUCTURE
-- ------------------------------------------------------------------------------

-- 1.0 Tables Fondatrices des Organisations & Adhésions GIE
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    license_number TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_organizations_code ON public.organizations(code);

CREATE TABLE IF NOT EXISTS public.organization_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    role_id TEXT NOT NULL DEFAULT 'gie_agent',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_org UNIQUE (user_id, organization_id)
);

CREATE INDEX IF NOT EXISTS idx_org_memberships_user ON public.organization_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org ON public.organization_memberships(organization_id);


-- 1.1 Flotte de Véhicules
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

-- 1.2 Gares Routières Officielles
CREATE TABLE IF NOT EXISTS public.stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    city TEXT NOT NULL,
    region TEXT NOT NULL DEFAULT 'Dakar',
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stations_city ON public.stations(city);

-- 1.3 Sessions de Caisse Quai & Chauffeur
CREATE TABLE IF NOT EXISTS public.cash_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    operator_id UUID NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    operator_role TEXT NOT NULL CHECK (operator_role IN ('coxeur', 'driver', 'gie_agent')),
    opening_balance INT NOT NULL DEFAULT 0,
    closing_balance INT,
    total_revenue INT NOT NULL DEFAULT 0,
    ticket_count INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'verified')),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cash_sessions_org ON public.cash_sessions(organization_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_op ON public.cash_sessions(operator_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_status ON public.cash_sessions(status);

-- 1.4 Table : public.app_releases (Gouvernance et Versioning Applicatif)
CREATE TABLE IF NOT EXISTS public.app_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'all')),
    latest_version TEXT NOT NULL,
    minimum_supported_version TEXT NOT NULL,
    update_required BOOLEAN NOT NULL DEFAULT false,
    store_url TEXT,
    release_notes TEXT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_releases_platform ON public.app_releases(platform);
ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_releases_public_read" ON public.app_releases;
CREATE POLICY "app_releases_public_read" ON public.app_releases
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "app_releases_service_role" ON public.app_releases;
CREATE POLICY "app_releases_service_role" ON public.app_releases
    FOR ALL TO service_role USING (true) WITH CHECK (true);

INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
SELECT 'android', '1.0.0', '1.0.0', false, 'https://play.google.com/store/apps/details?id=com.dioufy.transport', 'Version initiale Dioufy-TS'
WHERE NOT EXISTS (SELECT 1 FROM public.app_releases WHERE platform = 'android');

INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
SELECT 'web', '1.0.0', '1.0.0', false, 'https://dioufy.sn', 'PWA Dioufy-TS'
WHERE NOT EXISTS (SELECT 1 FROM public.app_releases WHERE platform = 'web');

INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
SELECT 'all', '1.0.0', '1.0.0', false, 'https://dioufy.sn', 'Version globale Dioufy-TS'
WHERE NOT EXISTS (SELECT 1 FROM public.app_releases WHERE platform = 'all');



-- 2. EXTENSION DES TABLES TRIPS, BOOKINGS & TICKETS
-- ------------------------------------------------------------------------------

-- Synchronisation préalable des agences historiques vers public.organizations si la table existe
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'agencies'
    ) THEN
        INSERT INTO public.organizations (id, code, name, metadata, created_at, updated_at)
        SELECT 
            a.id, 
            'ORG_' || REPLACE(a.id::text, '-', ''),
            COALESCE(NULLIF(TRIM(a.name), ''), 'Agence ' || SUBSTRING(a.id::text FROM 1 FOR 8)),
            COALESCE(a.metadata, '{}'::jsonb),
            COALESCE(a.created_at, NOW()),
            NOW()
        FROM public.agencies a
        WHERE NOT EXISTS (
            SELECT 1 FROM public.organizations o WHERE o.id = a.id
        )
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- Création défensive d'entrées d'organisation pour tout agency_id orphelin existant dans trips
INSERT INTO public.organizations (id, code, name, is_active, metadata, created_at, updated_at)
SELECT DISTINCT 
    t.agency_id,
    'ORG_' || REPLACE(t.agency_id::text, '-', ''),
    'Organisation ' || SUBSTRING(t.agency_id::text FROM 1 FOR 8),
    TRUE,
    '{"auto_migrated_from_trips": true}'::jsonb,
    NOW(),
    NOW()
FROM public.trips t
WHERE t.agency_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM public.organizations o WHERE o.id = t.agency_id
  )
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS departure_station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS arrival_station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS coxeur_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS commission_rate_platform NUMERIC(5,2) DEFAULT 5.00,
    ADD COLUMN IF NOT EXISTS commission_rate_driver NUMERIC(5,2) DEFAULT 7.00,
    ADD COLUMN IF NOT EXISTS commission_rate_coxeur NUMERIC(5,2) DEFAULT 3.00;

-- Rétrocompatibilité : synchroniser organization_id à partir de agency_id avec vérification stricte de clé étrangère
UPDATE public.trips 
SET organization_id = agency_id 
WHERE organization_id IS NULL 
  AND agency_id IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM public.organizations o WHERE o.id = public.trips.agency_id
  );

CREATE INDEX IF NOT EXISTS idx_trips_org ON public.trips(organization_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON public.trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_vehicle ON public.trips(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_trips_coxeur ON public.trips(coxeur_id);

-- Extension de public.bookings
ALTER TABLE public.bookings
    ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS passenger_name TEXT,
    ADD COLUMN IF NOT EXISTS passenger_phone TEXT;

-- Extension de public.tickets
ALTER TABLE public.tickets
    ADD COLUMN IF NOT EXISTS composted_at TIMESTAMPTZ;


-- 3. TABLE TICKET_COMMISSIONS (JOURNAL FINANCIER IMMUABLE)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ticket_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
    payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    coxeur_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    gross_amount NUMERIC(12,2) NOT NULL,
    platform_fee NUMERIC(12,2) NOT NULL,
    gie_share NUMERIC(12,2) NOT NULL,
    driver_share NUMERIC(12,2) NOT NULL,
    coxeur_share NUMERIC(12,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'allocated' CHECK (status IN ('allocated', 'settled', 'refunded', 'disputed')),
    notes TEXT,
    refund_reason TEXT,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_commission_booking UNIQUE (booking_id)
);

CREATE INDEX IF NOT EXISTS idx_commissions_org ON public.ticket_commissions(organization_id);
CREATE INDEX IF NOT EXISTS idx_commissions_driver ON public.ticket_commissions(driver_id);
CREATE INDEX IF NOT EXISTS idx_commissions_coxeur ON public.ticket_commissions(coxeur_id);
CREATE INDEX IF NOT EXISTS idx_commissions_trip ON public.ticket_commissions(trip_id);


-- 4. CONFIRM_PAYMENT : VALIDATION FINANCIÈRE ATOMIQUE SÉCURISÉE (FAIL-CLOSED)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_payment(
    p_booking_id UUID,
    p_provider TEXT DEFAULT 'Wave',
    p_provider_ref TEXT DEFAULT NULL,
    p_amount INTEGER DEFAULT 0,
    p_ticket_signature TEXT DEFAULT '',
    p_coxeur_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_jwt_role TEXT;
    v_is_service_role BOOLEAN;
    v_booking RECORD;
    v_payment_id UUID;
    v_idempotency_key TEXT;
    v_ticket_id UUID;
    v_gross NUMERIC(12,2);
    v_rate_platform NUMERIC(5,2);
    v_rate_driver NUMERIC(5,2);
    v_rate_coxeur NUMERIC(5,2);
    v_platform_fee NUMERIC(12,2);
    v_driver_share NUMERIC(12,2);
    v_coxeur_share NUMERIC(12,2);
    v_gie_share NUMERIC(12,2);
    v_driver_id UUID;
    v_coxeur_id UUID;
    v_org_id UUID;
BEGIN
    v_jwt_role := COALESCE(current_setting('request.jwt.claim.role', true), '');
    v_is_service_role := (v_jwt_role = 'service_role');

    -- Blocage strict des appels directs clients
    IF v_jwt_role <> '' AND NOT v_is_service_role THEN
        RAISE EXCEPTION 'Accès refusé : la confirmation de paiement requiert une clé service_role serveur après validation prestataire.';
    END IF;

    -- Verrouillage de la réservation
    SELECT b.*, 
           t.price AS trip_price, 
           t.id AS t_id, 
           t.driver_id AS t_driver, 
           t.coxeur_id AS t_coxeur,
           COALESCE(t.organization_id, t.agency_id) AS t_org,
           t.commission_rate_platform AS t_rate_platform,
           t.commission_rate_driver AS t_rate_driver,
           t.commission_rate_coxeur AS t_rate_coxeur
    INTO v_booking
    FROM public.bookings b
    LEFT JOIN public.trips t ON t.id = b.trip_id
    WHERE b.id = p_booking_id
    FOR UPDATE OF b;

    IF v_booking.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservation introuvable.');
    END IF;

    -- Idempotence
    IF v_booking.status = 'paid' THEN
        SELECT id INTO v_payment_id FROM public.payments WHERE booking_id = p_booking_id LIMIT 1;
        SELECT id INTO v_ticket_id FROM public.tickets WHERE booking_id = p_booking_id LIMIT 1;
        RETURN jsonb_build_object(
            'success', true,
            'booking_id', p_booking_id,
            'payment_id', v_payment_id,
            'ticket_id', v_ticket_id,
            'already_paid', true,
            'message', 'Réservation déjà confirmée et payée.'
        );
    END IF;

    -- Montant effectif garanti par le tarif officiel du trajet
    v_gross := GREATEST(COALESCE(v_booking.trip_price, 0), COALESCE(p_amount, 0));
    IF v_gross <= 0 THEN
        v_gross := COALESCE(p_amount, 0);
    END IF;

    v_idempotency_key := COALESCE(p_provider_ref, 'pay_' || p_booking_id::text);

    -- Enregistrement du paiement
    INSERT INTO public.payments (booking_id, amount, provider, provider_ref, status, idempotency_key)
    VALUES (p_booking_id, v_gross::integer, p_provider, p_provider_ref, 'successful', v_idempotency_key)
    ON CONFLICT (idempotency_key) DO UPDATE SET 
        status = 'successful',
        amount = EXCLUDED.amount
    RETURNING id INTO v_payment_id;

    IF v_payment_id IS NULL THEN
        SELECT id INTO v_payment_id FROM public.payments WHERE idempotency_key = v_idempotency_key;
    END IF;

    -- Mise à jour de la réservation
    UPDATE public.bookings 
    SET status = 'paid', paid_at = NOW() 
    WHERE id = p_booking_id;

    -- Sièges vendus
    UPDATE public.seats 
    SET status = 'sold', lock_until = NULL 
    WHERE locked_by = p_booking_id;

    -- Émission du billet
    INSERT INTO public.tickets (booking_id, payload, signature, issued_at)
    VALUES (
        p_booking_id,
        jsonb_build_object(
            'booking_id', p_booking_id,
            'payment_id', v_payment_id,
            'provider', p_provider,
            'provider_ref', p_provider_ref,
            'amount', v_gross,
            'issued_at', NOW()
        ),
        COALESCE(NULLIF(p_ticket_signature, ''), md5(p_booking_id::text || v_gross::text || NOW()::text)),
        NOW()
    )
    ON CONFLICT (booking_id) DO NOTHING
    RETURNING id INTO v_ticket_id;

    IF v_ticket_id IS NULL THEN
        SELECT id INTO v_ticket_id FROM public.tickets WHERE booking_id = p_booking_id;
    END IF;

    -- Ventilation des commissions
    v_rate_platform := COALESCE(v_booking.t_rate_platform, 5.00);
    v_rate_driver   := COALESCE(v_booking.t_rate_driver, 7.00);
    v_rate_coxeur   := COALESCE(v_booking.t_rate_coxeur, 3.00);

    v_platform_fee := round((v_gross * v_rate_platform) / 100.0, 2);
    IF v_platform_fee < 150.00 AND v_gross >= 1000.00 THEN
        v_platform_fee := 150.00;
    END IF;

    v_driver_share := round((v_gross * v_rate_driver) / 100.0, 2);
    v_coxeur_share := round((v_gross * v_rate_coxeur) / 100.0, 2);
    v_gie_share    := v_gross - v_platform_fee - v_driver_share - v_coxeur_share;

    v_driver_id := v_booking.t_driver;
    v_org_id    := v_booking.t_org;

    -- Sécurisation contre clés orphelines vers organizations & app_users
    IF v_org_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.organizations WHERE id = v_org_id) THEN
        v_org_id := NULL;
    END IF;
    IF v_driver_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.app_users WHERE id = v_driver_id) THEN
        v_driver_id := NULL;
    END IF;

    IF p_coxeur_id IS NOT NULL THEN
        v_coxeur_id := p_coxeur_id;
    ELSIF v_booking.t_coxeur IS NOT NULL THEN
        v_coxeur_id := v_booking.t_coxeur;
    ELSE
        v_coxeur_id := NULL;
    END IF;

    IF v_coxeur_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.app_users WHERE id = v_coxeur_id) THEN
        v_coxeur_id := NULL;
    END IF;

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
        v_coxeur_id,
        v_gross,
        v_platform_fee,
        v_gie_share,
        v_driver_share,
        v_coxeur_share,
        'allocated'
    )
    ON CONFLICT (booking_id) DO UPDATE SET
        payment_id   = EXCLUDED.payment_id,
        gross_amount = EXCLUDED.gross_amount,
        platform_fee = EXCLUDED.platform_fee,
        gie_share    = EXCLUDED.gie_share,
        driver_share = EXCLUDED.driver_share,
        coxeur_share = EXCLUDED.coxeur_share,
        coxeur_id    = COALESCE(EXCLUDED.coxeur_id, public.ticket_commissions.coxeur_id),
        driver_id    = COALESCE(EXCLUDED.driver_id, public.ticket_commissions.driver_id);

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
END;
$$;

-- Révocation stricte
REVOKE ALL ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) TO service_role;


-- 5. SELL_TICKET_CASH : VENTE EN ESPÈCES AU QUAI AVEC TRANSACTION ATOMIQUE
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
    v_effective_amount INT;
    v_ref TEXT;
    v_confirm_res JSONB;
BEGIN
    v_caller_id := auth.uid();

    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('coxeur', 'gie_admin', 'gie_agent', 'driver', 'super_admin', 'platform_admin') THEN
        RAISE EXCEPTION 'Accès refusé : seuls les agents de quai, coxeurs ou gestionnaires GIE peuvent émettre des billets en espèces.';
    END IF;

    SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id;
    IF v_trip.id IS NULL THEN
        RAISE EXCEPTION 'Trajet introuvable pour l émission du billet.';
    END IF;

    v_effective_amount := COALESCE(p_amount, v_trip.price);

    -- Disponibilité du siège
    SELECT id INTO v_seat_id 
    FROM public.seats 
    WHERE trip_id = p_trip_id AND seat_number = p_seat_number AND status = 'available'
    FOR UPDATE;

    IF v_seat_id IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.seats WHERE trip_id = p_trip_id AND seat_number = p_seat_number) THEN
            INSERT INTO public.seats (trip_id, seat_number, status)
            VALUES (p_trip_id, p_seat_number, 'available')
            RETURNING id INTO v_seat_id;
        ELSE
            RAISE EXCEPTION 'Le siège % n est plus disponible sur ce départ.', p_seat_number;
        END IF;
    END IF;

    v_booking_id := gen_random_uuid();
    v_ref := 'CASH-' || SUBSTRING(v_booking_id::text, 1, 8);

    INSERT INTO public.bookings (
        id, user_id, trip_id, seats, status, passenger_name, passenger_phone, agency_id, paid_at
    )
    VALUES (
        v_booking_id,
        v_caller_id,
        p_trip_id,
        jsonb_build_array(p_seat_number),
        'pending',
        p_passenger_name,
        p_passenger_phone,
        v_trip.agency_id,
        NOW()
    );

    UPDATE public.seats 
    SET status = 'locked', locked_by = v_booking_id, lock_until = NOW() + INTERVAL '10 minutes'
    WHERE id = v_seat_id;

    -- Validation financière
    v_confirm_res := public.confirm_payment(
        p_booking_id := v_booking_id,
        p_provider   := 'Espèces Guichet',
        p_provider_ref := v_ref,
        p_amount     := v_effective_amount,
        p_ticket_signature := '',
        p_coxeur_id  := v_caller_id
    );

    -- ROLLBACK ATOMIQUE OBLIGATOIRE SI ÉCHEC
    IF v_confirm_res IS NULL OR (v_confirm_res->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Échec de confirmation financière du billet en espèces : %', 
            COALESCE(v_confirm_res->>'message', 'Transaction rejetée');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'ticket_ref', v_ref,
        'seat_number', p_seat_number,
        'amount', v_effective_amount,
        'trip_id', p_trip_id,
        'passenger_name', p_passenger_name,
        'passenger_phone', p_passenger_phone,
        'message', 'Billet #' || v_ref || ' émis et encaissé avec succès pour ' || p_passenger_name || ' (Siège ' || p_seat_number || ').'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sell_ticket_cash(UUID, TEXT, TEXT, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sell_ticket_cash(UUID, TEXT, TEXT, TEXT, INTEGER) TO service_role;


-- 6. REFUND_OR_CANCEL_BOOKING : ANNULATION ET REMBOURSEMENT SÉCURISÉS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refund_or_cancel_booking(
    p_booking_id UUID,
    p_reason TEXT DEFAULT 'Annulation passager'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_booking RECORD;
BEGIN
    v_caller_id := auth.uid();
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF v_booking.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservation introuvable.');
    END IF;

    IF v_caller_id <> v_booking.user_id AND v_caller_role NOT IN ('super_admin', 'platform_admin', 'gie_admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non autorisé à annuler cette réservation.');
    END IF;

    IF v_booking.status IN ('cancelled', 'refunded') THEN
        RETURN jsonb_build_object('success', true, 'message', 'Réservation déjà annulée ou remboursée.');
    END IF;

    UPDATE public.seats
    SET status = 'available', locked_by = NULL, lock_until = NULL
    WHERE locked_by = p_booking_id;

    UPDATE public.bookings
    SET status = CASE WHEN v_booking.status = 'paid' THEN 'refunded' ELSE 'cancelled' END
    WHERE id = p_booking_id;

    UPDATE public.ticket_commissions
    SET status = 'refunded',
        refund_reason = p_reason,
        cancelled_at = NOW()
    WHERE booking_id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'status', CASE WHEN v_booking.status = 'paid' THEN 'refunded' ELSE 'cancelled' END,
        'message', 'Réservation annulée avec succès et sièges libérés.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.refund_or_cancel_booking(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refund_or_cancel_booking(UUID, TEXT) TO service_role;


-- 7. CREATE_MANAGED_USER RENFORCÉ (SIGNATURE & ORDRE CANONIQUE RESPECTÉS)
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
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_new_user_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    v_caller_id := auth.uid();
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;

    -- Contrôle d'autorisation
    IF v_caller_role NOT IN ('super_admin', 'platform_admin', 'gie_admin') THEN
        RAISE EXCEPTION 'Permissions insuffisantes pour créer des comptes gérés.';
    END IF;

    -- Organisation strictement obligatoire pour les rôles opérationnels
    IF p_role IN ('gie_admin', 'gie_agent', 'driver', 'coxeur', 'mechanic') AND p_organization_id IS NULL THEN
        RAISE EXCEPTION 'Le rattachement à une organisation GIE est obligatoire pour le rôle %.', p_role;
    END IF;

    -- Isolation : un gérant GIE ne peut créer que dans sa propre organisation
    IF v_caller_role = 'gie_admin' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.organization_memberships
            WHERE user_id = v_caller_id AND organization_id = p_organization_id AND is_active = TRUE
        ) THEN
            RAISE EXCEPTION 'Isolation GIE : vous ne pouvez créer des membres que pour votre propre coopérative.';
        END IF;
    END IF;

    v_new_user_id := gen_random_uuid();
    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    -- Insertion dans auth.users
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    )
    VALUES (
        v_new_user_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        p_email,
        v_encrypted_pw,
        NOW(),
        jsonb_build_object('provider', 'email', 'providers', array['email'], 'role', p_role),
        jsonb_build_object('full_name', p_full_name, 'phone', p_phone, 'role', p_role, 'organization_id', p_organization_id),
        NOW(),
        NOW()
    );

    -- Insertion ou mise à jour dans public.app_users
    INSERT INTO public.app_users (id, email, full_name, phone, role, created_at, updated_at)
    VALUES (v_new_user_id, p_email, p_full_name, p_phone, p_role, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        updated_at = NOW();

    -- Rattachement organisationnel
    IF p_organization_id IS NOT NULL THEN
        INSERT INTO public.organization_memberships (user_id, organization_id, role_id, is_active, created_at)
        VALUES (v_new_user_id, p_organization_id, p_role, TRUE, NOW())
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', p_email,
        'role', p_role,
        'organization_id', p_organization_id,
        'message', 'Compte créé avec succès et rattaché à son organisation.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO service_role;


-- 8. POLITIQUES DE SÉCURITÉ ROW LEVEL SECURITY (RLS) SANS FUITE
-- ------------------------------------------------------------------------------

-- 8.1 Table vehicles
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

-- 8.2 Table stations
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stations_read_policy" ON public.stations;
CREATE POLICY "stations_read_policy" ON public.stations
    FOR SELECT TO authenticated, anon
    USING (TRUE);

-- 8.3 Table cash_sessions
ALTER TABLE public.cash_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cash_sessions_select_policy" ON public.cash_sessions;
CREATE POLICY "cash_sessions_select_policy" ON public.cash_sessions
    FOR SELECT TO authenticated
    USING (
        operator_id = auth.uid()
        OR organization_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.is_active = TRUE
        )
        OR EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    );

-- 8.4 Table ticket_commissions (Cloisonnement strict)
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

-- 8.5 Table payments (Isolation étanche multi-tenant)
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select_policy" ON public.payments;
CREATE POLICY "payments_select_policy" ON public.payments
    FOR SELECT TO authenticated
    USING (
        -- Le voyageur voit ses propres paiements
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = payments.booking_id AND b.user_id = (SELECT auth.uid())
        )
        -- Administrateur plateforme
        OR EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
        -- Gestionnaire ou agent GIE : strictement limité aux trajets de son organisation
        OR EXISTS (
            SELECT 1 FROM public.bookings b
            JOIN public.trips t ON t.id = b.trip_id
            JOIN public.organization_memberships om ON (
                om.user_id = (SELECT auth.uid()) 
                AND (om.organization_id = COALESCE(t.organization_id, t.agency_id))
                AND om.role_id IN ('gie_admin', 'gie_agent')
                AND om.is_active = TRUE
            )
            WHERE b.id = payments.booking_id
        )
    );

DROP POLICY IF EXISTS "payments_service_role_write" ON public.payments;
CREATE POLICY "payments_service_role_write" ON public.payments
    FOR ALL TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);

COMMIT;
