-- =============================================================================
-- KAIRO — Complete Supabase database script
-- =============================================================================
--
-- HOW TO RUN (new or empty project):
--   1. Supabase Dashboard → SQL Editor → New query
--   2. Paste this entire file and click Run
--   3. Authentication → Providers → enable Email (Email/Password)
--   4. Project Settings → API → copy URL and anon key into Flutter
--
-- IDEMPOTENT: uses DROP IF EXISTS / CREATE OR REPLACE where applicable.
-- Safe to re-run on the same project (does not delete table data).
--
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. EXTENSIONS
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. updated_at helper (reused by several triggers)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. users (public profile linked to auth.users)
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id               uuid primary key references auth.users (id) on delete cascade,
  email            text not null unique,
  email_verified   timestamptz,
  name             text,
  username         text unique,
  image            text,
  bio              text,
  mood             text,
  mood_updated_at  timestamptz,
  username_changed_at timestamptz,
  cover_url        text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Extra columns if users already existed without mood / cover / username policy
alter table public.users add column if not exists mood text;
alter table public.users add column if not exists mood_updated_at timestamptz;
alter table public.users add column if not exists username_changed_at timestamptz;
alter table public.users add column if not exists cover_url text;

create index if not exists users_username_idx on public.users (username);
create index if not exists users_email_idx on public.users (email);
create extension if not exists pg_trgm;
create index if not exists users_name_trgm_idx on public.users using gin (name gin_trgm_ops);
create index if not exists users_username_trgm_idx on public.users using gin (username gin_trgm_ops);

-- Trigger: create a public profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, email_verified, name, username)
  values (
    new.id,
    new.email,
    new.email_confirmed_at,
    coalesce(new.raw_user_meta_data->>'name', null),
    nullif(trim(new.raw_user_meta_data->>'username'), '')
  )
  on conflict (id) do update set
    email          = excluded.email,
    email_verified = excluded.email_verified,
    name           = coalesce(excluded.name, public.users.name),
    username       = coalesce(excluded.username, public.users.username),
    updated_at     = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. SOCIAL TABLES
-- ---------------------------------------------------------------------------
create table if not exists public.posts (
  id           uuid primary key default gen_random_uuid(),
  content      text not null,
  media_url    text,
  media_type   text,
  is_anonymous boolean not null default false,
  post_kind    text not null default 'post',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  author_id    uuid not null references public.users (id) on delete cascade
);

create index if not exists posts_author_anon_idx on public.posts (author_id, is_anonymous);
create index if not exists posts_anon_created_idx on public.posts (is_anonymous, created_at desc);
create index if not exists posts_created_idx on public.posts (created_at desc);
create index if not exists posts_content_trgm_idx on public.posts using gin (content gin_trgm_ops);

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
  before update on public.posts
  for each row execute function public.set_updated_at();

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  content    text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  author_id  uuid not null references public.users (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade
);

create index if not exists comments_post_idx on public.comments (post_id, created_at);

drop trigger if exists comments_set_updated_at on public.comments;
create trigger comments_set_updated_at
  before update on public.comments
  for each row execute function public.set_updated_at();

create table if not exists public.likes (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  author_id  uuid not null references public.users (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade,
  unique (author_id, post_id)
);

create index if not exists likes_post_idx on public.likes (post_id);

create table if not exists public.post_views (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users (id) on delete cascade,
  post_id         uuid not null references public.posts (id) on delete cascade,
  watched_seconds int not null default 0,
  created_at      timestamptz not null default now()
);

create index if not exists post_views_user_post_idx on public.post_views (user_id, post_id);

create table if not exists public.follows (
  id                  uuid primary key default gen_random_uuid(),
  created_at          timestamptz not null default now(),
  follower_id         uuid not null references public.users (id) on delete cascade,
  following_id        uuid not null references public.users (id) on delete cascade,
  seen_by_followee_at timestamptz,
  unique (follower_id, following_id),
  check (follower_id <> following_id)
);

create index if not exists follows_follower_idx on public.follows (follower_id);
create index if not exists follows_following_idx on public.follows (following_id);
create index if not exists follows_followee_seen_idx on public.follows (following_id, seen_by_followee_at);

create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  content     text not null,
  media_url   text,
  media_type  text,
  created_at  timestamptz not null default now(),
  read_at     timestamptz,
  sender_id   uuid not null references public.users (id) on delete cascade,
  receiver_id uuid not null references public.users (id) on delete cascade,
  check (sender_id <> receiver_id)
);

