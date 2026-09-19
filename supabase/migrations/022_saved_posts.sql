-- Saved posts (cloud, per account).
create table if not exists public.saved_posts (
  user_id    uuid not null references public.users (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index if not exists saved_posts_user_idx on public.saved_posts (user_id, created_at desc);

alter table public.saved_posts enable row level security;

drop policy if exists "Read own saved posts" on public.saved_posts;
create policy "Read own saved posts" on public.saved_posts
  for select using (auth.uid() = user_id);

drop policy if exists "Save posts" on public.saved_posts;
create policy "Save posts" on public.saved_posts
  for insert with check (auth.uid() = user_id);

drop policy if exists "Unsave posts" on public.saved_posts;
create policy "Unsave posts" on public.saved_posts
  for delete using (auth.uid() = user_id);

grant select, insert, delete on public.saved_posts to authenticated;
