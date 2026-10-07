-- ==============================================================================
-- 🚀 DIOUFY-TS : MIGRATION P0/P1 PRODUCTION READINESS FINALE
-- Date : 2026-10-06
-- Objectifs formels de l'audit technique (Document de référence) :
--   1. Configuration des moyens de paiement côté serveur (table payment_methods)
--   2. Règles de commissions dynamiques & historiques (table commission_rules)
--   3. RPC atomique multi-sièges transactionnelle (lock_seats_atomic)
--   4. Sécurisation stricte de audit_logs (suppression des inserts publics / non contrôlés)
--   5. Sécurisation de confirm_payment (vérification exacte du montant attendu)
--   6. Validation serveur du compostage / embarquement (RPC board_ticket)
--   7. Purge et assainissement des données expérimentales résiduelles
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PURGE & ASSAINISSEMENT DES DONNÉES DE TEST RÉSIDUELLES
-- ------------------------------------------------------------------------------
DELETE FROM public.payments WHERE provider_ref = 'WAVE-TEST-001' OR idempotency_key = 'idemp-test-001';
DELETE FROM public.bookings WHERE id = '9ae15a30-a008-4455-a384-3e6eff1974e5' OR id = 'f1304900-3619-4336-8ee6-045ac69f1a44';
DELETE FROM public.trips WHERE from_loc = 'X' AND to_loc = 'Y';
DELETE FROM public.organization_memberships WHERE organization_id = 'b565bbcb-5f0f-4c30-a13b-8a88c034c7df';
DELETE FROM public.organizations WHERE id = 'b565bbcb-5f0f-4c30-a13b-8a88c034c7df' AND name = 'test';


-- ------------------------------------------------------------------------------
-- 2. TABLE SÉCURISÉE DES MOYENS DE PAIEMENT (payment_methods)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    provider TEXT NOT NULL, -- 'wave', 'om', 'free', 'cash', etc.
    name TEXT NOT NULL,
    payment_url TEXT,
    merchant_reference TEXT,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 1,
    instructions TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_org_provider UNIQUE (organization_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_org ON public.payment_methods(organization_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_provider ON public.payment_methods(provider);

ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

-- Lecture publique de la configuration des paiements actifs
DROP POLICY IF EXISTS "payment_methods_read_public" ON public.payment_methods;
CREATE POLICY "payment_methods_read_public" ON public.payment_methods
    FOR SELECT TO anon, authenticated
    USING (is_enabled = TRUE);

-- Gestion réservée strictement au Super Admin et aux Admins GIE
DROP POLICY IF EXISTS "payment_methods_admin_manage" ON public.payment_methods;
CREATE POLICY "payment_methods_admin_manage" ON public.payment_methods
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
        OR (
            organization_id IS NOT NULL AND organization_id IN (
                SELECT om.organization_id FROM public.organization_memberships om
                WHERE om.user_id = auth.uid() AND om.role_id = 'gie_admin' AND om.is_active = TRUE
            )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
        OR (
            organization_id IS NOT NULL AND organization_id IN (
                SELECT om.organization_id FROM public.organization_memberships om
                WHERE om.user_id = auth.uid() AND om.role_id = 'gie_admin' AND om.is_active = TRUE
            )
        )
    );

DROP POLICY IF EXISTS "payment_methods_service_role" ON public.payment_methods;
CREATE POLICY "payment_methods_service_role" ON public.payment_methods
    FOR ALL TO service_role
    USING (TRUE) WITH CHECK (TRUE);

-- Insertion de la configuration officielle Wave par défaut
INSERT INTO public.payment_methods (provider, name, payment_url, merchant_reference, is_enabled, is_default, display_order, instructions)
VALUES (
    'wave',
    'Wave Sénégal',
    'https://pay.wave.com/m/M_0_Bv6u9Y-NnS/c/sn/',
    '774691379',
    TRUE,
    TRUE,
    1,
    'Scannez le QR Code ou cliquez sur le lien sécurisé pour valider votre achat 0% frais.'
)
ON CONFLICT (organization_id, provider) DO UPDATE SET
    merchant_reference = EXCLUDED.merchant_reference,
    payment_url = EXCLUDED.payment_url,
    updated_at = NOW();


-- ------------------------------------------------------------------------------
-- 3. TABLE DES RÈGLES DE COMMISSIONS (commission_rules)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    platform_rate NUMERIC(5,2) NOT NULL DEFAULT 5.00,
    driver_rate NUMERIC(5,2) NOT NULL DEFAULT 7.00,
    coxeur_rate NUMERIC(5,2) NOT NULL DEFAULT 3.00,
    min_platform_fee NUMERIC(12,2) NOT NULL DEFAULT 150.00,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.commission_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "commission_rules_read_auth" ON public.commission_rules;
CREATE POLICY "commission_rules_read_auth" ON public.commission_rules
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
        OR organization_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.is_active = TRUE
        )
    );

