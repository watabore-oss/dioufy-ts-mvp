-- ==============================================================================
-- Migration : Phase 1 - Verrouillage Sécurité Supabase & Alignement RBAC (P0)
-- Plateforme : Dioufy-TS
-- Date : 2026-10-01
-- Référentiels : Audit technique 01-10-2026, OWASP ASVS 4.0, Supabase Postgres Best Practices
-- ==============================================================================

-- ==============================================================================
-- 1. ALIGNEMENT RBAC & PERMISSIONS OFFICIELLES
-- ==============================================================================

-- 1.1 Insertion du rôle 'gie_agent' (Agent d'Exploitation GIE) dans system_roles
INSERT INTO public.system_roles (id, name, description, level, is_system_locked)
VALUES 
    ('gie_agent', 'Agent d''Exploitation GIE', 'Gestion opérationnelle locale des départs, de la flotte et des bordereaux du GIE', 3, TRUE)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    level = EXCLUDED.level,
    is_system_locked = EXCLUDED.is_system_locked;

-- 1.2 Insertion des permissions officielles pour 'gie_agent'
INSERT INTO public.role_permissions (role_id, permission_id)
VALUES
    ('gie_agent', 'booking.search'),
    ('gie_agent', 'booking.manage_trips'),
    ('gie_agent', 'fleet.view_vehicles'),
    ('gie_agent', 'cash.generate_statement')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 1.3 Verrouillage de la lecture du catalogue RBAC aux seuls utilisateurs authentifiés
-- (Empêche l'énumération publique / reconnaissance des rôles et permissions par anon)
DROP POLICY IF EXISTS "Allow select system_roles" ON public.system_roles;
CREATE POLICY "Allow select system_roles" ON public.system_roles
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow select system_permissions" ON public.system_permissions;
CREATE POLICY "Allow select system_permissions" ON public.system_permissions
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow select role_permissions" ON public.role_permissions;
CREATE POLICY "Allow select role_permissions" ON public.role_permissions
    FOR SELECT TO authenticated USING (true);

-- ==============================================================================
-- 2. ALIGNEMENT RPC create_managed_user (SUPPRESSION RÔLE FANTÔME 'controller')
-- ==============================================================================
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
BEGIN
    -- Normalisation du rôle : conversion de l'alias historique 'controller' vers le rôle officiel 'coxeur'
    IF v_sanitized_role = 'controller' THEN
        v_sanitized_role := 'coxeur';
    END IF;

    -- A. Authentification de l'appelant
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non authentifié. Session requise.');
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

    -- C. Rôle cible et hiérarchie
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
        IF v_sanitized_role NOT IN ('gie_agent', 'driver', 'coxeur') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Un gérant de GIE ne peut créer que des agents GIE, chauffeurs ou coxeurs.');
        END IF;
        -- Règle stricte : Le GIE Admin force son organisation
        v_target_org := v_caller_org;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Votre rôle ne dispose pas de l autorisation de provisionner des comptes.');
    END IF;

    -- E. Validation du mot de passe (Minimum 8 caractères pour durcissement de sécurité)
    IF p_password IS NULL OR LENGTH(TRIM(p_password)) < 8 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Le mot de passe initial doit contenir au minimum 8 caractères.');
    END IF;

    -- F. Nettoyage de l'e-mail et du téléphone
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

    -- Si aucun e-mail n'est renseigné, générer un e-mail technique unique
    IF v_clean_email IS NULL THEN
        v_clean_email := 'user.' || REGEXP_REPLACE(v_clean_phone, '[^0-9]', '', 'g') || '@dioufy-ts.sn';
    END IF;

    -- G. Contrôle d'unicité
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un compte avec l e-mail "' || v_clean_email || '" existe déjà.');
    END IF;

    IF v_clean_phone IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE phone = v_clean_phone) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Un compte avec le téléphone "' || v_clean_phone || '" existe déjà.');
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
            'provider', 'email',
            'providers', ARRAY['email']
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
        gen_random_uuid()::text,
        v_new_user_id,
        jsonb_build_object(
            'sub', v_new_user_id::text,
            'email', v_clean_email,
            'phone', v_clean_phone
        ),
        'email',
        v_clean_email,
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

REVOKE EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated, service_role;

-- ==============================================================================
-- 3. SÉCURISATION DES FONCTIONS TRANSACTIONNELLES & REVOCATIONS ANON
-- ==============================================================================

-- 3.1 expire_locks : STRICTEMENT RÉSERVÉ À SERVICE_ROLE
CREATE OR REPLACE FUNCTION public.expire_locks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  -- 1. Libérer les sièges verrouillés dont le délai a expiré
  UPDATE public.seats
    SET status = 'available', lock_until = NULL, locked_by = NULL
    WHERE status = 'locked' AND lock_until IS NOT NULL AND lock_until < now();

  -- 2. Annuler les réservations temporaires expirées
  UPDATE public.bookings
    SET status = 'cancelled'
    WHERE status = 'pending' AND lock_expires_at IS NOT NULL AND lock_expires_at < now();

  -- 3. Purger les requêtes idempotentes obsolètes (> 24 heures)
  DELETE FROM public.idempotent_requests
    WHERE created_at < now() - INTERVAL '24 hours';
END;
$$;

REVOKE ALL ON FUNCTION public.expire_locks() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_locks() TO service_role;

-- 3.2 confirm_payment : STRICTEMENT RÉSERVÉ À SERVICE_ROLE (EDGE FUNCTIONS / WEBHOOKS)
-- EMPÊCHE TOUT CLIENT DE VALIDER ARBITRAIREMENT DES PAIEMENTS VIA RPC DIRECTE
CREATE OR REPLACE FUNCTION public.confirm_payment(
  p_booking_id uuid,
  p_provider text DEFAULT 'Wave',
  p_provider_ref text DEFAULT NULL,
  p_amount integer DEFAULT 0,
  p_ticket_signature text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_payment_id uuid;
  v_idempotency_key text;
  v_existing_status text;
BEGIN
  -- Vérifier l'existence et l'état de la réservation
  SELECT status INTO v_existing_status FROM public.bookings WHERE id = p_booking_id;
  IF v_existing_status IS NULL THEN
    RAISE EXCEPTION 'Réservation introuvable : %', p_booking_id;
  END IF;

  v_idempotency_key := COALESCE(p_provider_ref, 'pay_' || p_booking_id::text);

  -- 1. Insérer le paiement de façon idempotente
  INSERT INTO public.payments (booking_id, amount, provider, provider_ref, status, idempotency_key)
  VALUES (p_booking_id, p_amount, p_provider, p_provider_ref, 'successful', v_idempotency_key)
  ON CONFLICT (idempotency_key) DO UPDATE SET status = 'successful'
  RETURNING id INTO v_payment_id;

  -- 2. Mettre à jour la réservation à 'paid'
  UPDATE public.bookings SET status = 'paid' WHERE id = p_booking_id;

  -- 3. Mettre à jour les sièges associés à 'sold'
  UPDATE public.seats SET status = 'sold', lock_until = NULL WHERE locked_by = p_booking_id;

  RETURN jsonb_build_object('success', true, 'payment_id', v_payment_id);
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_payment(uuid, text, text, integer, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_payment(uuid, text, text, integer, text) TO service_role;

-- 3.3 lock_seat : DURCISSEMENT VALIDATION & SEARCH_PATH
CREATE OR REPLACE FUNCTION public.lock_seat(
  p_trip_id uuid,
  p_seat_number text,
  p_user_id uuid DEFAULT NULL,
  p_lock_minutes integer DEFAULT 10,
  p_request_id text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_seat_id uuid;
  v_booking_id uuid;
  v_effective_user_id uuid;
  v_now timestamptz := now();
  v_sanitized_minutes integer;
  v_lock_until timestamptz;
  v_stored_request record;
BEGIN
  -- Bornage de sécurité du délai de verrouillage (entre 1 et 15 minutes max)
  v_sanitized_minutes := LEAST(GREATEST(COALESCE(p_lock_minutes, 10), 1), 15);
  v_lock_until := v_now + (v_sanitized_minutes || ' minutes')::interval;

  -- Forcer l'identité de l'utilisateur authentifié s'il est connecté
  v_effective_user_id := COALESCE(auth.uid(), p_user_id);

  -- Validation idempotence
  IF p_request_id IS NOT NULL THEN
    SELECT result->>'booking_id' as booking_id INTO v_stored_request
    FROM public.idempotent_requests
    WHERE request_id = p_request_id AND operation = 'lock_seat';
    
    IF FOUND AND v_stored_request.booking_id IS NOT NULL THEN
      RETURN (v_stored_request.booking_id)::uuid;
    END IF;
  END IF;

  -- Verrouillage de la ligne du siège
  SELECT id INTO v_seat_id FROM public.seats
    WHERE trip_id = p_trip_id AND seat_number = p_seat_number
    FOR UPDATE;

  -- Création automatique si inexistant
  IF v_seat_id IS NULL THEN
    INSERT INTO public.seats (trip_id, seat_number, status)
      VALUES (p_trip_id, p_seat_number, 'available')
      ON CONFLICT (trip_id, seat_number) DO NOTHING
      RETURNING id INTO v_seat_id;

    IF v_seat_id IS NULL THEN
      SELECT id INTO v_seat_id FROM public.seats
        WHERE trip_id = p_trip_id AND seat_number = p_seat_number
        FOR UPDATE;
    END IF;
  END IF;

  -- Vérifier la disponibilité
  PERFORM 1 FROM public.seats WHERE id = v_seat_id AND (
    status = 'available' OR (status = 'locked' AND (lock_until IS NULL OR lock_until < v_now))
  );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seat % not available on trip %', p_seat_number, p_trip_id;
  END IF;

  -- Créer la réservation temporaire
  INSERT INTO public.bookings (user_id, trip_id, seats, status, lock_expires_at, agency_id)
  VALUES (
    v_effective_user_id,
    p_trip_id,
    to_jsonb(ARRAY[p_seat_number]::text[]),
    'pending',
    v_lock_until,
    (SELECT agency_id FROM public.trips WHERE id = p_trip_id)
  )
  RETURNING id INTO v_booking_id;

  -- Mettre à jour le siège
  UPDATE public.seats
    SET status = 'locked', lock_until = v_lock_until, locked_by = v_booking_id
    WHERE id = v_seat_id;

  -- Enregistrer l'opération idempotente
  IF p_request_id IS NOT NULL THEN
    INSERT INTO public.idempotent_requests (request_id, operation, result)
      VALUES (p_request_id, 'lock_seat', jsonb_build_object('booking_id', v_booking_id))
      ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_booking_id;
END;
$$;

REVOKE ALL ON FUNCTION public.lock_seat(uuid, text, uuid, integer, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.lock_seat(uuid, text, uuid, integer, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.lock_seat(uuid, text, uuid, integer, text) TO authenticated, service_role;

-- 3.4 release_seat : CONTRÔLE D'AUTORITÉ SUR LE BOOKING & SEARCH_PATH
CREATE OR REPLACE FUNCTION public.release_seat(
  p_booking_id uuid,
  p_request_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_stored_request record;
  v_booking_user_id uuid;
BEGIN
  -- Contrôle d'autorité : l'appelant doit être le propriétaire ou service_role
  IF auth.role() <> 'service_role' THEN
    SELECT user_id INTO v_booking_user_id FROM public.bookings WHERE id = p_booking_id;
    IF v_booking_user_id IS NOT NULL AND v_booking_user_id <> auth.uid() THEN
      RAISE EXCEPTION 'Non autorisé à annuler cette réservation.';
    END IF;
  END IF;

  -- Contrôle idempotence
  IF p_request_id IS NOT NULL THEN
    SELECT 1 INTO v_stored_request
      FROM public.idempotent_requests
      WHERE request_id = p_request_id AND operation = 'release_seat';
    
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  -- Libérer le siège s'il est toujours en attente
  UPDATE public.seats
    SET status = 'available', lock_until = NULL, locked_by = NULL
    WHERE locked_by = p_booking_id AND status = 'locked';

  UPDATE public.bookings
    SET status = 'cancelled'
    WHERE id = p_booking_id AND status = 'pending';

  IF p_request_id IS NOT NULL THEN
    INSERT INTO public.idempotent_requests (request_id, operation, result)
      VALUES (p_request_id, 'release_seat', '{}'::jsonb)
      ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.release_seat(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.release_seat(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.release_seat(uuid, text) TO authenticated, service_role;

-- 3.5 lookup_email_by_phone & check_account_exists : SEARCH_PATH FIX
CREATE OR REPLACE FUNCTION public.lookup_email_by_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
    v_clean_phone TEXT;
    v_raw_phone TEXT;
    v_email TEXT;
BEGIN
    IF p_phone IS NULL OR TRIM(p_phone) = '' THEN
        RETURN NULL;
    END IF;

    v_raw_phone := REGEXP_REPLACE(TRIM(p_phone), '[^0-9+]', '', 'g');
    IF v_raw_phone LIKE '+%' THEN
        v_clean_phone := v_raw_phone;
    ELSIF v_raw_phone LIKE '221%' THEN
        v_clean_phone := '+' || v_raw_phone;
    ELSE
        v_clean_phone := '+221' || v_raw_phone;
    END IF;

    SELECT email INTO v_email
    FROM public.app_users
    WHERE phone = v_clean_phone AND email IS NOT NULL AND email <> '' AND is_active = TRUE
    LIMIT 1;

    IF v_email IS NULL THEN
        SELECT email INTO v_email
        FROM auth.users
        WHERE phone = v_clean_phone AND email IS NOT NULL AND email <> ''
        LIMIT 1;
    END IF;

    RETURN v_email;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_account_exists(
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
    v_clean_phone TEXT;
    v_clean_email TEXT;
    v_phone_exists BOOLEAN := FALSE;
    v_email_exists BOOLEAN := FALSE;
    v_raw_phone TEXT;
BEGIN
    IF p_phone IS NOT NULL AND TRIM(p_phone) <> '' THEN
        v_raw_phone := REGEXP_REPLACE(TRIM(p_phone), '[^0-9+]', '', 'g');
        IF v_raw_phone LIKE '+%' THEN
            v_clean_phone := v_raw_phone;
        ELSIF v_raw_phone LIKE '221%' THEN
            v_clean_phone := '+' || v_raw_phone;
        ELSE
            v_clean_phone := '+221' || v_raw_phone;
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM public.app_users WHERE phone = v_clean_phone
            UNION
            SELECT 1 FROM auth.users WHERE phone = v_clean_phone
        ) INTO v_phone_exists;
    END IF;

    IF p_email IS NOT NULL AND TRIM(p_email) <> '' THEN
        v_clean_email := LOWER(TRIM(p_email));
        SELECT EXISTS (
            SELECT 1 FROM public.app_users WHERE LOWER(email) = v_clean_email
            UNION
            SELECT 1 FROM auth.users WHERE LOWER(email) = v_clean_email
        ) INTO v_email_exists;
    END IF;

    RETURN jsonb_build_object(
        'phone_exists', v_phone_exists,
        'email_exists', v_email_exists
    );
END;
$$;

-- Révocation anon pour is_platform_admin et get_user_organization_ids
REVOKE ALL ON FUNCTION public.is_platform_admin(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_platform_admin(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_user_organization_ids(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_organization_ids(UUID) TO authenticated, service_role;

-- ==============================================================================
-- 4. POLITIQUES RLS SUR LES 5 TABLES ORPHELINES & RENFORCEMENT GLOBAL
-- ==============================================================================

-- Index d'optimisation RLS (règles Supabase Best Practices)
CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON public.payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_baggage_booking_id ON public.baggage(booking_id);
CREATE INDEX IF NOT EXISTS idx_driver_positions_trip_id ON public.driver_positions(trip_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_agency_id ON public.trips(agency_id);

-- 4.1 Table : agencies
ALTER TABLE public.agencies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public_read_agencies" ON public.agencies;
DROP POLICY IF EXISTS "agencies_read_policy" ON public.agencies;
DROP POLICY IF EXISTS "agencies_write_policy" ON public.agencies;

CREATE POLICY "agencies_read_policy" ON public.agencies
  FOR SELECT USING (true);

CREATE POLICY "agencies_write_policy" ON public.agencies
  FOR ALL TO authenticated
  USING (public.is_platform_admin((select auth.uid())))
  WITH CHECK (public.is_platform_admin((select auth.uid())));

-- 4.2 Table : idempotent_requests (Isolation totale, service_role uniquement)
ALTER TABLE public.idempotent_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "idempotent_requests_isolation" ON public.idempotent_requests;
DROP POLICY IF EXISTS "idempotent_requests_service_role" ON public.idempotent_requests;

CREATE POLICY "idempotent_requests_service_role" ON public.idempotent_requests
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- 4.3 Table : payments (Lecture compartimentée, écriture exclusive service_role)
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "payments_select_policy" ON public.payments;
DROP POLICY IF EXISTS "payments_write_policy" ON public.payments;
DROP POLICY IF EXISTS "payments_service_role_write" ON public.payments;

CREATE POLICY "payments_select_policy" ON public.payments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = payments.booking_id AND b.user_id = (select auth.uid())
    )
    OR public.is_platform_admin((select auth.uid()))
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      JOIN public.trips t ON t.id = b.trip_id
      WHERE b.id = payments.booking_id
        AND (
          t.agency_id IN (SELECT public.get_user_organization_ids((select auth.uid())))
          OR EXISTS (
            SELECT 1 FROM public.organization_memberships om
            WHERE om.user_id = (select auth.uid())
              AND om.role_id IN ('gie_admin', 'gie_agent')
              AND om.is_active = TRUE
          )
        )
    )
  );

CREATE POLICY "payments_service_role_write" ON public.payments
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- 4.4 Table : driver_positions (Lecture authentifiée, mise à jour réservée au chauffeur)
ALTER TABLE public.driver_positions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "driver_positions_select_policy" ON public.driver_positions;
DROP POLICY IF EXISTS "driver_positions_upsert_policy" ON public.driver_positions;

CREATE POLICY "driver_positions_select_policy" ON public.driver_positions
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "driver_positions_upsert_policy" ON public.driver_positions
  FOR ALL TO authenticated
  USING ((select auth.uid()) = driver_id)
  WITH CHECK ((select auth.uid()) = driver_id);

-- 4.5 Table : baggage
ALTER TABLE public.baggage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "baggage_select_policy" ON public.baggage;
DROP POLICY IF EXISTS "baggage_insert_policy" ON public.baggage;
DROP POLICY IF EXISTS "baggage_update_policy" ON public.baggage;

CREATE POLICY "baggage_select_policy" ON public.baggage
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = baggage.booking_id AND b.user_id = (select auth.uid())
    )
    OR public.is_platform_admin((select auth.uid()))
    OR EXISTS (
      SELECT 1 FROM public.organization_memberships om
      WHERE om.user_id = (select auth.uid())
        AND om.role_id IN ('driver', 'coxeur', 'gie_admin', 'gie_agent')
        AND om.is_active = TRUE
    )
  );

CREATE POLICY "baggage_insert_policy" ON public.baggage
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = baggage.booking_id AND b.user_id = (select auth.uid())
    )
    OR EXISTS (
      SELECT 1 FROM public.organization_memberships om
      WHERE om.user_id = (select auth.uid())
        AND om.role_id IN ('coxeur', 'driver', 'gie_admin', 'gie_agent')
        AND om.is_active = TRUE
    )
    OR public.is_platform_admin((select auth.uid()))
  );

CREATE POLICY "baggage_update_policy" ON public.baggage
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_memberships om
      WHERE om.user_id = (select auth.uid())
        AND om.role_id IN ('coxeur', 'driver', 'gie_admin')
        AND om.is_active = TRUE
    )
    OR public.is_platform_admin((select auth.uid()))
  );

-- 4.6 Table : bookings (Suppression de public_read_bookings laxiste)
DROP POLICY IF EXISTS "public_read_bookings" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;

CREATE POLICY "bookings_select_policy" ON public.bookings
  FOR SELECT TO authenticated
  USING (
    user_id = (select auth.uid())
    OR public.is_platform_admin((select auth.uid()))
    OR EXISTS (
      SELECT 1 FROM public.organization_memberships om
      WHERE om.user_id = (select auth.uid())
        AND om.role_id IN ('coxeur', 'driver', 'gie_admin', 'gie_agent')
        AND om.is_active = TRUE
    )
  );

CREATE POLICY "bookings_insert_policy" ON public.bookings
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (select auth.uid())
    OR public.is_platform_admin((select auth.uid()))
  );

CREATE POLICY "bookings_update_policy" ON public.bookings
  FOR UPDATE TO authenticated
  USING (
    (user_id = (select auth.uid()) AND status = 'pending')
    OR public.is_platform_admin((select auth.uid()))
  )
  WITH CHECK (
    (user_id = (select auth.uid()) AND status IN ('pending', 'cancelled'))
    OR public.is_platform_admin((select auth.uid()))
  );

-- 4.7 Table : tickets (Lecture sécurisée par voyageur ou agent)
DROP POLICY IF EXISTS "tickets_passenger_read_policy" ON public.tickets;
CREATE POLICY "tickets_passenger_read_policy" ON public.tickets
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = tickets.booking_id AND b.user_id = (select auth.uid())
    )
    OR public.is_platform_admin((select auth.uid()))
    OR EXISTS (
      SELECT 1 FROM public.organization_memberships om
      WHERE om.user_id = (select auth.uid())
        AND om.role_id IN ('coxeur', 'driver', 'gie_admin', 'gie_agent')
        AND om.is_active = TRUE
    )
  );

-- ==============================================================================
-- 5. PROTECTION pg_graphql (EXCLUSION DES TABLES INTERNES ET SENSIBLES)
-- ==============================================================================
COMMENT ON TABLE public.payments IS E'@graphql({"exclude": true})';
COMMENT ON TABLE public.idempotent_requests IS E'@graphql({"exclude": true})';
COMMENT ON TABLE public.rbac_audit_logs IS E'@graphql({"exclude": true})';
COMMENT ON TABLE public.organization_memberships IS E'@graphql({"exclude": true})';
COMMENT ON TABLE public.driver_positions IS E'@graphql({"exclude": true})';
COMMENT ON TABLE public.baggage IS E'@graphql({"exclude": true})';
