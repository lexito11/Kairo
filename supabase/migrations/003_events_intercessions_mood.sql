-- Eventos, intercesiones y estado de ánimo en perfil

alter table public.users
  add column if not exists mood text,
  add column if not exists mood_updated_at timestamptz;

create table if not exists public.events (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  location    text,
  description text,
  event_date  timestamptz not null,
  denomination text,
  created_by  uuid references public.users (id) on delete set null,
  created_at  timestamptz not null default now()
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

alter table public.events enable row level security;
alter table public.intercessions enable row level security;

drop policy if exists "Leer eventos" on public.events;
create policy "Leer eventos" on public.events for select using (true);
drop policy if exists "Crear eventos autenticado" on public.events;
create policy "Crear eventos autenticado" on public.events for insert with check (auth.uid() = created_by);

drop policy if exists "Leer intercesiones" on public.intercessions;
create policy "Leer intercesiones" on public.intercessions for select using (true);
drop policy if exists "Interceder" on public.intercessions;
create policy "Interceder" on public.intercessions for insert with check (auth.uid() = user_id);
drop policy if exists "Quitar intercesión" on public.intercessions;
create policy "Quitar intercesión" on public.intercessions for delete using (auth.uid() = user_id);

grant select on public.events to anon, authenticated;
grant insert on public.events to authenticated;
grant select, insert, delete on public.intercessions to authenticated;

-- Datos iniciales de eventos (solo si la tabla está vacía)
insert into public.events (title, location, description, event_date, denomination)
select * from (values
  ('Culto dominical', 'Iglesia Central', 'Adoración y predicación', now() + interval '2 days', 'general'),
  ('Estudio bíblico', 'Salón juvenil', 'Estudio del libro de Romanos', now() + interval '4 days', 'general'),
  ('Noche de alabanza', 'Auditorio principal', 'Alabanza y testimonios', now() + interval '6 days', 'general')
) as v(title, location, description, event_date, denomination)
where not exists (select 1 from public.events limit 1);
