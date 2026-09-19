-- =============================================================================
-- KAIRO — Apply features missing from the original complete schema
-- =============================================================================
--
-- Safe to re-run (IF NOT EXISTS / DROP POLICY IF EXISTS).
-- Paste into Supabase SQL Editor and click Run.
--
-- Covers:
--   stories likes + sound
--   story archive (keep after 24h)
--   profile moments + covers + likes
--   username cooldown column
--   profile cover_url
--   user blocks
--   saved posts (cloud)
--   media bucket size (300 MB)
--   live rooms (catalog, chat, likes, presence)
--   chat groups (members, invites, messages, admin roles)
--
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- Users: cover, username cooldown, story archive preference
-- ---------------------------------------------------------------------------
alter table public.users
  add column if not exists cover_url text;

alter table public.users
  add column if not exists username_changed_at timestamptz;

alter table public.users
  add column if not exists save_story_archive boolean not null default true;

-- ---------------------------------------------------------------------------
-- Stories: archive after 24h + optional sound name
-- ---------------------------------------------------------------------------
alter table public.stories
  add column if not exists archived boolean not null default true;

alter table public.stories
  add column if not exists sound_name text;

create or replace function public.set_story_archived()
returns trigger
language plpgsql
as $$
begin
  select coalesce(save_story_archive, true)
    into new.archived
  from public.users
  where id = new.author_id;
  return new;
end;
$$;

drop trigger if exists stories_set_archived on public.stories;
create trigger stories_set_archived
  before insert on public.stories
  for each row execute function public.set_story_archived();

drop policy if exists "Leer historias no expiradas" on public.stories;
drop policy if exists "Leer historias" on public.stories;
drop policy if exists "Read non-expired stories" on public.stories;
drop policy if exists "Read stories" on public.stories;
create policy "Read stories" on public.stories for select
  using (
    expires_at > now()
    or (author_id = auth.uid() and archived = true)
  );

-- Story likes
create table if not exists public.story_likes (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  author_id  uuid not null references public.users (id) on delete cascade,
  story_id   uuid not null references public.stories (id) on delete cascade,
  unique (author_id, story_id)
);

create index if not exists story_likes_story_idx on public.story_likes (story_id);
create index if not exists story_likes_author_idx on public.story_likes (author_id);

alter table public.story_likes enable row level security;

drop policy if exists "Leer likes de historias" on public.story_likes;
drop policy if exists "Read story likes" on public.story_likes;
create policy "Read story likes" on public.story_likes for select using (true);

drop policy if exists "Dar like a historia" on public.story_likes;
drop policy if exists "Create story likes" on public.story_likes;
create policy "Create story likes" on public.story_likes for insert
  with check (auth.uid() = author_id);

drop policy if exists "Quitar like de historia" on public.story_likes;
drop policy if exists "Delete own story likes" on public.story_likes;
create policy "Delete own story likes" on public.story_likes for delete
  using (auth.uid() = author_id);

grant select on public.story_likes to anon, authenticated;
grant insert, delete on public.story_likes to authenticated;

-- ---------------------------------------------------------------------------
-- Profile moments (highlights)
-- ---------------------------------------------------------------------------
create table if not exists public.profile_moments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  title      text not null,
  icon_id    text not null default 'star',
  sort_order int not null default 0,
  cover_url  text,
  created_at timestamptz not null default now()
);

alter table public.profile_moments
  add column if not exists cover_url text;

