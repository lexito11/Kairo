create table if not exists public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

drop policy if exists "Leer mis bloqueos" on public.user_blocks;
drop policy if exists "Read own blocks" on public.user_blocks;
create policy "Read own blocks" on public.user_blocks
  for select using (auth.uid() = blocker_id);

drop policy if exists "Bloquear" on public.user_blocks;
drop policy if exists "Create blocks" on public.user_blocks;
create policy "Create blocks" on public.user_blocks
  for insert with check (auth.uid() = blocker_id);

drop policy if exists "Desbloquear" on public.user_blocks;
drop policy if exists "Delete own blocks" on public.user_blocks;
create policy "Delete own blocks" on public.user_blocks
  for delete using (auth.uid() = blocker_id);

grant select, insert, delete on public.user_blocks to authenticated;
