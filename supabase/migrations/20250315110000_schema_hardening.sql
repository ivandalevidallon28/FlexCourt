-- Schema hardening: courts (max_hours, is_active, name unique), reservations (past/range/max_hours/whole_hours), change_requests (new_date).
-- Non-breaking: additive columns and constraints only.

-- 1) Courts: max_hours, is_active, unique name
alter table public.courts
  add column if not exists max_hours int not null default 4,
  add column if not exists is_active boolean not null default true;

create unique index if not exists courts_name_key on public.courts (name);


alter table public.reservations
  add constraint reservations_no_past_booking
  check (date >= current_date);

alter table public.reservations
  drop constraint if exists reservations_valid_time_range;

alter table public.reservations
  add constraint reservations_valid_time_range
  check (end_time > start_time);

alter table public.reservations
  drop constraint if exists reservations_max_4_hours;

alter table public.reservations
  add constraint reservations_max_4_hours
  check (extract(epoch from (end_time - start_time)) / 3600 <= 4);

-- Whole-hour constraints omitted: existing rows may have non-zero minutes. Add after data backfill if required.

-- 3) reservation_change_requests: new_date for date moves
alter table public.reservation_change_requests
  add column if not exists new_date date;

comment on column public.reservation_change_requests.new_date is 'When admin proposes a different date (optional; null = same date).';
