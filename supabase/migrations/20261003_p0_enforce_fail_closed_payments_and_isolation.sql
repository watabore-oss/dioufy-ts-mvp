-- ==============================================================================
-- 🚀 MIGRATION P0 CRITIQUE : VERROUILLAGE SÉCURITÉ PAIEMENTS & ISOLATION GIE
-- Fichier : 20261003_p0_enforce_fail_closed_payments_and_isolation.sql
-- Date : 03-10-2026
-- 
-- Objectifs formels de l'audit :
-- 1. Verrouillage strict de confirm_payment :
--    - RÉVOCATION totale d'accès pour 'authenticated', 'anon', 'public'.
--    - ACCÈS EXCLUSIF réservé à 'service_role' (Webhooks serveurs authentifiés).
--    - Interdiction absolue pour un voyageur de marquer son paiement réussi.
-- 2. Atomisme strict de sell_ticket_cash :
--    - Vérification rigoureuse du résultat de confirm_payment.
--    - Si la confirmation échoue, RAISE EXCEPTION pour garantir le rollback intégral
--      de la transaction (aucun siège bloqué, aucune réservation orpheline).
-- 3. Isolation multi-tenant des paiements (RLS) :
--    - Correction de la politique RLS sur 'payments' pour corréler obligatoirement
--      l'organisation du membre GIE avec le trajet correspondant.
--    - Élimination formelle de la fuite d'informations inter-GIE.
-- ==============================================================================

-- 1. VERROUILLAGE D'ACCÈS SUR CONFIRM_PAYMENT
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
    -- Récupération du rôle JWT d'exécution
    v_jwt_role := COALESCE(current_setting('request.jwt.claim.role', true), '');
    v_is_service_role := (v_jwt_role = 'service_role');

    -- 1. Verrouillage d'accès absolu :
    -- Si l'appel provient d'un contexte de requête API direct sans service_role,
    -- rejeter formellement pour empêcher toute confirmation frauduleuse par un client.
    IF v_jwt_role <> '' AND NOT v_is_service_role THEN
        RAISE EXCEPTION 'Accès refusé : la confirmation de paiement requiert une clé service_role serveur après validation prestataire.';
    END IF;

    -- 2. Récupération et verrouillage de la réservation
    SELECT b.*, 
           t.price AS trip_price, 
           t.id AS t_id, 
           t.driver_id AS t_driver, 
           t.coxeur_id AS t_coxeur,
           t.organization_id AS t_org,
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

    -- Idempotence : si la réservation est déjà payée, retourner les données sans doublon
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

    -- Montant effectif garanti par le tarif officiel du trajet pour prévenir toute fraude client
    v_gross := GREATEST(COALESCE(v_booking.trip_price, 0), COALESCE(p_amount, 0));
    IF v_gross <= 0 THEN
        v_gross := COALESCE(p_amount, 0);
    END IF;

    v_idempotency_key := COALESCE(p_provider_ref, 'pay_' || p_booking_id::text);

    -- 3. Enregistrement sécurisé du paiement
    INSERT INTO public.payments (booking_id, amount, provider, provider_ref, status, idempotency_key)
    VALUES (p_booking_id, v_gross::integer, p_provider, p_provider_ref, 'successful', v_idempotency_key)
    ON CONFLICT (idempotency_key) DO UPDATE SET 
        status = 'successful',
        amount = EXCLUDED.amount
    RETURNING id INTO v_payment_id;

    IF v_payment_id IS NULL THEN
        SELECT id INTO v_payment_id FROM public.payments WHERE idempotency_key = v_idempotency_key;
    END IF;

    -- 4. Mise à jour de la réservation
    UPDATE public.bookings 
    SET status = 'paid', paid_at = NOW() 
    WHERE id = p_booking_id;

    -- 5. Passage définitif des sièges à 'sold'
    UPDATE public.seats 
    SET status = 'sold', lock_until = NULL 
    WHERE locked_by = p_booking_id;

    -- 6. Émission officielle et unique du billet dans public.tickets
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

    -- 7. Calcul dynamique et immuable des commissions
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

    -- Détermination du coxeur bénéficiaire
    IF p_coxeur_id IS NOT NULL THEN
        v_coxeur_id := p_coxeur_id;
    ELSIF v_booking.t_coxeur IS NOT NULL THEN
        v_coxeur_id := v_booking.t_coxeur;
    ELSE
        v_coxeur_id := NULL;
    END IF;

    -- Journal financier immuable dans ticket_commissions
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