create index if not exists messages_conversation_idx
  on public.messages (sender_id, receiver_id, created_at desc);
create index if not exists messages_receiver_unread_idx
  on public.messages (receiver_id, read_at);

create table if not exists public.stories (
  id         uuid primary key default gen_random_uuid(),
  media_url  text not null,
  media_type text not null default 'image',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  author_id  uuid not null references public.users (id) on delete cascade
);

create index if not exists stories_author_expires_idx on public.stories (author_id, expires_at desc);
create index if not exists stories_expires_idx on public.stories (expires_at);

create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  location     text,
  description  text,
  event_date   timestamptz not null,
  denomination text,
  created_by   uuid references public.users (id) on delete set null,
  created_at   timestamptz not null default now()
);

create index if not exists events_date_idx on public.events (event_date);

create table if not exists public.intercessions (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create index if not exists intercessions_post_idx on public.intercessions (post_id);

-- ---------------------------------------------------------------------------
-- 4. RPC FUNCTIONS (stories / mutual friends)
-- ---------------------------------------------------------------------------
create or replace function public.are_mutual_friends(user_a uuid, user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.follows f1
    join public.follows f2
      on f1.follower_id = f2.following_id
     and f1.following_id = f2.follower_id
    where f1.follower_id = user_a
      and f1.following_id = user_b
  );
$$;

create or replace function public.get_mutual_friend_stories(viewer_id uuid)
returns setof public.stories
language sql
stable
security definer
set search_path = public
as $$
  select s.*
  from public.stories s
  where s.expires_at > now()
    and s.author_id <> viewer_id
    and public.are_mutual_friends(viewer_id, s.author_id)
  order by s.created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY — enable on all tables
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.post_views enable row level security;
alter table public.follows enable row level security;
alter table public.messages enable row level security;
alter table public.stories enable row level security;
alter table public.events enable row level security;
alter table public.intercessions enable row level security;

-- users
drop policy if exists "Perfiles públicos legibles" on public.users;
drop policy if exists "Users are publicly readable" on public.users;
create policy "Users are publicly readable"
  on public.users for select using (true);

drop policy if exists "Usuario actualiza su perfil" on public.users;
drop policy if exists "Users can update own profile" on public.users;
create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- posts
drop policy if exists "Leer posts públicos no anónimos" on public.posts;
drop policy if exists "Read public non-anonymous posts" on public.posts;
create policy "Read public non-anonymous posts"
  on public.posts for select
  using (is_anonymous = false or author_id = auth.uid());

drop policy if exists "Crear posts autenticado" on public.posts;
drop policy if exists "Authenticated users can create posts" on public.posts;
create policy "Authenticated users can create posts"
  on public.posts for insert
  with check (auth.uid() = author_id);

drop policy if exists "Editar propios posts" on public.posts;
drop policy if exists "Users can update own posts" on public.posts;
create policy "Users can update own posts"
  on public.posts for update
  using (auth.uid() = author_id);

drop policy if exists "Borrar propios posts" on public.posts;
drop policy if exists "Users can delete own posts" on public.posts;
create policy "Users can delete own posts"
  on public.posts for delete
  using (auth.uid() = author_id);

-- comments
drop policy if exists "Leer comentarios" on public.comments;
drop policy if exists "Read comments" on public.comments;
create policy "Read comments" on public.comments for select using (true);

drop policy if exists "Crear comentarios" on public.comments;
drop policy if exists "Create comments" on public.comments;
create policy "Create comments" on public.comments for insert
  with check (auth.uid() = author_id);

drop policy if exists "Editar propios comentarios" on public.comments;
drop policy if exists "Users can update own comments" on public.comments;
create policy "Users can update own comments" on public.comments for update
  using (auth.uid() = author_id);

drop policy if exists "Borrar propios comentarios" on public.comments;
drop policy if exists "Users can delete own comments" on public.comments;
create policy "Users can delete own comments" on public.comments for delete
  using (auth.uid() = author_id);

-- likes
drop policy if exists "Leer likes" on public.likes;
drop policy if exists "Read likes" on public.likes;
create policy "Read likes" on public.likes for select using (true);

drop policy if exists "Dar like" on public.likes;
drop policy if exists "Create likes" on public.likes;
create policy "Create likes" on public.likes for insert
  with check (auth.uid() = author_id);

drop policy if exists "Quitar like" on public.likes;
drop policy if exists "Delete own likes" on public.likes;
create policy "Delete own likes" on public.likes for delete
  using (auth.uid() = author_id);

-- post_views
drop policy if exists "Leer propias vistas" on public.post_views;
drop policy if exists "Read own post views" on public.post_views;
create policy "Read own post views" on public.post_views for select
  using (auth.uid() = user_id);

drop policy if exists "Registrar vista" on public.post_views;
drop policy if exists "Create post views" on public.post_views;
create policy "Create post views" on public.post_views for insert
  with check (auth.uid() = user_id);

drop policy if exists "Actualizar vista" on public.post_views;
drop policy if exists "Update own post views" on public.post_views;
create policy "Update own post views" on public.post_views for update
  using (auth.uid() = user_id);

-- follows
drop policy if exists "Leer follows" on public.follows;
drop policy if exists "Read follows" on public.follows;
create policy "Read follows" on public.follows for select using (true);

drop policy if exists "Seguir" on public.follows;
drop policy if exists "Create follows" on public.follows;
create policy "Create follows" on public.follows for insert
  with check (auth.uid() = follower_id);

drop policy if exists "Dejar de seguir" on public.follows;
drop policy if exists "Unfollow" on public.follows;
create policy "Unfollow" on public.follows for delete
  using (auth.uid() = follower_id);

drop policy if exists "Eliminar seguidor" on public.follows;
drop policy if exists "Remove follower" on public.follows;
create policy "Remove follower" on public.follows for delete
  using (auth.uid() = following_id);

drop policy if exists "Marcar notificación vista" on public.follows;
drop policy if exists "Mark follow notification seen" on public.follows;
create policy "Mark follow notification seen" on public.follows for update
  using (auth.uid() = following_id);

-- messages
drop policy if exists "Leer mensajes propios" on public.messages;
drop policy if exists "Read own messages" on public.messages;
create policy "Read own messages" on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Enviar mensajes" on public.messages;
drop policy if exists "Send messages" on public.messages;
create policy "Send messages" on public.messages for insert
  with check (auth.uid() = sender_id);

drop policy if exists "Marcar leído" on public.messages;
drop policy if exists "Mark messages as read" on public.messages;
create policy "Mark messages as read" on public.messages for update
  using (auth.uid() = receiver_id);

-- stories
drop policy if exists "Leer historias no expiradas" on public.stories;
drop policy if exists "Read non-expired stories" on public.stories;
create policy "Read non-expired stories" on public.stories for select
  using (expires_at > now());

drop policy if exists "Crear historias" on public.stories;
drop policy if exists "Create stories" on public.stories;
create policy "Create stories" on public.stories for insert
  with check (auth.uid() = author_id);

drop policy if exists "Borrar propias historias" on public.stories;
drop policy if exists "Delete own stories" on public.stories;
create policy "Delete own stories" on public.stories for delete
  using (auth.uid() = author_id);

-- events
drop policy if exists "Leer eventos" on public.events;
drop policy if exists "Read events" on public.events;
create policy "Read events" on public.events for select using (true);

drop policy if exists "Crear eventos autenticado" on public.events;
drop policy if exists "Authenticated users can create events" on public.events;
create policy "Authenticated users can create events" on public.events for insert
  with check (auth.uid() = created_by);

-- intercessions
drop policy if exists "Leer intercesiones" on public.intercessions;
drop policy if exists "Read intercessions" on public.intercessions;
create policy "Read intercessions" on public.intercessions for select using (true);

drop policy if exists "Interceder" on public.intercessions;
drop policy if exists "Create intercessions" on public.intercessions;
create policy "Create intercessions" on public.intercessions for insert
  with check (auth.uid() = user_id);

drop policy if exists "Quitar intercesión" on public.intercessions;
drop policy if exists "Delete own intercessions" on public.intercessions;
create policy "Delete own intercessions" on public.intercessions for delete
  using (auth.uid() = user_id);

-- chat groups
create table if not exists public.chat_groups (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(trim(name)) between 2 and 80),
  created_at       timestamptz not null default now(),
  created_by       uuid not null references public.users (id) on delete cascade,
  member_count     integer not null default 1 check (member_count >= 1 and member_count <= 5000),
  is_public        boolean not null default false,
  admins_only_chat boolean not null default false,
  description      text check (description is null or char_length(description) <= 280),
  image_url        text
);

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