create table if not exists public.profile_moment_items (
  id           uuid primary key default gen_random_uuid(),
  moment_id    uuid not null references public.profile_moments (id) on delete cascade,
  media_url    text not null,
  media_type   text not null default 'image',
  story_id     uuid references public.stories (id) on delete set null,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

create index if not exists profile_moments_user_idx on public.profile_moments (user_id, sort_order);
create index if not exists profile_moment_items_moment_idx on public.profile_moment_items (moment_id, sort_order);

alter table public.profile_moments enable row level security;
alter table public.profile_moment_items enable row level security;

drop policy if exists "Leer momentos de perfil" on public.profile_moments;
drop policy if exists "Read profile moments" on public.profile_moments;
create policy "Read profile moments" on public.profile_moments for select using (true);

drop policy if exists "Crear propios momentos" on public.profile_moments;
drop policy if exists "Create own profile moments" on public.profile_moments;
create policy "Create own profile moments" on public.profile_moments for insert
  with check (auth.uid() = user_id);

drop policy if exists "Editar propios momentos" on public.profile_moments;
drop policy if exists "Update own profile moments" on public.profile_moments;
create policy "Update own profile moments" on public.profile_moments for update
  using (auth.uid() = user_id);

drop policy if exists "Borrar propios momentos" on public.profile_moments;
drop policy if exists "Delete own profile moments" on public.profile_moments;
create policy "Delete own profile moments" on public.profile_moments for delete
  using (auth.uid() = user_id);

drop policy if exists "Leer items de momentos" on public.profile_moment_items;
drop policy if exists "Read profile moment items" on public.profile_moment_items;
create policy "Read profile moment items" on public.profile_moment_items for select using (true);

drop policy if exists "Crear items de momentos propios" on public.profile_moment_items;
drop policy if exists "Create own profile moment items" on public.profile_moment_items;
create policy "Create own profile moment items" on public.profile_moment_items for insert
  with check (
    exists (
      select 1 from public.profile_moments m
      where m.id = moment_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "Borrar items de momentos propios" on public.profile_moment_items;
drop policy if exists "Delete own profile moment items" on public.profile_moment_items;
create policy "Delete own profile moment items" on public.profile_moment_items for delete
  using (
    exists (
      select 1 from public.profile_moments m
      where m.id = moment_id and m.user_id = auth.uid()
    )
  );

grant select on public.profile_moments to anon, authenticated;
grant insert, update, delete on public.profile_moments to authenticated;
grant select on public.profile_moment_items to anon, authenticated;
grant insert, delete on public.profile_moment_items to authenticated;

create table if not exists public.moment_item_likes (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id    uuid not null references public.users (id) on delete cascade,
  item_id    uuid not null references public.profile_moment_items (id) on delete cascade,
  unique (user_id, item_id)
);

create index if not exists moment_item_likes_item_idx on public.moment_item_likes (item_id);

alter table public.moment_item_likes enable row level security;

drop policy if exists "Leer likes de momentos" on public.moment_item_likes;
drop policy if exists "Read moment item likes" on public.moment_item_likes;
create policy "Read moment item likes" on public.moment_item_likes for select using (true);

drop policy if exists "Dar like a momento" on public.moment_item_likes;
drop policy if exists "Create moment item likes" on public.moment_item_likes;
create policy "Create moment item likes" on public.moment_item_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Quitar like de momento" on public.moment_item_likes;
drop policy if exists "Delete own moment item likes" on public.moment_item_likes;
create policy "Delete own moment item likes" on public.moment_item_likes for delete
  using (auth.uid() = user_id);

grant select on public.moment_item_likes to anon, authenticated;
grant insert, delete on public.moment_item_likes to authenticated;

-- ---------------------------------------------------------------------------
-- User blocks
-- ---------------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

drop policy if exists "Leer mis bloqueos" on public.user_blocks;
drop policy if exists "Read own blocks" on public.user_blocks;
create policy "Read own blocks" on public.user_blocks
  for select using (auth.uid() = blocker_id);

drop policy if exists "Bloquear" on public.user_blocks;
drop policy if exists "Create blocks" on public.user_blocks;
create policy "Create blocks" on public.user_blocks
  for insert with check (auth.uid() = blocker_id);

drop policy if exists "Desbloquear" on public.user_blocks;
drop policy if exists "Delete own blocks" on public.user_blocks;
create policy "Delete own blocks" on public.user_blocks
  for delete using (auth.uid() = blocker_id);

grant select, insert, delete on public.user_blocks to authenticated;

-- ---------------------------------------------------------------------------
-- Saved posts (cloud, per account — not device-only)
-- ---------------------------------------------------------------------------
create table if not exists public.saved_posts (
  user_id    uuid not null references public.users (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index if not exists saved_posts_user_idx on public.saved_posts (user_id, created_at desc);

alter table public.saved_posts enable row level security;

drop policy if exists "Read own saved posts" on public.saved_posts;
create policy "Read own saved posts" on public.saved_posts
  for select using (auth.uid() = user_id);

drop policy if exists "Save posts" on public.saved_posts;
create policy "Save posts" on public.saved_posts
  for insert with check (auth.uid() = user_id);

drop policy if exists "Unsave posts" on public.saved_posts;
create policy "Unsave posts" on public.saved_posts
  for delete using (auth.uid() = user_id);

grant select, insert, delete on public.saved_posts to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: processed videos up to 300 MB
-- ---------------------------------------------------------------------------
update storage.buckets
set file_size_limit = 314572800
where id = 'media';

-- ---------------------------------------------------------------------------
-- Live rooms (catalog, chat, likes, presence)
-- ---------------------------------------------------------------------------
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

alter table public.live_streams add column if not exists total_viewers int not null default 0;
alter table public.live_streams add column if not exists ended_at timestamptz;
alter table public.live_streams add column if not exists last_heartbeat timestamptz not null default now();

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
create policy "Leer en vivos" on public.live_streams for select using (true);
drop policy if exists "Crear en vivo" on public.live_streams;
create policy "Crear en vivo" on public.live_streams for insert with check (auth.uid() = host_id);
drop policy if exists "Actualizar propio en vivo" on public.live_streams;
create policy "Actualizar propio en vivo" on public.live_streams for update using (auth.uid() = host_id);
drop policy if exists "Leer chat en vivo" on public.live_stream_messages;
create policy "Leer chat en vivo" on public.live_stream_messages for select using (true);
drop policy if exists "Comentar en vivo" on public.live_stream_messages;
create policy "Comentar en vivo" on public.live_stream_messages for insert with check (auth.uid() = author_id);
drop policy if exists "Leer likes en vivo" on public.live_stream_likes;
create policy "Leer likes en vivo" on public.live_stream_likes for select using (true);
drop policy if exists "Dar like en vivo" on public.live_stream_likes;
create policy "Dar like en vivo" on public.live_stream_likes for insert with check (auth.uid() = user_id);
drop policy if exists "Quitar like en vivo" on public.live_stream_likes;
create policy "Quitar like en vivo" on public.live_stream_likes for delete using (auth.uid() = user_id);
drop policy if exists "Leer presencia propia" on public.live_stream_viewers;
create policy "Leer presencia propia" on public.live_stream_viewers for select using (auth.uid() = user_id);

grant select on public.live_streams to anon, authenticated;
grant insert, update on public.live_streams to authenticated;
grant select on public.live_stream_messages to anon, authenticated;
grant insert on public.live_stream_messages to authenticated;
grant select on public.live_stream_likes to anon, authenticated;
grant insert, delete on public.live_stream_likes to authenticated;
grant select on public.live_stream_viewers to authenticated;

create or replace function public.live_likes_count_sync()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.live_streams set likes_count = likes_count + 1 where id = new.stream_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.live_streams set likes_count = greatest(likes_count - 1, 0) where id = old.stream_id;
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
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.live_streams
    set is_live = false, ended_at = coalesce(ended_at, now())
    where is_live = true and last_heartbeat < now() - interval '2 minutes';
end;
$$;

create or replace function public.live_heartbeat(p_stream_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  update public.live_streams
    set last_heartbeat = now()
    where id = p_stream_id and host_id = auth.uid() and is_live = true;
end;
$$;

create or replace function public.live_join_stream(p_stream_id uuid, p_session_key text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_session_key is null or length(trim(p_session_key)) < 8 then
    raise exception 'Sesión inválida';
  end if;
  if not exists (select 1 from public.live_streams where id = p_stream_id and is_live = true) then
    raise exception 'Esta transmisión ya no está en vivo';
  end if;
  insert into public.live_stream_viewers (stream_id, session_key, user_id)
  values (p_stream_id, trim(p_session_key), auth.uid())
  on conflict (stream_id, session_key) do update
    set last_seen = now(),
        user_id = coalesce(excluded.user_id, public.live_stream_viewers.user_id);
end;
$$;

create or replace function public.live_qualify_viewer(p_stream_id uuid, p_session_key text)
returns void language plpgsql security definer set search_path = public as $$
declare v_qualified boolean;
begin
  select qualified into v_qualified
  from public.live_stream_viewers
  where stream_id = p_stream_id and session_key = trim(p_session_key);
  if not found or v_qualified then return; end if;
  update public.live_stream_viewers
    set qualified = true, last_seen = now()
    where stream_id = p_stream_id and session_key = trim(p_session_key);
  update public.live_streams
    set viewer_count = viewer_count + 1, total_viewers = total_viewers + 1
    where id = p_stream_id and is_live = true;
end;
$$;

create or replace function public.live_leave_stream(p_stream_id uuid, p_session_key text)
returns void language plpgsql security definer set search_path = public as $$
declare v_qualified boolean;
begin
  select qualified into v_qualified
  from public.live_stream_viewers
  where stream_id = p_stream_id and session_key = trim(p_session_key);
  if not found then return; end if;
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
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_stream_messages'
  ) then
    alter publication supabase_realtime add table public.live_stream_messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_streams'
  ) then
    alter publication supabase_realtime add table public.live_streams;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Chat groups (same as migrations/027_chat_groups.sql)
-- ---------------------------------------------------------------------------
create table if not exists public.chat_groups (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(trim(name)) between 2 and 80),
  created_at       timestamptz not null default now(),
  created_by       uuid not null references public.users (id) on delete cascade,
  member_count     integer not null default 1 check (member_count >= 1 and member_count <= 5000),
  is_public        boolean not null default false,
  admins_only_chat boolean not null default false
);

alter table public.chat_groups add column if not exists is_public boolean not null default false;
alter table public.chat_groups add column if not exists admins_only_chat boolean not null default false;

create table if not exists public.chat_group_members (
  group_id  uuid not null references public.chat_groups (id) on delete cascade,
  user_id   uuid not null references public.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  role      text not null default 'member' check (role in ('admin', 'member')),
  primary key (group_id, user_id)
);

create table if not exists public.chat_group_messages (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.chat_groups (id) on delete cascade,
  sender_id  uuid not null references public.users (id) on delete cascade,
  content    text not null default '',
  created_at timestamptz not null default now(),
  media_url  text,
  media_type text
);

alter table public.chat_group_messages add column if not exists media_url text;
alter table public.chat_group_messages add column if not exists media_type text;
alter table public.chat_group_messages alter column content set default '';

create table if not exists public.chat_group_invites (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.chat_groups (id) on delete cascade,
  inviter_id   uuid not null references public.users (id) on delete cascade,
  invitee_id   uuid not null references public.users (id) on delete cascade,
  status       text not null default 'pending'
               check (status in ('pending', 'accepted', 'rejected')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  seen_at      timestamptz,
  unique (group_id, invitee_id)
);

alter table public.chat_group_invites add column if not exists seen_at timestamptz;

create index if not exists chat_groups_created_by_idx on public.chat_groups (created_by);
create index if not exists chat_group_members_user_idx on public.chat_group_members (user_id);
create index if not exists chat_group_messages_group_created_idx
  on public.chat_group_messages (group_id, created_at desc);
create index if not exists chat_group_invites_invitee_pending_idx
  on public.chat_group_invites (invitee_id, status);

create or replace function public.is_chat_group_member(p_group_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_chat_group_admin(p_group_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = auth.uid() and role = 'admin'
  );
$$;

alter table public.chat_groups enable row level security;
alter table public.chat_group_members enable row level security;
alter table public.chat_group_messages enable row level security;
alter table public.chat_group_invites enable row level security;

drop policy if exists "Ver grupos donde soy miembro" on public.chat_groups;
drop policy if exists "Ver grupos propios o públicos" on public.chat_groups;
drop policy if exists "Listar grupos autenticados" on public.chat_groups;
drop policy if exists "Read chat groups" on public.chat_groups;
create policy "Read chat groups" on public.chat_groups for select
  using (auth.uid() is not null);

drop policy if exists "Ver membresías de mis grupos" on public.chat_group_members;
drop policy if exists "Read group memberships" on public.chat_group_members;
create policy "Read group memberships" on public.chat_group_members for select
  using (user_id = auth.uid() or public.is_chat_group_member(group_id));

drop policy if exists "Leer mensajes de grupo" on public.chat_group_messages;
drop policy if exists "Read group messages" on public.chat_group_messages;
create policy "Read group messages" on public.chat_group_messages for select
  using (public.is_chat_group_member(group_id));

drop policy if exists "Enviar mensajes de grupo" on public.chat_group_messages;
drop policy if exists "Send group messages" on public.chat_group_messages;
create policy "Send group messages" on public.chat_group_messages for insert
  with check (
    auth.uid() = sender_id
    and public.is_chat_group_member(group_id)
    and (
      not (select g.admins_only_chat from public.chat_groups g where g.id = group_id)
      or public.is_chat_group_admin(group_id)
    )
    and (char_length(trim(content)) > 0 or media_url is not null)
  );

drop policy if exists "Ver invitaciones propias" on public.chat_group_invites;
drop policy if exists "Read group invites" on public.chat_group_invites;
create policy "Read group invites" on public.chat_group_invites for select
  using (
    invitee_id = auth.uid()
    or inviter_id = auth.uid()
    or public.is_chat_group_admin(group_id)
  );

create or replace function public.enforce_chat_group_member_limit()
returns trigger language plpgsql as $$
declare v_count integer;
begin
  select count(*) into v_count from public.chat_group_members where group_id = new.group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;
  return new;
end;
$$;

drop trigger if exists chat_group_member_limit_trg on public.chat_group_members;
create trigger chat_group_member_limit_trg
  before insert on public.chat_group_members
  for each row execute function public.enforce_chat_group_member_limit();

create or replace function public.sync_chat_group_member_count()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    update public.chat_groups
    set member_count = (select count(*) from public.chat_group_members where group_id = new.group_id)
    where id = new.group_id;
  elsif tg_op = 'DELETE' then
    update public.chat_groups
    set member_count = greatest((select count(*) from public.chat_group_members where group_id = old.group_id), 1)
    where id = old.group_id;
  end if;
  return null;
end;
$$;

drop trigger if exists chat_group_member_count_trg on public.chat_group_members;
create trigger chat_group_member_count_trg
  after insert or delete on public.chat_group_members
  for each row execute function public.sync_chat_group_member_count();

create or replace function public.enforce_max_group_admins()
returns trigger language plpgsql as $$
declare v_count integer;
begin
  if new.role <> 'admin' then return new; end if;
  select count(*) into v_count from public.chat_group_members
  where group_id = new.group_id and role = 'admin';
  if tg_op = 'UPDATE' and old.role = 'admin' then v_count := v_count - 1; end if;
  if v_count >= 3 then raise exception 'max_admins_reached'; end if;
  return new;
end;
$$;

drop trigger if exists chat_group_max_admins_trg on public.chat_group_members;
create trigger chat_group_max_admins_trg
  before insert or update of role on public.chat_group_members
  for each row execute function public.enforce_max_group_admins();

create or replace function public.enforce_min_one_group_admin()
returns trigger language plpgsql as $$
declare v_count integer;
begin
  if tg_op = 'UPDATE' and old.role = 'admin' and new.role = 'member' then
    select count(*) into v_count from public.chat_group_members
    where group_id = old.group_id and role = 'admin';
    if v_count <= 1 then raise exception 'last_admin'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists chat_group_min_admin_trg on public.chat_group_members;
create trigger chat_group_min_admin_trg
  before update of role on public.chat_group_members
  for each row execute function public.enforce_min_one_group_admin();

drop function if exists public.create_chat_group(text);
drop function if exists public.create_chat_group(text, boolean);

create or replace function public.create_chat_group(
  p_name text,
  p_is_public boolean default false,
  p_admins_only_chat boolean default false
)
returns public.chat_groups
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_created integer;
  v_group public.chat_groups;
  v_name text := trim(p_name);
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if char_length(v_name) < 2 then raise exception 'invalid_name'; end if;
  select count(*) into v_created from public.chat_groups where created_by = v_uid;
  if v_created >= 5 then raise exception 'group_limit_reached'; end if;
  insert into public.chat_groups (name, created_by, member_count, is_public, admins_only_chat)
  values (v_name, v_uid, 1, coalesce(p_is_public, false), coalesce(p_admins_only_chat, false))
  returning * into v_group;
  insert into public.chat_group_members (group_id, user_id, role)
  values (v_group.id, v_uid, 'admin');
  return v_group;
end;
$$;

create or replace function public.join_public_group(p_group_id uuid)
returns public.chat_groups
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_group from public.chat_groups where id = p_group_id;
  if not found then raise exception 'group_not_found'; end if;
  if not v_group.is_public then raise exception 'group_private'; end if;
  if exists (select 1 from public.chat_group_members where group_id = p_group_id and user_id = v_uid) then
    raise exception 'already_member';
  end if;
  select count(*) into v_count from public.chat_group_members where group_id = p_group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;
  insert into public.chat_group_members (group_id, user_id, role)
  values (p_group_id, v_uid, 'member');
  select * into v_group from public.chat_groups where id = p_group_id;
  return v_group;
end;
$$;

create or replace function public.invite_to_group(p_group_id uuid, p_invitee_id uuid)
returns public.chat_group_invites
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
  v_invite public.chat_group_invites;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_invitee_id = v_uid then raise exception 'cannot_invite_self'; end if;
  select * into v_group from public.chat_groups where id = p_group_id;
  if not found then raise exception 'group_not_found'; end if;
  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;
  if exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = p_invitee_id
  ) then
    raise exception 'already_member';
  end if;
  select count(*) into v_count from public.chat_group_members where group_id = p_group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;
  select * into v_invite from public.chat_group_invites
  where group_id = p_group_id and invitee_id = p_invitee_id;
  if found then
    if v_invite.status = 'accepted' then raise exception 'already_member'; end if;
    if v_invite.status = 'pending' then return v_invite; end if;
    update public.chat_group_invites
    set status = 'pending', inviter_id = v_uid, created_at = now(), responded_at = null, seen_at = null
    where id = v_invite.id
    returning * into v_invite;
    return v_invite;
  end if;
  insert into public.chat_group_invites (group_id, inviter_id, invitee_id, status)
  values (p_group_id, v_uid, p_invitee_id, 'pending')
  returning * into v_invite;
  return v_invite;
end;
$$;

create or replace function public.respond_group_invite(p_invite_id uuid, p_accept boolean)
returns public.chat_group_invites
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_invite public.chat_group_invites;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_invite
  from public.chat_group_invites
  where id = p_invite_id and invitee_id = v_uid and status = 'pending';
  if not found then raise exception 'invite_not_found'; end if;
  if not p_accept then
    update public.chat_group_invites
    set status = 'rejected', responded_at = now()
    where id = p_invite_id
    returning * into v_invite;
    return v_invite;
  end if;
  select count(*) into v_count from public.chat_group_members where group_id = v_invite.group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;
  insert into public.chat_group_members (group_id, user_id, role)
  values (v_invite.group_id, v_uid, 'member')
  on conflict do nothing;
  update public.chat_group_invites
  set status = 'accepted', responded_at = now()
  where id = p_invite_id
  returning * into v_invite;
  return v_invite;
end;
$$;

create or replace function public.mark_group_invites_seen()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.chat_group_invites
  set seen_at = now()
  where invitee_id = auth.uid() and status = 'pending' and seen_at is null;
end;
$$;

create or replace function public.set_group_admins_only_chat(p_group_id uuid, p_admins_only boolean)
returns public.chat_groups
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;
  update public.chat_groups
  set admins_only_chat = coalesce(p_admins_only, false)
  where id = p_group_id
  returning * into v_group;
  return v_group;
end;
$$;

create or replace function public.set_group_member_role(
  p_group_id uuid, p_user_id uuid, p_role text
)
returns public.chat_group_members
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_member public.chat_group_members;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_role not in ('admin', 'member') then raise exception 'invalid_role'; end if;
  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;
  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = p_user_id
  ) then
    raise exception 'not_member';
  end if;
  update public.chat_group_members
  set role = p_role
  where group_id = p_group_id and user_id = p_user_id
  returning * into v_member;
  return v_member;
end;
$$;

grant select on public.chat_groups to authenticated;
grant select on public.chat_group_members to authenticated;
grant select, insert on public.chat_group_messages to authenticated;
grant select on public.chat_group_invites to authenticated;
grant execute on function public.is_chat_group_member(uuid) to authenticated;
grant execute on function public.is_chat_group_admin(uuid) to authenticated;
grant execute on function public.create_chat_group(text, boolean, boolean) to authenticated;
grant execute on function public.join_public_group(uuid) to authenticated;
grant execute on function public.invite_to_group(uuid, uuid) to authenticated;
grant execute on function public.respond_group_invite(uuid, boolean) to authenticated;
grant execute on function public.mark_group_invites_seen() to authenticated;
grant execute on function public.set_group_admins_only_chat(uuid, boolean) to authenticated;
grant execute on function public.set_group_member_role(uuid, uuid, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'chat_group_messages'
     )
  then
    alter publication supabase_realtime add table public.chat_group_messages;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Search: trigram indexes for ilike on users / posts / groups
-- ---------------------------------------------------------------------------
create extension if not exists pg_trgm;

create index if not exists users_name_trgm_idx
  on public.users using gin (name gin_trgm_ops);

create index if not exists users_username_trgm_idx
  on public.users using gin (username gin_trgm_ops);

create index if not exists posts_content_trgm_idx
  on public.posts using gin (content gin_trgm_ops);

create index if not exists chat_groups_name_trgm_idx
  on public.chat_groups using gin (name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Chat groups: description, image, leave (028)
-- ---------------------------------------------------------------------------
alter table public.chat_groups add column if not exists description text;
alter table public.chat_groups add column if not exists image_url text;
alter table public.chat_groups drop constraint if exists chat_groups_description_len;
alter table public.chat_groups
  add constraint chat_groups_description_len
  check (description is null or char_length(description) <= 280);

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

create or replace function public.update_chat_group_profile(
  p_group_id uuid,
  p_description text default null,
  p_image_url text default null,
  p_clear_image boolean default false
)
returns public.chat_groups
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
  v_description text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;
  if p_description is not null then
    v_description := trim(p_description);
    if char_length(v_description) > 280 then raise exception 'invalid_description'; end if;
    if public.group_text_is_blocked(v_description) then raise exception 'blocked_content'; end if;
    if v_description = '' then v_description := null; end if;
  end if;
  if p_image_url is not null
     and p_image_url not like '%/storage/v1/object/public/media/%' then
    raise exception 'invalid_image';
  end if;
  update public.chat_groups
  set
    description = case when p_description is not null then v_description else description end,
    image_url = case
      when p_clear_image then null
      when p_image_url is not null then p_image_url
      else image_url
    end
  where id = p_group_id
  returning * into v_group;
  if not found then raise exception 'group_not_found'; end if;
  return v_group;
end;
$$;

create or replace function public.leave_chat_group(p_group_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_members integer;
  v_admins integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select role into v_role
  from public.chat_group_members
  where group_id = p_group_id and user_id = v_uid;
  if not found then raise exception 'not_member'; end if;
  select count(*) into v_members from public.chat_group_members where group_id = p_group_id;
  select count(*) into v_admins
  from public.chat_group_members
  where group_id = p_group_id and role = 'admin';
  if v_members <= 1 then
    delete from public.chat_groups where id = p_group_id;
    return;
  end if;
  if v_role = 'admin' and v_admins <= 1 then
    raise exception 'last_admin';
  end if;
  delete from public.chat_group_members
  where group_id = p_group_id and user_id = v_uid;
end;
$$;

grant execute on function public.group_text_is_blocked(text) to authenticated;
grant execute on function public.update_chat_group_profile(uuid, text, text, boolean) to authenticated;
grant execute on function public.leave_chat_group(uuid) to authenticated;

commit;

-- Confirmed infractions + automatic block at 4: run migrations/030_account_infractions.sql
-- Post-publication queue + RLS/storage/email: run migrations/031_post_moderation_security.sql
-- Queue worker, storage delete, private-bucket prep, OCR RPC: run migrations/032_moderation_hardening.sql
