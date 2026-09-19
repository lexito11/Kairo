-- =============================================================================
-- KAIRO — Global content and community policy
-- Safe to re-run. English. Paste into the SQL Editor.
-- Order with later files: 029 → 030 → 031 → 032.
-- Enforces text on write. Reports for users. Logs blocked attempts.
-- Visual bikini/nudity classification still needs a vision provider.
-- group_text_is_blocked is an alias of kairo_text_is_blocked. 027/028 must
-- not replace this with a weaker regex after this file has been applied.
-- =============================================================================

create table if not exists public.moderation_events (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.users (id) on delete set null,
  source      text not null,
  category    text not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  target_type text not null check (target_type in (
    'post', 'comment', 'user', 'group', 'event', 'message', 'live', 'story'
  )),
  target_id   uuid not null,
  reason      text not null check (reason in (
    'sexual', 'nudity', 'bikini', 'underwear', 'sexualPromotion',
    'discrimination', 'bullying', 'harassment', 'threats', 'severeInsult'
  )),
  created_at  timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

create index if not exists content_reports_target_idx
  on public.content_reports (target_type, target_id);

alter table public.moderation_events enable row level security;
alter table public.content_reports enable row level security;

drop policy if exists "Insert own reports" on public.content_reports;
create policy "Insert own reports" on public.content_reports for insert
  with check (auth.uid() = reporter_id);

drop policy if exists "Read own reports" on public.content_reports;
create policy "Read own reports" on public.content_reports for select
  using (auth.uid() = reporter_id);

grant select, insert on public.content_reports to authenticated;
grant insert on public.moderation_events to authenticated;

create or replace function public.kairo_normalize_text(p_text text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(
    translate(
      lower(coalesce(p_text, '')),
      'áàäâéèëêíìïîóòöôúùüûñ@01345$!',
      'aaaaeeeeiiiioooouuuunaoieasi'
    ),
    '[^a-z0-9]+',
    ' ',
    'g'
  ));
$$;

create or replace function public.kairo_compact_text(p_text text)
returns text
language sql
immutable
as $$
  select replace(public.kairo_normalize_text(p_text), ' ', '');
$$;

create or replace function public.kairo_text_is_blocked(p_text text)
returns boolean
language plpgsql
immutable
as $$
declare
  v_spaced text := public.kairo_normalize_text(p_text);
  v_compact text := replace(v_spaced, ' ', '');
  v_term text;
begin
  if v_spaced is null or v_spaced = '' then
    return false;
  end if;

  foreach v_term in array array[
    'porn', 'porno', 'nopor', 'xxx', 'onlyfans', 'fansly', 'nsfw', 'hentai',
    'nudes', 'nude', 'nudity', 'naked', 'desnudo', 'desnuda', 'desnudos',
    'bikini', 'lenceria', 'ropainterior', 'underwear', 'sexting',
    'sexualizado', 'sexualizada', 'pornhub', 'xvideos', 'xnxx',
    'chaturbate', 'stripchat', 'packxxx'
  ]
  loop
    if position(v_term in v_compact) > 0 then
      return true;
    end if;
  end loop;

  if v_spaced ~ '(contenido sexual|ropa interior|servicios? sexual|pack (de )?fotos)' then
    return true;
  end if;

  if v_spaced ~ 'te voy a (matar|pegar|golpear|violar|disparar|encontrar)' then
    return true;
  end if;
  if v_spaced ~ 'te (mato|pego|violo)' then
    return true;
  end if;

  if v_spaced ~ '(eres|sos|usted es) (una? )?(puta|puto|perra|malparid[oa]|hij[oa] de puta)' then
    return true;
  end if;
  if v_spaced ~ 'hij[oa] de (puta|perra)' then
    return true;
  end if;
  if v_spaced ~ 'mal nacido|malnacido' then
    return true;
  end if;

  if v_spaced !~ '(camisa|fondo|color|pared|auto|coche|zapato|bolso|pelo|tinta|pintura|cafe|carbon|mono en)' then
    if v_spaced ~ '(negro|negra|indio|india|moreno|morena) de (mierda|porqueria)' then
      return true;
    end if;
    if v_spaced ~ '(maldit[oa]|odio a los|odio a las) (negros?|negras?|indios?|indias?)' then
      return true;
    end if;
    if v_spaced ~ '(eres|sos) un mono' then
      return true;
    end if;
  end if;

  if v_spaced ~ 'en todas tus (publicaciones|fotos|historias|comentarios)' then
    return true;
  end if;
  if v_spaced ~ 'te voy a (acosar|perseguir|molestar)|para molestarte' then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.group_text_is_blocked(p_text text)
returns boolean
language sql
immutable
as $$
  select public.kairo_text_is_blocked(p_text);
$$;

create or replace function public.enforce_kairo_content()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_blob text;
begin
  v_blob := trim(concat_ws(
    ' ',
    v_row->>'content',
    v_row->>'title',
    v_row->>'name',
    v_row->>'description',
    v_row->>'username',
    v_row->>'bio'
  ));

  if public.kairo_text_is_blocked(v_blob) then
    insert into public.moderation_events (actor_id, source, category)
    values (auth.uid(), tg_table_name, 'blocked_content');
    raise exception 'blocked_content';
  end if;

  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'posts', 'comments', 'messages', 'chat_group_messages', 'chat_groups',
    'users', 'events', 'live_streams', 'live_stream_messages', 'churches'
  ]
  loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists kairo_content_%s_trg on public.%I', t, t);
      execute format(
        'create trigger kairo_content_%s_trg before insert or update on public.%I for each row execute function public.enforce_kairo_content()',
        t, t
      );
    end if;
  end loop;
end $$;

grant execute on function public.kairo_normalize_text(text) to authenticated;
grant execute on function public.kairo_compact_text(text) to authenticated;
grant execute on function public.kairo_text_is_blocked(text) to authenticated;
grant execute on function public.group_text_is_blocked(text) to authenticated;
