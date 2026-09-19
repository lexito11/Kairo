-- =============================================================================
-- KAIRO — Moderation hardening (run AFTER 029, 030, 031)
-- Safe to re-run. Does not drop data. Does not change the text policy.
-- Does NOT flip the media bucket to private automatically.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 027/028 must never weaken 029: always delegate when kairo_text exists
-- ---------------------------------------------------------------------------
create or replace function public.group_text_is_blocked(p_text text)
returns boolean
language plpgsql
stable
as $$
begin
  if to_regprocedure('public.kairo_text_is_blocked(text)') is not null then
    return public.kairo_text_is_blocked(p_text);
  end if;
  return coalesce(p_text, '') ~* '(porn|xxx|onlyfans|nsfw|hentai|nudes?|nudity|naked|desnud[oa]s?|bikini|lencer[ií]a|ropa interior|underwear|sexting|sexualiz|expl[ií]cit[oa]|contenido sexual)';
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin email: no hardcoded address. Empty = skip send.
-- ---------------------------------------------------------------------------
insert into public.kairo_platform_settings (key, value)
values
  ('admin_alert_email', ''),
  ('moderation_worker_url', ''),
  ('moderation_job_secret', '')
on conflict (key) do nothing;

create or replace function public.kairo_build_admin_block_email(p_user_id uuid)
returns table(subject text, body text, to_email text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user public.users%rowtype;
  v_lines text := '';
  v_inf record;
  v_to text;
begin
  select * into v_user from public.users where id = p_user_id;
  if not found then
    return;
  end if;

  select s.value into v_to
  from public.kairo_platform_settings s
  where s.key = 'admin_alert_email';
  v_to := btrim(coalesce(v_to, ''));

  for v_inf in
    select i.id, i.content_type, i.content_id, i.category, i.reason, i.created_at, i.media_ref
    from public.content_infractions i
    where i.user_id = p_user_id
    order by i.created_at
  loop
    v_lines := v_lines
      || E'\n- Infraccion ' || v_inf.id::text
      || E'\n  categoria: ' || v_inf.category
      || E'\n  motivo: ' || v_inf.reason
      || E'\n  fecha: ' || to_char(v_inf.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') || ' UTC'
      || E'\n  contenido: ' || v_inf.content_type || ' / ' || v_inf.content_id::text
      || case
           when v_inf.media_ref is not null and v_inf.media_ref <> ''
           then E'\n  referencia media: ' || v_inf.media_ref
           else ''
         end;
  end loop;

  subject := 'KAIRO: cuenta bloqueada automaticamente (4 infracciones)';
  body :=
    'Una cuenta fue bloqueada automaticamente por alcanzar 4 infracciones confirmadas.'
    || E'\n\nIdentificador: ' || v_user.id::text
    || E'\nNombre: ' || coalesce(v_user.name, '(no disponible)')
    || E'\nUsuario: ' || coalesce(v_user.username, '(no disponible)')
    || E'\nCorreo: ' || coalesce(v_user.email, '(no disponible)')
    || E'\nFecha y hora del bloqueo: '
    || to_char(coalesce(v_user.blocked_at, now()) at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') || ' UTC'
    || E'\nNumero total de infracciones: 4'
    || E'\nEstado actual de la cuenta: BLOQUEADA'
    || E'\nMotivo del bloqueo: 4 infracciones acumuladas'
    || E'\n\nHistorial de infracciones (referencias seguras, sin contenido sensible):'
    || v_lines
    || E'\n\nRevisa el caso en el panel administrativo de KAIRO.';
  to_email := v_to;
  return next;
end;
$$;

create or replace function public.kairo_queue_admin_notice(
  p_kind text,
  p_subject text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_to text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if coalesce(btrim(p_kind), '') = '' or coalesce(btrim(p_subject), '') = '' then
    return null;
  end if;

  select s.value into v_to
  from public.kairo_platform_settings s
  where s.key = 'admin_alert_email';
  v_to := btrim(coalesce(v_to, ''));
  if v_to = '' or position('@' in v_to) = 0 then
    return null;
  end if;

  insert into public.admin_email_outbox (
    user_id, kind, subject, body, to_email, status
  ) values (
    v_uid, left(p_kind, 120), p_subject, coalesce(p_body, ''), v_to, 'pending'
  )
  on conflict (user_id, kind) do update
    set subject = excluded.subject,
        body = excluded.body,
        to_email = excluded.to_email,
        status = 'pending',
        last_error = null
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.list_pending_admin_emails()
returns setof public.admin_email_outbox
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  return query
  select *
  from public.admin_email_outbox
  where status in ('pending', 'failed', 'sending')
    and position('@' in coalesce(to_email, '')) > 0
  order by created_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage path extract + delete (public URL, signed URL, raw path)
-- Does not change bucket visibility.
-- ---------------------------------------------------------------------------
create or replace function public.kairo_extract_storage_paths(p_media text)
returns text[]
language plpgsql
immutable
as $$
declare
  v_paths text[] := '{}';
  v_json jsonb;
  v_elem jsonb;
  v_url text;
  v_path text;
begin
  if p_media is null or btrim(p_media) = '' then
    return v_paths;
  end if;

  begin
    v_json := p_media::jsonb;
  exception
    when others then
      v_json := null;
  end;

  if v_json is not null and jsonb_typeof(v_json) = 'array' then
    for v_elem in select * from jsonb_array_elements(v_json)
    loop
      v_paths := v_paths || public.kairo_extract_storage_paths(v_elem #>> '{}');
    end loop;
    return v_paths;
  end if;

  if v_json is not null and jsonb_typeof(v_json) = 'string' then
    return public.kairo_extract_storage_paths(v_json #>> '{}');
  end if;

  v_url := split_part(split_part(btrim(p_media), '#', 1), '?', 1);
  if v_url ~ '/object/(public|sign|authenticated)/media/' then
    v_path := regexp_replace(v_url, '^.*/object/(public|sign|authenticated)/media/', '');
  elsif position('/storage/v1/object/public/media/' in v_url) > 0 then
    v_path := split_part(v_url, '/storage/v1/object/public/media/', 2);
  elsif v_url like 'media/%' then
    v_path := substr(v_url, 7);
  else
    v_path := v_url;
  end if;

  v_path := btrim(v_path);
  v_path := replace(replace(replace(v_path, '%2F', '/'), '%2f', '/'), '%20', ' ');
  if v_path <> '' and v_path not like 'http%' then
    v_paths := array_append(v_paths, v_path);
  end if;
  return v_paths;
end;
$$;

create or replace function public.kairo_delete_storage_objects(p_media text)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_paths text[];
  v_path text;
  v_deleted int := 0;
  v_error text := null;
begin
  v_paths := public.kairo_extract_storage_paths(p_media);
  if v_paths is null or array_length(v_paths, 1) is null then
    return jsonb_build_object('deleted', 0, 'error', null);
  end if;

  begin
    foreach v_path in array v_paths
    loop
      delete from storage.objects
      where bucket_id = 'media'
        and name in (v_path, replace(v_path, '%20', ' '));
      if found then
        v_deleted := v_deleted + 1;
      end if;
    end loop;
  exception
    when others then
      v_error := sqlerrm;
  end;

  return jsonb_build_object('deleted', v_deleted, 'error', v_error);
end;
$$;

-- Optional: flip media to private AFTER the app can sign URLs.
-- Not executed automatically (would break existing public Image.network links).
create or replace function public.kairo_set_media_bucket_private()
returns text
language plpgsql
security definer
set search_path = public, storage
as $$
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;

  update storage.buckets
  set public = false
  where id = 'media';

  if not found then
    return 'media_bucket_missing';
  end if;
  return 'media_bucket_private';
end;
$$;

-- ---------------------------------------------------------------------------
-- OCR / vision text check (same 029 policy; no new word lists)
-- ---------------------------------------------------------------------------
create or replace function public.kairo_text_violates_policy(p_text text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if to_regprocedure('public.kairo_text_is_blocked(text)') is null then
    return false;
  end if;
  return public.kairo_text_is_blocked(p_text);
end;
$$;

-- Text cron: do not rewrite the same media row every minute.
create or replace function public.process_moderation_text_batch(p_limit integer default 25)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.moderation_queue%rowtype;
  v_n integer := 0;
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  for v_row in
    select *
    from public.moderation_queue
    where status = 'pending'
      and (
        coalesce(media_ref, '') = ''
        or coalesce(analysis_notes, '') not like '%awaiting_media_review%'
      )
    order by created_at
    limit greatest(coalesce(p_limit, 25), 1)
    for update skip locked
  loop
    v_n := v_n + 1;

    if coalesce(v_row.text_blob, '') <> ''
       and to_regprocedure('public.kairo_text_is_blocked(text)') is not null
       and public.kairo_text_is_blocked(v_row.text_blob) then
      perform public.confirm_content_infraction(
        v_row.content_type,
        v_row.content_id,
        'blocked_content',
        'blocked_content',
        null,
        v_row.user_id,
        'post_publish_text_policy',
        v_row.id,
        'automated'
      );
      continue;
    end if;

    if coalesce(v_row.media_ref, '') = '' then
      update public.moderation_queue
      set status = 'approved',
          analysis_notes = 'text_policy_allowed; no media',
          text_blob = null,
          finished_at = now()
      where id = v_row.id;
    else
      update public.moderation_queue
      set analysis_notes = 'text_policy_allowed; awaiting_media_review',
          status = 'pending'
      where id = v_row.id;
    end if;
  end loop;

  update public.moderation_queue
  set status = 'pending',
      last_error = 'stale_processing_reset'
  where status = 'processing'
    and started_at < now() - interval '10 minutes';

  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- Automatic queue worker (no-op if URL/secret not configured)
-- ---------------------------------------------------------------------------
create or replace function public.kairo_invoke_moderation_worker()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  select s.value into v_url
  from public.kairo_platform_settings s
  where s.key = 'moderation_worker_url';
  select s.value into v_secret
  from public.kairo_platform_settings s
  where s.key = 'moderation_job_secret';

  begin
    if coalesce(btrim(v_secret), '') = '' then
      select decrypted_secret into v_secret
      from vault.decrypted_secrets
      where name = 'KAIRO_JOB_SECRET'
      limit 1;
    end if;
  exception
    when others then
      null;
  end;

  v_url := btrim(coalesce(v_url, ''));
  v_secret := btrim(coalesce(v_secret, ''));
  if v_url = '' or v_secret = '' then
    return 'skipped_missing_url_or_secret';
  end if;

  if exists (select 1 from pg_extension where extname = 'pg_net') then
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-kairo-job-secret', v_secret
      ),
      body := '{"action":"process"}'::jsonb
    );
    return 'requested';
  end if;

  return 'skipped_no_pg_net';
exception
  when others then
    return 'skipped_error';
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule(j.jobid)
      from cron.job j
      where j.jobname in ('kairo-moderation-text', 'kairo-moderation-worker');
    exception
      when others then
        null;
    end;
    perform cron.schedule(
      'kairo-moderation-text',
      '* * * * *',
      'select public.process_moderation_text_batch(25)'
    );
    perform cron.schedule(
      'kairo-moderation-worker',
      '* * * * *',
      'select public.kairo_invoke_moderation_worker()'
    );
  end if;
exception
  when others then
    null;
end $$;

revoke all on function public.kairo_text_violates_policy(text) from public, anon, authenticated;
revoke all on function public.kairo_invoke_moderation_worker() from public, anon, authenticated;
revoke all on function public.kairo_delete_storage_objects(text) from public, anon, authenticated;
revoke all on function public.kairo_set_media_bucket_private() from public, anon;
revoke all on function public.list_pending_admin_emails() from public, anon, authenticated;

grant execute on function public.group_text_is_blocked(text) to authenticated;
grant execute on function public.kairo_queue_admin_notice(text, text, text) to authenticated;
grant execute on function public.kairo_set_media_bucket_private() to authenticated;
grant execute on function public.kairo_extract_storage_paths(text) to authenticated;
grant execute on function public.kairo_text_violates_policy(text) to service_role;
grant execute on function public.kairo_invoke_moderation_worker() to service_role;
grant execute on function public.list_pending_admin_emails() to service_role;
grant execute on function public.kairo_delete_storage_objects(text) to service_role;
grant execute on function public.process_moderation_text_batch(integer) to service_role;
