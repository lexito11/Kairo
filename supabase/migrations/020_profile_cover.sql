-- Profile cover photo (separate from the profile image column).
alter table public.users
  add column if not exists cover_url text;
