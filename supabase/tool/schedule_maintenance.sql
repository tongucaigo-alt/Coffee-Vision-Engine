-- Apply only after Founder deployment approval. Store actual secrets in Vault first.
-- Required Vault names: atlas_project_url and atlas_maintenance_secret.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.schedule('atlas-contribution-hourly-cleanup','0 * * * *', $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='atlas_project_url') || '/functions/v1/contribution-api',
    headers := jsonb_build_object('Content-Type','application/json','Authorization',
      'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='atlas_maintenance_secret')),
    body := '{"action":"maintenance"}'::jsonb,
    timeout_milliseconds := 50000
  );
$job$);
