-- Fix token upsert RLS failures on ON CONFLICT(token) updates.
-- Allow authenticated users to update conflicting token rows, but enforce
-- that final row ownership is always the current user.

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;

create policy "user_push_tokens_update_own"
on public.user_push_tokens for update
using (auth.role() = 'authenticated')
with check (user_id = public.current_user_id());