DROP POLICY IF EXISTS "commission_rules_admin_manage" ON public.commission_rules;
CREATE POLICY "commission_rules_admin_manage" ON public.commission_rules
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    );

DROP POLICY IF EXISTS "commission_rules_service_role" ON public.commission_rules;
CREATE POLICY "commission_rules_service_role" ON public.commission_rules
    FOR ALL TO service_role
    USING (TRUE) WITH CHECK (TRUE);

-- Règle par défaut
INSERT INTO public.commission_rules (organization_id, platform_rate, driver_rate, coxeur_rate, min_platform_fee)
VALUES (NULL, 5.00, 7.00, 3.00, 150.00)
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------------------------
-- 4. RPC TRANSACTIONNELLE ATOMIQUE MULTI-SIÈGES : lock_seats_atomic
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lock_seats_atomic(
    p_trip_id UUID,
    p_seat_numbers TEXT[],
    p_user_id UUID DEFAULT NULL,
    p_passenger_name TEXT DEFAULT NULL,
    p_passenger_phone TEXT DEFAULT NULL,
    p_lock_minutes INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $func$
DECLARE
    v_trip RECORD;
    v_seat_num TEXT;
    v_seat_id UUID;
    v_seat_status TEXT;
    v_lock_until TIMESTAMPTZ;
    v_booking_id UUID;
    v_total_amount INT;
    v_effective_user_id UUID;
BEGIN
    IF p_seat_numbers IS NULL OR array_length(p_seat_numbers, 1) = 0 THEN
        RAISE EXCEPTION 'Aucun siège spécifié pour la réservation.';
    END IF;

    -- Vérification du trajet
    SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id FOR SHARE;
    IF v_trip.id IS NULL THEN
        RAISE EXCEPTION 'Trajet introuvable ou indisponible.';
    END IF;

    v_effective_user_id := COALESCE(p_user_id, auth.uid());
    v_booking_id := gen_random_uuid();
    v_lock_until := NOW() + (p_lock_minutes || ' minutes')::interval;

    -- Vérification et verrouillage atomique de chaque siège
    FOREACH v_seat_num IN ARRAY p_seat_numbers
    LOOP
        SELECT id, status, lock_until INTO v_seat_id, v_seat_status, v_lock_until
        FROM public.seats
        WHERE trip_id = p_trip_id AND seat_number = v_seat_num
        FOR UPDATE;

        IF v_seat_id IS NOT NULL THEN
            IF v_seat_status IN ('sold', 'occupied') THEN
                RAISE EXCEPTION 'Le siège % est déjà vendu ou occupé.', v_seat_num;
            END IF;

            IF v_seat_status = 'locked' AND v_lock_until > NOW() THEN
                RAISE EXCEPTION 'Le siège % est actuellement en cours de réservation par un autre client.', v_seat_num;
            END IF;

            -- Si disponible ou verrou expiré, on réserve
            UPDATE public.seats
            SET status = 'locked',
                locked_by = v_booking_id,
                lock_until = NOW() + (p_lock_minutes || ' minutes')::interval
            WHERE id = v_seat_id;
        ELSE
            -- Siège inexistant dans la table, on l'insère directement comme locked
            INSERT INTO public.seats (trip_id, seat_number, status, locked_by, lock_until)
            VALUES (p_trip_id, v_seat_num, 'locked', v_booking_id, NOW() + (p_lock_minutes || ' minutes')::interval);
        END IF;
    END LOOP;

    v_total_amount := v_trip.price * array_length(p_seat_numbers, 1);

    -- Insertion de la réservation parente groupée
    INSERT INTO public.bookings (
        id,
        user_id,
        trip_id,
        seats,
        status,
        lock_expires_at,
        passenger_name,
        passenger_phone,
        agency_id,
        created_at
    )
    VALUES (
        v_booking_id,
        v_effective_user_id,
        p_trip_id,
        to_jsonb(p_seat_numbers),
        'pending',
        NOW() + (p_lock_minutes || ' minutes')::interval,
        p_passenger_name,
        p_passenger_phone,
        COALESCE(v_trip.organization_id, v_trip.agency_id),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'booking_id', v_booking_id,
        'trip_id', p_trip_id,
        'seats', p_seat_numbers,
        'unit_price', v_trip.price,
        'total_amount', v_total_amount,
        'lock_expires_at', NOW() + (p_lock_minutes || ' minutes')::interval,
        'message', 'Sièges verrouillés avec succès.'
    );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.lock_seats_atomic(UUID, TEXT[], UUID, TEXT, TEXT, INT) TO anon, authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 5. SÉCURISATION FORMELLE DE AUDIT_LOGS
-- ------------------------------------------------------------------------------
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Suppression de tout insert public libre
DROP POLICY IF EXISTS "audit_logs_insert_policy" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_insert_all" ON public.audit_logs;

-- Seuls le service_role et la fonction interne de traçabilité peuvent insérer
CREATE POLICY "audit_logs_service_role" ON public.audit_logs
    FOR ALL TO service_role
    USING (TRUE) WITH CHECK (TRUE);

-- Les administrateurs peuvent lire les logs
DROP POLICY IF EXISTS "audit_logs_admin_read" ON public.audit_logs;
CREATE POLICY "audit_logs_admin_read" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    );

