-- ==============================================================================
-- Migration : Synchronisation Automatique auth.users -> public.app_users & RBAC
-- Date : 2026-09-11
-- Description : Déclencheur automatique à l'inscription pour alimenter
--               le profil utilisateur public et les affiliations de rôles (RBAC).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_role_id TEXT;
    v_org_id UUID;
    v_full_name TEXT;
    v_phone TEXT;
    v_avatar_url TEXT;
BEGIN
    -- 1. Extraction tolérante des métadonnées (Google OAuth, Email/Password, Téléphone OTP)
    v_full_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'user_name',
        SPLIT_PART(NEW.email, '@', 1),
        'Voyageur Dioufy'
    );
    v_phone := COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone, '');
    v_role_id := COALESCE(NEW.raw_user_meta_data->>'role', 'passenger');
    v_avatar_url := COALESCE(
        NEW.raw_user_meta_data->>'avatar_url',
        NEW.raw_user_meta_data->>'picture'
    );
    
    -- 2. Si un organization_id est fourni (ex: GIE Thiès)
    IF (NEW.raw_user_meta_data->>'organization_id') IS NOT NULL AND (NEW.raw_user_meta_data->>'organization_id') <> '' THEN
        BEGIN
            v_org_id := (NEW.raw_user_meta_data->>'organization_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
            v_org_id := NULL;
        END;
    ELSE
        v_org_id := NULL;
    END IF;

    -- 3. Insertion ou mise à jour idempotente dans public.app_users
    INSERT INTO public.app_users (id, email, phone, full_name, role, avatar_url, created_at)
    VALUES (
        NEW.id,
        NEW.email,
        NULLIF(v_phone, ''),
        v_full_name,
        v_role_id,
        v_avatar_url,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = COALESCE(EXCLUDED.email, public.app_users.email),
        phone = COALESCE(NULLIF(EXCLUDED.phone, ''), public.app_users.phone),
        role = COALESCE(public.app_users.role, EXCLUDED.role),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.app_users.avatar_url);

    -- 4. Insertion idempotente dans public.organization_memberships pour le moteur RBAC
    BEGIN
        INSERT INTO public.organization_memberships (user_id, organization_id, role_id, is_active)
        VALUES (
            NEW.id,
            v_org_id,
            v_role_id,
            TRUE
        )
        ON CONFLICT (user_id, organization_id, role_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NEW;
END;
$$;

-- Révocation des droits publics et attribution restreinte
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- Création ou remplacement du déclencheur automatique sur auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
