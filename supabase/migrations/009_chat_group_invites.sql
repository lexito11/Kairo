-- Grupos públicos/privados e invitaciones.

alter table public.chat_groups
  add column if not exists is_public boolean not null default false;

create table if not exists public.chat_group_invites (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.chat_groups (id) on delete cascade,
  inviter_id   uuid not null references public.users (id) on delete cascade,
  invitee_id   uuid not null references public.users (id) on delete cascade,
  status       text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  unique (group_id, invitee_id)
);

create index if not exists chat_group_invites_invitee_pending_idx
  on public.chat_group_invites (invitee_id, status);

alter table public.chat_group_invites enable row level security;

drop policy if exists "Ver invitaciones propias" on public.chat_group_invites;
create policy "Ver invitaciones propias" on public.chat_group_invites for select
  using (
    invitee_id = auth.uid()
    or inviter_id = auth.uid()
    or exists (
      select 1 from public.chat_group_members m
      where m.group_id = group_id and m.user_id = auth.uid() and m.role = 'admin'
    )
  );

drop policy if exists "Ver grupos donde soy miembro" on public.chat_groups;
create policy "Ver grupos propios o públicos" on public.chat_groups for select
  using (
    is_public = true
    or exists (
      select 1 from public.chat_group_members m
      where m.group_id = id and m.user_id = auth.uid()
    )
  );

create or replace function public.create_chat_group(p_name text, p_is_public boolean default false)
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

  insert into public.chat_groups (name, created_by, member_count, is_public)
  values (v_name, v_uid, 1, coalesce(p_is_public, false))
  returning * into v_group;

  insert into public.chat_group_members (group_id, user_id, role)
  values (v_group.id, v_uid, 'admin');

  return v_group;
end;
$$;

create or replace function public.join_public_group(p_group_id uuid)
returns public.chat_groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_group from public.chat_groups where id = p_group_id;
  if not found then raise exception 'group_not_found'; end if;
  if not v_group.is_public then raise exception 'group_private'; end if;

  if exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid
  ) then
    raise exception 'already_member';
  end if;

  select count(*) into v_count from public.chat_group_members where group_id = p_group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;

  insert into public.chat_group_members (group_id, user_id, role)
  values (p_group_id, v_uid, 'member');

  select * into v_group from public.chat_groups where id = p_group_id;
  return v_group;
end;
$$;

create or replace function public.invite_to_group(p_group_id uuid, p_invitee_id uuid)
returns public.chat_group_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
  v_invite public.chat_group_invites;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_invitee_id = v_uid then raise exception 'cannot_invite_self'; end if;

  select * into v_group from public.chat_groups where id = p_group_id;
  if not found then raise exception 'group_not_found'; end if;
  if v_group.is_public then raise exception 'group_is_public'; end if;

  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;

  if exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = p_invitee_id
  ) then
    raise exception 'already_member';
  end if;

  select count(*) into v_count from public.chat_group_members where group_id = p_group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;

  select * into v_invite
  from public.chat_group_invites
  where group_id = p_group_id and invitee_id = p_invitee_id;

  if found then
    if v_invite.status = 'accepted' then raise exception 'already_member'; end if;
    if v_invite.status = 'pending' then return v_invite; end if;
    update public.chat_group_invites
    set status = 'pending', inviter_id = v_uid, created_at = now(), responded_at = null
    where id = v_invite.id
    returning * into v_invite;
    return v_invite;
  end if;

  insert into public.chat_group_invites (group_id, inviter_id, invitee_id, status)
  values (p_group_id, v_uid, p_invitee_id, 'pending')
  returning * into v_invite;

  return v_invite;
end;
$$;

create or replace function public.respond_group_invite(p_invite_id uuid, p_accept boolean)
returns public.chat_group_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_invite public.chat_group_invites;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_invite
  from public.chat_group_invites
  where id = p_invite_id and invitee_id = v_uid and status = 'pending';

  if not found then raise exception 'invite_not_found'; end if;

  if not p_accept then
    update public.chat_group_invites
    set status = 'rejected', responded_at = now()
    where id = p_invite_id
    returning * into v_invite;
    return v_invite;
  end if;

  select count(*) into v_count from public.chat_group_members where group_id = v_invite.group_id;
  if v_count >= 5000 then raise exception 'group_full'; end if;

  insert into public.chat_group_members (group_id, user_id, role)
  values (v_invite.group_id, v_uid, 'member')
  on conflict do nothing;

  update public.chat_group_invites
  set status = 'accepted', responded_at = now()
  where id = p_invite_id
  returning * into v_invite;

  return v_invite;
end;
$$;

grant execute on function public.create_chat_group(text, boolean) to authenticated;
grant execute on function public.join_public_group(uuid) to authenticated;
grant execute on function public.invite_to_group(uuid, uuid) to authenticated;
grant execute on function public.respond_group_invite(uuid, boolean) to authenticated;
grant select on public.chat_group_invites to authenticated;