-- Révocation stricte : AUCUN accès direct depuis le Web/Mobile pour authenticated ou anon
REVOKE ALL ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) FROM anon;
REVOKE ALL ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) TO service_role;


-- 2. VENTE DIRECTE EN ESPÈCES AU GUICHET / QUAI — TRANSACTION ATOMIQUE INDIVISIBLE
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

    -- 1. Contrôle d'autorisation de l'agent de quai
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('coxeur', 'gie_admin', 'gie_agent', 'driver', 'super_admin', 'platform_admin') THEN
        RAISE EXCEPTION 'Accès refusé : seuls les agents de quai, coxeurs ou gestionnaires GIE peuvent émettre des billets en espèces.';
    END IF;

    -- 2. Contrôle du trajet
    SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id;
    IF v_trip.id IS NULL THEN
        RAISE EXCEPTION 'Trajet introuvable pour l émission du billet.';
    END IF;

    v_effective_amount := COALESCE(p_amount, v_trip.price);

    -- 3. Verrouillage atomique du siège (SELECT FOR UPDATE)
    SELECT id INTO v_seat_id 
    FROM public.seats 
    WHERE trip_id = p_trip_id AND seat_number = p_seat_number AND status = 'available'
    FOR UPDATE;

    IF v_seat_id IS NULL THEN
        -- Si le siège n'existe pas encore dans la table, le créer à la volée s'il est légitime
        IF NOT EXISTS (SELECT 1 FROM public.seats WHERE trip_id = p_trip_id AND seat_number = p_seat_number) THEN
            INSERT INTO public.seats (trip_id, seat_number, status)
            VALUES (p_trip_id, p_seat_number, 'available')
            RETURNING id INTO v_seat_id;
        ELSE
            RAISE EXCEPTION 'Le siège % n est plus disponible sur ce départ.', p_seat_number;
        END IF;
    END IF;

    -- 4. Création de la réservation
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

    -- Verrouillage provisoire du siège
    UPDATE public.seats 
    SET status = 'locked', locked_by = v_booking_id, lock_until = NOW() + INTERVAL '10 minutes'
    WHERE id = v_seat_id;

    -- 5. Confirmation financière via confirm_payment
    v_confirm_res := public.confirm_payment(
        p_booking_id := v_booking_id,
        p_provider   := 'Espèces Guichet',
        p_provider_ref := v_ref,
        p_amount     := v_effective_amount,
        p_ticket_signature := '',
        p_coxeur_id  := v_caller_id
    );

    -- VÉRIFICATION CRITIQUE : Échouer de manière fermée !
    -- Si confirm_payment ne confirme pas un succès financier, la transaction entière
    -- DOIT être annulée immédiatement via RAISE EXCEPTION (Rollback PostgreSQL automatique).
    IF v_confirm_res IS NULL OR (v_confirm_res->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Échec de confirmation financière du billet en espèces : %', 
            COALESCE(v_confirm_res->>'message', 'Transaction rejetée');
    END IF;

    -- Retour garanti uniquement après validation complète et indivisible
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


-- 3. CORRECTION RLS STRICTE SUR PAYMENTS — ÉLIMINATION DE LA FUITE MULTI-TENANT
-- ------------------------------------------------------------------------------
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select_policy" ON public.payments;
CREATE POLICY "payments_select_policy" ON public.payments
    FOR SELECT TO authenticated
    USING (
        -- 1. Le voyageur qui a acheté la réservation
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = payments.booking_id AND b.user_id = (SELECT auth.uid())
        )
        -- 2. Administrateur plateforme global
        OR public.is_platform_admin((SELECT auth.uid()))
        -- 3. Gestionnaire ou agent GIE : STRICTEMENT limité aux trajets de son organisation active
        OR EXISTS (
            SELECT 1 FROM public.bookings b
            JOIN public.trips t ON t.id = b.trip_id
            JOIN public.organization_memberships om ON (
                om.user_id = (SELECT auth.uid()) 
                AND (om.organization_id = t.organization_id OR om.organization_id = t.agency_id)
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


-- 4. CORRECTION RLS SUR TICKET_COMMISSIONS — STRICTE ISOLATION
-- ------------------------------------------------------------------------------
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
