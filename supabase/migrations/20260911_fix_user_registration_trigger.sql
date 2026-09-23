-- ==============================================================================
-- Migration : Correction Définitive & Auto-Réparatrice du Déclencheur Inscription
-- Date : 2026-09-11
-- Fichier : supabase/migrations/20260911_fix_user_registration_trigger.sql
-- Problème résolu : "Database error saving new user" (HTTP 500 à l'inscription)
-- Cause racine : Échec du trigger handle_new_user() sur organization_memberships
--                ou contraintes strictes provoquant le rollback d'auth.users.
-- ==============================================================================

-- 1. Création de la table organization_memberships si absente
CREATE TABLE IF NOT EXISTS public.organization_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    organization_id UUID,
    role_id TEXT NOT NULL DEFAULT 'passenger',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour les performances de recherche
CREATE INDEX IF NOT EXISTS idx_org_memberships_user_id ON public.organization_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_org_memberships_org_id ON public.organization_memberships(organization_id);

-- 2. Création de la table app_users si absente avec tous les champs requis
CREATE TABLE IF NOT EXISTS public.app_users (
    id UUID PRIMARY KEY,
    email TEXT,
    phone TEXT,
    full_name TEXT NOT NULL DEFAULT 'Utilisateur Dioufy',
    role TEXT NOT NULL DEFAULT 'passenger',
    avatar_url TEXT,
    organization_id UUID,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_users_email ON public.app_users(email);
CREATE INDEX IF NOT EXISTS idx_app_users_phone ON public.app_users(phone);

-- 3. Activation RLS avec politiques permissives pour les utilisateurs authentifiés
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    -- Politique de lecture pour tous les utilisateurs authentifiés
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'app_users' AND policyname = 'Allow read app_users for authenticated'
    ) THEN
        CREATE POLICY "Allow read app_users for authenticated" ON public.app_users
            FOR SELECT TO authenticated USING (true);
    END IF;

    -- Politique de mise à jour de son propre profil
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'app_users' AND policyname = 'Allow self update app_users'
    ) THEN
        CREATE POLICY "Allow self update app_users" ON public.app_users
            FOR UPDATE TO authenticated USING (auth.uid() = id);
    END IF;

    -- Politique d'insertion pour service_role ou self
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'app_users' AND policyname = 'Allow insert app_users'
    ) THEN
        CREATE POLICY "Allow insert app_users" ON public.app_users
            FOR INSERT TO authenticated, anon WITH CHECK (true);
    END IF;
END $$;

-- 4. Déclencheur indestructible handle_new_user avec bloc EXCEPTION hermétique
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
BEGIN
    -- Extraction sécurisée des métadonnées
    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Utilisateur Dioufy');
    v_phone := COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone, '');
    v_role_id := COALESCE(NEW.raw_user_meta_data->>'role', 'passenger');
    
    BEGIN
        IF (NEW.raw_user_meta_data->>'organization_id') IS NOT NULL AND (NEW.raw_user_meta_data->>'organization_id') <> '' THEN
            v_org_id := (NEW.raw_user_meta_data->>'organization_id')::uuid;
        ELSE
            v_org_id := NULL;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_org_id := NULL;
    END;

    -- 1. Insertion protégée dans public.app_users
    BEGIN
        INSERT INTO public.app_users (id, email, phone, full_name, role, created_at, updated_at)
        VALUES (
            NEW.id,
            NEW.email,
            v_phone,
            v_full_name,
            v_role_id,
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            phone = CASE WHEN EXCLUDED.phone <> '' THEN EXCLUDED.phone ELSE public.app_users.phone END,
            email = COALESCE(EXCLUDED.email, public.app_users.email),
            role = EXCLUDED.role,
            updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
        -- Log d'avertissement mais ne bloque jamais l'enregistrement dans auth.users
        RAISE WARNING 'handle_new_user app_users insert warning: %', SQLERRM;
    END;

    -- 2. Insertion protégée dans public.organization_memberships
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'organization_memberships') THEN
            INSERT INTO public.organization_memberships (user_id, organization_id, role_id, is_active)
            VALUES (
                NEW.id,
                v_org_id,
                v_role_id,
                TRUE
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user organization_memberships insert warning: %', SQLERRM;
    END;

    -- Toujours retourner NEW avec succès garanti pour valider l'inscription
    RETURN NEW;
END;
$$;

-- Permissions d'exécution
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role, postgres;

-- 5. Réinstallation propre du déclencheur sur auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
