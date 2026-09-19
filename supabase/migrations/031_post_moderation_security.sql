-- =============================================================================
-- KAIRO — Post-publication moderation queue, storage takedown, RLS hardening
-- Safe to re-run. English. Paste AFTER 029 and 030.
-- Pre-filter stays: rejected writes are NOT infractions.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.kairo_is_internal()
returns boolean
language sql
stable
as $$
  select current_user in ('postgres', 'supabase_admin')
      or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
$$;

-- ---------------------------------------------------------------------------
-- Infraction history extras (reuse content_infractions)
-- ---------------------------------------------------------------------------
alter table public.content_infractions
  add column if not exists detection_method text;

alter table public.content_infractions
  add column if not exists confirmed_at timestamptz;

alter table public.content_infractions
  add column if not exists queue_id uuid;

alter table public.content_infractions
  add column if not exists storage_deleted boolean not null default false;

alter table public.content_infractions
  add column if not exists storage_error text;

update public.content_infractions
set confirmed_at = coalesce(confirmed_at, created_at)
where confirmed_at is null;

-- ---------------------------------------------------------------------------
-- Email outbox: real statuses (do not mark sent on a mere attempt)
-- ---------------------------------------------------------------------------
alter table public.admin_email_outbox
  add column if not exists status text not null default 'pending';

alter table public.admin_email_outbox
  drop constraint if exists admin_email_outbox_status_check;

alter table public.admin_email_outbox
  add constraint admin_email_outbox_status_check
  check (status in ('pending', 'sending', 'sent', 'failed'));

alter table public.admin_email_outbox
  add column if not exists last_error text;

alter table public.admin_email_outbox
  add column if not exists attempt_count integer not null default 0;

alter table public.admin_email_outbox
  add column if not exists http_status integer;

alter table public.admin_email_outbox
  add column if not exists provider_request_id text;

update public.admin_email_outbox
set status = case when sent_at is not null then 'sent' else coalesce(status, 'pending') end;

-- ---------------------------------------------------------------------------
-- Post-publication queue
-- ---------------------------------------------------------------------------
create table if not exists public.moderation_queue (
  id              uuid primary key default gen_random_uuid(),
  content_type    text not null,
  content_id      uuid not null,
  user_id         uuid references public.users (id) on delete set null,
  media_ref       text,
  media_type      text,
  text_blob       text,
  status          text not null default 'pending'
                  check (status in (
                    'pending', 'processing', 'approved', 'flagged',
                    'confirmed', 'rejected', 'removed'
                  )),
  attempts        integer not null default 0,
  last_error      text,
  analysis_notes  text,
  category        text,
  reason          text,
  infraction_id   uuid references public.content_infractions (id) on delete set null,
  created_at      timestamptz not null default now(),
  started_at      timestamptz,
  finished_at     timestamptz,
  unique (content_type, content_id)
);

create index if not exists moderation_queue_status_idx
  on public.moderation_queue (status, created_at);

alter table public.moderation_queue enable row level security;

drop policy if exists "Admins read moderation queue" on public.moderation_queue;
create policy "Admins read moderation queue" on public.moderation_queue
  for select using (public.kairo_is_admin());

grant select on public.moderation_queue to authenticated;

-- ---------------------------------------------------------------------------
-- Protect user admin / block columns (client UPDATE was too wide)
-- ---------------------------------------------------------------------------
create or replace function public.protect_user_restricted_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.kairo_is_internal() then
    return new;
  end if;
  if public.kairo_is_admin(auth.uid()) then
    return new;
  end if;

  if new.is_admin is distinct from old.is_admin
     or new.account_status is distinct from old.account_status
     or new.blocked_at is distinct from old.blocked_at
     or new.blocked_reason is distinct from old.blocked_reason
     or new.infraction_count is distinct from old.infraction_count
     or new.email is distinct from old.email then
    raise exception 'restricted_user_fields';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_user_restricted_columns_trg on public.users;
create trigger protect_user_restricted_columns_trg
  before update on public.users
  for each row execute function public.protect_user_restricted_columns();

-- Official KAIRO messages: user may change only read_at
create or replace function public.protect_kairo_official_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.kairo_is_internal() then
    return new;
  end if;
  new.body := old.body;
  new.user_id := old.user_id;
  new.infraction_id := old.infraction_id;
  new.created_at := old.created_at;
  return new;
