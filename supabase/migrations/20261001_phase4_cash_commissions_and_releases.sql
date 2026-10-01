-- ==============================================================================
-- MIGRATION PHASE 4 : CAISSES, COMMISSIONS SERVEUR ET GOUVERNANCE DES RELEASES
-- Fichier : 20261001_phase4_cash_commissions_and_releases.sql
-- Date : 01-10-2026
-- Description :
--   1. Création de la table `cash_sessions` pour persistance et audit des clôtures chauffeur/guichet.
--   2. RPC `close_cash_session` avec calcul mathématique bancaire des commissions.
--   3. Création de la table `app_releases` pour versioning applicatif forcé (minimum_supported_version).
--   4. RLS compartimenté et protection anti-falsification.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABLE : public.cash_sessions
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cash_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT,
    driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    driver_name TEXT,
    bus_id TEXT NOT NULL,
    route TEXT NOT NULL,
    session_date TEXT NOT NULL,
    total_passengers INTEGER NOT NULL DEFAULT 0,
    digital_revenue NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    cash_revenue NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    total_revenue NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    driver_commission_rate NUMERIC(5,4) NOT NULL DEFAULT 0.0500,
    coxeur_commission NUMERIC(12,2) NOT NULL DEFAULT 2000.00,
    platform_fee_rate NUMERIC(5,4) NOT NULL DEFAULT 0.0250,
    driver_commission NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    platform_fee NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    net_cash_deposit NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    status TEXT NOT NULL DEFAULT 'closed' CHECK (status IN ('open', 'closed', 'verified', 'disputed')),
    signature TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    closed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index pour requêtes performantes
CREATE INDEX IF NOT EXISTS idx_cash_sessions_driver_id ON public.cash_sessions(driver_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_bus_id ON public.cash_sessions(bus_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_closed_at ON public.cash_sessions(closed_at DESC);

-- Sécurisation RLS
ALTER TABLE public.cash_sessions ENABLE ROW LEVEL SECURITY;

-- Les chauffeurs/utilisateurs authentifiés peuvent enregistrer et consulter leurs sessions
DROP POLICY IF EXISTS "cash_sessions_select_policy" ON public.cash_sessions;
CREATE POLICY "cash_sessions_select_policy"
ON public.cash_sessions
FOR SELECT
TO authenticated
USING (
    driver_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
        AND ur.role IN ('super_admin', 'platform_admin', 'operator_admin', 'gie_agent', 'accountant')
    )
);

DROP POLICY IF EXISTS "cash_sessions_insert_policy" ON public.cash_sessions;
CREATE POLICY "cash_sessions_insert_policy"
ON public.cash_sessions
FOR INSERT
TO authenticated
WITH CHECK (
    driver_id IS NULL OR driver_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
        AND ur.role IN ('super_admin', 'platform_admin', 'operator_admin', 'gie_agent')
    )
);

DROP POLICY IF EXISTS "cash_sessions_service_role" ON public.cash_sessions;
CREATE POLICY "cash_sessions_service_role"
ON public.cash_sessions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

COMMENT ON TABLE public.cash_sessions IS '@graphql({"exclude": true})';

