-- Dioufy-TS MVP schema (base)

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'passenger' check (role in ('passenger','driver','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  departure_city text not null,
  arrival_city text not null,
  departure_time timestamptz not null,
  price_xof int not null check (price_xof > 0),
  total_seats int not null default 40 check (total_seats > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.seats (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  seat_number text not null,
  status text not null default 'available' check (status in ('available','held','booked')),
  unique (trip_id, seat_number)
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid not null references public.trips(id) on delete cascade,
  seat_id uuid not null references public.seats(id) on delete restrict,
  amount_xof int not null check (amount_xof > 0),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.seats enable row level security;
alter table public.bookings enable row level security;

-- Policies MVP (a durcir avant prod)
create policy if not exists "profiles_self_select" on public.profiles
for select to authenticated using (auth.uid() = id);

create policy if not exists "profiles_self_upsert" on public.profiles
for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy if not exists "trips_read_all" on public.trips
for select to anon, authenticated using (true);

create policy if not exists "seats_read_all" on public.seats
for select to anon, authenticated using (true);

create policy if not exists "bookings_owner" on public.bookings
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
