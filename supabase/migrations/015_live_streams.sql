-- =============================================================================
-- KAIRO — Transmisiones en vivo
-- Ejecutar en Supabase SQL Editor
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

create index if not exists live_streams_live_idx
  on public.live_streams (is_live, created_at desc);

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

alter table public.live_streams enable row level security;
alter table public.live_stream_messages enable row level security;
alter table public.live_stream_likes enable row level security;

drop policy if exists "Leer en vivos" on public.live_streams;
create policy "Leer en vivos" on public.live_streams for select using (true);

drop policy if exists "Crear en vivo" on public.live_streams;
create policy "Crear en vivo" on public.live_streams for insert
  with check (auth.uid() = host_id);

drop policy if exists "Actualizar propio en vivo" on public.live_streams;
create policy "Actualizar propio en vivo" on public.live_streams for update
  using (auth.uid() = host_id);

drop policy if exists "Leer chat en vivo" on public.live_stream_messages;
create policy "Leer chat en vivo" on public.live_stream_messages for select using (true);

drop policy if exists "Comentar en vivo" on public.live_stream_messages;
create policy "Comentar en vivo" on public.live_stream_messages for insert
  with check (auth.uid() = author_id);

drop policy if exists "Leer likes en vivo" on public.live_stream_likes;
create policy "Leer likes en vivo" on public.live_stream_likes for select using (true);

drop policy if exists "Dar like en vivo" on public.live_stream_likes;
create policy "Dar like en vivo" on public.live_stream_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Quitar like en vivo" on public.live_stream_likes;
create policy "Quitar like en vivo" on public.live_stream_likes for delete
  using (auth.uid() = user_id);

grant select on public.live_streams to anon, authenticated;
grant insert, update on public.live_streams to authenticated;
grant select on public.live_stream_messages to anon, authenticated;
grant insert on public.live_stream_messages to authenticated;
grant select on public.live_stream_likes to anon, authenticated;
grant insert, delete on public.live_stream_likes to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'live_stream_messages'
  ) then
    alter publication supabase_realtime add table public.live_stream_messages;
  end if;
end $$;
