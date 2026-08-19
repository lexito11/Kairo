-- =============================================================================
-- KAIRO — Administración de solicitudes de iglesias
-- Ejecutar en Supabase SQL Editor (después de 004_churches.sql)
-- =============================================================================

-- 1. Rol de administrador en usuarios
alter table public.users
  add column if not exists is_admin boolean not null default false;

create index if not exists users_is_admin_idx on public.users (is_admin)
  where is_admin = true;

-- Marca tu cuenta como admin (cambia el email):
-- update public.users set is_admin = true where email = 'tu@email.com';

-- 2. RLS: admins pueden ver solicitudes pendientes y aprobar/rechazar
drop policy if exists "Iglesias activas o propias legibles" on public.churches;
drop policy if exists "Iglesias legibles" on public.churches;

create policy "Iglesias legibles"
  on public.churches for select
  using (
    status = 'active'
    or auth.uid() = created_by
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin = true
    )
  );

drop policy if exists "Actualizar iglesia propia" on public.churches;
drop policy if exists "Actualizar iglesia" on public.churches;

create policy "Actualizar iglesia"
  on public.churches for update
  using (
    auth.uid() = created_by
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin = true
    )
  );

-- 3. Función RPC para aprobar / rechazar (valida admin en servidor)
create or replace function public.review_church(
  p_church_id uuid,
  p_action text
)
returns public.churches
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin boolean;
  v_row public.churches;
begin
  select is_admin into v_admin
  from public.users
  where id = auth.uid();

  if coalesce(v_admin, false) = false then
    raise exception 'No autorizado';
  end if;

  if p_action not in ('approve', 'reject') then
    raise exception 'Acción no válida';
  end if;

  update public.churches
  set
    status = case when p_action = 'approve' then 'active' else 'rejected' end,
    activated_at = case when p_action = 'approve' then coalesce(activated_at, now()) else null end,
    updated_at = now()
  where id = p_church_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Iglesia no encontrada';
  end if;

  return v_row;
end;
$$;

grant execute on function public.review_church(uuid, text) to authenticated;
