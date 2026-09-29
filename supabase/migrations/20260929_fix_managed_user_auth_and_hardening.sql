-- ==============================================================================
-- DIOUFY-TS • MIGRATION DE PRODUCTION : PROVISIONNEMENT AUTH & DURCISSEMENT RBAC
-- Date : 29 Septembre 2026
-- Version : 2.1.0
-- 
-- Objectifs :
-- 1. Provisionnement effectif des comptes dans auth.users et auth.identities
-- 2. Résolution de l'impossibilité de connexion des utilisateurs managés
-- 3. Sécurisation stricte des RPC contre l'exposition anon / PUBLIC
-- 4. Fonctions anti-doublon et recherche d'identifiant sécurisées par RPC
-- ==============================================================================

-- 1. Extensions cryptographiques requises
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ==============================================================================
-- 2. FONCTION DE RECHERCHE D'IDENTIFIANT SÉCURISÉE (Phone -> Email)
-- Utilisée par l'écran de login lorsque l'utilisateur saisit son numéro de téléphone.
-- Permet de respecter le RLS sur app_users tout en permettant la connexion par mot de passe.
-- ==============================================================================
DROP FUNCTION IF EXISTS public.lookup_email_by_phone(TEXT);

CREATE OR REPLACE FUNCTION public.lookup_email_by_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
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

    -- Recherche en priorité dans app_users
    SELECT email INTO v_email
    FROM public.app_users
    WHERE phone = v_clean_phone AND email IS NOT NULL AND email <> ''
    LIMIT 1;

    -- Recherche alternative dans auth.users
    IF v_email IS NULL THEN
        SELECT email INTO v_email
        FROM auth.users
        WHERE phone = v_clean_phone AND email IS NOT NULL AND email <> ''
        LIMIT 1;
    END IF;

    RETURN v_email;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.lookup_email_by_phone(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_email_by_phone(TEXT) TO anon, authenticated, service_role;

-- ==============================================================================
-- 3. FONCTION DE VÉRIFICATION PRÉVENTIVE D'UNICITÉ (Anti-Doublons)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.check_account_exists(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.check_account_exists(
    p_phone TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_clean_phone TEXT;
    v_clean_email TEXT;
    v_phone_exists BOOLEAN := FALSE;
    v_email_exists BOOLEAN := FALSE;
    v_raw_phone TEXT;
BEGIN
    -- Normalisation téléphone sénégalais
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

    -- Normalisation email
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

REVOKE EXECUTE ON FUNCTION public.check_account_exists(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_account_exists(TEXT, TEXT) TO anon, authenticated, service_role;

-- ==============================================================================
-- 4. RPC DE PROVISIONNEMENT OFFICIEL : create_managed_user(...)
-- Crée l'utilisateur dans auth.users avec mot de passe crypté bcrypt,
-- ajoute l'identité dans auth.identities, et configure app_users + organization_memberships.
-- ==============================================================================
DROP FUNCTION IF EXISTS public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS public.create_managed_user;

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
SET search_path = extensions, public, auth, pg_catalog
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
BEGIN
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
    SELECT level INTO v_target_level FROM public.system_roles WHERE id = p_role;
    IF v_target_level IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Rôle cible invalide : ' || COALESCE(p_role, 'indéfini'));
    END IF;

    -- D. Cloisonnement Anti-Élévation de Privilèges
    IF v_caller_role = 'super_admin' THEN
        v_target_org := p_organization_id;
    ELSIF v_caller_role = 'platform_admin' THEN
        IF p_role IN ('super_admin', 'platform_admin') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Le rôle Platform Admin ne peut pas provisionner d administrateurs système.');
        END IF;
        v_target_org := p_organization_id;
    ELSIF v_caller_role = 'gie_admin' THEN
        IF p_role NOT IN ('gie_agent', 'driver', 'coxeur', 'controller') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Un gérant de GIE ne peut créer que des agents, chauffeurs, coxeurs ou contrôleurs.');
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
        confirmed_at,
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
        NOW(),
        jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email']
        ),
        jsonb_build_object(
            'full_name', p_full_name,
            'name', p_full_name,
            'role', p_role,
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
        gen_random_uuid(),
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
        p_role,
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
        p_role,
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
        p_role,
        v_target_org,
        v_caller_id,
        jsonb_build_object(
            'full_name', p_full_name,
            'email', v_clean_email,
            'phone', v_clean_phone,
            'role', p_role,
            'created_at', NOW()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', v_clean_email,
        'phone', v_clean_phone,
        'role', p_role,
        'message', 'Compte [' || p_role || '] créé avec succès pour ' || p_full_name || '.'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', 'Erreur serveur : ' || SQLERRM);
END;
$$;

-- Révocation stricte des accès anon et public sur create_managed_user
REVOKE EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated, service_role;

-- ==============================================================================
-- 5. DURCISSEMENT GLOBAL DES PERMISSIONS SUR TOUTES LES FONCTIONS SENSIBLES
-- Conformité Supabase Security Advisors (évite l'exposition non désirée aux clients anon)
-- ==============================================================================

-- get_my_profile_and_permissions : Réservé aux utilisateurs authentifiés
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_my_profile_and_permissions') THEN
        REVOKE EXECUTE ON FUNCTION public.get_my_profile_and_permissions() FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.get_my_profile_and_permissions() FROM anon;
        GRANT EXECUTE ON FUNCTION public.get_my_profile_and_permissions() TO authenticated, service_role;
    END IF;
END $$;

-- handle_new_user : Fonction interne pour triggers, jamais appelée directement par l'API
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user') THEN
        REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
        REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role, postgres;
    END IF;
END $$;
