-- ==============================================================================
-- Migration : Phase 2 - Autorité Serveur Billetterie & Compostage Atomique (P0)
-- Plateforme : Dioufy-TS
-- Date : 2026-10-01
-- Référentiels : Audit technique 01-10-2026, Résilience Réseau Sénégal, OWASP ASVS
-- ==============================================================================

-- ==============================================================================
-- 1. ÉVOLUTION DU SCHÉMA : Table public.tickets
-- ==============================================================================

-- 1.1 Ajout des colonnes de traçabilité et de cycle de vie sur tickets
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'valid';
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS validated_by UUID REFERENCES public.app_users(id) ON DELETE SET NULL;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS ticket_number TEXT;
ALTER TABLE public.tickets ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- 1.2 Ajout de colonnes miroir sur bookings pour cohérence opérationnelle
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS boarded_at TIMESTAMPTZ;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS boarded_by UUID REFERENCES public.app_users(id) ON DELETE SET NULL;

-- 1.3 Index de performance pour le scan optique à haute fréquence
CREATE INDEX IF NOT EXISTS idx_tickets_ticket_number ON public.tickets(ticket_number);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON public.tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_used_at ON public.tickets(used_at);
CREATE INDEX IF NOT EXISTS idx_tickets_booking_id ON public.tickets(booking_id);
CREATE INDEX IF NOT EXISTS idx_bookings_boarded_at ON public.bookings(boarded_at);

-- ==============================================================================
-- 2. PROCÉDURE STOCKÉE ATOMIQUE : compost_ticket(...)
-- ==============================================================================
-- Cette RPC est l'autorité centrale de compostage.
-- Elle élimine toute possibilité de fraude par copie de QR code ou billet non payé.
CREATE OR REPLACE FUNCTION public.compost_ticket(
    p_ticket_ref TEXT,
    p_trip_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_ticket RECORD;
    v_booking RECORD;
    v_caller_id UUID;
    v_now TIMESTAMPTZ := NOW();
    v_clean_ref TEXT := TRIM(p_ticket_ref);
BEGIN
    v_caller_id := auth.uid();

    IF v_clean_ref IS NULL OR v_clean_ref = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'INVALID_PARAM',
            'message', 'Référence de billet vide.'
        );
    END IF;

    -- 1. Recherche du ticket par identifiant, numéro de billet, ref de payload ou booking_id
    SELECT 
        t.id,
        t.booking_id,
        t.status AS ticket_status,
        t.used_at,
        t.validated_by,
        t.payload,
        b.status AS booking_status,
        b.trip_id AS booking_trip_id,
        b.user_id AS passenger_id,
        b.seats,
        b.boarded_at
    INTO v_ticket
    FROM public.tickets t
    JOIN public.bookings b ON b.id = t.booking_id
    WHERE t.id::TEXT = v_clean_ref
       OR t.ticket_number = v_clean_ref
       OR b.id::TEXT = v_clean_ref
       OR (t.payload->>'ref' = v_clean_ref)
    LIMIT 1;

    -- 2. Rétrocompatibilité : Si absent de tickets, chercher dans la table bookings
    IF v_ticket IS NULL THEN
        SELECT 
            b.id,
            b.status AS booking_status,
            b.trip_id AS booking_trip_id,
            b.user_id AS passenger_id,
            b.seats,
            b.boarded_at,
            b.boarded_by
        INTO v_booking
        FROM public.bookings b
        WHERE b.id::TEXT = v_clean_ref
        LIMIT 1;

        IF v_booking IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'NOT_FOUND',
                'message', 'Billet introuvable dans le système central.'
            );
        END IF;

        -- Vérifier l'état de paiement
        IF v_booking.booking_status <> 'paid' THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'UNPAID',
                'message', 'Ce billet n''a pas été payé ou a été annulé (Statut: ' || v_booking.booking_status || ').'
            );
        END IF;

        -- Vérifier si déjà embarqué
        IF v_booking.boarded_at IS NOT NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'ALREADY_USED',
                'used_at', v_booking.boarded_at,
                'message', 'Attention : Ce voyageur est DÉJÀ EMBARQUÉ (validé à ' || to_char(v_booking.boarded_at, 'HH24:MI:SS le DD/MM/YYYY') || ').'
            );
        END IF;

        -- Création et validation atomique du ticket
        INSERT INTO public.tickets (
            booking_id, payload, signature, status, used_at, validated_by, ticket_number
        )
        VALUES (
            v_booking.id,
            jsonb_build_object(
                'booking_id', v_booking.id,
                'seats', v_booking.seats,
                'created_at', v_now
            ),
            'server_validated_on_board',
            'used',
            v_now,
            v_caller_id,
            v_clean_ref
        )
        RETURNING id INTO v_ticket.id;

        UPDATE public.bookings
        SET boarded_at = v_now,
            boarded_by = v_caller_id
        WHERE id = v_booking.id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'VALIDATED',
            'ticket_id', v_ticket.id,
            'booking_id', v_booking.id,
            'seats', v_booking.seats,
            'message', 'Embarquement validé avec succès.',
            'validated_at', v_now
        );
    END IF;

    -- 3. Vérification paiement
    IF v_ticket.booking_status <> 'paid' THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'UNPAID',
            'message', 'Ce billet n''est pas payé (Statut: ' || v_ticket.booking_status || ').'
        );
    END IF;

    -- 4. Détection anti-double passage (Billet déjà composté)
    IF v_ticket.ticket_status = 'used' OR v_ticket.used_at IS NOT NULL OR v_ticket.boarded_at IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'ALREADY_USED',
            'used_at', COALESCE(v_ticket.used_at, v_ticket.boarded_at),
            'message', 'Attention : Billet DÉJÀ COMPOSTÉ à ' || to_char(COALESCE(v_ticket.used_at, v_ticket.boarded_at), 'HH24:MI:SS le DD/MM/YYYY')
        );
    END IF;

    -- 5. Contrôle de concordance du trajet (si p_trip_id est fourni par le scanner du coxeur/chauffeur)
    IF p_trip_id IS NOT NULL AND v_ticket.booking_trip_id IS NOT NULL AND v_ticket.booking_trip_id <> p_trip_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'WRONG_TRIP',
            'message', 'Ce billet est valide pour un AUTRE trajet.'
        );
    END IF;

    -- 6. Compostage transactionnel atomique
    UPDATE public.tickets
    SET status = 'used',
        used_at = v_now,
        validated_by = v_caller_id
    WHERE id = v_ticket.id;

    UPDATE public.bookings
    SET boarded_at = v_now,
        boarded_by = v_caller_id
    WHERE id = v_ticket.booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'VALIDATED',
        'ticket_id', v_ticket.id,
        'booking_id', v_ticket.booking_id,
        'seats', v_ticket.seats,
        'message', 'Billet certifié authentique. Embarquement autorisé.',
        'validated_at', v_now
    );
