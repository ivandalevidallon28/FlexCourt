-- Payment deadline and player timeline access.

alter table public.reservations
  add column if not exists payment_due_at timestamp with time zone,
  add column if not exists paid_at timestamp with time zone;

create index if not exists idx_reservations_payment_due_at
  on public.reservations (payment_due_at);

-- Allow players to view their own reservation history timeline.
drop policy if exists "reservation_history_player_select_own" on public.reservation_history;
create policy "reservation_history_player_select_own"
on public.reservation_history for select
using (
  exists (
    select 1
    from public.reservations r
    where r.id = reservation_history.reservation_id
      and r.user_id = public.current_user_id()
  )
);
