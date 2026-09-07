-- Supabase / Postgres schema for Dioufy-TS MVP
-- IDEMPOTENCE STRATEGY:
--   1. All mutations use either idempotency_key (payments) or request_id (lock_seat, release_seat)
--   2. idempotent_requests table stores request_id + operation -> cached result
--   3. Functions check cache first BEFORE modifying state
--   4. On retry, the same booking/payment result is returned
--   5. Old requests (>24h) are purged by expire_locks() cron job
--
-- This ensures exactly-once semantics even with network retries, webhook duplicates, or client errors.

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Agencies
CREATE TABLE IF NOT EXISTS agencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Users
CREATE TABLE IF NOT EXISTS app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text,
  email text,
  full_name text,
  role text DEFAULT 'traveller', -- traveller | driver | agency_staff | admin
  agency_id uuid REFERENCES agencies(id) ON DELETE SET NULL,
  fcm_token text,
  created_at timestamptz DEFAULT now()
);

-- Trips
CREATE TABLE IF NOT EXISTS trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id uuid REFERENCES agencies(id) ON DELETE CASCADE,
  from_loc text NOT NULL,
  to_loc text NOT NULL,
  depart_at timestamptz NOT NULL,
  price integer NOT NULL,
  seats_count integer NOT NULL DEFAULT 36,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Bookings (created BEFORE seats since seats references bookings)
CREATE TABLE IF NOT EXISTS bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES app_users(id) ON DELETE SET NULL,
  trip_id uuid REFERENCES trips(id) ON DELETE CASCADE,
  seats jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'pending', -- pending | paid | cancelled
  lock_expires_at timestamptz,
  agency_id uuid REFERENCES agencies(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Seats (references bookings, so created after bookings)
CREATE TABLE IF NOT EXISTS seats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid REFERENCES trips(id) ON DELETE CASCADE,
  seat_number text NOT NULL,
  status text NOT NULL DEFAULT 'available', -- available | locked | sold
  lock_until timestamptz,
  locked_by uuid REFERENCES bookings(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (trip_id, seat_number)
);

-- Idempotent requests: track request IDs to guarantee exactly-once semantics
CREATE TABLE IF NOT EXISTS idempotent_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  operation text NOT NULL, -- 'lock_seat', 'payment', 'release_seat', etc.
  result jsonb NOT NULL, -- the response to return on retry
  created_at timestamptz DEFAULT now(),
  UNIQUE (request_id, operation)
);

-- Payments (with strong idempotence via idempotency_key)
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES bookings(id) ON DELETE CASCADE,
  amount integer NOT NULL,
  provider text,
  provider_ref text,
  status text NOT NULL DEFAULT 'pending', -- pending | successful | failed
  idempotency_key text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (idempotency_key),
  UNIQUE (provider_ref)
);

-- Tickets
CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES bookings(id) ON DELETE CASCADE,
  payload jsonb NOT NULL,
  signature text NOT NULL,
  issued_at timestamptz DEFAULT now()
);

-- Baggage
CREATE TABLE IF NOT EXISTS baggage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES bookings(id) ON DELETE CASCADE,
  photos text[] DEFAULT ARRAY[]::text[],
  id_doc text,
  status text DEFAULT 'registered',
  created_at timestamptz DEFAULT now()
);

-- Driver positions (approx updated every 60s)
CREATE TABLE IF NOT EXISTS driver_positions (
  driver_id uuid PRIMARY KEY,
  trip_id uuid REFERENCES trips(id),
  lat double precision,
  lng double precision,
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trips_agency ON trips(agency_id);
CREATE INDEX IF NOT EXISTS idx_seats_trip_status ON seats(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_trip ON bookings(trip_id);
CREATE INDEX IF NOT EXISTS idx_idempotent_requests_lookup ON idempotent_requests(request_id, operation);
CREATE INDEX IF NOT EXISTS idx_idempotent_requests_cleanup ON idempotent_requests(created_at);

-- Row Level Security: enable per-table and provide sample policies

-- Helper note: adjust the claim name used below to match your JWT claims.
-- Supabase exposes JWT claims via current_setting('jwt.claims.<claim_name>', true)

-- Enable RLS on tables that must be isolated per agency
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE seats ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Policies: allow service role (server-side) full access
CREATE POLICY service_role_full_access ON trips FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );
CREATE POLICY service_role_full_access_bookings ON bookings FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );
CREATE POLICY service_role_full_access_seats ON seats FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );
CREATE POLICY service_role_full_access_tickets ON tickets FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );

