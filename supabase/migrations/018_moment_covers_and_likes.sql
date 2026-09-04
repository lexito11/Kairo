-- =============================================================================
-- KAIRO — Portada de Momentos + corazones por ítem
-- Supabase → SQL Editor → Run
-- =============================================================================

alter table public.profile_moments
  add column if not exists cover_url text;

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
create policy "Leer likes de momentos" on public.moment_item_likes for select
  using (true);

drop policy if exists "Dar like a momento" on public.moment_item_likes;
create policy "Dar like a momento" on public.moment_item_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists "Quitar like de momento" on public.moment_item_likes;
create policy "Quitar like de momento" on public.moment_item_likes for delete
  using (auth.uid() = user_id);

grant select on public.moment_item_likes to anon, authenticated;
grant insert, delete on public.moment_item_likes to authenticated;
