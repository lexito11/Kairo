-- =============================================================================
-- KAIRO — Interacciones de historias (likes + nombre del sonido)
-- Ejecutar en Supabase SQL Editor
-- =============================================================================

alter table public.stories
  add column if not exists sound_name text;

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
create policy "Leer likes de historias" on public.story_likes for select
  using (true);

drop policy if exists "Dar like a historia" on public.story_likes;
create policy "Dar like a historia" on public.story_likes for insert
  with check (auth.uid() = author_id);

drop policy if exists "Quitar like de historia" on public.story_likes;
create policy "Quitar like de historia" on public.story_likes for delete
  using (auth.uid() = author_id);

grant select on public.story_likes to anon, authenticated;
grant insert, delete on public.story_likes to authenticated;