end;
$$;

drop trigger if exists protect_kairo_official_message_trg on public.kairo_official_messages;
create trigger protect_kairo_official_message_trg
  before update on public.kairo_official_messages
  for each row execute function public.protect_kairo_official_message();

-- ---------------------------------------------------------------------------
-- Storage path helpers + delete (does not flip the public bucket)
-- ---------------------------------------------------------------------------
create or replace function public.kairo_extract_storage_paths(p_media text)
returns text[]
language plpgsql
immutable
as $$
declare
  v_paths text[] := '{}';
  v_item text;
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

  v_url := p_media;
  if position('/object/public/media/' in v_url) > 0 then
    v_path := split_part(v_url, '/object/public/media/', 2);
  elsif position('/object/sign/media/' in v_url) > 0 then
    v_path := split_part(split_part(v_url, '/object/sign/media/', 2), '?', 1);
  elsif position('/storage/v1/object/public/media/' in v_url) > 0 then
    v_path := split_part(v_url, '/storage/v1/object/public/media/', 2);
  else
    v_path := v_url;
  end if;

  v_path := btrim(v_path);
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
        and name = v_path;
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

-- ---------------------------------------------------------------------------
-- Official notice copy
-- ---------------------------------------------------------------------------
create or replace function public.kairo_official_notice_body(
  p_count integer,
  p_category text,
  p_blocked boolean
)
returns text
language sql
immutable
as $$
  select
    'Comunicación oficial de KAIRO. Tu contenido fue eliminado porque incumplió las normas'
    || case
         when coalesce(trim(p_category), '') = '' then '.'
         else ' (' || trim(p_category) || ').'
       end
    || ' Esta infracción ha sido registrada en tu cuenta. '
    || 'Llevas ' || coalesce(p_count, 1)::text || ' de 4 infracciones acumuladas.'
    || case
         when p_blocked then
           ' Has alcanzado 4 infracciones acumuladas y tu cuenta ha sido bloqueada automáticamente.'
         else
           ''
       end;
$$;

-- ---------------------------------------------------------------------------
-- Enqueue after publish (does not block the insert)
-- ---------------------------------------------------------------------------
create or replace function public.kairo_enqueue_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_type text;
  v_user uuid;
  v_media text;
  v_text text;
  v_media_type text;
