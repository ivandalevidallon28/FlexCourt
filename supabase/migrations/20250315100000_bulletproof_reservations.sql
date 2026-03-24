-- Bulletproof reservations: history, COMPLETED/EXPIRED, DB-level no-double-booking, optional state transition check.
-- Run after existing migrations.

-- 1) Extend reservation status to include COMPLETED and EXPIRED
alter table public.reservations
  drop constraint if exists reservations_status_check;

alter table public.reservations
  add constraint reservations_status_check
  check (status in ('PENDING','APPROVED','REJECTED','CANCELLED','ADMIN','COMPLETED','EXPIRED'));

-- 2) Reservation history for full audit trail (immutable log)
create table if not exists public.reservation_history (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  changed_at timestamp with time zone default timezone('utc', now()),
  changed_by uuid references public.users(id) on delete set null,
  old_status text,
  new_status text,
  old_date date,
  new_date date,
  old_start_time time,
  new_start_time time,
  old_end_time time,
  new_end_time time,
  notes text
);

create index if not exists idx_reservation_history_reservation_id
  on public.reservation_history (reservation_id);
create index if not exists idx_reservation_history_changed_at
  on public.reservation_history (changed_at);

alter table public.reservation_history enable row level security;

-- Only admin can read history (audit); inserts are from triggers/service_role.
create policy "reservation_history_admin_select"
  on public.reservation_history for select
  using (
    exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'admin'
    )
  );

-- Allow insert from authenticated (trigger runs as table owner; RLS with check for insert often needs service_role or definer)
-- For trigger-driven inserts we use SECURITY DEFINER in a function, so no policy needed for insert from trigger.
create policy "reservation_history_insert_authenticated"
  on public.reservation_history for insert
  with check (true);

-- 3) Trigger: log status and time changes into reservation_history
create or replace function public.reservation_history_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.reservation_history (
      reservation_id, changed_by, new_status, new_date, new_start_time, new_end_time, notes
    )
    values (
      NEW.id, auth.uid(), NEW.status, NEW.date, NEW.start_time, NEW.end_time,
      'Created'
    );
    return NEW;
  elsif TG_OP = 'UPDATE' then
    if OLD.status is distinct from NEW.status
       or OLD.date is distinct from NEW.date
       or OLD.start_time is distinct from NEW.start_time
       or OLD.end_time is distinct from NEW.end_time then
      insert into public.reservation_history (
        reservation_id, changed_by,
        old_status, new_status,
        old_date, new_date,
        old_start_time, new_start_time,
        old_end_time, new_end_time,
        notes
      )
      values (
        NEW.id, auth.uid(),
        OLD.status, NEW.status,
        OLD.date, NEW.date,
        OLD.start_time, NEW.start_time,
        OLD.end_time, NEW.end_time,
        'Updated'
      );
    end if;
    return NEW;
  end if;
  return NULL;
end;
$$;

drop trigger if exists reservation_history_trigger on public.reservations;
create trigger reservation_history_trigger
  after insert or update on public.reservations
  for each row execute function public.reservation_history_log();

-- 4) Database-level no-double-booking: raise if overlap exists on INSERT or UPDATE
create or replace function public.reservations_assert_no_overlap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_overlaps boolean;
begin
  if NEW.start_time >= NEW.end_time then
    raise exception 'Start time must be before end time';
  end if;

  select exists (
    select 1
    from public.reservations r
    where r.court_id = NEW.court_id
      and r.date = NEW.date
      and r.status in ('PENDING','APPROVED','ADMIN')
      and (NEW.start_time < r.end_time and NEW.end_time > r.start_time)
      and (TG_OP = 'INSERT' or r.id <> NEW.id)
  ) into v_overlaps;

  if v_overlaps then
    raise exception 'Double booking not allowed: this court and time slot are already reserved.'
      using errcode = 'P0001';
  end if;

  return NEW;
end;
$$;

drop trigger if exists reservations_no_double_booking on public.reservations;
create trigger reservations_no_double_booking
  before insert or update of court_id, date, start_time, end_time, status
  on public.reservations
  for each row execute function public.reservations_assert_no_overlap();

-- 5) Optional: valid status transitions (relaxed to allow current app behavior)
-- Uncomment and tune if you want to enforce only specific transitions.
/*
create or replace function public.reservations_validate_status_transition()
returns trigger
language plpgsql
as $$
constraint
  valid_from_pending   : PENDING   -> APPROVED | REJECTED | CANCELLED
  valid_from_approved : APPROVED  -> COMPLETED | CANCELLED
  valid_from_admin    : ADMIN     -> CANCELLED (or same as APPROVED)
  others terminal
begin
  if OLD.status = NEW.status then
    return NEW;
  end if;
  case OLD.status
    when 'PENDING' then
      if NEW.status not in ('APPROVED','REJECTED','CANCELLED') then
        raise exception 'Invalid transition from PENDING to %', NEW.status;
      end if;
    when 'APPROVED','ADMIN' then
      if NEW.status not in ('COMPLETED','CANCELLED') then
        raise exception 'Invalid transition from % to %', OLD.status, NEW.status;
      end if;
    when 'REJECTED','CANCELLED','COMPLETED','EXPIRED' then
      raise exception 'Cannot change status from terminal state %', OLD.status;
    else
      null;
  end case;
  return NEW;
end;
$$;
drop trigger if exists reservations_status_transition on public.reservations;
create trigger reservations_status_transition
  before update on public.reservations
  for each row execute function public.reservations_validate_status_transition();
*/
