-- =============================================================================
-- KAIRO — Confirmed infractions and automatic account block at 4
-- Safe to re-run. English. Paste AFTER 029. Then run 031, then 032.
-- Complements post-publication moderation. Does not change immediate publish.
-- Does not add pre-moderation.
-- admin_alert_email is empty until set in kairo_platform_settings.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Platform settings (admin alert email)
-- ---------------------------------------------------------------------------
create table if not exists public.kairo_platform_settings (
  key   text primary key,
  value text not null
);

insert into public.kairo_platform_settings (key, value)
values ('admin_alert_email', '')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Users: persistent account status (reuse is_admin; do not use user_blocks)
-- user_blocks = user-to-user mute. This is platform account status.
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists is_admin boolean not null default false;

alter table public.users
  add column if not exists account_status text not null default 'active';

alter table public.users
  drop constraint if exists users_account_status_check;

alter table public.users
  add constraint users_account_status_check
  check (account_status in ('active', 'blocked'));

alter table public.users
  add column if not exists blocked_at timestamptz;

alter table public.users
  add column if not exists blocked_reason text;

alter table public.users
  add column if not exists infraction_count integer not null default 0;

create index if not exists users_account_status_idx
  on public.users (account_status)
  where account_status = 'blocked';

-- ---------------------------------------------------------------------------
-- Reports: review state (pending reports are NOT infractions)
-- ---------------------------------------------------------------------------
alter table public.content_reports
  add column if not exists status text not null default 'pending';

alter table public.content_reports
  drop constraint if exists content_reports_status_check;

alter table public.content_reports
  add constraint content_reports_status_check
  check (status in ('pending', 'confirmed', 'dismissed'));

alter table public.content_reports
  add column if not exists reviewed_at timestamptz;

alter table public.content_reports
  add column if not exists reviewed_by uuid references public.users (id) on delete set null;

alter table public.content_reports
  add column if not exists infraction_id uuid;

-- ---------------------------------------------------------------------------
-- Confirmed infractions (history is never deleted on block)
-- ---------------------------------------------------------------------------
create table if not exists public.content_infractions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users (id) on delete restrict,
  content_type    text not null,
  content_id      uuid not null,
  category        text not null,
  reason          text not null,
  status          text not null default 'confirmed'
                  check (status in ('confirmed')),
  source          text not null default 'admin'
                  check (source in ('admin', 'report', 'automated')),
  source_report_id uuid,
  media_ref       text,
  content_removed boolean not null default true,
  created_at      timestamptz not null default now(),
  unique (content_type, content_id)
);

create index if not exists content_infractions_user_idx
  on public.content_infractions (user_id, created_at);

create unique index if not exists content_infractions_report_uidx
  on public.content_infractions (source_report_id)
  where source_report_id is not null;

alter table public.content_reports
  drop constraint if exists content_reports_infraction_fk;

alter table public.content_reports
  add constraint content_reports_infraction_fk
  foreign key (infraction_id) references public.content_infractions (id)
  on delete set null;

-- ---------------------------------------------------------------------------
-- One automatic block event per account (idempotent)
-- ---------------------------------------------------------------------------
create table if not exists public.account_block_events (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users (id) on delete restrict,
  kind              text not null default 'auto_four_strikes',
  reason            text not null default '4 infracciones acumuladas',
  infraction_count  integer not null default 4,
  created_at        timestamptz not null default now(),
  unique (user_id, kind)
);

