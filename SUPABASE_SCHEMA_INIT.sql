-- ===================================================================
-- SUPABASE SCHEMA INITIALIZATION SCRIPT FOR DIOUFY-TS MVP
-- ===================================================================
-- Copy & paste this entire script into Supabase SQL Editor at:
-- https://supabase.com/dashboard/project/yrarlatdoulyfyjpqzlp/sql/new
-- Then click "Run"
-- ===================================================================

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
  role text DEFAULT 'traveller',
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
  status text NOT NULL DEFAULT 'pending',
  lock_expires_at timestamptz,
  agency_id uuid REFERENCES agencies(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Seats (references bookings, so created after bookings)
CREATE TABLE IF NOT EXISTS seats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid REFERENCES trips(id) ON DELETE CASCADE,
  seat_number text NOT NULL,
  status text NOT NULL DEFAULT 'available',
  lock_until timestamptz,
  locked_by uuid REFERENCES bookings(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE (trip_id, seat_number)
);

-- Idempotent requests: track request IDs to guarantee exactly-once semantics
CREATE TABLE IF NOT EXISTS idempotent_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  operation text NOT NULL,
  result jsonb NOT NULL,
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
  status text NOT NULL DEFAULT 'pending',
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

-- Enable RLS on tables that must be isolated per agency
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE seats ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Policy: allow service role (server-side) full read/write access
CREATE POLICY service_role_full_access ON trips FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );
CREATE POLICY service_role_full_access_bookings ON bookings FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );
CREATE POLICY service_role_full_access_seats ON seats FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );
CREATE POLICY service_role_full_access_tickets ON tickets FOR ALL USING ( current_setting('request.jwt.claims.role', true) = 'service_role' );

-- Atomic seat lock function with idempotence
CREATE OR REPLACE FUNCTION lock_seat(
  p_trip_id uuid,
  p_seat_number text,
  p_user_id uuid,
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

  -- find seat and lock row for update
  SELECT id INTO v_seat_id FROM seats
    WHERE trip_id = p_trip_id AND seat_number = p_seat_number
    FOR UPDATE;

  IF v_seat_id IS NULL THEN
    RAISE EXCEPTION 'Seat not found';
  END IF;

  -- check availability
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

-- Release seat with idempotence
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