create index if not exists chat_groups_created_by_idx on public.chat_groups (created_by);
create index if not exists chat_group_members_user_idx on public.chat_group_members (user_id);
create index if not exists chat_group_messages_group_created_idx
  on public.chat_group_messages (group_id, created_at desc);
create index if not exists chat_group_invites_invitee_pending_idx
  on public.chat_group_invites (invitee_id, status);
create index if not exists chat_groups_name_trgm_idx
  on public.chat_groups using gin (name gin_trgm_ops);

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

drop policy if exists "Read chat groups" on public.chat_groups;
create policy "Read chat groups" on public.chat_groups for select
  using (auth.uid() is not null);

drop policy if exists "Read group memberships" on public.chat_group_members;
create policy "Read group memberships" on public.chat_group_members for select
  using (user_id = auth.uid() or public.is_chat_group_member(group_id));

drop policy if exists "Read group messages" on public.chat_group_messages;
create policy "Read group messages" on public.chat_group_messages for select
  using (public.is_chat_group_member(group_id));

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

create or replace function public.group_text_is_blocked(p_text text)
returns boolean language sql immutable as $$
  select coalesce(p_text, '') ~* '(porn|xxx|onlyfans|nsfw|hentai|nudes?|nudity|naked|desnud[oa]s?|bikini|lencer[ií]a|ropa interior|underwear|sexting|sexualiz|expl[ií]cit[oa]|contenido sexual)';
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

