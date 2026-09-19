-- =============================================================================
-- KAIRO — Events catalog columns and creator policies
-- Safe to re-run. Paste into Supabase SQL Editor.
-- =============================================================================

alter table public.events
  add column if not exists estado_verificacion text not null default 'activo';

alter table public.events
  drop constraint if exists events_estado_verificacion_check;

alter table public.events
  add constraint events_estado_verificacion_check
  check (estado_verificacion in ('pendiente', 'activo', 'rechazado'));

alter table public.events
  add column if not exists category text;

alter table public.events
  add column if not exists image_url text;

create index if not exists events_date_idx
  on public.events (event_date);

drop policy if exists "Leer eventos" on public.events;
drop policy if exists "Read events" on public.events;
create policy "Read events" on public.events for select
  using (
    estado_verificacion = 'activo'
    or auth.uid() = created_by
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin = true
    )
  );

drop policy if exists "Crear eventos autenticado" on public.events;
drop policy if exists "Authenticated users can create events" on public.events;
drop policy if exists "Create events" on public.events;
create policy "Create events" on public.events for insert
  with check (auth.uid() = created_by);

drop policy if exists "Update own pending events" on public.events;
create policy "Update own pending events" on public.events for update
  using (auth.uid() = created_by and estado_verificacion = 'pendiente')
  with check (auth.uid() = created_by);

drop policy if exists "Delete own pending events" on public.events;
create policy "Delete own pending events" on public.events for delete
  using (auth.uid() = created_by and estado_verificacion = 'pendiente');

grant select on public.events to anon, authenticated;
grant insert, update, delete on public.events to authenticated;
