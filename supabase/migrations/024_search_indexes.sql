-- Índices para búsqueda por texto (ilike) en usuarios, posts y grupos.
-- No crea tablas nuevas: usa datos que ya existen.

create extension if not exists pg_trgm;

create index if not exists users_name_trgm_idx
  on public.users using gin (name gin_trgm_ops);

create index if not exists users_username_trgm_idx
  on public.users using gin (username gin_trgm_ops);

create index if not exists posts_content_trgm_idx
  on public.posts using gin (content gin_trgm_ops);

create index if not exists chat_groups_name_trgm_idx
  on public.chat_groups using gin (name gin_trgm_ops);