-- ------------------------------------------------------------------------------
-- 2. RPC ATOMIQUE : close_cash_session
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_cash_session(
    p_trip_id TEXT,
    p_bus_id TEXT,
    p_route TEXT,
    p_session_date TEXT,
    p_total_passengers INTEGER,
    p_digital_revenue NUMERIC,
    p_cash_revenue NUMERIC,
    p_driver_commission_rate NUMERIC DEFAULT 0.05,
    p_coxeur_commission NUMERIC DEFAULT 2000.0,
    p_platform_fee_rate NUMERIC DEFAULT 0.025,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_total_revenue NUMERIC(12,2);
    v_driver_commission NUMERIC(12,2);
    v_platform_fee NUMERIC(12,2);
    v_net_cash_deposit NUMERIC(12,2);
    v_driver_id UUID;
    v_driver_name TEXT;
    v_signature TEXT;
    v_session_id UUID;
    v_closed_at TIMESTAMPTZ;
BEGIN
    -- Identification du chauffeur appelant
    v_driver_id := auth.uid();
    
    -- Récupération du nom du chauffeur s'il existe dans profiles ou auth
    IF v_driver_id IS NOT NULL THEN
        SELECT COALESCE(raw_user_meta_data->>'full_name', email)
        INTO v_driver_name
        FROM auth.users
        WHERE id = v_driver_id;
    END IF;

    -- Calculs financiers stricts
    v_total_revenue := COALESCE(p_digital_revenue, 0) + COALESCE(p_cash_revenue, 0);
    v_driver_commission := round(v_total_revenue * COALESCE(p_driver_commission_rate, 0.05), 2);
    v_platform_fee := round(v_total_revenue * COALESCE(p_platform_fee_rate, 0.025), 2);
    v_net_cash_deposit := COALESCE(p_cash_revenue, 0) - v_driver_commission - COALESCE(p_coxeur_commission, 2000.0);
    v_closed_at := now();

    -- Génération de l'empreinte d'intégrité (signature sha256)
    v_signature := encode(
        digest(
            COALESCE(p_bus_id, '') || '|' ||
            COALESCE(p_route, '') || '|' ||
            v_total_revenue::text || '|' ||
            v_net_cash_deposit::text || '|' ||
            v_closed_at::text,
            'sha256'
        ),
        'hex'
    );

    -- Insertion atomique
    INSERT INTO public.cash_sessions (
        trip_id,
        driver_id,
        driver_name,
        bus_id,
        route,
        session_date,
        total_passengers,
        digital_revenue,
        cash_revenue,
        total_revenue,
        driver_commission_rate,
        coxeur_commission,
        platform_fee_rate,
        driver_commission,
        platform_fee,
        net_cash_deposit,
        signature,
        status,
        metadata,
        closed_at,
        created_at,
        updated_at
    ) VALUES (
        p_trip_id,
        v_driver_id,
        v_driver_name,
        p_bus_id,
        p_route,
        p_session_date,
        COALESCE(p_total_passengers, 0),
        COALESCE(p_digital_revenue, 0),
        COALESCE(p_cash_revenue, 0),
        v_total_revenue,
        COALESCE(p_driver_commission_rate, 0.05),
        COALESCE(p_coxeur_commission, 2000.0),
        COALESCE(p_platform_fee_rate, 0.025),
        v_driver_commission,
        v_platform_fee,
        v_net_cash_deposit,
        v_signature,
        'closed',
        COALESCE(p_metadata, '{}'::jsonb),
        v_closed_at,
        v_closed_at,
        v_closed_at
    )
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id,
        'total_revenue', v_total_revenue,
        'driver_commission', v_driver_commission,
        'coxeur_commission', COALESCE(p_coxeur_commission, 2000.0),
        'platform_fee', v_platform_fee,
        'net_cash_deposit', v_net_cash_deposit,
        'signature', v_signature,
        'closed_at', v_closed_at
    );
END;
$$;

-- Révocation anon, autorisation aux utilisateurs authentifiés et service_role
REVOKE EXECUTE ON FUNCTION public.close_cash_session FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_cash_session TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. TABLE : public.app_releases (Gouvernance et Versioning Forcé)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'all')),
    latest_version TEXT NOT NULL,
    minimum_supported_version TEXT NOT NULL,
    update_required BOOLEAN NOT NULL DEFAULT false,
    store_url TEXT,
    release_notes TEXT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index sur platform pour requêtes ultra rapides au lancement de l'app
CREATE INDEX IF NOT EXISTS idx_app_releases_platform ON public.app_releases(platform);

-- Sécurisation RLS
ALTER TABLE public.app_releases ENABLE ROW LEVEL SECURITY;

-- Tout le monde (y compris les clients non connectés) peut consulter la version supportée
DROP POLICY IF EXISTS "app_releases_public_read" ON public.app_releases;
CREATE POLICY "app_releases_public_read"
ON public.app_releases
FOR SELECT
TO anon, authenticated
USING (true);

-- Seul le service_role et les super_admin peuvent modifier les versions
DROP POLICY IF EXISTS "app_releases_admin_manage" ON public.app_releases;
CREATE POLICY "app_releases_admin_manage"
ON public.app_releases
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
        AND ur.role IN ('super_admin', 'platform_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
        AND ur.role IN ('super_admin', 'platform_admin')
    )
);

DROP POLICY IF EXISTS "app_releases_service_role" ON public.app_releases;
CREATE POLICY "app_releases_service_role"
ON public.app_releases
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Insertion idempotente des versions actuelles en production
INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
SELECT 'android', '1.0.0', '1.0.0', false, 'https://play.google.com/store/apps/details?id=com.dioufy.transport', 'Version initiale Dioufy-TS'
WHERE NOT EXISTS (SELECT 1 FROM public.app_releases WHERE platform = 'android');

INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
SELECT 'web', '1.0.0', '1.0.0', false, 'https://dioufy.sn', 'PWA Dioufy-TS'
WHERE NOT EXISTS (SELECT 1 FROM public.app_releases WHERE platform = 'web');

INSERT INTO public.app_releases (platform, latest_version, minimum_supported_version, update_required, store_url, release_notes)
SELECT 'all', '1.0.0', '1.0.0', false, 'https://dioufy.sn', 'Version globale Dioufy-TS'
WHERE NOT EXISTS (SELECT 1 FROM public.app_releases WHERE platform = 'all');
