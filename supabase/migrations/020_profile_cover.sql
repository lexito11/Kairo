-- Portada del perfil (distinta de la foto de perfil / image).
alter table public.users
  add column if not exists cover_url text;
