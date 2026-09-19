-- =============================================================================
-- KAIRO — Live rooms: catalog, chat, likes, presence, realtime
-- Safe to re-run. Paste into Supabase SQL Editor if 015 was never applied.
-- =============================================================================

create table if not exists public.live_streams (
  id            uuid primary key default gen_random_uuid(),
  host_id       uuid not null references public.users (id) on delete cascade,
  title         text not null,
  orientation   text not null default '16:9'
                check (orientation in ('16:9', '9:16')),
  tags          text[] not null default '{}',
  thumbnail_url text,
  viewer_count  int not null default 0,
  likes_count   int not null default 0,
  is_live       boolean not null default true,
  created_at    timestamptz not null default now()
);

alter table public.live_streams
  add column if not exists total_viewers int not null default 0;

alter table public.live_streams
  add column if not exists ended_at timestamptz;

alter table public.live_streams
  add column if not exists last_heartbeat timestamptz not null default now();

create index if not exists live_streams_live_idx
  on public.live_streams (is_live, created_at desc);

create unique index if not exists live_streams_one_live_per_host
  on public.live_streams (host_id)
  where is_live = true;

create table if not exists public.live_stream_messages (
  id         uuid primary key default gen_random_uuid(),
  stream_id  uuid not null references public.live_streams (id) on delete cascade,
  author_id  uuid not null references public.users (id) on delete cascade,
  content    text not null,
  kind       text not null default 'chat' check (kind in ('chat', 'join')),
  created_at timestamptz not null default now()
);

create index if not exists live_stream_messages_stream_idx
  on public.live_stream_messages (stream_id, created_at);

create table if not exists public.live_stream_likes (
  stream_id uuid not null references public.live_streams (id) on delete cascade,
  user_id   uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (stream_id, user_id)
);

create table if not exists public.live_stream_viewers (
  stream_id   uuid not null references public.live_streams (id) on delete cascade,
  session_key text not null,
  user_id     uuid references public.users (id) on delete cascade,
  joined_at   timestamptz not null default now(),
  last_seen   timestamptz not null default now(),
  qualified   boolean not null default false,
  primary key (stream_id, session_key)
);

alter table public.live_streams enable row level security;
alter table public.live_stream_messages enable row level security;
alter table public.live_stream_likes enable row level security;
alter table public.live_stream_viewers enable row level security;

drop policy if exists "Leer en vivos" on public.live_streams;
drop policy if exists "Read live streams" on public.live_streams;
create policy "Read live streams" on public.live_streams for select using (true);

drop policy if exists "Crear en vivo" on public.live_streams;
drop policy if exists "Create live streams" on public.live_streams;
create policy "Create live streams" on public.live_streams for insert
  with check (auth.uid() = host_id);

drop policy if exists "Actualizar propio en vivo" on public.live_streams;
drop policy if exists "Update own live streams" on public.live_streams;
create policy "Update own live streams" on public.live_streams for update
  using (auth.uid() = host_id);

drop policy if exists "Leer chat en vivo" on public.live_stream_messages;
drop policy if exists "Read live chat" on public.live_stream_messages;
create policy "Read live chat" on public.live_stream_messages for select using (true);

drop policy if exists "Comentar en vivo" on public.live_stream_messages;
drop policy if exists "Create live chat" on public.live_stream_messages;
create policy "Create live chat" on public.live_stream_messages for insert
  with check (auth.uid() = author_id);

drop policy if exists "Leer likes en vivo" on public.live_stream_likes;
drop policy if exists "Read live likes" on public.live_stream_likes;
create policy "Read live likes" on public.live_stream_likes for select using (true);

drop policy if exists "Dar like en vivo" on public.live_stream_likes;
drop policy if exists "Create live likes" on public.live_stream_likes;
create policy "Create live likes" on public.live_stream_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Quitar like en vivo" on public.live_stream_likes;
drop policy if exists "Delete own live likes" on public.live_stream_likes;
create policy "Delete own live likes" on public.live_stream_likes for delete
  using (auth.uid() = user_id);

