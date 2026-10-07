-- ==============================================================================
-- Migration : Correctif RLS Recursion & Support Robuste Réinitialisation Mot de Passe
-- Date : 2026-09-30
-- Contexte :
-- 1. Résolution de l'erreur 500 sur organization_memberships (récursion infinie RLS).
-- 2. Ajout des colonnes manquantes sur public.app_users (is_active, avatar_url, organization_id, updated_at).
-- 3. Sécurisation et tolérance aux pannes de get_my_profile_and_permissions().
-- ==============================================================================

-- 1. S'assurer que toutes les colonnes requises existent sur public.app_users
ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS organization_id UUID;
ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2. Création de fonctions auxiliaires SECURITY DEFINER pour éviter la récursion RLS sur organization_memberships
CREATE OR REPLACE FUNCTION public.is_platform_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.organization_memberships
        WHERE user_id = p_user_id
          AND is_active = TRUE
          AND role_id IN ('super_admin', 'platform_admin')
    );
$$;

CREATE OR REPLACE FUNCTION public.get_user_organization_ids(p_user_id UUID)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public
STABLE
AS $$
    SELECT organization_id FROM public.organization_memberships
    WHERE user_id = p_user_id AND is_active = TRUE AND organization_id IS NOT NULL;
$$;

REVOKE EXECUTE ON FUNCTION public.is_platform_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_platform_admin(UUID) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_user_organization_ids(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_organization_ids(UUID) TO authenticated, service_role;

-- 3. Remplacement de la politique RLS sur organization_memberships pour éliminer toute récursion infinie
DROP POLICY IF EXISTS "Users can view memberships" ON public.organization_memberships;
CREATE POLICY "Users can view memberships" ON public.organization_memberships
    FOR SELECT TO authenticated
    USING (
        (select auth.uid()) = user_id
        OR public.is_platform_admin((select auth.uid()))
        OR (
            organization_id IS NOT NULL 
            AND organization_id IN (SELECT public.get_user_organization_ids((select auth.uid())))
        )
    );

-- 4. RPC get_my_profile_and_permissions durcie et tolérante aux pannes
CREATE OR REPLACE FUNCTION public.get_my_profile_and_permissions()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
    v_effective_role TEXT := 'passenger';
    v_org_id UUID;
    v_org_name TEXT;
    v_permissions JSONB := '[]'::jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('error', 'Unauthenticated');
    END IF;

    -- Récupérer le profil dans app_users
    SELECT id, email, phone, full_name, role, organization_id, avatar_url, is_active
    INTO v_user
    FROM public.app_users
    WHERE id = v_user_id;

    -- Si app_users n'a pas encore la ligne, la créer à la volée depuis auth.users
    IF v_user IS NULL THEN
        BEGIN
            INSERT INTO public.app_users (id, email, phone, full_name, role, is_active)
            SELECT 
                u.id, 
                u.email, 
                u.phone,
                COALESCE(u.raw_user_meta_data->>'full_name', 'Utilisateur Dioufy'),
                'passenger',
                TRUE
            FROM auth.users u
            WHERE u.id = v_user_id
            ON CONFLICT (id) DO UPDATE SET
                email = EXCLUDED.email,
                phone = COALESCE(EXCLUDED.phone, public.app_users.phone);

            SELECT id, email, phone, full_name, role, organization_id, avatar_url, is_active
            INTO v_user
            FROM public.app_users
            WHERE id = v_user_id;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'get_my_profile_and_permissions insert warning: %', SQLERRM;
        END;
    END IF;

    -- Déterminer le rôle le plus privilégié depuis organization_memberships
    BEGIN
        SELECT om.role_id, om.organization_id, o.name
        INTO v_effective_role, v_org_id, v_org_name
        FROM public.organization_memberships om
        LEFT JOIN public.organizations o ON o.id = om.organization_id
        JOIN public.system_roles sr ON sr.id = om.role_id
        WHERE om.user_id = v_user_id AND om.is_active = TRUE
        ORDER BY sr.level ASC
        LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        v_effective_role := NULL;
    END;

    -- Si aucune affiliation trouvée, utiliser le rôle dans app_users
    IF v_effective_role IS NULL THEN
        v_effective_role := COALESCE(v_user.role, 'passenger');
        v_org_id := v_user.organization_id;
    END IF;

    -- Récupérer la liste des permissions associées à ce rôle
    BEGIN
        SELECT jsonb_agg(rp.permission_id)
        INTO v_permissions
        FROM public.role_permissions rp
        WHERE rp.role_id = v_effective_role;
    EXCEPTION WHEN OTHERS THEN
        v_permissions := '[]'::jsonb;
    END;

    v_permissions := COALESCE(v_permissions, '[]'::jsonb);

    RETURN jsonb_build_object(
        'id', v_user_id,
        'email', v_user.email,
        'phone', v_user.phone,
        'full_name', COALESCE(v_user.full_name, 'Utilisateur Dioufy'),
        'role', v_effective_role,
        'organization_id', v_org_id,
        'organization_name', v_org_name,
        'avatar_url', v_user.avatar_url,
        'is_active', COALESCE(v_user.is_active, TRUE),
        'permissions', v_permissions
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_profile_and_permissions() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_my_profile_and_permissions() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile_and_permissions() TO authenticated, service_role;
