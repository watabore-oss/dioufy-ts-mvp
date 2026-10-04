-- ==============================================================================
-- 🚀 DIOUFY-TS : GESTION DES COOPÉRATIVES GIE & PROGRAMMATION DES TRAJETS
-- Date : 2026-10-04
-- Objectifs :
--   1. Permettre au Super Admin de créer, modifier, activer/désactiver des GIE
--   2. Permettre aux GIE de programmer leurs propres départs en toute étanchéité
--   3. Auditer toutes les opérations et garantir l'intégrité référentielle
-- ==============================================================================

-- 1. POLITIQUES RLS SUR public.organizations
-- ------------------------------------------------------------------------------
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "organizations_select_policy" ON public.organizations;
DROP POLICY IF EXISTS "Allow select organizations" ON public.organizations;

CREATE POLICY "organizations_select_policy" ON public.organizations
    FOR SELECT TO authenticated, anon
    USING (
        is_active = TRUE
        OR EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
    );

DROP POLICY IF EXISTS "organizations_admin_manage_policy" ON public.organizations;
CREATE POLICY "organizations_admin_manage_policy" ON public.organizations
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

DROP POLICY IF EXISTS "organizations_service_role" ON public.organizations;
CREATE POLICY "organizations_service_role" ON public.organizations
    FOR ALL TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);


-- 2. FONCTION RPC SÉCURISÉE : public.create_organization
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_organization(
    p_name TEXT,
    p_code TEXT,
    p_contact_phone TEXT DEFAULT NULL,
    p_contact_email TEXT DEFAULT NULL,
    p_license_number TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_clean_code TEXT;
    v_clean_name TEXT;
    v_new_org_id UUID;
BEGIN
    v_caller_id := auth.uid();

    -- Vérification du rôle appelant
    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('super_admin', 'platform_admin') AND current_setting('request.jwt.claims.role', true) != 'service_role' THEN
        RAISE EXCEPTION 'Accès refusé : seuls les Super Administrateurs peuvent enregistrer des coopératives GIE.';
    END IF;

    -- Nettoyage et validation des entrées
    v_clean_name := TRIM(p_name);
    IF v_clean_name IS NULL OR LENGTH(v_clean_name) < 2 THEN
        RAISE EXCEPTION 'Le nom de la coopérative est obligatoire (au moins 2 caractères).';
    END IF;

    v_clean_code := LOWER(REGEXP_REPLACE(TRIM(p_code), '[^a-zA-Z0-9_]', '_', 'g'));
    IF v_clean_code IS NULL OR LENGTH(v_clean_code) < 2 THEN
        v_clean_code := 'gie_' || SUBSTRING(MD5(v_clean_name) FROM 1 FOR 8);
    END IF;

    IF EXISTS (SELECT 1 FROM public.organizations WHERE code = v_clean_code) THEN
        RAISE EXCEPTION 'Une coopérative avec le code "%" existe déjà.', v_clean_code;
    END IF;

    v_new_org_id := gen_random_uuid();

    INSERT INTO public.organizations (
        id,
        code,
        name,
        contact_phone,
        contact_email,
        license_number,
        is_active,
        metadata,
        created_at,
        updated_at
    )
    VALUES (
        v_new_org_id,
        v_clean_code,
        v_clean_name,
        NULLIF(TRIM(p_contact_phone), ''),
        NULLIF(TRIM(p_contact_email), ''),
        NULLIF(TRIM(p_license_number), ''),
        TRUE,
        '{}'::jsonb,
        NOW(),
        NOW()
    );

    -- Traçabilité AuditLog
    BEGIN
        INSERT INTO public.audit_logs (actor_id, actor_role, action, target_type, target_id, details)
        VALUES (
            v_caller_id,
            COALESCE(v_caller_role, 'super_admin'),
            'organization.create',
            'organization',
            v_new_org_id::text,
            jsonb_build_object('name', v_clean_name, 'code', v_clean_code)
        );
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Ne pas bloquer si table audit indisponible
    END;

    RETURN jsonb_build_object(
        'success', TRUE,
        'id', v_new_org_id,
        'code', v_clean_code,
        'name', v_clean_name,
        'message', 'Coopérative GIE enregistrée avec succès.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_organization(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;


-- 3. FONCTION RPC SÉCURISÉE : public.update_organization_status
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_organization_status(
    p_organization_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
BEGIN
    v_caller_id := auth.uid();

    SELECT role INTO v_caller_role FROM public.app_users WHERE id = v_caller_id;
    IF v_caller_role NOT IN ('super_admin', 'platform_admin') AND current_setting('request.jwt.claims.role', true) != 'service_role' THEN
        RAISE EXCEPTION 'Accès refusé : seuls les Super Administrateurs peuvent modifier le statut d un GIE.';
    END IF;

    UPDATE public.organizations
    SET is_active = p_is_active, updated_at = NOW()
    WHERE id = p_organization_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Coopérative GIE introuvable.';
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'id', p_organization_id,
        'is_active', p_is_active,
        'message', 'Statut de la coopérative mis à jour.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_organization_status(UUID, BOOLEAN) TO authenticated, service_role;


-- 4. POLITIQUES RLS SUR public.trips POUR AUTORISER LES GIE
-- ------------------------------------------------------------------------------
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trips_select_public" ON public.trips;
DROP POLICY IF EXISTS "public_read_trips" ON public.trips;
CREATE POLICY "trips_select_public" ON public.trips
    FOR SELECT TO authenticated, anon
    USING (TRUE);

DROP POLICY IF EXISTS "trips_manage_policy" ON public.trips;
CREATE POLICY "trips_manage_policy" ON public.trips
    FOR ALL TO authenticated
    USING (
        -- Super Admin
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
        -- GIE Admin ou Agent rattaché à cette organisation
        OR organization_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.role_id IN ('gie_admin', 'gie_agent') AND om.is_active = TRUE
        )
        OR agency_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.role_id IN ('gie_admin', 'gie_agent') AND om.is_active = TRUE
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.app_users u
            WHERE u.id = auth.uid() AND u.role IN ('super_admin', 'platform_admin')
        )
        OR organization_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.role_id IN ('gie_admin', 'gie_agent') AND om.is_active = TRUE
        )
        OR agency_id IN (
            SELECT om.organization_id FROM public.organization_memberships om
            WHERE om.user_id = auth.uid() AND om.role_id IN ('gie_admin', 'gie_agent') AND om.is_active = TRUE
        )
    );

DROP POLICY IF EXISTS "trips_service_role" ON public.trips;
CREATE POLICY "trips_service_role" ON public.trips
    FOR ALL TO service_role
    USING (TRUE)
    WITH CHECK (TRUE);