END;
$$;

-- Révocation stricte : seuls les personnels authentifiés (coxeur, chauffeur, admin) ou service_role peuvent composter
REVOKE ALL ON FUNCTION public.compost_ticket(TEXT, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.compost_ticket(TEXT, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.compost_ticket(TEXT, UUID) TO authenticated, service_role;

-- ==============================================================================
-- 3. ÉMISSION SERVEUR DE BILLET SÉCURISÉ : issue_ticket(...)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.issue_ticket(
    p_booking_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions
AS $$
DECLARE
    v_booking RECORD;
    v_trip RECORD;
    v_ticket_id UUID;
    v_ticket_number TEXT;
    v_payload JSONB;
    v_signature TEXT;
    v_server_key TEXT := 'dioufy_sec_vault_2026_sn';
BEGIN
    -- 1. Récupérer la réservation
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF v_booking IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservation introuvable.');
    END IF;

    IF v_booking.status <> 'paid' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservation non payée. Impossible d émettre un billet.');
    END IF;

    -- 2. Récupérer le trajet
    SELECT * INTO v_trip FROM public.trips WHERE id = v_booking.trip_id;

    -- 3. Génération du numéro de billet unique
    v_ticket_id := gen_random_uuid();
    v_ticket_number := 'DIOUFY-' || UPPER(SUBSTRING(v_ticket_id::text, 1, 8));

    -- 4. Construction du payload certifié serveur
    v_payload := jsonb_build_object(
        'ticket_id', v_ticket_id,
        'ticket_number', v_ticket_number,
        'booking_id', v_booking.id,
        'trip_id', v_booking.trip_id,
        'passenger_id', v_booking.user_id,
        'seats', v_booking.seats,
        'departure', COALESCE(v_trip.from_loc, 'Dakar'),
        'arrival', COALESCE(v_trip.to_loc, 'Région'),
        'depart_at', v_trip.depart_at,
        'price', v_trip.price,
        'issued_at', NOW()
    );

    -- 5. Signature cryptographique HMAC-SHA256 par le serveur
    v_signature := encode(extensions.hmac(v_payload::text, v_server_key, 'sha256'), 'hex');

    -- 6. Enregistrement officiel en base
    INSERT INTO public.tickets (
        id,
        booking_id,
        ticket_number,
        payload,
        signature,
        status,
        qr_data,
        issued_at
    )
    VALUES (
        v_ticket_id,
        p_booking_id,
        v_ticket_number,
        v_payload,
        v_signature,
        'valid',
        jsonb_build_object('payload', v_payload, 'signature', v_signature)::text,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        payload = EXCLUDED.payload,
        signature = EXCLUDED.signature,
        status = 'valid'
    RETURNING id INTO v_ticket_id;

    RETURN jsonb_build_object(
        'success', true,
        'ticket_id', v_ticket_id,
        'ticket_number', v_ticket_number,
        'payload', v_payload,
        'signature', v_signature
    );
END;
$$;

REVOKE ALL ON FUNCTION public.issue_ticket(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.issue_ticket(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.issue_ticket(UUID) TO authenticated, service_role;
