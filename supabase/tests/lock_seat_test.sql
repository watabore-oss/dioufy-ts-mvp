-- Test script for lock_seat function
-- Creates a temporary trip/seat and runs two parallel transactions attempting the same seat.

BEGIN;
-- prepare data
INSERT INTO agencies (name) VALUES ('test agency') RETURNING id INTO temp_trip_agency;
INSERT INTO trips (agency_id, from_loc, to_loc, depart_at, price, seats_count)
  VALUES (temp_trip_agency, 'Dakar', 'Thi\xe8s', now()+interval '1 hour', 1000, 4)
  RETURNING id INTO temp_trip;
INSERT INTO seats (trip_id, seat_number) VALUES (temp_trip, 'A1');
COMMIT;

-- Session 1
\echo 'Starting session1';
BEGIN;
SELECT lock_seat(temp_trip, 'A1', gen_random_uuid());
-- no commit, hold lock for a moment
\echo 'Session1 locked';
\sleep 2
COMMIT;
\echo 'Session1 committed';

-- Session 2
\echo 'Starting session2';
BEGIN;
-- should fail since seat locked by session1 until commit
SELECT lock_seat(temp_trip, 'A1', gen_random_uuid());
COMMIT;
\echo 'Session2 committed';

-- cleanup
DELETE FROM seats WHERE trip_id = temp_trip;
DELETE FROM trips WHERE id = temp_trip;
DELETE FROM agencies WHERE id = temp_trip_agency;
