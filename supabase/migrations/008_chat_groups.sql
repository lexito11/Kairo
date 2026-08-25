-- Grupos de chat: máx. 5 creados por usuario, máx. 5000 miembros por grupo.

create table if not exists public.chat_groups (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(trim(name)) between 2 and 80),
  created_at   timestamptz not null default now(),
  created_by   uuid not null references public.users (id) on delete cascade,
  member_count integer not null default 1 check (member_count >= 1 and member_count <= 5000)
);

create table if not exists public.chat_group_members (
  group_id  uuid not null references public.chat_groups (id) on delete cascade,
  user_id   uuid not null references public.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  role      text not null default 'member' check (role in ('admin', 'member')),
  primary key (group_id, user_id)
);

create table if not exists public.chat_group_messages (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.chat_groups (id) on delete cascade,
  sender_id  uuid not null references public.users (id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_groups_created_by_idx
  on public.chat_groups (created_by);

create index if not exists chat_group_members_user_idx
  on public.chat_group_members (user_id);

create index if not exists chat_group_messages_group_created_idx
  on public.chat_group_messages (group_id, created_at desc);

-- ----------------------------------------------------------------------------- RLS
alter table public.chat_groups enable row level security;
alter table public.chat_group_members enable row level security;
alter table public.chat_group_messages enable row level security;

drop policy if exists "Ver grupos donde soy miembro" on public.chat_groups;
create policy "Ver grupos donde soy miembro" on public.chat_groups for select
  using (
    exists (
      select 1 from public.chat_group_members m
      where m.group_id = id and m.user_id = auth.uid()
    )
  );

drop policy if exists "Ver membresías de mis grupos" on public.chat_group_members;
create policy "Ver membresías de mis grupos" on public.chat_group_members for select
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.chat_group_members m
      where m.group_id = group_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "Leer mensajes de grupo" on public.chat_group_messages;
create policy "Leer mensajes de grupo" on public.chat_group_messages for select
  using (
    exists (
      select 1 from public.chat_group_members m
      where m.group_id = group_id and m.user_id = auth.uid()
    )
  );

drop policy if exists "Enviar mensajes de grupo" on public.chat_group_messages;
create policy "Enviar mensajes de grupo" on public.chat_group_messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chat_group_members m
      where m.group_id = group_id and m.user_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------- Límite miembros (5000)
create or replace function public.enforce_chat_group_member_limit()
returns trigger
language plpgsql
as $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.chat_group_members
  where group_id = new.group_id;

  if v_count >= 5000 then
    raise exception 'group_full';
  end if;

  return new;
end;
$$;

drop trigger if exists chat_group_member_limit_trg on public.chat_group_members;
create trigger chat_group_member_limit_trg
  before insert on public.chat_group_members
  for each row execute function public.enforce_chat_group_member_limit();

-- Mantener member_count sincronizado
create or replace function public.sync_chat_group_member_count()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    update public.chat_groups
    set member_count = (
      select count(*) from public.chat_group_members where group_id = new.group_id
    )
    where id = new.group_id;
  elsif tg_op = 'DELETE' then
    update public.chat_groups
    set member_count = (
      select count(*) from public.chat_group_members where group_id = old.group_id
    )
    where id = old.group_id;
  end if;
  return null;
end;
$$;

drop trigger if exists chat_group_member_count_trg on public.chat_group_members;
create trigger chat_group_member_count_trg
  after insert or delete on public.chat_group_members
  for each row execute function public.sync_chat_group_member_count();

-- ----------------------------------------------------------------------------- RPC crear grupo (máx. 5 por usuario)
create or replace function public.create_chat_group(p_name text)
returns public.chat_groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_created integer;
  v_group public.chat_groups;
  v_name text := trim(p_name);
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if char_length(v_name) < 2 then
    raise exception 'invalid_name';
  end if;

  select count(*) into v_created
  from public.chat_groups
  where created_by = v_uid;

  if v_created >= 5 then
    raise exception 'group_limit_reached';
  end if;

  insert into public.chat_groups (name, created_by, member_count)
  values (v_name, v_uid, 1)
  returning * into v_group;

  insert into public.chat_group_members (group_id, user_id, role)
  values (v_group.id, v_uid, 'admin');

  return v_group;
end;
$$;

grant execute on function public.create_chat_group(text) to authenticated;
grant select on public.chat_groups to authenticated;
grant select on public.chat_group_members to authenticated;
grant select, insert on public.chat_group_messages to authenticated;

-- Realtime (opcional, si la publicación existe)
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'chat_group_messages'
  ) then
    null;
  elsif exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.chat_group_messages;
  end if;
end $$;
