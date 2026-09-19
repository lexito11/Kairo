-- =============================================================================
-- KAIRO — Chat groups: description, image, leave
-- Safe to re-run ONLY after public.chat_groups exists.
-- If you get 42P01 (relation chat_groups does not exist), paste
-- 027_028_chat_groups_complete.sql instead of this file.
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
