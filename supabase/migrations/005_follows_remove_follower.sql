-- Permitir eliminar a quien te sigue (botón Eliminar en Personas → Me agregaron)
drop policy if exists "Eliminar seguidor" on public.follows;
create policy "Eliminar seguidor" on public.follows
  for delete
  using (auth.uid() = following_id);