begin
  v_type := tg_table_name;
  if v_type = 'posts' then
    v_type := 'post';
    v_user := new.author_id;
  elsif v_type = 'comments' then
    v_type := 'comment';
    v_user := new.author_id;
  elsif v_type = 'messages' then
    v_type := 'message';
    v_user := new.sender_id;
  elsif v_type = 'chat_group_messages' then
    v_type := 'group_message';
    v_user := new.sender_id;
  elsif v_type = 'stories' then
    v_type := 'story';
    v_user := new.author_id;
  elsif v_type = 'live_stream_messages' then
    v_type := 'live_message';
    v_user := new.author_id;
  elsif v_type = 'events' then
    v_type := 'event';
    v_user := new.created_by;
  elsif v_type = 'live_streams' then
    v_type := 'live';
    v_user := new.host_id;
  else
    return new;
  end if;

  v_media := coalesce(v_row->>'media_url', v_row->>'image_url', v_row->>'thumbnail_url');
  v_media_type := v_row->>'media_type';
  v_text := left(btrim(concat_ws(' ', v_row->>'content', v_row->>'title', v_row->>'description')), 2000);

  insert into public.moderation_queue (
    content_type, content_id, user_id, media_ref, media_type, text_blob, status
  ) values (
    v_type, new.id, v_user, v_media, v_media_type, nullif(v_text, ''), 'pending'
  )
  on conflict (content_type, content_id) do nothing;

  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'posts', 'comments', 'messages', 'chat_group_messages',
    'stories', 'live_stream_messages', 'events', 'live_streams'
  ]
  loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists kairo_enqueue_%s_trg on public.%I', t, t);
      execute format(
        'create trigger kairo_enqueue_%s_trg after insert on public.%I for each row execute function public.kairo_enqueue_moderation()',
        t, t
      );
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Confirm RPC: service_role/internal/admin, storage, notices, email pending
-- ---------------------------------------------------------------------------
create or replace function public.confirm_content_infraction(
  p_content_type text,
  p_content_id uuid,
  p_category text,
  p_reason text,
  p_source_report_id uuid default null,
  p_user_id uuid default null,
  p_detection_method text default null,
  p_queue_id uuid default null,
  p_source text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.content_infractions%rowtype;
  v_inf public.content_infractions%rowtype;
  v_owner uuid;
  v_media text;
  v_count integer;
  v_blocked boolean := false;
  v_block_id uuid;
  v_outbox_id uuid;
  v_email record;
  v_body text;
  v_source text;
  v_storage jsonb;
begin
  if not (
    public.kairo_is_internal()
    or public.kairo_is_admin(auth.uid())
  ) then
    if auth.uid() is null then
      raise exception 'not_authenticated';
    end if;
    raise exception 'not_admin';
  end if;
  if p_content_type is null or p_content_id is null then
    raise exception 'invalid_content';
  end if;
  if coalesce(trim(p_category), '') = '' or coalesce(trim(p_reason), '') = '' then
    raise exception 'invalid_reason';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_content_type || ':' || p_content_id::text));

  select * into v_existing
  from public.content_infractions
  where content_type = p_content_type
    and content_id = p_content_id;

  if found then
    if p_source_report_id is not null then
      update public.content_reports
      set status = 'confirmed',
          reviewed_at = coalesce(reviewed_at, now()),
          reviewed_by = coalesce(reviewed_by, auth.uid()),
          infraction_id = v_existing.id
      where id = p_source_report_id;
    end if;
    update public.moderation_queue
    set status = 'confirmed',
        infraction_id = v_existing.id,
        finished_at = coalesce(finished_at, now())
    where content_type = p_content_type
      and content_id = p_content_id;

    select infraction_count, account_status = 'blocked'
    into v_count, v_blocked
    from public.users
    where id = v_existing.user_id;

    return jsonb_build_object(
      'infraction_id', v_existing.id,
      'user_id', v_existing.user_id,
      'infraction_count', coalesce(v_count, 0),
      'account_blocked', coalesce(v_blocked, false),
      'duplicate', true
    );
  end if;

  select o_user_id, o_media_ref
  into v_owner, v_media
  from public.kairo_resolve_content_owner(p_content_type, p_content_id);

  if v_media is null then
    select media_ref into v_media
    from public.moderation_queue
    where content_type = p_content_type and content_id = p_content_id;
  end if;

  v_owner := coalesce(v_owner, p_user_id);
  if v_owner is null then
    raise exception 'content_not_found';
  end if;

  perform pg_advisory_xact_lock(hashtext('kairo-user:' || v_owner::text));

  v_source := coalesce(
    nullif(trim(p_source), ''),
    case when p_source_report_id is not null then 'report' else 'admin' end
  );
  if v_source not in ('admin', 'report', 'automated') then
    v_source := 'admin';
  end if;

  insert into public.content_infractions (
    user_id, content_type, content_id, category, reason,
    source, source_report_id, media_ref, content_removed,
    detection_method, confirmed_at, queue_id
  ) values (
    v_owner, p_content_type, p_content_id, trim(p_category), trim(p_reason),
    v_source, p_source_report_id, v_media, true,
    coalesce(p_detection_method, v_source), now(), p_queue_id
  )
  returning * into v_inf;

  perform public.kairo_remove_offending_content(p_content_type, p_content_id);

  begin
    v_storage := public.kairo_delete_storage_objects(v_media);
    update public.content_infractions
    set storage_deleted = coalesce((v_storage->>'deleted')::int, 0) > 0,
        storage_error = v_storage->>'error'
    where id = v_inf.id;
  exception
    when others then
      update public.content_infractions
      set storage_error = sqlerrm
      where id = v_inf.id;
  end;

  update public.content_reports
  set status = 'confirmed',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      infraction_id = v_inf.id
  where (id = p_source_report_id)
     or (target_type = p_content_type and target_id = p_content_id and status = 'pending');

  select count(*) into v_count
  from public.content_infractions
  where user_id = v_owner
    and status = 'confirmed';

  update public.users
  set infraction_count = v_count,
      updated_at = now()
  where id = v_owner;

  v_blocked := v_count >= 4;
  v_body := public.kairo_official_notice_body(v_count, p_category, v_blocked);

  insert into public.kairo_official_messages (user_id, body, infraction_id)
  values (v_owner, v_body, v_inf.id)
  on conflict (infraction_id) do nothing;

  if v_blocked then
    update public.users
    set account_status = 'blocked',
        blocked_at = coalesce(blocked_at, now()),
        blocked_reason = '4 infracciones acumuladas',
        infraction_count = v_count,
        updated_at = now()
    where id = v_owner;

    insert into public.account_block_events (
      user_id, kind, reason, infraction_count
    ) values (
      v_owner, 'auto_four_strikes', '4 infracciones acumuladas', v_count
    )
    on conflict (user_id, kind) do nothing
    returning id into v_block_id;

    if v_block_id is not null then
      select s.subject, s.body, s.to_email into v_email
      from public.kairo_build_admin_block_email(v_owner) s;

      insert into public.admin_email_outbox (
        user_id, kind, subject, body, to_email, status
      ) values (
        v_owner, 'auto_block', v_email.subject, v_email.body, v_email.to_email, 'pending'
      )
      on conflict (user_id, kind) do nothing
      returning id into v_outbox_id;
    end if;
  end if;

  update public.moderation_queue
  set status = 'removed',
      infraction_id = v_inf.id,
      category = trim(p_category),
      reason = trim(p_reason),
      text_blob = null,
      finished_at = now()
  where content_type = p_content_type
    and content_id = p_content_id
     or id = p_queue_id;

  return jsonb_build_object(
    'infraction_id', v_inf.id,
    'user_id', v_owner,
    'infraction_count', v_count,
    'account_blocked', v_blocked,
    'duplicate', false,
    'outbox_id', v_outbox_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Text pass of the queue (same policy as pre-filter; not an infraction unless
-- the row already exists — i.e. it slipped past the BEFORE trigger)
-- ---------------------------------------------------------------------------
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
    order by created_at
    limit greatest(coalesce(p_limit, 25), 1)
    for update skip locked
  loop
    v_n := v_n + 1;

    if coalesce(v_row.text_blob, '') <> ''
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
      set analysis_notes = coalesce(analysis_notes, '')
        || case when analysis_notes is null then '' else '; ' end
        || 'text_policy_allowed; awaiting_media_review',
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

create or replace function public.claim_moderation_media_batch(p_limit integer default 8)
returns setof public.moderation_queue
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;

  return query
  with picked as (
    select q.id
    from public.moderation_queue q
    where q.status = 'pending'
      and coalesce(q.media_ref, '') <> ''
      and q.attempts < 5
    order by q.created_at
    limit greatest(coalesce(p_limit, 8), 1)
    for update skip locked
  )
  update public.moderation_queue q
  set status = 'processing',
      started_at = now(),
      attempts = q.attempts + 1
  from picked
  where q.id = picked.id
  returning q.*;
end;
$$;

create or replace function public.complete_moderation_job(
  p_queue_id uuid,
  p_status text,
  p_category text default null,
  p_reason text default null,
  p_notes text default null,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.moderation_queue%rowtype;
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  if p_status not in ('approved', 'flagged', 'confirmed', 'rejected', 'removed', 'pending') then
    raise exception 'invalid_status';
  end if;

  select * into v_row from public.moderation_queue where id = p_queue_id;
  if not found then
    raise exception 'queue_not_found';
  end if;

  if p_status = 'confirmed' then
    return public.confirm_content_infraction(
      v_row.content_type,
      v_row.content_id,
      coalesce(p_category, 'blocked_content'),
      coalesce(p_reason, 'blocked_content'),
      null,
      v_row.user_id,
      coalesce(p_notes, 'post_publish_media'),
      v_row.id,
      'automated'
    );
  end if;

  update public.moderation_queue
  set status = p_status,
      category = coalesce(p_category, category),
      reason = coalesce(p_reason, reason),
      analysis_notes = coalesce(p_notes, analysis_notes),
      last_error = p_error,
      text_blob = case when p_status in ('approved', 'rejected', 'removed') then null else text_blob end,
      finished_at = case when p_status = 'pending' then null else now() end
  where id = p_queue_id;

  return jsonb_build_object('queue_id', p_queue_id, 'status', p_status);
end;
$$;

create or replace function public.review_moderation_queue_item(
  p_queue_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.moderation_queue%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  select * into v_row from public.moderation_queue where id = p_queue_id;
  if not found then
    raise exception 'queue_not_found';
  end if;

  if p_action = 'confirm' then
    return public.confirm_content_infraction(
      v_row.content_type,
      v_row.content_id,
      coalesce(v_row.category, 'blocked_content'),
      coalesce(v_row.reason, 'admin_confirmed'),
      null,
      v_row.user_id,
      'admin_queue_review',
      v_row.id,
      'admin'
    );
  end if;

  if p_action = 'approve' then
    update public.moderation_queue
    set status = 'approved',
        finished_at = now(),
        text_blob = null,
        analysis_notes = coalesce(analysis_notes || '; ', '') || 'admin_approved'
    where id = p_queue_id;
    return jsonb_build_object('queue_id', p_queue_id, 'status', 'approved');
  end if;

  raise exception 'invalid_action';
end;
$$;

-- Email: never mark sent here. Only move pending -> sending and record the attempt.
create or replace function public.kairo_send_admin_block_email(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, net, extensions
as $$
declare
  v_row public.admin_email_outbox%rowtype;
  v_url text;
  v_req bigint;
begin
  select * into v_row from public.admin_email_outbox where id = p_outbox_id;
  if not found then
    return;
  end if;
  if v_row.status = 'sent' then
    return;
  end if;

  update public.admin_email_outbox
  set status = 'sending',
      attempt_count = attempt_count + 1,
      last_error = null
  where id = p_outbox_id;

  v_url := 'https://formsubmit.co/ajax/' || v_row.to_email;

  begin
    select net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Accept', 'application/json'
      ),
      body := jsonb_build_object(
        'name', 'KAIRO',
        '_subject', v_row.subject,
        '_captcha', 'false',
        'mensaje', v_row.body
      )
    ) into v_req;

    update public.admin_email_outbox
    set provider_request_id = v_req::text,
        status = 'sending',
        last_error = 'http_queued_awaiting_response'
    where id = p_outbox_id;
  exception
    when others then
      update public.admin_email_outbox
      set status = 'failed',
          last_error = sqlerrm
      where id = p_outbox_id;
  end;
end;
$$;

create or replace function public.kairo_mark_admin_email(
  p_outbox_id uuid,
  p_status text,
  p_http_status integer default null,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  if p_status not in ('pending', 'sending', 'sent', 'failed') then
    raise exception 'invalid_status';
  end if;

  update public.admin_email_outbox
  set status = p_status,
      http_status = p_http_status,
      last_error = p_error,
      sent_at = case when p_status = 'sent' then now() else sent_at end
  where id = p_outbox_id;
end;
$$;

create or replace function public.flush_admin_block_emails()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.admin_email_outbox%rowtype;
  v_n integer := 0;
begin
  if not public.kairo_is_internal() and not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  for v_row in
    select * from public.admin_email_outbox
    where status in ('pending', 'failed')
    order by created_at
  loop
    perform public.kairo_send_admin_block_email(v_row.id);
    v_n := v_n + 1;
  end loop;
  return v_n;
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
  order by created_at;
end;
$$;

-- Optional cron for the SQL text pass (media is handled by the Edge Function)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'kairo-moderation-text';
    exception
      when others then
        null;
    end;
    perform cron.schedule(
      'kairo-moderation-text',
      '* * * * *',
      'select public.process_moderation_text_batch(25)'
    );
  end if;
exception
  when others then
    null;
end $$;

revoke all on function public.process_moderation_text_batch(integer) from public, anon, authenticated;
revoke all on function public.claim_moderation_media_batch(integer) from public, anon, authenticated;
revoke all on function public.complete_moderation_job(uuid, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.kairo_mark_admin_email(uuid, text, integer, text) from public, anon, authenticated;
revoke all on function public.list_pending_admin_emails() from public, anon, authenticated;
revoke all on function public.kairo_delete_storage_objects(text) from public, anon, authenticated;

grant execute on function public.kairo_official_notice_body(integer, text, boolean) to authenticated;
grant execute on function public.confirm_content_infraction(text, uuid, text, text, uuid, uuid, text, uuid, text) to authenticated;
grant execute on function public.review_moderation_queue_item(uuid, text) to authenticated;
grant execute on function public.flush_admin_block_emails() to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'users'
  ) then
    alter publication supabase_realtime add table public.users;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'moderation_queue'
  ) then
    alter publication supabase_realtime add table public.moderation_queue;
  end if;
exception
  when others then
    null;
end $$;
