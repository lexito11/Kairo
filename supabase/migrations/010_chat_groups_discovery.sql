-- Descubrimiento de grupos + invitaciones vistas en notificaciones.

alter table public.chat_group_invites
  add column if not exists seen_at timestamptz;

drop policy if exists "Ver grupos propios o públicos" on public.chat_groups;
create policy "Listar grupos autenticados" on public.chat_groups for select
  using (auth.uid() is not null);

create or replace function public.mark_group_invites_seen()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_group_invites
  set seen_at = now()
  where invitee_id = auth.uid()
    and status = 'pending'
    and seen_at is null;
end;
$$;

-- Permitir invitar también en grupos públicos (notificación inicial).
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
    set status = 'pending', inviter_id = v_uid, created_at = now(), responded_at = null, seen_at = null
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

grant execute on function public.mark_group_invites_seen() to authenticated;
