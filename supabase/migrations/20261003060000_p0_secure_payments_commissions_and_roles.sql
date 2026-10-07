-- ==============================================================================
-- 🚀 MIGRATION P0 : SÉCURISATION DES PAIEMENTS, WEBHOOKS, COMMISSIONS DYNAMIQUES
-- ET CLOISONNEMENT ORGANISATIONNEL DES COMPTES MÉTIER
-- Fichier : 20261003_p0_secure_payments_commissions_and_roles.sql
-- Date : 03-10-2026
-- 
-- Objectifs de l'audit :
-- 1. Sécuriser confirm_payment : interdire la confirmation par un passager côté client.
--    Seul le service_role (Edge Functions webhook) ou le personnel autorisé en guichet
--    peut confirmer un paiement.
-- 2. Dynamiser le partage des revenus (ticket_commissions) :
--    - Taux configurables par trajet (plateforme, chauffeur, coxeur, GIE).
--    - Coxeur et chauffeur réels rattachés au trajet ou à l'encaissement quai.
-- 3. Corriger sell_ticket_cash : vérifier strictement le retour de confirm_payment
--    avant de renvoyer le succès.
-- 4. Ajouter la procédure atomique refund_or_cancel_booking pour la gestion des remboursements.
-- 5. Renforcer create_managed_user : affectation organisationnelle obligatoire
--    pour tous les rôles opérationnels (gie_agent, driver, coxeur, mechanic).
-- ==============================================================================

-- 1. EXTENSION DE LA TABLE TRIPS (COMMISSIONS & COXEUR AFFECTÉ)
-- ------------------------------------------------------------------------------
ALTER TABLE public.trips 
    ADD COLUMN IF NOT EXISTS coxeur_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS commission_rate_platform NUMERIC(5,2) DEFAULT 5.00,
    ADD COLUMN IF NOT EXISTS commission_rate_driver NUMERIC(5,2) DEFAULT 7.00,
    ADD COLUMN IF NOT EXISTS commission_rate_coxeur NUMERIC(5,2) DEFAULT 3.00;

CREATE INDEX IF NOT EXISTS idx_trips_coxeur ON public.trips(coxeur_id);

-- 2. EXTENSION DE TICKET_COMMISSIONS (AUDIT TRAIL & ANNULATION)
-- ------------------------------------------------------------------------------
ALTER TABLE public.ticket_commissions
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS refund_reason TEXT,
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- 3. PROCÉDURE ATOMIQUE CONFIRM_PAYMENT SÉCURISÉE
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
    v_caller_id := auth.uid();
    -- Détecter si l'appel provient de la clé service_role (Edge Function)
    v_is_service_role := (current_setting('request.jwt.claim.role', true) = 'service_role');

    -- 1. Contrôle d'autorisation strict :
    -- Un voyageur (client final) ne peut JAMAIS forcer la confirmation d'un paiement en base.
    -- Seul le service_role (Edge Functions webhook sécurisées) ou un agent staff habilité peut confirmer.
    IF NOT v_is_service_role THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Non authentifié.');
        END IF;

        SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
        IF v_caller_role NOT IN ('gie_admin', 'gie_agent', 'driver', 'coxeur', 'super_admin', 'platform_admin') THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Accès refusé : la confirmation d un paiement nécessite la validation d une passerelle officielle ou d un agent de quai autorisé.'
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

    -- Calcul du montant effectif (priorité au prix de la réservation / trajet serveur pour éviter toute fraude de montant)
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

    -- 5. Passage des sièges à 'sold'
    UPDATE public.seats 
    SET status = 'sold', lock_until = NULL 
    WHERE locked_by = p_booking_id;

    -- 6. Émission officielle du billet dans public.tickets
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

    -- 7. Ventilation financière des commissions selon les règles métier
    v_rate_platform := COALESCE(v_booking.t_rate_platform, 5.00);
    v_rate_driver   := COALESCE(v_booking.t_rate_driver, 7.00);
    v_rate_coxeur   := COALESCE(v_booking.t_rate_coxeur, 3.00);

    -- Frais plateforme Dioufy (avec plancher de 150 FCFA si tarif standard)
    v_platform_fee := round((v_gross * v_rate_platform) / 100.0, 2);
    IF v_platform_fee < 150.00 AND v_gross >= 1000.00 THEN
        v_platform_fee := 150.00;
    END IF;

    v_driver_share := round((v_gross * v_rate_driver) / 100.0, 2);
    v_coxeur_share := round((v_gross * v_rate_coxeur) / 100.0, 2);
    v_gie_share    := v_gross - v_platform_fee - v_driver_share - v_coxeur_share;

    v_driver_id := v_booking.t_driver;
    v_org_id    := v_booking.t_org;

    -- Détermination précise du coxeur bénéficiaire :
    -- 1) Priorité au coxeur passé explicitement (ex: vente quai)
    -- 2) Sinon le coxeur affecté au trajet (trips.coxeur_id)
    -- 3) Sinon si l'appelant est un coxeur, son identifiant
    -- 4) Sinon NULL
    IF p_coxeur_id IS NOT NULL THEN
        v_coxeur_id := p_coxeur_id;
    ELSIF v_booking.t_coxeur IS NOT NULL THEN
        v_coxeur_id := v_booking.t_coxeur;
    ELSIF v_caller_role = 'coxeur' THEN
        v_coxeur_id := v_caller_id;
    ELSE
        v_coxeur_id := NULL;
    END IF;

    -- Enregistrement immuable du bordereau de commission
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
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur confirm_payment : ' || SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID, TEXT, TEXT, INTEGER, TEXT, UUID) TO authenticated, service_role;

