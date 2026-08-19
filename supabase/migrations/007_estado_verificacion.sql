-- =============================================================================
-- KAIRO — verification status (pendiente / activo / rechazado) + rejection reason
-- Run in Supabase SQL Editor after 004_churches.sql (006_church_admin.sql optional)
-- =============================================================================

-- 0. Admin flag on users (required for admin panel + RLS below)
alter table public.users
  add column if not exists is_admin boolean not null default false;

create index if not exists users_is_admin_idx on public.users (is_admin)
  where is_admin = true;

-- Mark your account as admin (replace email):
-- update public.users set is_admin = true where email = 'your@email.com';

-- 1. Churches: estado_verificacion + motivo_rechazo columns
alter table public.churches
  add column if not exists estado_verificacion text;

alter table public.churches
  add column if not exists motivo_rechazo text;

-- Migrate existing rows from legacy status column (English) if present
update public.churches
set estado_verificacion = case coalesce(status, estado_verificacion)
  when 'pending' then 'pendiente'
  when 'active' then 'activo'
  when 'rejected' then 'rechazado'
  when 'pendiente' then 'pendiente'
  when 'activo' then 'activo'
  when 'rechazado' then 'rechazado'
  else 'pendiente'
end
where estado_verificacion is null or trim(estado_verificacion) = '';

alter table public.churches
  alter column estado_verificacion set default 'pendiente';

alter table public.churches
  alter column estado_verificacion set not null;

alter table public.churches
  drop constraint if exists churches_estado_verificacion_check;

alter table public.churches
  add constraint churches_estado_verificacion_check
  check (estado_verificacion in ('pendiente', 'activo', 'rechazado'));

create index if not exists churches_estado_verificacion_idx
  on public.churches (estado_verificacion);

-- 2. Events: same field for future event-creation approval flow
alter table public.events
  add column if not exists estado_verificacion text not null default 'activo';

alter table public.events
  drop constraint if exists events_estado_verificacion_check;

alter table public.events
  add constraint events_estado_verificacion_check
  check (estado_verificacion in ('pendiente', 'activo', 'rechazado'));

create index if not exists events_estado_verificacion_idx
  on public.events (estado_verificacion);

-- 3. Endorsement trigger: sync estado_verificacion when 10 members endorse
create or replace function public.refresh_church_endorsement_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cid uuid;
  cnt int;
begin
  cid := coalesce(NEW.church_id, OLD.church_id);

  select count(*)::int into cnt
  from public.church_endorsements
  where church_id = cid;

  update public.churches
  set
    endorsement_count = cnt,
    status = case when cnt >= 10 then 'active' else coalesce(status, 'pending') end,
    estado_verificacion = case when cnt >= 10 then 'activo' else coalesce(estado_verificacion, 'pendiente') end,
    activated_at = case
      when cnt >= 10 then coalesce(activated_at, now())
      else activated_at
    end,
    updated_at = now()
  where id = cid;

  return coalesce(NEW, OLD);
end;
$$;

-- 4. RLS: public visibility only when estado_verificacion = activo
drop policy if exists "Iglesias legibles" on public.churches;
drop policy if exists "Churches readable" on public.churches;

create policy "Churches readable"
  on public.churches for select
  using (
    estado_verificacion = 'activo'
    or auth.uid() = created_by
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin = true
    )
  );

-- 5. RPC: approve / reject church (optional rejection reason)
drop function if exists public.review_church(uuid, text);

create or replace function public.review_church(
  p_church_id uuid,
  p_action text,
  p_motivo_rechazo text default null
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
    raise exception 'Unauthorized';
  end if;

  if p_action not in ('approve', 'reject') then
    raise exception 'Invalid action';
  end if;

  update public.churches
  set
    estado_verificacion = case when p_action = 'approve' then 'activo' else 'rechazado' end,
    status = case when p_action = 'approve' then 'active' else 'rejected' end,
    motivo_rechazo = case when p_action = 'reject' then nullif(trim(p_motivo_rechazo), '') else null end,
    activated_at = case when p_action = 'approve' then coalesce(activated_at, now()) else null end,
    updated_at = now()
  where id = p_church_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Church not found';
  end if;

  return v_row;
end;
$$;

grant execute on function public.review_church(uuid, text, text) to authenticated;
