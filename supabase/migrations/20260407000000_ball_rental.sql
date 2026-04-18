-- Ball rental: inventory, per-session rentals (₱100, unlimited time), rent/return RPCs.

create table if not exists public.balls (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'AVAILABLE'
    check (status in ('AVAILABLE', 'IN_USE')),
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists balls_name_key on public.balls (name);

create table if not exists public.ball_rentals (
  id uuid primary key default gen_random_uuid(),
  ball_id uuid not null references public.balls (id) on delete restrict,
  user_id uuid not null references public.users (id) on delete cascade,
  amount integer not null default 100 check (amount = 100),
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'COMPLETED')),
  paid_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  returned_at timestamptz
);

create unique index if not exists ball_rentals_one_active_per_ball
  on public.ball_rentals (ball_id)
  where status = 'ACTIVE';

create index if not exists idx_ball_rentals_user_status
  on public.ball_rentals (user_id, status);

alter table public.balls enable row level security;
alter table public.ball_rentals enable row level security;

drop policy if exists "balls_select_authenticated" on public.balls;
create policy "balls_select_authenticated"
on public.balls for select
using (auth.role() = 'authenticated');

drop policy if exists "balls_admin_all" on public.balls;
create policy "balls_admin_all"
on public.balls for all
using (
  exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and lower(trim(u.role)) = 'admin'
  )
);

drop policy if exists "ball_rentals_select_own_or_admin" on public.ball_rentals;
create policy "ball_rentals_select_own_or_admin"
on public.ball_rentals for select
using (
  user_id = public.current_user_id()
  or exists (
    select 1 from public.users u
    where u.id = public.current_user_id()
      and lower(trim(u.role)) = 'admin'
  )
);

-- Mutations only through security definer RPCs (or admin on balls).

create or replace function public.rent_ball(p_ball_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rental_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  update public.balls
  set status = 'IN_USE'
  where id = p_ball_id and status = 'AVAILABLE';
  if not found then
    raise exception 'Ball is not available for rental';
  end if;

  insert into public.ball_rentals (ball_id, user_id, amount, status, paid_at)
  values (p_ball_id, v_uid, 100, 'ACTIVE', timezone('utc', now()))
  returning id into v_rental_id;

  return v_rental_id;
end;
$$;

create or replace function public.return_ball(p_rental_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ball_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.ball_rentals r
  set status = 'COMPLETED',
      returned_at = timezone('utc', now())
  where r.id = p_rental_id
    and r.status = 'ACTIVE'
    and r.user_id = auth.uid()
  returning r.ball_id into v_ball_id;

  if v_ball_id is null then
    raise exception 'Only the renter can return this active rental';
  end if;

  update public.balls
  set status = 'AVAILABLE'
  where id = v_ball_id;
end;
$$;

grant execute on function public.rent_ball(uuid) to authenticated;
grant execute on function public.return_ball(uuid) to authenticated;

insert into public.balls (name, status)
values
  ('Ball #1', 'AVAILABLE'),
  ('Ball #2', 'AVAILABLE'),
  ('Ball #3', 'AVAILABLE')
on conflict (name) do nothing;
