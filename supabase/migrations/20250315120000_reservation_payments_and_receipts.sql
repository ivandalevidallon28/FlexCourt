-- Reservation payment proof flow:
-- - Player uploads receipt image to storage bucket "document"
-- - Receipt path + payment status is stored on reservation
-- - Admin reviews and marks INVALID / DOWNPAYMENT_PAID / PAID

alter table public.reservations
  add column if not exists payment_status text not null default 'UNPAID',
  add column if not exists payment_receipt_path text,
  add column if not exists payment_receipt_uploaded_at timestamp with time zone,
  add column if not exists payment_review_note text,
  add column if not exists payment_reviewed_by uuid references public.users(id) on delete set null,
  add column if not exists payment_reviewed_at timestamp with time zone;

alter table public.reservations
  drop constraint if exists reservations_payment_status_check;

alter table public.reservations
  add constraint reservations_payment_status_check
  check (
    payment_status in (
      'UNPAID',
      'RECEIPT_UPLOADED',
      'INVALID',
      'DOWNPAYMENT_PAID',
      'PAID'
    )
  );

create index if not exists idx_reservations_payment_status
  on public.reservations (payment_status);

-- ─────────────────────────────────────────────────────────────────────────────
-- Storage policies for bucket: document
-- Path convention: receipts/<user_id>/<reservation_id>/<file>
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "document_receipts_insert_owner" on storage.objects;
create policy "document_receipts_insert_owner"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'document'
  and split_part(name, '/', 1) = 'receipts'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists "document_receipts_update_owner" on storage.objects;
create policy "document_receipts_update_owner"
on storage.objects for update to authenticated
using (
  bucket_id = 'document'
  and split_part(name, '/', 1) = 'receipts'
  and split_part(name, '/', 2) = auth.uid()::text
)
with check (
  bucket_id = 'document'
  and split_part(name, '/', 1) = 'receipts'
  and split_part(name, '/', 2) = auth.uid()::text
);

drop policy if exists "document_receipts_select_owner_or_admin" on storage.objects;
create policy "document_receipts_select_owner_or_admin"
on storage.objects for select to authenticated
using (
  bucket_id = 'document'
  and (
    split_part(name, '/', 2) = auth.uid()::text
    or exists (
      select 1
      from public.users u
      where u.id = auth.uid()
        and u.role = 'admin'
    )
  )
);
