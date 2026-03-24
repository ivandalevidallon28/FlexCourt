-- Store per-device FCM tokens for push delivery.

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null unique,
  platform text,
  updated_at timestamp with time zone not null default timezone('utc', now()),
  created_at timestamp with time zone not null default timezone('utc', now())
);

create index if not exists idx_user_push_tokens_user_id
  on public.user_push_tokens(user_id);

alter table public.user_push_tokens enable row level security;

drop policy if exists "user_push_tokens_select_own_or_admin" on public.user_push_tokens;
create policy "user_push_tokens_select_own_or_admin"
on public.user_push_tokens for select
using (
  user_id = public.current_user_id()
  or exists (
    select 1 from public.users u
    where u.id = public.current_user_id() and u.role = 'admin'
  )
);

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
on public.user_push_tokens for insert
with check (user_id = public.current_user_id());

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
create policy "user_push_tokens_update_own"
on public.user_push_tokens for update
using (user_id = public.current_user_id())
with check (user_id = public.current_user_id());

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
on public.user_push_tokens for delete
using (user_id = public.current_user_id());
