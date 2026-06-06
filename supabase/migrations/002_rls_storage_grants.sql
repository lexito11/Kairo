-- KAIRO — RLS completo, grants y Storage bucket "media"

-- updated_at en posts
drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
  before update on public.posts
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------- RLS: comments
alter table public.comments enable row level security;
drop policy if exists "Leer comentarios" on public.comments;
create policy "Leer comentarios" on public.comments for select using (true);
drop policy if exists "Crear comentarios" on public.comments;
create policy "Crear comentarios" on public.comments for insert with check (auth.uid() = author_id);
drop policy if exists "Editar propios comentarios" on public.comments;
create policy "Editar propios comentarios" on public.comments for update using (auth.uid() = author_id);
drop policy if exists "Borrar propios comentarios" on public.comments;
create policy "Borrar propios comentarios" on public.comments for delete using (auth.uid() = author_id);

-- ----------------------------------------------------------------------------- RLS: likes
alter table public.likes enable row level security;
drop policy if exists "Leer likes" on public.likes;
create policy "Leer likes" on public.likes for select using (true);
drop policy if exists "Dar like" on public.likes;
create policy "Dar like" on public.likes for insert with check (auth.uid() = author_id);
drop policy if exists "Quitar like" on public.likes;
create policy "Quitar like" on public.likes for delete using (auth.uid() = author_id);

-- ----------------------------------------------------------------------------- RLS: post_views
alter table public.post_views enable row level security;
drop policy if exists "Leer propias vistas" on public.post_views;
create policy "Leer propias vistas" on public.post_views for select using (auth.uid() = user_id);
drop policy if exists "Registrar vista" on public.post_views;
create policy "Registrar vista" on public.post_views for insert with check (auth.uid() = user_id);
drop policy if exists "Actualizar vista" on public.post_views;
create policy "Actualizar vista" on public.post_views for update using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------- RLS: follows
alter table public.follows enable row level security;
drop policy if exists "Leer follows" on public.follows;
create policy "Leer follows" on public.follows for select using (true);
drop policy if exists "Seguir" on public.follows;
create policy "Seguir" on public.follows for insert with check (auth.uid() = follower_id);
drop policy if exists "Dejar de seguir" on public.follows;
create policy "Dejar de seguir" on public.follows for delete using (auth.uid() = follower_id);
drop policy if exists "Marcar notificación vista" on public.follows;
create policy "Marcar notificación vista" on public.follows for update using (auth.uid() = following_id);

-- ----------------------------------------------------------------------------- RLS: messages
alter table public.messages enable row level security;
drop policy if exists "Leer mensajes propios" on public.messages;
create policy "Leer mensajes propios" on public.messages for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
drop policy if exists "Enviar mensajes" on public.messages;
create policy "Enviar mensajes" on public.messages for insert with check (auth.uid() = sender_id);
drop policy if exists "Marcar leído" on public.messages;
create policy "Marcar leído" on public.messages for update
  using (auth.uid() = receiver_id);

-- ----------------------------------------------------------------------------- RLS: stories
alter table public.stories enable row level security;
drop policy if exists "Leer historias no expiradas" on public.stories;
create policy "Leer historias no expiradas" on public.stories for select using (expires_at > now());
drop policy if exists "Crear historias" on public.stories;
create policy "Crear historias" on public.stories for insert with check (auth.uid() = author_id);
drop policy if exists "Borrar propias historias" on public.stories;
create policy "Borrar propias historias" on public.stories for delete using (auth.uid() = author_id);

-- ----------------------------------------------------------------------------- Grants
grant select, insert, update, delete on public.comments to authenticated;
grant select, insert, delete on public.likes to authenticated;
grant select, insert, update on public.post_views to authenticated;
grant select, insert, update, delete on public.follows to authenticated;
grant select, insert, update on public.messages to authenticated;
grant select, insert, delete on public.stories to authenticated;
grant select on public.posts to anon;

-- ----------------------------------------------------------------------------- Storage bucket "media"
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', true, 52428800)
on conflict (id) do update set public = true, file_size_limit = 52428800;

drop policy if exists "Media público lectura" on storage.objects;
create policy "Media público lectura" on storage.objects for select using (bucket_id = 'media');

drop policy if exists "Media subida autenticada" on storage.objects;
create policy "Media subida autenticada" on storage.objects for insert
  with check (bucket_id = 'media' and auth.role() = 'authenticated');

drop policy if exists "Media borrar propio" on storage.objects;
create policy "Media borrar propio" on storage.objects for delete
  using (bucket_id = 'media' and auth.uid()::text = (storage.foldername(name))[1]);