drop policy if exists "Leer presencia propia" on public.live_stream_viewers;
drop policy if exists "Read own live presence" on public.live_stream_viewers;
create policy "Read own live presence" on public.live_stream_viewers for select
  using (auth.uid() = user_id);

grant select on public.live_streams to anon, authenticated;
grant insert, update on public.live_streams to authenticated;
grant select on public.live_stream_messages to anon, authenticated;
grant insert on public.live_stream_messages to authenticated;
grant select on public.live_stream_likes to anon, authenticated;
grant insert, delete on public.live_stream_likes to authenticated;
grant select on public.live_stream_viewers to authenticated;

create or replace function public.live_likes_count_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.live_streams
      set likes_count = likes_count + 1
      where id = new.stream_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.live_streams
      set likes_count = greatest(likes_count - 1, 0)
      where id = old.stream_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists live_likes_count_sync on public.live_stream_likes;
create trigger live_likes_count_sync
  after insert or delete on public.live_stream_likes
  for each row execute function public.live_likes_count_sync();

create or replace function public.live_sweep_stale()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.live_streams
    set is_live = false,
        ended_at = coalesce(ended_at, now())
    where is_live = true
      and last_heartbeat < now() - interval '2 minutes';
end;
$$;

create or replace function public.live_heartbeat(p_stream_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'You must sign in';
  end if;
  update public.live_streams
    set last_heartbeat = now()
    where id = p_stream_id
      and host_id = auth.uid()
      and is_live = true;
end;
$$;

create or replace function public.live_join_stream(p_stream_id uuid, p_session_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_session_key is null or length(trim(p_session_key)) < 8 then
    raise exception 'Invalid session';
  end if;
  if not exists (
    select 1 from public.live_streams
    where id = p_stream_id and is_live = true
  ) then
    raise exception 'This live stream has ended';
  end if;

  insert into public.live_stream_viewers (stream_id, session_key, user_id)
  values (p_stream_id, trim(p_session_key), auth.uid())
  on conflict (stream_id, session_key) do update
    set last_seen = now(),
        user_id = coalesce(excluded.user_id, public.live_stream_viewers.user_id);
end;
$$;

create or replace function public.live_qualify_viewer(p_stream_id uuid, p_session_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_qualified boolean;
begin
  select qualified into v_qualified
  from public.live_stream_viewers
  where stream_id = p_stream_id and session_key = trim(p_session_key);

  if not found or v_qualified then
    return;
  end if;

  update public.live_stream_viewers
    set qualified = true,
        last_seen = now()
    where stream_id = p_stream_id and session_key = trim(p_session_key);

  update public.live_streams
    set viewer_count = viewer_count + 1,
        total_viewers = total_viewers + 1
    where id = p_stream_id and is_live = true;
end;
$$;

create or replace function public.live_leave_stream(p_stream_id uuid, p_session_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_qualified boolean;
begin
  select qualified into v_qualified
  from public.live_stream_viewers
  where stream_id = p_stream_id and session_key = trim(p_session_key);

  if not found then
    return;
  end if;

  delete from public.live_stream_viewers
  where stream_id = p_stream_id and session_key = trim(p_session_key);

  if v_qualified then
    update public.live_streams
      set viewer_count = greatest(viewer_count - 1, 0)
      where id = p_stream_id and is_live = true;
  end if;
end;
$$;

grant execute on function public.live_sweep_stale() to anon, authenticated;
grant execute on function public.live_heartbeat(uuid) to authenticated;
grant execute on function public.live_join_stream(uuid, text) to anon, authenticated;
grant execute on function public.live_qualify_viewer(uuid, text) to anon, authenticated;
grant execute on function public.live_leave_stream(uuid, text) to anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_stream_messages'
  ) then
    alter publication supabase_realtime add table public.live_stream_messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_streams'
  ) then
    alter publication supabase_realtime add table public.live_streams;
  end if;
end $$;