-- Policies: allow public read access for travellers (anon and authenticated)
CREATE POLICY public_read_agencies ON agencies FOR SELECT USING (true);
CREATE POLICY public_read_trips ON trips FOR SELECT USING (true);
CREATE POLICY public_read_seats ON seats FOR SELECT USING (true);
CREATE POLICY public_read_bookings ON bookings FOR SELECT USING (true);

-- Atomic seat lock function with idempotence: uses request_id to guarantee exactly-once
CREATE OR REPLACE FUNCTION lock_seat(
  p_trip_id uuid,
  p_seat_number text,
  p_user_id uuid DEFAULT NULL,
  p_lock_minutes integer DEFAULT 10,
  p_request_id text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_seat_id uuid;
  v_booking_id uuid;
  v_now timestamptz := now();
  v_lock_until timestamptz := v_now + (p_lock_minutes || ' minutes')::interval;
  v_stored_request record;
BEGIN
  -- Check if this request has already been processed
  IF p_request_id IS NOT NULL THEN
    SELECT result->'booking_id' as booking_id INTO v_stored_request
      FROM idempotent_requests
      WHERE request_id = p_request_id AND operation = 'lock_seat';
    
    -- If found, return the cached result
    IF FOUND THEN
      RETURN (v_stored_request.booking_id)::uuid;
    END IF;
  END IF;

  -- find seat and lock row for update (or create it on the fly if not exists)
  SELECT id INTO v_seat_id FROM seats
    WHERE trip_id = p_trip_id AND seat_number = p_seat_number
    FOR UPDATE;

  IF v_seat_id IS NULL THEN
    INSERT INTO seats (trip_id, seat_number, status)
      VALUES (p_trip_id, p_seat_number, 'available')
      ON CONFLICT (trip_id, seat_number) DO NOTHING
      RETURNING id INTO v_seat_id;

    IF v_seat_id IS NULL THEN
      SELECT id INTO v_seat_id FROM seats
        WHERE trip_id = p_trip_id AND seat_number = p_seat_number
        FOR UPDATE;
    END IF;
  END IF;

  -- check availability (allow if available or locked but expired)
  PERFORM 1 FROM seats WHERE id = v_seat_id AND (
    status = 'available' OR (status = 'locked' AND (lock_until IS NULL OR lock_until < v_now))
  );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seat not available';
  END IF;

  -- create booking
  INSERT INTO bookings (user_id, trip_id, seats, status, lock_expires_at, agency_id)
  VALUES (p_user_id, p_trip_id, to_jsonb(ARRAY[p_seat_number]::text[]), 'pending', v_lock_until,
          (SELECT agency_id FROM trips WHERE id = p_trip_id))
  RETURNING id INTO v_booking_id;

  -- update seat to locked and reference booking
  UPDATE seats SET status = 'locked', lock_until = v_lock_until, locked_by = v_booking_id
    WHERE id = v_seat_id;

  -- Store the idempotent request result
  IF p_request_id IS NOT NULL THEN
    INSERT INTO idempotent_requests (request_id, operation, result)
      VALUES (p_request_id, 'lock_seat', jsonb_build_object('booking_id', v_booking_id))
      ON CONFLICT DO NOTHING;
  END IF;

  RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Release seat with idempotence: safe to call multiple times
CREATE OR REPLACE FUNCTION release_seat(
  p_booking_id uuid,
  p_request_id text DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_stored_request record;
BEGIN
  -- Check if this request has already been processed
  IF p_request_id IS NOT NULL THEN
    SELECT 1 INTO v_stored_request
      FROM idempotent_requests
      WHERE request_id = p_request_id AND operation = 'release_seat';
    
    -- If found, return early (already processed)
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;

  UPDATE seats
    SET status = 'available', lock_until = NULL, locked_by = NULL
    WHERE locked_by = p_booking_id AND status = 'locked';

  UPDATE bookings SET status = 'cancelled' WHERE id = p_booking_id AND status = 'pending';

  -- Store the idempotent request result
  IF p_request_id IS NOT NULL THEN
    INSERT INTO idempotent_requests (request_id, operation, result)
      VALUES (p_request_id, 'release_seat', '{}')
      ON CONFLICT DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Periodic expiration: clear any seat locks that have passed their lock_until
CREATE OR REPLACE FUNCTION expire_locks() RETURNS void AS $$
BEGIN
  UPDATE seats
    SET status = 'available', lock_until = NULL, locked_by = NULL
    WHERE status = 'locked' AND lock_until IS NOT NULL AND lock_until < now();
  -- mark bookings as cancelled
  UPDATE bookings SET status = 'cancelled' WHERE status = 'pending' AND lock_expires_at < now();
  -- clean up old idempotent request records (older than 24h)
  DELETE FROM idempotent_requests WHERE created_at < now() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Confirmation atomique et idempotente du paiement et libération/validation des billets
CREATE OR REPLACE FUNCTION confirm_payment(
  p_booking_id uuid,
  p_provider text DEFAULT 'Wave',
  p_provider_ref text DEFAULT NULL,
  p_amount integer DEFAULT 0,
  p_ticket_signature text DEFAULT ''
) RETURNS jsonb AS $$
DECLARE
  v_payment_id uuid;
  v_idempotency_key text;
BEGIN
  v_idempotency_key := COALESCE(p_provider_ref, 'pay_' || p_booking_id::text);

  -- 1. Inserer le paiement s'il n'existe pas deja (idempotent)
  INSERT INTO payments (booking_id, amount, provider, provider_ref, status, idempotency_key)
  VALUES (p_booking_id, p_amount, p_provider, p_provider_ref, 'successful', v_idempotency_key)
  ON CONFLICT (idempotency_key) DO UPDATE SET status = 'successful'
  RETURNING id INTO v_payment_id;

  -- 2. Passer la reservation a 'paid'
  UPDATE bookings SET status = 'paid' WHERE id = p_booking_id;

  -- 3. Passer les sieges a 'sold'
  UPDATE seats SET status = 'sold', lock_until = NULL WHERE locked_by = p_booking_id;

  RETURN jsonb_build_object('success', true, 'payment_id', v_payment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION confirm_payment(uuid, text, text, integer, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION lock_seat(uuid, text, uuid, integer, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION release_seat(uuid, text) TO anon, authenticated, service_role;

-- ===================================================================
-- SEED INITIAL (Données de démonstration pour MVP Dioufy-TS)
-- ===================================================================
DO $$
BEGIN
  -- Agences de transport
  INSERT INTO agencies (id, name, metadata)
    VALUES ('a0000000-0000-0000-0000-000000000001', 'Dioufy Trans', '{"verified": true}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO agencies (id, name, metadata)
    VALUES ('a0000000-0000-0000-0000-000000000002', 'Galsen Tour', '{"verified": true}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO agencies (id, name, metadata)
    VALUES ('a0000000-0000-0000-0000-000000000003', 'Touba Express', '{"verified": true}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  -- Trajets Dakar -> Thiès
  INSERT INTO trips (id, agency_id, from_loc, to_loc, depart_at, price, seats_count, metadata)
    VALUES ('t0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Dakar', 'Thiès', now() + interval '2 hours', 7500, 36, '{"type": "CONFORT"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO trips (id, agency_id, from_loc, to_loc, depart_at, price, seats_count, metadata)
    VALUES ('t0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'Dakar', 'Thiès', now() + interval '4 hours', 4500, 36, '{"type": "STANDARD"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO trips (id, agency_id, from_loc, to_loc, depart_at, price, seats_count, metadata)
    VALUES ('t0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'Dakar', 'Thiès', now() + interval '6 hours', 8200, 36, '{"type": "CONFORT"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  -- Trajets Dakar -> Touba
  INSERT INTO trips (id, agency_id, from_loc, to_loc, depart_at, price, seats_count, metadata)
    VALUES ('t0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Dakar', 'Touba', now() + interval '3 hours', 12500, 36, '{"type": "CONFORT"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO trips (id, agency_id, from_loc, to_loc, depart_at, price, seats_count, metadata)
    VALUES ('t0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000003', 'Dakar', 'Touba', now() + interval '5 hours', 9500, 36, '{"type": "STANDARD"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

  -- Sièges déjà vendus de démonstration
  INSERT INTO seats (trip_id, seat_number, status)
    VALUES 
      ('t0000000-0000-0000-0000-000000000001', 'A3', 'sold'),
      ('t0000000-0000-0000-0000-000000000001', 'B2', 'sold'),
      ('t0000000-0000-0000-0000-000000000001', 'C5', 'sold'),
      ('t0000000-0000-0000-0000-000000000001', 'D1', 'sold')
    ON CONFLICT (trip_id, seat_number) DO NOTHING;
END;
$$;
