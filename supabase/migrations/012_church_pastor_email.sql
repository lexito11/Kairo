-- KAIRO — Correo del pastor / líder responsable de la iglesia
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- (después de 004_churches.sql / 005_church_responsible_leader.sql)

alter table public.churches
  add column if not exists pastor_email text;

-- Opcional: rellenar filas antiguas sin correo (no bloquea el formulario nuevo)
update public.churches
set pastor_email = ''
where pastor_email is null;

-- Validación básica de formato (permite vacío en filas legacy)
alter table public.churches
  drop constraint if exists churches_pastor_email_format;

alter table public.churches
  add constraint churches_pastor_email_format
  check (
    pastor_email is null
    or trim(pastor_email) = ''
    or pastor_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  );

comment on column public.churches.pastor_email is
  'Correo del pastor o líder responsable de la iglesia (solicitud de registro)';