-- live rooms
create table if not exists public.live_streams (
  id            uuid primary key default gen_random_uuid(),
  host_id       uuid not null references public.users (id) on delete cascade,
  title         text not null,
  orientation   text not null default '16:9'
                check (orientation in ('16:9', '9:16')),
  tags          text[] not null default '{}',
  thumbnail_url text,
  viewer_count  int not null default 0,
  total_viewers int not null default 0,
  likes_count   int not null default 0,
  is_live       boolean not null default true,
  last_heartbeat timestamptz not null default now(),
  ended_at      timestamptz,
  created_at    timestamptz not null default now()
);

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

-- user_blocks
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

-- ---------------------------------------------------------------------------
-- 6. GRANTS (anon can read the public feed; authenticated can write)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant select on public.users to anon, authenticated;
grant update on public.users to authenticated;

grant select on public.posts to anon, authenticated;
grant insert, update, delete on public.posts to authenticated;

grant select on public.comments to anon, authenticated;
grant insert, update, delete on public.comments to authenticated;

grant select on public.likes to anon, authenticated;
grant insert, delete on public.likes to authenticated;

grant select on public.intercessions to anon, authenticated;
grant insert, delete on public.intercessions to authenticated;

grant select on public.follows to anon, authenticated;
grant insert, update, delete on public.follows to authenticated;

grant select on public.events to anon, authenticated;
grant insert on public.events to authenticated;

grant select, insert, delete on public.stories to authenticated;
grant select on public.stories to anon;

