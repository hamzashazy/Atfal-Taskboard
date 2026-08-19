-- Self-service profile completion. Accounts created directly by an admin
-- (before the signup flow existed) don't have email/contact_no set — this
-- lets a signed-in user (typically a city head) fill those in themselves.

-- Surface email/contact_no so the client can detect an incomplete profile.
create or replace function public.atfal_login(p_username text, p_password text)
returns json
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; t uuid; cname text;
begin
  perform pg_sleep(0.3); -- brute-force damper
  select * into u from public.atfal_users
  where lower(username) = lower(trim(p_username)) and active;
  if not found or u.password_hash <> extensions.crypt(p_password, u.password_hash) then
    raise exception 'AUTH: invalid username or password';
  end if;
  insert into public.atfal_sessions (user_id) values (u.id) returning token into t;
  select name into cname from public.atfal_cities where id = u.city_id;
  return json_build_object('token', t, 'user_id', u.id, 'username', u.username,
    'display_name', u.display_name, 'role', u.role, 'city_id', u.city_id, 'city_name', cname,
    'email', u.email, 'contact_no', u.contact_no);
end $$;

create or replace function public.atfal_me(p_token uuid)
returns json
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; cname text;
begin
  u := public.atfal_auth(p_token);
  select name into cname from public.atfal_cities where id = u.city_id;
  return json_build_object('user_id', u.id, 'username', u.username,
    'display_name', u.display_name, 'role', u.role, 'city_id', u.city_id, 'city_name', cname,
    'email', u.email, 'contact_no', u.contact_no);
end $$;

create or replace function public.atfal_update_profile(p_token uuid, p_email text, p_contact_no text)
returns json
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users; norm_email text; new_email text; new_contact text;
begin
  u := public.atfal_auth(p_token);
  norm_email := nullif(lower(trim(p_email)), '');
  if norm_email is not null and norm_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' then
    raise exception 'Enter a valid email address';
  end if;
  if norm_email is not null and exists (
    select 1 from public.atfal_users where lower(email) = norm_email and id <> u.id
  ) then
    raise exception 'Another account already uses this email';
  end if;
  update public.atfal_users
  set email = coalesce(norm_email, email),
      contact_no = coalesce(nullif(trim(p_contact_no), ''), contact_no)
  where id = u.id
  returning email, contact_no into new_email, new_contact;
  return json_build_object('email', new_email, 'contact_no', new_contact);
end $$;
