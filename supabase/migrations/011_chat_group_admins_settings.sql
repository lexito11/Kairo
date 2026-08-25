-- Admins (máx. 3), modo solo-admins y media en mensajes de grupo.

alter table public.chat_groups
  add column if not exists admins_only_chat boolean not null default false;

alter table public.chat_group_messages
  add column if not exists media_url text,
  add column if not exists media_type text;

alter table public.chat_group_messages
  alter column content set default '';

-- Máximo 3 administradores por grupo
create or replace function public.enforce_max_group_admins()
returns trigger
language plpgsql
as $$
declare
  v_count integer;
begin
  if new.role <> 'admin' then
    return new;
  end if;

  select count(*) into v_count
  from public.chat_group_members
  where group_id = new.group_id and role = 'admin';

  if tg_op = 'UPDATE' and old.role = 'admin' then
    v_count := v_count - 1;
  end if;

  if v_count >= 3 then
    raise exception 'max_admins_reached';
  end if;

  return new;
end;
$$;

drop trigger if exists chat_group_max_admins_trg on public.chat_group_members;
create trigger chat_group_max_admins_trg
  before insert or update of role on public.chat_group_members
  for each row execute function public.enforce_max_group_admins();

-- No dejar grupo sin administrador
create or replace function public.enforce_min_one_group_admin()
returns trigger
language plpgsql
as $$
declare
  v_count integer;
begin
  if tg_op = 'UPDATE' and old.role = 'admin' and new.role = 'member' then
    select count(*) into v_count
    from public.chat_group_members
    where group_id = old.group_id and role = 'admin';
    if v_count <= 1 then
      raise exception 'last_admin';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists chat_group_min_admin_trg on public.chat_group_members;
create trigger chat_group_min_admin_trg
  before update of role on public.chat_group_members
  for each row execute function public.enforce_min_one_group_admin();

drop policy if exists "Enviar mensajes de grupo" on public.chat_group_messages;
create policy "Enviar mensajes de grupo" on public.chat_group_messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chat_group_members m
      where m.group_id = group_id and m.user_id = auth.uid()
    )
    and (
      not (select g.admins_only_chat from public.chat_groups g where g.id = group_id)
      or exists (
        select 1 from public.chat_group_members m
        where m.group_id = group_id and m.user_id = auth.uid() and m.role = 'admin'
      )
    )
    and (
      char_length(trim(content)) > 0
      or media_url is not null
    )
  );

create or replace function public.set_group_admins_only_chat(p_group_id uuid, p_admins_only boolean)
returns public.chat_groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;

  update public.chat_groups
  set admins_only_chat = coalesce(p_admins_only, false)
  where id = p_group_id
  returning * into v_group;

  return v_group;
end;
$$;

create or replace function public.set_group_member_role(
  p_group_id uuid,
  p_user_id uuid,
  p_role text
)
returns public.chat_group_members
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_member public.chat_group_members;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_role not in ('admin', 'member') then raise exception 'invalid_role'; end if;

  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;

  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = p_user_id
  ) then
    raise exception 'not_member';
  end if;

  update public.chat_group_members
  set role = p_role
  where group_id = p_group_id and user_id = p_user_id
  returning * into v_member;

  return v_member;
end;
$$;

create or replace function public.create_chat_group(
  p_name text,
  p_is_public boolean default false,
  p_admins_only_chat boolean default false
)
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
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if char_length(v_name) < 2 then raise exception 'invalid_name'; end if;

  select count(*) into v_created from public.chat_groups where created_by = v_uid;
  if v_created >= 5 then raise exception 'group_limit_reached'; end if;

  insert into public.chat_groups (name, created_by, member_count, is_public, admins_only_chat)
  values (v_name, v_uid, 1, coalesce(p_is_public, false), coalesce(p_admins_only_chat, false))
  returning * into v_group;

  insert into public.chat_group_members (group_id, user_id, role)
  values (v_group.id, v_uid, 'admin');

  return v_group;
end;
$$;

grant execute on function public.set_group_admins_only_chat(uuid, boolean) to authenticated;
grant execute on function public.set_group_member_role(uuid, uuid, text) to authenticated;
