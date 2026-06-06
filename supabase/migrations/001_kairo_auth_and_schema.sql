-- =============================================================================
-- KAIRO — Supabase: Auth Email/Password + esquema alineado con Prisma
-- Ejecutar en: Supabase Dashboard → SQL Editor (o supabase db push)
-- =============================================================================

-- Extensiones
create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. PERFIL DE USUARIO (public.users) — enlazado a auth.users
--    La contraseña vive SOLO en auth.users (Supabase Auth).
-- -----------------------------------------------------------------------------
create table if not exists public.users (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text not null unique,
  email_verified timestamptz,
  name          text,
  username      text unique,
  image         text,
  bio           text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists users_username_idx on public.users (username);
create index if not exists users_email_idx on public.users (email);

-- Trigger: crear fila en public.users al registrarse con Email/Password
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
    email = excluded.email,
    email_verified = excluded.email_verified,
    name = coalesce(excluded.name, public.users.name),
    username = coalesce(excluded.username, public.users.username),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- updated_at automático
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 2. RLS — usuarios
-- -----------------------------------------------------------------------------
alter table public.users enable row level security;

create policy "Perfiles públicos legibles"
  on public.users for select
  using (true);

create policy "Usuario actualiza su perfil"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- -----------------------------------------------------------------------------
-- 3. RESTO DEL ESQUEMA (Prisma → Supabase)
-- -----------------------------------------------------------------------------

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

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  content    text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  author_id  uuid not null references public.users (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade
);

create table if not exists public.likes (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  author_id  uuid not null references public.users (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade,
  unique (author_id, post_id)
);

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
  unique (follower_id, following_id)
);

create index if not exists follows_followee_seen_idx on public.follows (following_id, seen_by_followee_at);

create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  content     text not null,
  media_url   text,
  media_type  text,
  created_at  timestamptz not null default now(),
  read_at     timestamptz,
  sender_id   uuid not null references public.users (id) on delete cascade,
  receiver_id uuid not null references public.users (id) on delete cascade
);

-- Historias (24 h) — amistad mutua se valida en la app / RPC
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

-- RLS básico posts (feed sin anónimos)
alter table public.posts enable row level security;

create policy "Leer posts públicos no anónimos"
  on public.posts for select
  using (is_anonymous = false or author_id = auth.uid());

create policy "Crear posts autenticado"
  on public.posts for insert
  with check (auth.uid() = author_id);

create policy "Editar propios posts"
  on public.posts for update
  using (auth.uid() = author_id);

-- Amigos mutuos (helper para historias / feed)
create or replace function public.are_mutual_friends(user_a uuid, user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.follows f1
    join public.follows f2
      on f1.follower_id = f2.following_id
     and f1.following_id = f2.follower_id
    where f1.follower_id = user_a and f1.following_id = user_b
  );
$$;

-- Historias visibles: mutuos + no expiradas
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

grant usage on schema public to anon, authenticated;
grant select on public.users to anon, authenticated;
grant all on public.users to authenticated;
grant select, insert, update on public.posts to authenticated;
