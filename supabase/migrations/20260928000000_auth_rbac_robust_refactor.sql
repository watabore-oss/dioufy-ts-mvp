-- ==============================================================================
-- Migration : Refonte Robuste du Flux d'Authentification & RBAC Dioufy-TS
-- Date : 2026-09-28
-- Objectif : Harmoniser organization_id sur app_users, verrouiller le RLS,
--            sécuriser le trigger d'inscription et installer get_my_profile_and_permissions.
-- ==============================================================================

-- 1. Harmonisation de la colonne organization_id sur public.app_users
ALTER TABLE public.app_users 
ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL;

-- Migration automatique des identifiants d'agences vers organization_id si applicable
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'app_users' AND column_name = 'agency_id'
    ) THEN
        UPDATE public.app_users
        SET organization_id = agency_id
        WHERE organization_id IS NULL AND agency_id IS NOT NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_users_org ON public.app_users(organization_id);

-- 2. Activation du ROW LEVEL SECURITY (RLS) sur toutes les tables d'authentification
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rbac_audit_logs ENABLE ROW LEVEL SECURITY;

-- Politiques de lecture publique/authentifiée sur les rôles et permissions
DROP POLICY IF EXISTS "Allow select system_roles" ON public.system_roles;
CREATE POLICY "Allow select system_roles" ON public.system_roles
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow select system_permissions" ON public.system_permissions;
CREATE POLICY "Allow select system_permissions" ON public.system_permissions
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow select role_permissions" ON public.role_permissions;
CREATE POLICY "Allow select role_permissions" ON public.role_permissions
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Allow select organizations" ON public.organizations;
CREATE POLICY "Allow select organizations" ON public.organizations
    FOR SELECT TO authenticated, anon USING (is_active = true);

-- Politiques de protection sur app_users
DROP POLICY IF EXISTS "Users can view their own profile or org colleagues" ON public.app_users;
CREATE POLICY "Users can view their own profile or org colleagues" ON public.app_users
    FOR SELECT TO authenticated
    USING (
        (select auth.uid()) = id
        OR EXISTS (
            SELECT 1 FROM public.organization_memberships om
            WHERE om.user_id = (select auth.uid())
              AND om.is_active = TRUE
              AND om.role_id IN ('super_admin', 'platform_admin')
        )
        OR (
            organization_id IS NOT NULL
            AND organization_id IN (
                SELECT om.organization_id FROM public.organization_memberships om
                WHERE om.user_id = (select auth.uid()) AND om.is_active = TRUE
            )
        )
    );

DROP POLICY IF EXISTS "Users can update their own profile" ON public.app_users;
CREATE POLICY "Users can update their own profile" ON public.app_users
    FOR UPDATE TO authenticated
    USING ((select auth.uid()) = id)
    WITH CHECK ((select auth.uid()) = id);

-- Politiques sur organization_memberships
DROP POLICY IF EXISTS "Users can view memberships" ON public.organization_memberships;
CREATE POLICY "Users can view memberships" ON public.organization_memberships
    FOR SELECT TO authenticated
    USING (
        (select auth.uid()) = user_id
        OR EXISTS (
            SELECT 1 FROM public.organization_memberships om
            WHERE om.user_id = (select auth.uid())
              AND om.is_active = TRUE
              AND om.role_id IN ('super_admin', 'platform_admin')
        )
        OR (
            organization_id IS NOT NULL
            AND organization_id IN (
                SELECT om.organization_id FROM public.organization_memberships om
                WHERE om.user_id = (select auth.uid()) AND om.is_active = TRUE
            )
        )
    );

-- Politiques sur rbac_audit_logs
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.rbac_audit_logs;
CREATE POLICY "Admins can view audit logs" ON public.rbac_audit_logs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_memberships om
            WHERE om.user_id = (select auth.uid())
              AND om.is_active = TRUE
              AND om.role_id IN ('super_admin', 'platform_admin')
        )
    );

-- 3. Déclencheur automatique d'inscription strict 'passenger' (Anti-Élévation)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_full_name TEXT;
    v_phone TEXT;
    v_avatar_url TEXT;
