-- KAIRO — Campo obligatorio: pastor o líder responsable de la iglesia
-- Ejecutar si ya corriste 004_churches.sql antes de este cambio.

alter table public.churches
  add column if not exists responsible_leader text;

update public.churches
set responsible_leader = 'Sin registrar'
where responsible_leader is null or trim(responsible_leader) = '';

alter table public.churches
  alter column responsible_leader set not null;
