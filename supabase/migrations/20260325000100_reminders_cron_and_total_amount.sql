-- Add total_amount for pricing transparency/future extensibility.
alter table public.reservations
  add column if not exists total_amount numeric;

update public.reservations
set total_amount = price
where total_amount is null;

-- Keep compatibility while app transitions to total_amount.
create or replace function public.sync_reservation_total_amount()
returns trigger
language plpgsql
as $$
begin
  if new.total_amount is null and new.price is not null then
    new.total_amount := new.price;
  end if;
  if new.price is null and new.total_amount is not null then
    new.price := new.total_amount;
  end if;
  return new;
end;
$$;

drop trigger if exists reservations_sync_total_amount_trigger on public.reservations;
create trigger reservations_sync_total_amount_trigger
before insert or update on public.reservations
for each row execute function public.sync_reservation_total_amount();

-- Schedule send_reminder every 15 minutes using pg_cron + pg_net.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

do $$
declare
  v_job_name text := 'send-reminder-every-15-min';
  v_project_url text;
  v_anon_key text;
begin
  begin
    select decrypted_secret into v_project_url
    from vault.decrypted_secrets
    where name = 'project_url'
    limit 1;

    select decrypted_secret into v_anon_key
    from vault.decrypted_secrets
    where name = 'anon_key'
    limit 1;
  exception
    when undefined_table then
      raise notice 'vault.decrypted_secrets not available; skipping reminder cron schedule';
      return;
  end;

  if v_project_url is null or v_anon_key is null then
    raise notice 'project_url/anon_key secrets missing; skipping reminder cron schedule';
    return;
  end if;

  begin
    perform cron.unschedule(v_job_name);
  exception
    when others then
      -- No existing job yet.
      null;
  end;

  perform cron.schedule(
    v_job_name,
    '*/15 * * * *',
    format(
      $f$
      select
        net.http_post(
          url := '%s/functions/v1/send_reminder',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer %s'
          ),
          body := '{}'::jsonb
        ) as request_id;
      $f$,
      v_project_url,
      v_anon_key
    )
  );
end $$;
