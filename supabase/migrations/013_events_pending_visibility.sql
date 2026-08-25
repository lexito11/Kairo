-- KAIRO — Pending events visible only to creator/admin; public sees active ones
-- Run in: Supabase Dashboard → SQL Editor

alter table public.events
  add column if not exists estado_verificacion text not null default 'activo';

alter table public.events
  drop constraint if exists events_estado_verificacion_check;

alter table public.events
  add constraint events_estado_verificacion_check
  check (estado_verificacion in ('pendiente', 'activo', 'rechazado'));

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
