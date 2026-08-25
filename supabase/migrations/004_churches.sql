-- =============================================================================
-- KAIRO — Registro de iglesias con verificación por país y fe de miembros
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabla principal de iglesias
-- -----------------------------------------------------------------------------
create table if not exists public.churches (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  denomination        text not null,
  city                text not null,
  responsible_leader  text not null,
  pastor_email        text,
  country_code        text not null,
  country_name        text not null,
  is_south_america    boolean not null default false,
  fiscal_id           text,
  legal_document_url  text,
  facebook_url        text,
  instagram_url       text,
  estado_verificacion text not null default 'pendiente'
                        check (estado_verificacion in ('pendiente', 'activo', 'rechazado')),
  motivo_rechazo      text,
  status              text not null default 'pending'
                        check (status in ('pending', 'active', 'rejected')),
  endorsement_count   int not null default 0,
  created_by          uuid not null references public.users (id) on delete cascade,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  activated_at        timestamptz,
  constraint churches_sa_requirements check (
    not is_south_america
    or (
      fiscal_id is not null
      and trim(fiscal_id) <> ''
      and legal_document_url is not null
      and trim(legal_document_url) <> ''
      and facebook_url is not null
      and trim(facebook_url) <> ''
      and instagram_url is not null
      and trim(instagram_url) <> ''
    )
  ),
  constraint churches_non_sa_social check (
    is_south_america
    or (
      (facebook_url is not null and trim(facebook_url) <> '')
      or (instagram_url is not null and trim(instagram_url) <> '')
    )
  )
);

create unique index if not exists churches_created_by_uidx
  on public.churches (created_by);

create index if not exists churches_status_idx
  on public.churches (status);

create index if not exists churches_country_code_idx
  on public.churches (country_code);

drop trigger if exists churches_set_updated_at on public.churches;
create trigger churches_set_updated_at
  before update on public.churches
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 2. Fe de miembros (10 endorsements activan la iglesia)
-- -----------------------------------------------------------------------------
create table if not exists public.church_endorsements (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (church_id, user_id)
);

create index if not exists church_endorsements_church_idx
  on public.church_endorsements (church_id);

-- -----------------------------------------------------------------------------
-- 3. Trigger: contar fe y activar iglesia al llegar a 10 miembros
-- -----------------------------------------------------------------------------
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
    status = case when cnt >= 10 then 'active' else 'pending' end,
    estado_verificacion = case when cnt >= 10 then 'activo' else 'pendiente' end,
    activated_at = case
      when cnt >= 10 then coalesce(activated_at, now())
      else null
    end,
    updated_at = now()
  where id = cid;

  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists church_endorsements_after_change on public.church_endorsements;
create trigger church_endorsements_after_change
  after insert or delete on public.church_endorsements
  for each row execute function public.refresh_church_endorsement_count();

-- Impedir que el creador dé fe de su propia iglesia
create or replace function public.prevent_self_church_endorsement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  select created_by into owner_id
  from public.churches
  where id = NEW.church_id;

  if owner_id = NEW.user_id then
    raise exception 'El creador de la iglesia no puede dar fe de la misma';
  end if;

  return NEW;
end;
$$;

drop trigger if exists church_endorsements_no_self on public.church_endorsements;
create trigger church_endorsements_no_self
  before insert on public.church_endorsements
  for each row execute function public.prevent_self_church_endorsement();

-- -----------------------------------------------------------------------------
-- 4. Vincular eventos con iglesia (opcional, nullable)
-- -----------------------------------------------------------------------------
alter table public.events
  add column if not exists church_id uuid references public.churches (id) on delete set null;

create index if not exists events_church_id_idx on public.events (church_id);

-- -----------------------------------------------------------------------------
-- 5. RLS
-- -----------------------------------------------------------------------------
alter table public.churches enable row level security;
alter table public.church_endorsements enable row level security;

drop policy if exists "Iglesias activas o propias legibles" on public.churches;
create policy "Iglesias legibles"
  on public.churches for select
  using (
    estado_verificacion = 'activo'
    or auth.uid() = created_by
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.is_admin = true
    )
  );

drop policy if exists "Registrar iglesia propia" on public.churches;
create policy "Registrar iglesia propia"
  on public.churches for insert
  with check (auth.uid() = created_by);

drop policy if exists "Actualizar iglesia propia" on public.churches;
create policy "Actualizar iglesia propia"
  on public.churches for update
  using (auth.uid() = created_by);

drop policy if exists "Fe de iglesia legible" on public.church_endorsements;
create policy "Fe de iglesia legible"
  on public.church_endorsements for select
  using (true);

drop policy if exists "Dar fe de iglesia" on public.church_endorsements;
create policy "Dar fe de iglesia"
  on public.church_endorsements for insert
  with check (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 6. Grants
-- -----------------------------------------------------------------------------
grant select, insert, update on public.churches to authenticated;
grant select, insert on public.church_endorsements to authenticated;
grant select on public.churches to anon;