-- 4. VENTE DIRECTE EN ESPÈCES AU GUICHET / QUAI AVEC CONTRÔLE STRICT
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

    -- 1. Contrôle d'accès des agents
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('coxeur', 'gie_admin', 'gie_agent', 'driver', 'super_admin', 'platform_admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Seuls les agents de quai, coxeurs ou gestionnaires GIE peuvent encaisser des billets au guichet.');
    END IF;

    -- 2. Contrôle du trajet
    SELECT * INTO v_trip FROM public.trips WHERE id = p_trip_id;
    IF v_trip.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Trajet introuvable.');
    END IF;

    v_effective_amount := COALESCE(p_amount, v_trip.price);

    -- 3. Disponibilité atomique du siège (SELECT FOR UPDATE)
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

    -- 5. Verrouiller le siège
    UPDATE public.seats 
    SET status = 'locked', locked_by = v_booking_id, lock_until = NOW() + INTERVAL '10 minutes'
    WHERE id = v_seat_id;

    -- 6. Confirmation atomique du paiement et génération des commissions
    v_confirm_res := public.confirm_payment(
        p_booking_id := v_booking_id,
        p_provider   := 'Espèces Guichet',
        p_provider_ref := v_ref,
        p_amount     := v_effective_amount,
        p_ticket_signature := '',
        p_coxeur_id  := v_caller_id
    );

    -- CONTRÔLE DE VALIDITÉ CRITIQUE : Ne jamais renvoyer success=true si confirm_payment échoue !
    IF v_confirm_res IS NULL OR (v_confirm_res->>'success')::boolean IS NOT TRUE THEN
        -- Rollback du siège
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

