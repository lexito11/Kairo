-- =============================================================================
-- KAIRO — Script completo de base de datos para Supabase
-- =============================================================================
--
-- CÓMO EJECUTAR (proyecto nuevo o vacío):
--   1. Supabase Dashboard → SQL Editor → New query
--   2. Pegar TODO este archivo y pulsar Run
--   3. Authentication → Providers → activar Email (Email/Password)
--   4. Project Settings → API → copiar URL y anon key a Flutter
--
-- IDEMPOTENTE: usa DROP IF EXISTS / CREATE OR REPLACE donde aplica.
-- Seguro re-ejecutar en el mismo proyecto (no borra datos de tablas).
--
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 0. EXTENSIONES
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. FUNCIÓN updated_at (reutilizada en varios triggers)
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
-- 2. TABLA users (perfil público enlazado a auth.users)
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
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Columnas extra si users ya existía sin mood (migración 003)
alter table public.users add column if not exists mood text;
alter table public.users add column if not exists mood_updated_at timestamptz;

create index if not exists users_username_idx on public.users (username);
create index if not exists users_email_idx on public.users (email);

-- Trigger: perfil al registrarse
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
-- 3. TABLAS SOCIALES
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
-- 4. FUNCIONES RPC (historias / amigos mutuos)
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
-- 5. ROW LEVEL SECURITY — habilitar en todas las tablas
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
create policy "Perfiles públicos legibles"
  on public.users for select using (true);

drop policy if exists "Usuario actualiza su perfil" on public.users;
create policy "Usuario actualiza su perfil"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- posts
drop policy if exists "Leer posts públicos no anónimos" on public.posts;
create policy "Leer posts públicos no anónimos"
  on public.posts for select
  using (is_anonymous = false or author_id = auth.uid());

drop policy if exists "Crear posts autenticado" on public.posts;
create policy "Crear posts autenticado"
  on public.posts for insert
  with check (auth.uid() = author_id);

drop policy if exists "Editar propios posts" on public.posts;
create policy "Editar propios posts"
  on public.posts for update
  using (auth.uid() = author_id);

drop policy if exists "Borrar propios posts" on public.posts;
create policy "Borrar propios posts"
  on public.posts for delete
  using (auth.uid() = author_id);

-- comments
drop policy if exists "Leer comentarios" on public.comments;
create policy "Leer comentarios" on public.comments for select using (true);

drop policy if exists "Crear comentarios" on public.comments;
create policy "Crear comentarios" on public.comments for insert
  with check (auth.uid() = author_id);

drop policy if exists "Editar propios comentarios" on public.comments;
create policy "Editar propios comentarios" on public.comments for update
  using (auth.uid() = author_id);

drop policy if exists "Borrar propios comentarios" on public.comments;
create policy "Borrar propios comentarios" on public.comments for delete
  using (auth.uid() = author_id);

-- likes
drop policy if exists "Leer likes" on public.likes;
create policy "Leer likes" on public.likes for select using (true);

drop policy if exists "Dar like" on public.likes;
create policy "Dar like" on public.likes for insert
  with check (auth.uid() = author_id);

drop policy if exists "Quitar like" on public.likes;
create policy "Quitar like" on public.likes for delete
  using (auth.uid() = author_id);

-- post_views
drop policy if exists "Leer propias vistas" on public.post_views;
create policy "Leer propias vistas" on public.post_views for select
  using (auth.uid() = user_id);

drop policy if exists "Registrar vista" on public.post_views;
create policy "Registrar vista" on public.post_views for insert
  with check (auth.uid() = user_id);

drop policy if exists "Actualizar vista" on public.post_views;
create policy "Actualizar vista" on public.post_views for update
  using (auth.uid() = user_id);

-- follows
drop policy if exists "Leer follows" on public.follows;
create policy "Leer follows" on public.follows for select using (true);

drop policy if exists "Seguir" on public.follows;
create policy "Seguir" on public.follows for insert
  with check (auth.uid() = follower_id);

