-- =============================================================================
-- KAIRO — Complete chat groups (027 + 028). Safe to re-run.
-- Paste THIS file into the SQL Editor. Do not paste 028 alone.
-- =============================================================================

-- =============================================================================
-- KAIRO — Chat groups: catalog, members, invites, messages, admin roles
-- Safe to re-run. Paste into Supabase SQL Editor (remote is missing these tables).
-- English policy names. Drops older Spanish policy names if they exist.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.chat_groups (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(trim(name)) between 2 and 80),
  created_at       timestamptz not null default now(),
  created_by       uuid not null references public.users (id) on delete cascade,
  member_count     integer not null default 1 check (member_count >= 1 and member_count <= 5000),
  is_public        boolean not null default false,
  admins_only_chat boolean not null default false
);

alter table public.chat_groups
  add column if not exists is_public boolean not null default false;

alter table public.chat_groups
  add column if not exists admins_only_chat boolean not null default false;

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
  content    text not null default '',
  created_at timestamptz not null default now(),
  media_url  text,
  media_type text
);

alter table public.chat_group_messages
  add column if not exists media_url text;

alter table public.chat_group_messages
  add column if not exists media_type text;

alter table public.chat_group_messages
  alter column content set default '';

create table if not exists public.chat_group_invites (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.chat_groups (id) on delete cascade,
  inviter_id   uuid not null references public.users (id) on delete cascade,
  invitee_id   uuid not null references public.users (id) on delete cascade,
  status       text not null default 'pending'
               check (status in ('pending', 'accepted', 'rejected')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  seen_at      timestamptz,
  unique (group_id, invitee_id)
);

alter table public.chat_group_invites
  add column if not exists seen_at timestamptz;

create index if not exists chat_groups_created_by_idx
  on public.chat_groups (created_by);

create index if not exists chat_group_members_user_idx
  on public.chat_group_members (user_id);

create index if not exists chat_group_messages_group_created_idx
  on public.chat_group_messages (group_id, created_at desc);

create index if not exists chat_group_invites_invitee_pending_idx
  on public.chat_group_invites (invitee_id, status);

create extension if not exists pg_trgm;

create index if not exists chat_groups_name_trgm_idx
  on public.chat_groups using gin (name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- RLS helper functions (security definer — avoids recursive member policies)
-- ---------------------------------------------------------------------------
create or replace function public.is_chat_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_group_members
    where group_id = p_group_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_chat_group_admin(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_group_members
    where group_id = p_group_id
      and user_id = auth.uid()
      and role = 'admin'
  );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.chat_groups enable row level security;
alter table public.chat_group_members enable row level security;
alter table public.chat_group_messages enable row level security;
alter table public.chat_group_invites enable row level security;

drop policy if exists "Ver grupos donde soy miembro" on public.chat_groups;
drop policy if exists "Ver grupos propios o públicos" on public.chat_groups;
drop policy if exists "Listar grupos autenticados" on public.chat_groups;
drop policy if exists "Read chat groups" on public.chat_groups;
create policy "Read chat groups" on public.chat_groups for select
  using (auth.uid() is not null);

drop policy if exists "Ver membresías de mis grupos" on public.chat_group_members;
drop policy if exists "Read group memberships" on public.chat_group_members;
create policy "Read group memberships" on public.chat_group_members for select
  using (
    user_id = auth.uid()
    or public.is_chat_group_member(group_id)
  );

drop policy if exists "Leer mensajes de grupo" on public.chat_group_messages;
drop policy if exists "Read group messages" on public.chat_group_messages;
create policy "Read group messages" on public.chat_group_messages for select
  using (public.is_chat_group_member(group_id));

drop policy if exists "Enviar mensajes de grupo" on public.chat_group_messages;
drop policy if exists "Send group messages" on public.chat_group_messages;
create policy "Send group messages" on public.chat_group_messages for insert
  with check (
    auth.uid() = sender_id
    and public.is_chat_group_member(group_id)
    and (
      not (select g.admins_only_chat from public.chat_groups g where g.id = group_id)
      or public.is_chat_group_admin(group_id)
    )
    and (
      char_length(trim(content)) > 0
      or media_url is not null
    )
  );

drop policy if exists "Ver invitaciones propias" on public.chat_group_invites;
drop policy if exists "Read group invites" on public.chat_group_invites;
create policy "Read group invites" on public.chat_group_invites for select
  using (
    invitee_id = auth.uid()
    or inviter_id = auth.uid()
    or public.is_chat_group_admin(group_id)
  );

-- ---------------------------------------------------------------------------
-- Triggers: member limit, member_count, max 3 admins, min 1 admin
-- ---------------------------------------------------------------------------
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
    set member_count = greatest(
      (
        select count(*) from public.chat_group_members where group_id = old.group_id
      ),
      1
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

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
drop function if exists public.create_chat_group(text);
drop function if exists public.create_chat_group(text, boolean);

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

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
grant select on public.chat_groups to authenticated;
grant select on public.chat_group_members to authenticated;
grant select, insert on public.chat_group_messages to authenticated;
grant select on public.chat_group_invites to authenticated;

grant execute on function public.is_chat_group_member(uuid) to authenticated;
grant execute on function public.is_chat_group_admin(uuid) to authenticated;
grant execute on function public.create_chat_group(text, boolean, boolean) to authenticated;
grant execute on function public.join_public_group(uuid) to authenticated;
grant execute on function public.invite_to_group(uuid, uuid) to authenticated;
grant execute on function public.respond_group_invite(uuid, boolean) to authenticated;
grant execute on function public.mark_group_invites_seen() to authenticated;
grant execute on function public.set_group_admins_only_chat(uuid, boolean) to authenticated;
grant execute on function public.set_group_member_role(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'chat_group_messages'
     )
  then
    alter publication supabase_realtime add table public.chat_group_messages;
  end if;
end $$;

-- =============================================================================
-- Profile: description, image, leave
-- =============================================================================

-- =============================================================================

alter table public.chat_groups
  add column if not exists description text;

alter table public.chat_groups
  add column if not exists image_url text;

alter table public.chat_groups
  drop constraint if exists chat_groups_description_len;

alter table public.chat_groups
  add constraint chat_groups_description_len
  check (description is null or char_length(description) <= 280);

create or replace function public.group_text_is_blocked(p_text text)
returns boolean
language sql
immutable
as $$
  select coalesce(p_text, '') ~* '(porn|xxx|onlyfans|nsfw|hentai|nudes?|nudity|naked|desnud[oa]s?|bikini|lencer[ií]a|ropa interior|underwear|sexting|sexualiz|expl[ií]cit[oa]|contenido sexual)';
$$;

create or replace function public.update_chat_group_profile(
  p_group_id uuid,
  p_description text default null,
  p_image_url text default null,
  p_clear_image boolean default false
)
returns public.chat_groups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_group public.chat_groups;
  v_description text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  if not exists (
    select 1 from public.chat_group_members
    where group_id = p_group_id and user_id = v_uid and role = 'admin'
  ) then
    raise exception 'not_admin';
  end if;

  if p_description is not null then
    v_description := trim(p_description);
    if char_length(v_description) > 280 then
      raise exception 'invalid_description';
    end if;
    if public.group_text_is_blocked(v_description) then
      raise exception 'blocked_content';
    end if;
    if v_description = '' then
      v_description := null;
    end if;
  end if;

  if p_image_url is not null
     and p_image_url not like '%/storage/v1/object/public/media/%' then
    raise exception 'invalid_image';
  end if;

  update public.chat_groups
  set
    description = case when p_description is not null then v_description else description end,
    image_url = case
      when p_clear_image then null
      when p_image_url is not null then p_image_url
      else image_url
    end
  where id = p_group_id
  returning * into v_group;

  if not found then raise exception 'group_not_found'; end if;
  return v_group;
end;
$$;

create or replace function public.leave_chat_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_members integer;
  v_admins integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select role into v_role
  from public.chat_group_members
  where group_id = p_group_id and user_id = v_uid;

  if not found then raise exception 'not_member'; end if;

  select count(*) into v_members from public.chat_group_members where group_id = p_group_id;
  select count(*) into v_admins
  from public.chat_group_members
  where group_id = p_group_id and role = 'admin';

  if v_members <= 1 then
    delete from public.chat_groups where id = p_group_id;
    return;
  end if;

  if v_role = 'admin' and v_admins <= 1 then
    raise exception 'last_admin';
  end if;

  delete from public.chat_group_members
  where group_id = p_group_id and user_id = v_uid;
end;
$$;

grant execute on function public.group_text_is_blocked(text) to authenticated;
grant execute on function public.update_chat_group_profile(uuid, text, text, boolean) to authenticated;
grant execute on function public.leave_chat_group(uuid) to authenticated;