create index if not exists account_block_events_user_idx
  on public.account_block_events (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Official KAIRO chat notices (one message per infraction)
-- ---------------------------------------------------------------------------
create table if not exists public.kairo_official_messages (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete restrict,
  body          text not null,
  infraction_id uuid not null references public.content_infractions (id) on delete restrict,
  created_at    timestamptz not null default now(),
  read_at       timestamptz,
  unique (infraction_id)
);

create index if not exists kairo_official_messages_user_idx
  on public.kairo_official_messages (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Admin email outbox (one auto-block email per user)
-- ---------------------------------------------------------------------------
create table if not exists public.admin_email_outbox (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete restrict,
  kind         text not null default 'auto_block',
  subject      text not null,
  body         text not null,
  to_email     text not null,
  created_at   timestamptz not null default now(),
  sent_at      timestamptz,
  unique (user_id, kind)
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.kairo_platform_settings enable row level security;
alter table public.content_infractions enable row level security;
alter table public.account_block_events enable row level security;
alter table public.kairo_official_messages enable row level security;
alter table public.admin_email_outbox enable row level security;

create or replace function public.kairo_is_admin(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select u.is_admin from public.users u where u.id = p_user_id),
    false
  );
$$;

create or replace function public.kairo_account_is_blocked(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select u.account_status = 'blocked'
      from public.users u
      where u.id = p_user_id
    ),
    false
  );
$$;

drop policy if exists "Admins read platform settings" on public.kairo_platform_settings;
create policy "Admins read platform settings" on public.kairo_platform_settings
  for select using (public.kairo_is_admin());

drop policy if exists "Admins read infractions" on public.content_infractions;
create policy "Admins read infractions" on public.content_infractions
  for select using (public.kairo_is_admin());

drop policy if exists "Admins read block events" on public.account_block_events;
create policy "Admins read block events" on public.account_block_events
  for select using (public.kairo_is_admin());

drop policy if exists "Own official messages" on public.kairo_official_messages;
create policy "Own official messages" on public.kairo_official_messages
  for select using (auth.uid() = user_id or public.kairo_is_admin());

drop policy if exists "Mark official messages read" on public.kairo_official_messages;
create policy "Mark official messages read" on public.kairo_official_messages
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Admins read email outbox" on public.admin_email_outbox;
create policy "Admins read email outbox" on public.admin_email_outbox
  for select using (public.kairo_is_admin());

drop policy if exists "Admins read all reports" on public.content_reports;
create policy "Admins read all reports" on public.content_reports
  for select using (public.kairo_is_admin());

grant select on public.kairo_platform_settings to authenticated;
grant select on public.content_infractions to authenticated;
grant select on public.account_block_events to authenticated;
grant select, update on public.kairo_official_messages to authenticated;
grant select on public.admin_email_outbox to authenticated;

-- ---------------------------------------------------------------------------
-- Blocked accounts cannot write (backend, not frontend)
-- ---------------------------------------------------------------------------
create or replace function public.enforce_account_not_blocked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if public.kairo_is_admin(auth.uid()) then
    return new;
  end if;
  if public.kairo_account_is_blocked(auth.uid()) then
    raise exception 'account_blocked';
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'posts', 'comments', 'likes', 'intercessions', 'post_views', 'saved_posts',
    'messages', 'follows', 'stories', 'story_likes', 'moments', 'moment_items',
    'events', 'live_streams', 'live_stream_messages', 'live_stream_likes',
    'chat_groups', 'chat_group_messages', 'chat_group_members', 'chat_group_invites',
    'content_reports', 'churches', 'users'
  ]
  loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists kairo_account_block_%s_trg on public.%I', t, t);
      execute format(
        'create trigger kairo_account_block_%s_trg before insert or update on public.%I for each row execute function public.enforce_account_not_blocked()',
        t, t
      );
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Resolve content owner and optional media reference
-- ---------------------------------------------------------------------------
create or replace function public.kairo_resolve_content_owner(
  p_content_type text,
  p_content_id uuid,
  out o_user_id uuid,
  out o_media_ref text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  o_user_id := null;
  o_media_ref := null;

  if p_content_type = 'post' then
    select author_id, media_url into o_user_id, o_media_ref
    from public.posts where id = p_content_id;
  elsif p_content_type = 'comment' then
    select author_id into o_user_id
    from public.comments where id = p_content_id;
  elsif p_content_type = 'message' then
    select sender_id, media_url into o_user_id, o_media_ref
    from public.messages where id = p_content_id;
    if o_user_id is null and to_regclass('public.chat_group_messages') is not null then
      select sender_id, media_url into o_user_id, o_media_ref
      from public.chat_group_messages where id = p_content_id;
    end if;
    if o_user_id is null and to_regclass('public.live_stream_messages') is not null then
      select author_id into o_user_id
      from public.live_stream_messages where id = p_content_id;
    end if;
  elsif p_content_type in ('group_message', 'chat_group_message') then
    if to_regclass('public.chat_group_messages') is not null then
      select sender_id, media_url into o_user_id, o_media_ref
      from public.chat_group_messages where id = p_content_id;
    end if;
  elsif p_content_type = 'story' then
    select author_id, media_url into o_user_id, o_media_ref
    from public.stories where id = p_content_id;
  elsif p_content_type = 'event' then
    begin
      select created_by, image_url into o_user_id, o_media_ref
      from public.events where id = p_content_id;
    exception
      when undefined_column then
        select created_by into o_user_id
        from public.events where id = p_content_id;
    end;
  elsif p_content_type in ('live', 'live_stream') then
    if to_regclass('public.live_streams') is not null then
      select host_id, thumbnail_url into o_user_id, o_media_ref
      from public.live_streams where id = p_content_id;
    end if;
  elsif p_content_type = 'live_message' then
    if to_regclass('public.live_stream_messages') is not null then
      select author_id into o_user_id
      from public.live_stream_messages where id = p_content_id;
    end if;
  elsif p_content_type = 'group' then
    if to_regclass('public.chat_groups') is not null then
      begin
        select created_by, image_url into o_user_id, o_media_ref
        from public.chat_groups where id = p_content_id;
      exception
        when undefined_column then
          select created_by into o_user_id
          from public.chat_groups where id = p_content_id;
      end;
    end if;
  elsif p_content_type = 'user' then
    select id, image into o_user_id, o_media_ref
    from public.users where id = p_content_id;
  end if;
end;
$$;

create or replace function public.kairo_remove_offending_content(
  p_content_type text,
  p_content_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_removed boolean := false;
begin
  if p_content_type = 'post' then
    delete from public.posts where id = p_content_id;
    v_removed := found;
  elsif p_content_type = 'comment' then
    delete from public.comments where id = p_content_id;
    v_removed := found;
  elsif p_content_type = 'message' then
    delete from public.messages where id = p_content_id;
    v_removed := found;
    if not v_removed and to_regclass('public.chat_group_messages') is not null then
      delete from public.chat_group_messages where id = p_content_id;
      v_removed := found;
    end if;
    if not v_removed and to_regclass('public.live_stream_messages') is not null then
      delete from public.live_stream_messages where id = p_content_id;
      v_removed := found;
    end if;
  elsif p_content_type in ('group_message', 'chat_group_message') then
    if to_regclass('public.chat_group_messages') is not null then
      delete from public.chat_group_messages where id = p_content_id;
      v_removed := found;
    end if;
  elsif p_content_type = 'story' then
    delete from public.stories where id = p_content_id;
    v_removed := found;
  elsif p_content_type = 'event' then
    delete from public.events where id = p_content_id;
    v_removed := found;
  elsif p_content_type in ('live', 'live_stream') then
    if to_regclass('public.live_streams') is not null then
      update public.live_streams
      set is_live = false, ended_at = coalesce(ended_at, now())
      where id = p_content_id;
      v_removed := found;
    end if;
  elsif p_content_type = 'live_message' then
    if to_regclass('public.live_stream_messages') is not null then
      delete from public.live_stream_messages where id = p_content_id;
      v_removed := found;
    end if;
  elsif p_content_type = 'group' then
    if to_regclass('public.chat_groups') is not null then
      begin
        update public.chat_groups
        set description = null, image_url = null
        where id = p_content_id;
        v_removed := found;
      exception
        when undefined_column then
          v_removed := false;
      end;
    end if;
  end if;
  return v_removed;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin email (same FormSubmit channel already used for church requests)
-- ---------------------------------------------------------------------------
create or replace function public.kairo_send_admin_block_email(p_outbox_id uuid)
returns void
language plpgsql
security definer
set search_path = public, net, extensions
as $$
declare
  v_row public.admin_email_outbox%rowtype;
  v_url text;
begin
  select * into v_row from public.admin_email_outbox where id = p_outbox_id;
  if not found or v_row.sent_at is not null then
    return;
  end if;

  v_url := 'https://formsubmit.co/ajax/' || v_row.to_email;

  begin
    perform net.http_post(
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
    );
    update public.admin_email_outbox
    set sent_at = now()
    where id = p_outbox_id;
  exception
    when others then
      -- Keep the outbox row so an admin refresh can retry. Block still stands.
      null;
  end;
end;
$$;

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

-- ---------------------------------------------------------------------------
-- Confirm a violation: delete content, record ONE infraction, notify, maybe block
-- ---------------------------------------------------------------------------
create or replace function public.confirm_content_infraction(
  p_content_type text,
  p_content_id uuid,
  p_category text,
  p_reason text,
  p_source_report_id uuid default null,
  p_user_id uuid default null
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
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.kairo_is_admin(auth.uid()) then
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
    update public.content_reports
    set status = 'confirmed',
        reviewed_at = coalesce(reviewed_at, now()),
        reviewed_by = coalesce(reviewed_by, auth.uid()),
        infraction_id = v_existing.id
    where target_type = p_content_type
      and target_id = p_content_id
      and status = 'pending';

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

  v_owner := coalesce(v_owner, p_user_id);
  if v_owner is null then
    raise exception 'content_not_found';
  end if;

  perform pg_advisory_xact_lock(hashtext('kairo-user:' || v_owner::text));

  v_source := case when p_source_report_id is not null then 'report' else 'admin' end;

  insert into public.content_infractions (
    user_id, content_type, content_id, category, reason,
    source, source_report_id, media_ref, content_removed
  ) values (
    v_owner, p_content_type, p_content_id, trim(p_category), trim(p_reason),
    v_source, p_source_report_id, v_media, true
  )
  returning * into v_inf;

  perform public.kairo_remove_offending_content(p_content_type, p_content_id);

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

  if v_count >= 4 then
    v_body := 'Tu contenido fue eliminado porque incumplió las normas de KAIRO. '
      || 'Esta infracción ha sido registrada en tu cuenta. '
      || 'Has alcanzado 4 infracciones acumuladas y tu cuenta ha sido bloqueada automáticamente.';
  else
    v_body := 'Tu contenido fue eliminado porque incumplió las normas de KAIRO. '
      || 'Esta infracción ha sido registrada en tu cuenta.';
  end if;

  insert into public.kairo_official_messages (user_id, body, infraction_id)
  values (v_owner, v_body, v_inf.id)
  on conflict (infraction_id) do nothing;

  if v_count >= 4 then
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
        user_id, kind, subject, body, to_email
      ) values (
        v_owner, 'auto_block', v_email.subject, v_email.body, v_email.to_email
      )
      on conflict (user_id, kind) do nothing
      returning id into v_outbox_id;

      if v_outbox_id is not null then
        perform public.kairo_send_admin_block_email(v_outbox_id);
      end if;
    end if;

    v_blocked := true;
  end if;

  return jsonb_build_object(
    'infraction_id', v_inf.id,
    'user_id', v_owner,
    'infraction_count', v_count,
    'account_blocked', v_blocked,
    'duplicate', false
  );
end;
$$;

create or replace function public.review_content_report(
  p_report_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.content_reports%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  if p_action not in ('confirm', 'dismiss') then
    raise exception 'invalid_action';
  end if;

  select * into v_report from public.content_reports where id = p_report_id;
  if not found then
    raise exception 'report_not_found';
  end if;

  if v_report.status <> 'pending' then
    return jsonb_build_object(
      'report_id', v_report.id,
      'status', v_report.status,
      'infraction_id', v_report.infraction_id,
      'duplicate', true
    );
  end if;

  if p_action = 'dismiss' then
    update public.content_reports
    set status = 'dismissed',
        reviewed_at = now(),
        reviewed_by = auth.uid()
    where id = p_report_id
      and status = 'pending';
    return jsonb_build_object(
      'report_id', p_report_id,
      'status', 'dismissed',
      'duplicate', false
    );
  end if;

  return public.confirm_content_infraction(
    v_report.target_type,
    v_report.target_id,
    v_report.reason,
    v_report.reason,
    v_report.id,
    null
  ) || jsonb_build_object('report_id', p_report_id, 'status', 'confirmed');
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
  if not public.kairo_is_admin(auth.uid()) then
    raise exception 'not_admin';
  end if;
  for v_row in
    select * from public.admin_email_outbox
    where sent_at is null
    order by created_at
  loop
    perform public.kairo_send_admin_block_email(v_row.id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'kairo_official_messages'
  ) then
    alter publication supabase_realtime add table public.kairo_official_messages;
  end if;
exception
  when others then
    null;
end $$;

grant execute on function public.kairo_is_admin(uuid) to authenticated;
grant execute on function public.kairo_account_is_blocked(uuid) to authenticated;
grant execute on function public.confirm_content_infraction(text, uuid, text, text, uuid, uuid) to authenticated;
grant execute on function public.review_content_report(uuid, text) to authenticated;
grant execute on function public.flush_admin_block_emails() to authenticated;