drop policy if exists "Dejar de seguir" on public.follows;
create policy "Dejar de seguir" on public.follows for delete
  using (auth.uid() = follower_id);

drop policy if exists "Eliminar seguidor" on public.follows;
create policy "Eliminar seguidor" on public.follows for delete
  using (auth.uid() = following_id);

drop policy if exists "Marcar notificación vista" on public.follows;
create policy "Marcar notificación vista" on public.follows for update
  using (auth.uid() = following_id);

-- messages
drop policy if exists "Leer mensajes propios" on public.messages;
create policy "Leer mensajes propios" on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "Enviar mensajes" on public.messages;
create policy "Enviar mensajes" on public.messages for insert
  with check (auth.uid() = sender_id);

drop policy if exists "Marcar leído" on public.messages;
create policy "Marcar leído" on public.messages for update
  using (auth.uid() = receiver_id);

-- stories
drop policy if exists "Leer historias no expiradas" on public.stories;
create policy "Leer historias no expiradas" on public.stories for select
  using (expires_at > now());

drop policy if exists "Crear historias" on public.stories;
create policy "Crear historias" on public.stories for insert
  with check (auth.uid() = author_id);

drop policy if exists "Borrar propias historias" on public.stories;
create policy "Borrar propias historias" on public.stories for delete
  using (auth.uid() = author_id);

-- events
drop policy if exists "Leer eventos" on public.events;
create policy "Leer eventos" on public.events for select using (true);

drop policy if exists "Crear eventos autenticado" on public.events;
create policy "Crear eventos autenticado" on public.events for insert
  with check (auth.uid() = created_by);

-- intercessions
drop policy if exists "Leer intercesiones" on public.intercessions;
create policy "Leer intercesiones" on public.intercessions for select using (true);

drop policy if exists "Interceder" on public.intercessions;
create policy "Interceder" on public.intercessions for insert
  with check (auth.uid() = user_id);

drop policy if exists "Quitar intercesión" on public.intercessions;
create policy "Quitar intercesión" on public.intercessions for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 6. GRANTS (anon puede ver feed público; authenticated puede escribir)
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

grant execute on function public.get_mutual_friend_stories(uuid) to authenticated;
grant execute on function public.are_mutual_friends(uuid, uuid) to authenticated;

-- Secuencias (ids autogenerados)
grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- 7. STORAGE — bucket "media" para fotos/videos de posts e historias
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', true, 52428800)
on conflict (id) do update
  set public = true, file_size_limit = 52428800;

drop policy if exists "Media público lectura" on storage.objects;
create policy "Media público lectura"
  on storage.objects for select
  using (bucket_id = 'media');

drop policy if exists "Media subida autenticada" on storage.objects;
create policy "Media subida autenticada"
  on storage.objects for insert
  with check (bucket_id = 'media' and auth.role() = 'authenticated');

drop policy if exists "Media actualizar propio" on storage.objects;
create policy "Media actualizar propio"
  on storage.objects for update
  using (bucket_id = 'media' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "Media borrar propio" on storage.objects;
create policy "Media borrar propio"
  on storage.objects for delete
  using (bucket_id = 'media' and auth.uid()::text = (storage.foldername(name))[1]);

-- ---------------------------------------------------------------------------
-- 8. REALTIME — chat en vivo (Flutter subscribeToMessages)
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
end $$;

-- ---------------------------------------------------------------------------
-- 9. DATOS INICIALES — eventos de ejemplo (solo si la tabla está vacía)
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

-- =============================================================================
-- CHECKLIST POST-EJECUCIÓN (manual en el Dashboard):
--   [ ] Authentication → Providers → Email → Enable
--   [ ] Authentication → URL Configuration → Site URL (ej. http://localhost:5173)
--   [ ] Storage → bucket "media" visible y público
--   [ ] Database → Replication → messages en supabase_realtime (verificar)
--   [ ] Flutter: SUPABASE_URL y SUPABASE_ANON_KEY en supabase_config.dart
-- =============================================================================
