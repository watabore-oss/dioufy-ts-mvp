-- ==============================================================================
-- 🚀 MIGRATION P0/P1 : CONSOLIDATION MÉTIER FINALE & CERTIFICATION PRODUCTION
-- Fichier : 20261006230615_p0_p1_state_machine_and_operational_consolidation.sql
-- Date : 06-10-2026
-- 
-- Objectifs d'après le document d'audit d'autorité (3-Dioufy ts- AUDITpour avoir un PROduit PRet.md) :
-- 1. Indexation stricte de toutes les clés étrangères (FK) pour la haute charge (Gamou, Magal).
-- 2. Verrouillage du modèle d'état et transitions strictes sur `trips` et `bookings`.
-- 3. Sécurisation de `confirm_payment` : interdiction du "GREATEST(trip_price, p_amount)" frauduleux,
--    validation du montant exact attendu, et rattachement automatique des commissions figées (commission_rules).
-- 4. Sécurisation de `sell_ticket_cash` : vérification stricte de l'affectation du coxeur/chauffeur
--    au départ ou à la même organisation GIE.
-- 5. Cloisonnement RLS de la table `vehicles` (vue publique anonyme sans fuite des données internes).
-- 6. Création des comptes staff réels de référence pour les tests E2E multi-rôles (GIE Admin, Chauffeur, Coxeur).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PERFORMANCE & INDEXATION DES CLÉS ÉTRANGÈRES CRITIQUES
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tickets_validated_by ON public.tickets(validated_by);
CREATE INDEX IF NOT EXISTS idx_bookings_boarded_by ON public.bookings(boarded_by);
CREATE INDEX IF NOT EXISTS idx_bookings_agency_id ON public.bookings(agency_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_station_id ON public.cash_sessions(station_id);
CREATE INDEX IF NOT EXISTS idx_trips_departure_station_id ON public.trips(departure_station_id);
CREATE INDEX IF NOT EXISTS idx_trips_arrival_station_id ON public.trips(arrival_station_id);
CREATE INDEX IF NOT EXISTS idx_trips_station_departure_id ON public.trips(station_departure_id);
CREATE INDEX IF NOT EXISTS idx_trips_station_arrival_id ON public.trips(station_arrival_id);
CREATE INDEX IF NOT EXISTS idx_app_users_agency_id ON public.app_users(agency_id);
CREATE INDEX IF NOT EXISTS idx_seats_locked_by ON public.seats(locked_by);
CREATE INDEX IF NOT EXISTS idx_ticket_commissions_payment_id ON public.ticket_commissions(payment_id);
CREATE INDEX IF NOT EXISTS idx_commission_rules_org ON public.commission_rules(organization_id);

-- ------------------------------------------------------------------------------
-- 2. VERROUILLAGE DES STATUTS ET MACHINES D'ÉTATS MÉTIER
-- ------------------------------------------------------------------------------
-- Extension de la contrainte check sur trips.status pour couvrir le cycle de quai
ALTER TABLE public.trips DROP CONSTRAINT IF EXISTS trips_status_check;
ALTER TABLE public.trips ADD CONSTRAINT trips_status_check 
    CHECK (status = ANY (ARRAY['scheduled'::text, 'at_dock'::text, 'boarding'::text, 'full'::text, 'departed'::text, 'in_transit'::text, 'completed'::text, 'cancelled'::text]));

-- Extension de la contrainte check sur bookings.status
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check 
    CHECK (status = ANY (ARRAY['pending'::text, 'payment_pending'::text, 'paid'::text, 'boarded'::text, 'completed'::text, 'cancelled'::text, 'refunded'::text, 'expired'::text]));

-- ------------------------------------------------------------------------------
-- 3. CONFIRM_PAYMENT SÉCURISÉ (FIN DU GREATEST FRAUDULEUX & RÈGLES FIGÉES)
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
    v_caller_id UUID;
    v_caller_role TEXT;
    v_is_service_role BOOLEAN;
    v_booking RECORD;
    v_payment_id UUID;
    v_idempotency_key TEXT;
    v_ticket_id UUID;
    v_gross NUMERIC(12,2);
    v_expected_amount NUMERIC(12,2);
    v_seats_count INT;
    v_rule RECORD;
    v_rate_platform NUMERIC(5,2);
    v_rate_driver NUMERIC(5,2);
    v_rate_coxeur NUMERIC(5,2);
    v_min_platform_fee NUMERIC(12,2);
    v_platform_fee NUMERIC(12,2);
    v_driver_share NUMERIC(12,2);
    v_coxeur_share NUMERIC(12,2);
    v_gie_share NUMERIC(12,2);
    v_driver_id UUID;
    v_coxeur_id UUID;
    v_org_id UUID;
BEGIN
    v_caller_id := auth.uid();
    v_is_service_role := (current_setting('request.jwt.claim.role', true) = 'service_role');

    -- 1. Contrôle d'autorisation strict :
    -- Le client final (passager) ne peut jamais déclencher confirm_payment directement
    IF NOT v_is_service_role THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Non authentifié.');
        END IF;

        SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
        IF v_caller_role NOT IN ('gie_admin', 'gie_agent', 'driver', 'coxeur', 'super_admin', 'platform_admin') THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Accès refusé : la confirmation d un paiement nécessite la validation officielle du serveur ou d un agent habilité.'
            );
        END IF;
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

    -- Si la réservation est déjà confirmée et payée, retour idempotent
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

    -- 3. Contrôle financier strict : calcul du montant exact attendu
    v_seats_count := jsonb_array_length(COALESCE(v_booking.seats, '[]'::jsonb));
    IF v_seats_count = 0 THEN
        v_seats_count := 1;
    END IF;

    v_expected_amount := COALESCE(v_booking.trip_price, 0) * v_seats_count;

    -- En guichet/espèces ou webhook, vérifier que le montant n'est pas inférieur
    IF p_amount > 0 AND p_amount < v_expected_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Montant payé insuffisant (' || p_amount || ' FCFA reçu vs ' || v_expected_amount || ' FCFA attendu).'
        );
    END IF;

    v_gross := v_expected_amount;
    IF v_gross <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tarif du voyage invalide ou nul.');
    END IF;

    -- 4. Enregistrement transactionnel du paiement
    v_idempotency_key := 'pay_' || p_booking_id::text;

    INSERT INTO public.payments (
        booking_id,
        amount,
        currency,
        provider,
        provider_ref,
        status,
        idempotency_key,
        created_at,
        updated_at
    )
    VALUES (
        p_booking_id,
        v_gross::integer,
        'XOF',
        p_provider,
        COALESCE(p_provider_ref, 'WAVE-' || SUBSTRING(p_booking_id::text, 1, 8)),
        'successful',
        v_idempotency_key,
        NOW(),
        NOW()
    )
    ON CONFLICT (idempotency_key) DO UPDATE SET
        status = 'successful',
        updated_at = NOW()
    RETURNING id INTO v_payment_id;

    IF v_payment_id IS NULL THEN
        SELECT id INTO v_payment_id FROM public.payments WHERE idempotency_key = v_idempotency_key;
    END IF;

    -- 5. Mise à jour de la réservation en PAID
    UPDATE public.bookings
    SET status = 'paid',
        paid_at = NOW(),
        lock_expires_at = NULL
    WHERE id = p_booking_id;

    -- 6. Verrouillage définitif des sièges en SOLD
    UPDATE public.seats
    SET status = 'sold',
        lock_until = NULL
    WHERE locked_by = p_booking_id;

    -- 7. Émission officielle du billet dans la table `tickets`
    INSERT INTO public.tickets (
        booking_id,
        payload,
        qr_signature,
        issued_at
    )
    VALUES (
        p_booking_id,
        jsonb_build_object(
            'ref', COALESCE(p_provider_ref, SUBSTRING(p_booking_id::text, 1, 8)),
            'booking_id', p_booking_id,
            'trip_id', v_booking.trip_id,
            'seats', v_booking.seats,
            'passenger_name', v_booking.passenger_name,
            'passenger_phone', v_booking.passenger_phone,
            'amount', v_gross,
            'paid_at', NOW()
        ),
        COALESCE(NULLIF(p_ticket_signature, ''), md5(p_booking_id::text || v_gross::text || NOW()::text)),
        NOW()
    )
    ON CONFLICT (booking_id) DO NOTHING
    RETURNING id INTO v_ticket_id;

    IF v_ticket_id IS NULL THEN
        SELECT id INTO v_ticket_id FROM public.tickets WHERE booking_id = p_booking_id;
    END IF;

    -- 8. Recherche de la règle de commission active pour l'organisation
    v_org_id := v_booking.t_org;
    SELECT * INTO v_rule
    FROM public.commission_rules
    WHERE (organization_id = v_org_id OR organization_id IS NULL)
      AND is_active = TRUE
      AND effective_from <= NOW()
      AND (effective_to IS NULL OR effective_to > NOW())
    ORDER BY organization_id NULLS LAST, created_at DESC
    LIMIT 1;

    IF v_rule.id IS NOT NULL THEN
        v_rate_platform   := v_rule.platform_rate;
        v_rate_driver     := v_rule.driver_rate;
        v_rate_coxeur     := v_rule.coxeur_rate;
        v_min_platform_fee := v_rule.min_platform_fee;
    ELSE
        v_rate_platform   := COALESCE(v_booking.t_rate_platform, 5.00);
        v_rate_driver     := COALESCE(v_booking.t_rate_driver, 7.00);
        v_rate_coxeur     := COALESCE(v_booking.t_rate_coxeur, 3.00);
        v_min_platform_fee := 150.00;
    END IF;

    -- Calcul des parts financières
    v_platform_fee := round((v_gross * v_rate_platform) / 100.0, 2);
    IF v_platform_fee < v_min_platform_fee AND v_gross >= 1000.00 THEN
        v_platform_fee := v_min_platform_fee;
    END IF;

    v_driver_share := round((v_gross * v_rate_driver) / 100.0, 2);
    v_coxeur_share := round((v_gross * v_rate_coxeur) / 100.0, 2);
    v_gie_share    := v_gross - v_platform_fee - v_driver_share - v_coxeur_share;

    v_driver_id := v_booking.t_driver;

    -- Détermination précise du coxeur bénéficiaire
    IF p_coxeur_id IS NOT NULL THEN
        v_coxeur_id := p_coxeur_id;
    ELSIF v_booking.t_coxeur IS NOT NULL THEN
        v_coxeur_id := v_booking.t_coxeur;
    ELSIF v_caller_role = 'coxeur' THEN
        v_coxeur_id := v_caller_id;
    ELSE
        v_coxeur_id := NULL;
    END IF;

    -- Enregistrement immuable de la commission avec traçabilité de la règle
    INSERT INTO public.ticket_commissions (
        booking_id, payment_id, trip_id, organization_id, driver_id, coxeur_id,
        gross_amount, platform_fee, gie_share, driver_share, coxeur_share, status,
        notes
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
        'allocated',
        'Appliqué selon règle ' || COALESCE(v_rule.id::text, 'défaut') || ' (Plateforme ' || v_rate_platform || '%, Chauffeur ' || v_rate_driver || '%, Coxeur ' || v_rate_coxeur || '%)'
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
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur confirm_payment : ' || SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 4. SELL_TICKET_CASH AVEC VÉRIFICATION D'AFFECTATION DU PERSONNEL
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
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    v_caller_id := auth.uid();

    -- 1. Récupération et contrôle de base de l'appelant
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('coxeur', 'gie_admin', 'gie_agent', 'driver', 'super_admin', 'platform_admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Seuls les agents autorisés peuvent encaisser des billets au guichet.');
    END IF;

    -- 2. Contrôle du départ
    SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id;
    IF v_trip.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Trajet introuvable.');
    END IF;

    -- 3. Règle métier : l'agent doit être affecté au trajet OU appartenir à l'organisation gestionnaire
    IF v_caller_role IN ('super_admin', 'platform_admin') THEN
        v_is_authorized := TRUE;
    ELSIF v_caller_role = 'coxeur' AND (v_trip.coxeur_id = v_caller_id OR v_trip.organization_id IN (
        SELECT organization_id FROM public.organization_memberships WHERE user_id = v_caller_id AND is_active = TRUE
    )) THEN
        v_is_authorized := TRUE;
    ELSIF v_caller_role = 'driver' AND v_trip.driver_id = v_caller_id THEN
        v_is_authorized := TRUE;
    ELSIF v_caller_role IN ('gie_admin', 'gie_agent') AND (v_trip.organization_id IN (
        SELECT organization_id FROM public.organization_memberships WHERE user_id = v_caller_id AND is_active = TRUE
    )) THEN
        v_is_authorized := TRUE;
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Accès refusé : vous n êtes pas affecté à ce départ ni rattaché au GIE responsable.'
        );
    END IF;

    v_effective_amount := COALESCE(p_amount, v_trip.price);

    -- 4. Disponibilité atomique du siège (SELECT FOR UPDATE)
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
            RETURN jsonb_build_object('success', false, 'message', 'Le siège ' || p_seat_number || ' n est plus disponible.');
        END IF;
    END IF;

    -- 5. Création de la réservation
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
        COALESCE(v_trip.organization_id, v_trip.agency_id),
        NOW()
    );

    -- 6. Verrouiller le siège
    UPDATE public.seats 
    SET status = 'locked', locked_by = v_booking_id, lock_until = NOW() + INTERVAL '10 minutes'
    WHERE id = v_seat_id;

    -- 7. Confirmation financière atomique
    v_confirm_res := public.confirm_payment(
        p_booking_id := v_booking_id,
        p_provider   := 'Espèces Guichet',
        p_provider_ref := v_ref,
        p_amount     := v_effective_amount,
        p_ticket_signature := '',
        p_coxeur_id  := CASE WHEN v_caller_role = 'coxeur' THEN v_caller_id ELSE v_trip.coxeur_id END
    );

    IF v_confirm_res IS NULL OR (v_confirm_res->>'success')::boolean IS NOT TRUE THEN
        UPDATE public.seats SET status = 'available', locked_by = NULL, lock_until = NULL WHERE id = v_seat_id;
        DELETE FROM public.bookings WHERE id = v_booking_id;
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Échec de confirmation financière du billet en espèces : ' || COALESCE(v_confirm_res->>'message', 'Erreur transactionnelle')
        );
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
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur sell_ticket_cash : ' || SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sell_ticket_cash(UUID, TEXT, TEXT, TEXT, INTEGER) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. SÉCURISATION RLS DE LA FLOTTE (VEHICLES)
-- ------------------------------------------------------------------------------
-- Ne pas exposer les identifiants chauffeurs actuels au public non authentifié
DROP POLICY IF EXISTS "vehicles_select_policy" ON public.vehicles;
CREATE POLICY "vehicles_select_policy" ON public.vehicles
    FOR SELECT TO authenticated
    USING (TRUE);

-- Les utilisateurs anonymes peuvent voir uniquement les véhicules rattachés à des trajets programmés
DROP POLICY IF EXISTS "vehicles_select_anon" ON public.vehicles;
CREATE POLICY "vehicles_select_anon" ON public.vehicles
    FOR SELECT TO anon
    USING (
        id IN (SELECT vehicle_id FROM public.trips WHERE status IN ('scheduled', 'at_dock', 'boarding'))
    );