BEGIN
    v_full_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'user_name',
        SPLIT_PART(NEW.email, '@', 1),
        'Voyageur Dioufy'
    );
    v_phone := COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone, '');
    v_avatar_url := COALESCE(
        NEW.raw_user_meta_data->>'avatar_url',
        NEW.raw_user_meta_data->>'picture'
    );

    -- TOUTE INSCRIPTION PUBLIQUE REÇOIT STRICTEMENT LE RÔLE 'passenger'.
    INSERT INTO public.app_users (
        id, email, phone, full_name, role, organization_id, avatar_url, created_at, updated_at
    )
    VALUES (
        NEW.id,
        NEW.email,
        NULLIF(v_phone, ''),
        v_full_name,
        'passenger',
        NULL,
        v_avatar_url,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = COALESCE(EXCLUDED.email, public.app_users.email),
        phone = COALESCE(NULLIF(EXCLUDED.phone, ''), public.app_users.phone),
        full_name = CASE WHEN public.app_users.full_name = 'Voyageur Dioufy' THEN EXCLUDED.full_name ELSE public.app_users.full_name END,
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.app_users.avatar_url),
        updated_at = NOW();

    -- Inscription dans organization_memberships avec le rôle passenger
    INSERT INTO public.organization_memberships (
        user_id, organization_id, role_id, is_active
    )
    VALUES (
        NEW.id,
        NULL,
        'passenger',
        TRUE
    )
    ON CONFLICT (user_id, organization_id, role_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user warning: %', SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role, postgres;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 4. RPC SÉCURISÉE : get_my_profile_and_permissions()
DROP FUNCTION IF EXISTS public.get_my_profile_and_permissions();

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
    v_result JSONB;
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
        INSERT INTO public.app_users (id, email, phone, full_name, role)
        SELECT 
            u.id, 
            u.email, 
            u.phone,
            COALESCE(u.raw_user_meta_data->>'full_name', 'Utilisateur Dioufy'),
            'passenger'
        FROM auth.users u
        WHERE u.id = v_user_id
        ON CONFLICT (id) DO NOTHING;

        SELECT id, email, phone, full_name, role, organization_id, avatar_url, is_active
        INTO v_user
        FROM public.app_users
        WHERE id = v_user_id;
    END IF;

    -- Déterminer le rôle le plus privilégié depuis organization_memberships
    SELECT om.role_id, om.organization_id, o.name
    INTO v_effective_role, v_org_id, v_org_name
    FROM public.organization_memberships om
    LEFT JOIN public.organizations o ON o.id = om.organization_id
    JOIN public.system_roles sr ON sr.id = om.role_id
    WHERE om.user_id = v_user_id AND om.is_active = TRUE
    ORDER BY sr.level ASC
    LIMIT 1;

    -- Si aucune affiliation trouvée, utiliser le rôle dans app_users
    IF v_effective_role IS NULL THEN
        v_effective_role := COALESCE(v_user.role, 'passenger');
        v_org_id := v_user.organization_id;
    END IF;

    -- Récupérer la liste des permissions associées à ce rôle
    SELECT jsonb_agg(rp.permission_id)
    INTO v_permissions
    FROM public.role_permissions rp
    WHERE rp.role_id = v_effective_role;

    v_permissions := COALESCE(v_permissions, '[]'::jsonb);

    v_result := jsonb_build_object(
        'id', v_user.id,
        'email', v_user.email,
        'phone', COALESCE(v_user.phone, ''),
        'full_name', v_user.full_name,
        'role', v_effective_role,
        'organization_id', v_org_id,
        'organization_name', v_org_name,
        'avatar_url', v_user.avatar_url,
        'permissions', v_permissions
    );

    RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_profile_and_permissions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_profile_and_permissions() TO authenticated;

-- 5. RPC SÉCURISÉE : create_managed_user(...)
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
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_org UUID;
    v_target_org UUID;
    v_target_level INT;
    v_caller_level INT;
    v_new_user_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non authentifié');
    END IF;

    -- Identifier le rôle de l'appelant
    SELECT om.role_id, om.organization_id, sr.level
    INTO v_caller_role, v_caller_org, v_caller_level
    FROM public.organization_memberships om
    JOIN public.system_roles sr ON sr.id = om.role_id
    WHERE om.user_id = v_caller_id AND om.is_active = TRUE
    ORDER BY sr.level ASC
    LIMIT 1;

    IF v_caller_role IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Privilèges insuffisants');
    END IF;

    -- Niveau du rôle cible
    SELECT level INTO v_target_level FROM public.system_roles WHERE id = p_role;
    IF v_target_level IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Rôle cible invalide');
    END IF;

    -- Anti-Élévation : Un appelant ne peut créer que des rôles de niveau strictement inférieur
    IF v_caller_level >= v_target_level AND v_caller_role <> 'super_admin' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tentative d élévation de privilège interdite');
    END IF;

    -- Cloisonnement d'organisation : un gérant de GIE ne peut créer que dans son GIE
    IF v_caller_role = 'gie_admin' THEN
        IF p_role IN ('super_admin', 'platform_admin', 'gie_admin') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Un gérant de GIE ne peut pas créer de rôles administratifs');
        END IF;
        v_target_org := v_caller_org;
    ELSE
        v_target_org := p_organization_id;
    END IF;

    -- Génération d'un identifiant pour le profil
    v_new_user_id := gen_random_uuid();

    -- Insertion dans public.app_users
    INSERT INTO public.app_users (
        id, email, phone, full_name, role, organization_id, is_active
    )
    VALUES (
        v_new_user_id,
        NULLIF(p_email, ''),
        NULLIF(p_phone, ''),
        p_full_name,
        p_role,
        v_target_org,
        TRUE
    );

    -- Insertion dans public.organization_memberships
    INSERT INTO public.organization_memberships (
        user_id, organization_id, role_id, is_active
    )
    VALUES (
        v_new_user_id,
        v_target_org,
        p_role,
        TRUE
    );

    -- Audit Log
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
            'email', p_email,
            'phone', p_phone
        )
    );

    RETURN jsonb_build_object(
        'success', true, 
        'user_id', v_new_user_id,
        'message', 'Utilisateur managé créé avec succès'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_managed_user(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;
