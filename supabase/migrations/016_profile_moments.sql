-- =============================================================================
-- KAIRO — Momentos (historias destacadas del perfil)
-- Ejecutar en Supabase SQL Editor
-- =============================================================================

create table if not exists public.profile_moments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  title      text not null,
  icon_id    text not null default 'star',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

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
create policy "Leer momentos de perfil" on public.profile_moments for select
  using (true);

drop policy if exists "Crear propios momentos" on public.profile_moments;
create policy "Crear propios momentos" on public.profile_moments for insert
  with check (auth.uid() = user_id);

drop policy if exists "Editar propios momentos" on public.profile_moments;
create policy "Editar propios momentos" on public.profile_moments for update
  using (auth.uid() = user_id);

drop policy if exists "Borrar propios momentos" on public.profile_moments;
create policy "Borrar propios momentos" on public.profile_moments for delete
  using (auth.uid() = user_id);

drop policy if exists "Leer items de momentos" on public.profile_moment_items;
create policy "Leer items de momentos" on public.profile_moment_items for select
  using (true);

drop policy if exists "Crear items de momentos propios" on public.profile_moment_items;
create policy "Crear items de momentos propios" on public.profile_moment_items for insert
  with check (
    exists (
      select 1 from public.profile_moments m
      where m.id = moment_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "Borrar items de momentos propios" on public.profile_moment_items;
create policy "Borrar items de momentos propios" on public.profile_moment_items for delete
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
