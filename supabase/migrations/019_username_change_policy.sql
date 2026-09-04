-- Usuario único + un cambio cada 6 meses.
-- El usuario generado al registrarse NO cuenta como cambio (username_changed_at queda null).

alter table public.users
  add column if not exists username_changed_at timestamptz;

create or replace function public.kairo_unique_username(p_base text, p_exclude uuid default null)
returns text
language plpgsql
as $$
declare
  v_base text;
  v_candidate text;
  v_i int := 0;
begin
  v_base := lower(regexp_replace(coalesce(p_base, ''), '[^a-z0-9_]', '', 'g'));
  if length(v_base) < 3 then
    v_base := 'user';
  end if;
  if length(v_base) > 16 then
    v_base := left(v_base, 16);
  end if;
  v_candidate := v_base;
  while exists (
    select 1
    from public.users
    where username = v_candidate
      and (p_exclude is null or id <> p_exclude)
  ) loop
    v_i := v_i + 1;
    v_candidate := left(v_base, 16) || v_i::text;
  end loop;
  return v_candidate;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_from_meta boolean := false;
begin
  v_username := nullif(lower(trim(new.raw_user_meta_data->>'username')), '');
  if v_username is not null then
    v_from_meta := true;
  else
    v_username := public.kairo_unique_username(split_part(new.email, '@', 1), new.id);
  end if;

  insert into public.users (id, email, email_verified, name, username, username_changed_at)
  values (
    new.id,
    new.email,
    new.email_confirmed_at,
    coalesce(new.raw_user_meta_data->>'name', null),
    v_username,
    case when v_from_meta then now() else null end
  )
  on conflict (id) do update set
    email = excluded.email,
    email_verified = excluded.email_verified,
    name = coalesce(excluded.name, public.users.name),
    username = coalesce(public.users.username, excluded.username),
    updated_at = now();
  return new;
end;
$$;

create or replace function public.enforce_username_change_policy()
returns trigger
language plpgsql
as $$
begin
  if new.username is not null then
    new.username := lower(trim(new.username));
    if new.username = '' then
      new.username := null;
    end if;
  end if;

  if tg_op = 'UPDATE' and new.username is distinct from old.username then
    if new.username is null or length(new.username) < 3 or length(new.username) > 20
       or new.username !~ '^[a-z0-9_]+$' then
      raise exception 'USERNAME_INVALID'
        using errcode = '22023';
    end if;

    if old.username is null or old.username = '' then
      -- Primera asignación (usuario generado). No inicia la espera de 6 meses.
      new.username_changed_at := old.username_changed_at;
    else
      if old.username_changed_at is not null
         and old.username_changed_at > now() - interval '6 months' then
        raise exception 'USERNAME_COOLDOWN'
          using errcode = 'P0001';
      end if;
      new.username_changed_at := now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists users_username_change_policy on public.users;
create trigger users_username_change_policy
  before update on public.users
  for each row execute function public.enforce_username_change_policy();

do $$
declare
  r record;
  v_name text;
begin
  for r in
    select id, email
    from public.users
    where username is null or btrim(username) = ''
  loop
    v_name := public.kairo_unique_username(split_part(r.email, '@', 1), r.id);
    update public.users
    set username = v_name
    where id = r.id;
  end loop;
end;
$$;