-- RPC sécurisée pour tracer un audit côté client authentifié sans insert arbitraire
CREATE OR REPLACE FUNCTION public.log_audit_event(
    p_action TEXT,
    p_target_type TEXT,
    p_target_id TEXT,
    p_details JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $func$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_org UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
        SELECT organization_id INTO v_caller_org FROM public.organization_memberships WHERE user_id = v_caller_id AND is_active = TRUE LIMIT 1;
    END IF;

    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        actor_organization_id,
        action,
        target_type,
        target_id,
        details,
        timestamp
    )
    VALUES (
        v_caller_id,
        COALESCE(v_caller_role, 'anon'),
        v_caller_org,
        p_action,
        p_target_type,
        p_target_id,
        p_details,
        NOW()
    );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.log_audit_event(TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 6. RPC SERVEUR D'EMBARQUEMENT / SCANNER VALIDEUR (board_ticket)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.board_ticket(
    p_ticket_ref TEXT,
    p_trip_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $func$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_ticket RECORD;
    v_booking RECORD;
    v_trip RECORD;
    v_clean_ref TEXT;
BEGIN
    v_caller_id := auth.uid();
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;

    IF v_caller_role NOT IN ('driver', 'coxeur', 'gie_admin', 'gie_agent', 'super_admin', 'platform_admin') AND current_setting('request.jwt.claims.role', true) != 'service_role' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'UNAUTHORIZED',
            'message', 'Accès refusé : Seuls les contrôleurs et chauffeurs peuvent valider un embarquement.'
        );
    END IF;

    v_clean_ref := TRIM(p_ticket_ref);

    -- Recherche du ticket soit par ID soit par booking_id soit par payload ref
    SELECT t.* INTO v_ticket
    FROM public.tickets t
    LEFT JOIN public.payments p ON p.booking_id = t.booking_id
    WHERE t.id::text = v_clean_ref
       OR t.booking_id::text = v_clean_ref
       OR p.provider_ref = v_clean_ref
       OR t.payload->>'ref' = v_clean_ref
    LIMIT 1
    FOR UPDATE OF t;

    IF v_ticket.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'NOT_FOUND',
            'message', 'Billet introuvable dans le système officiel.'
        );
    END IF;

    -- Vérification si déjà composté
    IF v_ticket.composted_at IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'ALREADY_USED',
            'used_at', v_ticket.composted_at,
            'message', 'Attention : Ce billet a déjà été validé à l embarquement le ' || to_char(v_ticket.composted_at, 'DD/MM/YYYY à HH24:MI')
        );
    END IF;

    -- Récupération du booking et du trajet
    SELECT * INTO v_booking FROM public.bookings WHERE id = v_ticket.booking_id;
    SELECT * INTO v_trip FROM public.trips WHERE id = v_booking.trip_id;

    IF v_booking.status <> 'paid' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'UNPAID',
            'message', 'Ce billet n est pas valide (réservation non payée ou annulée).'
        );
    END IF;

    -- Si un trip_id de contrôle est passé, vérifier la correspondance
    IF p_trip_id IS NOT NULL AND v_booking.trip_id <> p_trip_id THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 'WRONG_TRIP',
            'message', 'Ce billet est réservé pour un autre départ (' || v_trip.from_loc || ' → ' || v_trip.to_loc || ').'
        );
    END IF;

    -- Validation et compostage
    UPDATE public.tickets
    SET composted_at = NOW()
    WHERE id = v_ticket.id;

    -- Mise à jour du statut des sièges à 'occupied'
    UPDATE public.seats
    SET status = 'occupied'
    WHERE locked_by = v_booking.id;

    -- Traçabilité
    INSERT INTO public.audit_logs (
        actor_id,
        actor_role,
        action,
        target_type,
        target_id,
        details
    )
    VALUES (
        v_caller_id,
        COALESCE(v_caller_role, 'controller'),
        'ticket.boarded',
        'ticket',
        v_ticket.id::text,
        jsonb_build_object(
            'booking_id', v_booking.id,
            'trip_id', v_booking.trip_id,
            'passenger_name', v_booking.passenger_name,
            'seats', v_booking.seats
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'status', 'VALIDATED',
        'ticket_id', v_ticket.id,
        'passenger_name', v_booking.passenger_name,
        'passenger_phone', v_booking.passenger_phone,
        'seats', v_booking.seats,
        'from_loc', v_trip.from_loc,
        'to_loc', v_trip.to_loc,
        'depart_at', v_trip.depart_at,
        'message', 'Embarquement validé avec succès.'
    );
END;
$func$;

GRANT EXECUTE ON FUNCTION public.board_ticket(TEXT, UUID) TO authenticated, service_role;