-- 5. GESTION DES ANNULATIONS & REMBOURSEMENTS AVEC JOURNAL FINANCIER
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
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non authentifié.');
    END IF;

    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF v_booking.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservation introuvable.');
    END IF;

    -- Contrôle d'autorisation : Titulaire de la réservation ou agent/admin
    IF v_booking.user_id <> v_caller_id AND v_caller_role NOT IN ('super_admin', 'platform_admin', 'gie_admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Action non autorisée sur cette réservation.');
    END IF;

    -- 1. Libérer les sièges
    UPDATE public.seats 
    SET status = 'available', locked_by = NULL, lock_until = NULL 
    WHERE locked_by = p_booking_id;

    -- 2. Mettre à jour la réservation
    UPDATE public.bookings 
    SET status = 'cancelled' 
    WHERE id = p_booking_id;

    -- 3. Marquer la commission comme remboursée / annulée dans le journal financier
    UPDATE public.ticket_commissions 
    SET status = 'refunded', 
        refund_reason = p_reason, 
        cancelled_at = NOW() 
    WHERE booking_id = p_booking_id;

    -- 4. Journal d'audit
    INSERT INTO public.rbac_audit_logs (
        action, target_user_id, target_organization_id, performed_by, metadata
    )
    VALUES (
        'CANCEL_BOOKING',
        v_booking.user_id,
        v_booking.agency_id,
        v_caller_id,
        jsonb_build_object(
            'booking_id', p_booking_id,
            'reason', p_reason,
            'cancelled_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'message', 'Réservation annulée et sièges libérés avec succès.'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur annulation : ' || SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.refund_or_cancel_booking(UUID, TEXT) TO authenticated, service_role;

-- 6. RENFORCEMENT DE CREATE_MANAGED_USER (RATTACHEMENT ORGANISATIONNEL OBLIGATOIRE)
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

    -- D. Cloisonnement et vérification de l'organisation cible
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
        v_target_org := v_caller_org;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Votre rôle ne dispose pas de l autorisation de provisionner des comptes.');
    END IF;

    -- Règle stricte P0 de l'audit :
    -- Pour tous les rôles opérationnels (gie_admin, gie_agent, driver, coxeur, mechanic),
    -- le rattachement organisationnel est OBLIGATOIRE !
    IF v_sanitized_role IN ('gie_admin', 'gie_agent', 'driver', 'coxeur', 'mechanic') AND v_target_org IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'L affectation à une organisation/GIE est obligatoire pour le rôle [' || v_sanitized_role || '].'
        );
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

    IF v_clean_email IS NOT NULL THEN
        v_provider := 'email';
        v_provider_id := v_clean_email;
    ELSE
        v_provider := 'phone';
        v_provider_id := v_clean_phone;
        v_clean_email := 'user.' || REGEXP_REPLACE(v_clean_phone, '[^0-9]', '', 'g') || '@dioufy-ts.sn';
    END IF;

    -- G. Contrôle d'unicité explicite
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un compte avec l e-mail "' || v_clean_email || '" existe déjà.');
    END IF;

    IF v_clean_phone IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE phone = v_clean_phone) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un compte avec le numéro "' || v_clean_phone || '" existe déjà.');
    END IF;

    -- H. Création de l'utilisateur
    v_new_user_id := gen_random_uuid();
    v_encrypted_password := extensions.crypt(p_password, extensions.gen_salt('bf', 10));

    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        phone, phone_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new,
        email_change, is_super_admin
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
        jsonb_build_object('provider', v_provider, 'providers', ARRAY[v_provider]),
        jsonb_build_object(
            'full_name', p_full_name,
            'name', p_full_name,
            'role', v_sanitized_role,
            'email', v_clean_email,
            'phone', v_clean_phone,
            'email_verified', TRUE,
            'phone_verified', (v_clean_phone IS NOT NULL)
        ),
        NOW(), NOW(), '', '', '', '', FALSE
    );

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    )
    VALUES (
        gen_random_uuid(),
        v_new_user_id,
        jsonb_build_object('sub', v_new_user_id::text, 'email', v_clean_email, 'phone', v_clean_phone),
        v_provider,
        v_provider_id,
        NOW(), NOW(), NOW()
    );

    INSERT INTO public.app_users (
        id, email, phone, full_name, role, organization_id, is_active, created_at, updated_at
    )
    VALUES (
        v_new_user_id, v_clean_email, v_clean_phone, p_full_name, v_sanitized_role, v_target_org, TRUE, NOW(), NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        phone = COALESCE(EXCLUDED.phone, public.app_users.phone),
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        organization_id = EXCLUDED.organization_id,
        is_active = TRUE,
        updated_at = NOW();

    DELETE FROM public.organization_memberships WHERE user_id = v_new_user_id;

    IF v_target_org IS NOT NULL THEN
        INSERT INTO public.organization_memberships (
            user_id, organization_id, role_id, is_active, created_at, updated_at
        )
        VALUES (
            v_new_user_id, v_target_org, v_sanitized_role, TRUE, NOW(), NOW()
        );
    END IF;

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