grant select, insert, update on public.messages to authenticated;

grant select, insert, update on public.post_views to authenticated;

grant select, insert, delete on public.user_blocks to authenticated;

grant select on public.live_streams to anon, authenticated;
grant insert, update on public.live_streams to authenticated;
grant select on public.live_stream_messages to anon, authenticated;
grant insert on public.live_stream_messages to authenticated;
grant select on public.live_stream_likes to anon, authenticated;
grant insert, delete on public.live_stream_likes to authenticated;
grant select on public.live_stream_viewers to authenticated;

grant execute on function public.get_mutual_friend_stories(uuid) to authenticated;
grant execute on function public.are_mutual_friends(uuid, uuid) to authenticated;
grant execute on function public.live_sweep_stale() to anon, authenticated;
grant execute on function public.live_heartbeat(uuid) to authenticated;
grant execute on function public.live_join_stream(uuid, text) to anon, authenticated;
grant execute on function public.live_qualify_viewer(uuid, text) to anon, authenticated;
grant execute on function public.live_leave_stream(uuid, text) to anon, authenticated;

-- Sequences (generated ids)
grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- 7. STORAGE — "media" bucket for post and story photos/videos
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', true, 314572800)
on conflict (id) do update
  set public = true, file_size_limit = 314572800;

drop policy if exists "Media público lectura" on storage.objects;
drop policy if exists "Public media read" on storage.objects;
create policy "Public media read"
  on storage.objects for select
  using (bucket_id = 'media');

drop policy if exists "Media subida autenticada" on storage.objects;
drop policy if exists "Authenticated media upload" on storage.objects;
create policy "Authenticated media upload"
  on storage.objects for insert
  with check (bucket_id = 'media' and auth.role() = 'authenticated');

drop policy if exists "Media actualizar propio" on storage.objects;
drop policy if exists "Update own media" on storage.objects;
create policy "Update own media"
  on storage.objects for update
  using (bucket_id = 'media' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "Media borrar propio" on storage.objects;
drop policy if exists "Delete own media" on storage.objects;
create policy "Delete own media"
  on storage.objects for delete
  using (bucket_id = 'media' and auth.uid()::text = (storage.foldername(name))[1]);

-- ---------------------------------------------------------------------------
-- 8. REALTIME — live chat (Flutter subscribeToMessages)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_stream_messages'
  ) then
    alter publication supabase_realtime add table public.live_stream_messages;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_streams'
  ) then
    alter publication supabase_realtime add table public.live_streams;
  end if;
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_group_messages'
  ) then
    alter publication supabase_realtime add table public.chat_group_messages;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. SEED DATA — sample events (only if the table is empty)
-- ---------------------------------------------------------------------------
insert into public.events (title, location, description, event_date, denomination)
select v.title, v.location, v.description, v.event_date, v.denomination
from (
  values
    ('Culto dominical'::text, 'Iglesia Central'::text, 'Adoración y predicación'::text, now() + interval '2 days', 'general'::text),
    ('Estudio bíblico', 'Salón juvenil', 'Estudio del libro de Romanos', now() + interval '4 days', 'general'),
    ('Noche de alabanza', 'Auditorio principal', 'Alabanza y testimonios', now() + interval '6 days', 'general')
) as v(title, location, description, event_date, denomination)
where not exists (select 1 from public.events limit 1);

commit;

-- Confirmed infractions + automatic block at 4: run migrations/030_account_infractions.sql
-- Post-publication queue + RLS/storage/email: run migrations/031_post_moderation_security.sql

-- =============================================================================
-- POST-RUN CHECKLIST (manual in the Dashboard):
--   [ ] Authentication → Providers → Email → Enable
--   [ ] Authentication → URL Configuration → Site URL (e.g. http://localhost:5173)
--   [ ] Storage → "media" bucket is visible and public
--   [ ] Database → Replication → messages in supabase_realtime (verify)
--   [ ] Flutter: SUPABASE_URL and SUPABASE_ANON_KEY in supabase_config.dart
-- =============================================================================
