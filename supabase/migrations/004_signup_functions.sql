-- Signup / approval RPC layer.
--
-- Email setup (one-time, do this in the Supabase SQL editor — never commit
-- the key to git): once you have a Resend API key, run:
--
--   select vault.create_secret('re_xxxxxxxx', 'resend_api_key');
--
-- Until that secret exists, atfal_approve_signup() still approves the user
-- normally — it just skips sending the email (checked defensively below).
create extension if not exists pg_net;

create or replace function public.atfal_signup(
  p_full_name text, p_email text, p_contact_no text, p_city_id int, p_password text)
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare rid uuid; norm_email text := lower(trim(p_email));
begin
  perform pg_sleep(0.3); -- brute-force / spam damper, matches atfal_login

  if trim(p_full_name) = '' then raise exception 'Full name is required'; end if;
  if norm_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' then
    raise exception 'Enter a valid email address';
  end if;
  if trim(p_contact_no) = '' then raise exception 'Contact number is required'; end if;
  if length(p_password) < 6 then raise exception 'Password must be at least 6 characters'; end if;
  if not exists (select 1 from public.atfal_cities where id = p_city_id and active) then
    raise exception 'Select a valid city';
  end if;
  if exists (select 1 from public.atfal_users where lower(username) = norm_email and active) then
    raise exception 'An account with this email already exists — try logging in instead';
  end if;
  if exists (select 1 from public.atfal_signup_requests where lower(email) = norm_email and status = 'pending') then
    raise exception 'A request for this email is already awaiting admin approval';
  end if;

  insert into public.atfal_signup_requests (full_name, email, contact_no, city_id, password_hash)
  values (trim(p_full_name), norm_email, trim(p_contact_no), p_city_id,
          extensions.crypt(p_password, extensions.gen_salt('bf')))
  returning id into rid;
  return rid;
end $$;

create or replace function public.atfal_list_signup_requests(p_token uuid, p_status text default 'pending')
returns json
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  return coalesce((select json_agg(json_build_object(
    'id', r.id, 'full_name', r.full_name, 'email', r.email, 'contact_no', r.contact_no,
    'city_id', r.city_id, 'city_name', c.name, 'status', r.status,
    'review_note', r.review_note, 'created_at', r.created_at)
    order by r.created_at)
    from public.atfal_signup_requests r
    join public.atfal_cities c on c.id = r.city_id
    where p_status is null or r.status = p_status), '[]'::json);
end $$;

create or replace function public.atfal_approve_signup(p_token uuid, p_request_id uuid)
returns json
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare
  u public.atfal_users;
  r public.atfal_signup_requests;
  nid uuid;
  cname text;
  api_key text;
  site_url text := 'https://atfal-taskboard.vercel.app';
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;

  select * into r from public.atfal_signup_requests where id = p_request_id for update;
  if not found then raise exception 'Signup request not found'; end if;
  if r.status <> 'pending' then raise exception 'This request was already reviewed'; end if;
  if exists (select 1 from public.atfal_users where lower(username) = r.email and active) then
    raise exception 'An account with this email already exists';
  end if;

  select name into cname from public.atfal_cities where id = r.city_id;

  insert into public.atfal_users (username, password_hash, display_name, role, city_id, email, contact_no)
  values (r.email, r.password_hash, r.full_name, 'city_head', r.city_id, r.email, r.contact_no)
  returning id into nid;

  update public.atfal_signup_requests
  set status = 'approved', reviewed_by = u.id, reviewed_at = now()
  where id = p_request_id;

  -- Best-effort approval email — never let a missing/misconfigured mail
  -- setup block the actual approval above.
  begin
    select decrypted_secret into api_key from vault.decrypted_secrets where name = 'resend_api_key';
    if api_key is not null then
      perform net.http_post(
        url := 'https://api.resend.com/emails',
        headers := jsonb_build_object('Authorization', 'Bearer ' || api_key, 'Content-Type', 'application/json'),
        body := jsonb_build_object(
          'from', 'Atfal Taskboard <onboarding@resend.dev>',
          'to', jsonb_build_array(r.email),
          'subject', 'You''re approved — Atfal Taskboard access',
          'html', format(
            '<p>Assalamu alaikum %s,</p>' ||
            '<p>Your Atfal Taskboard account for <b>%s</b> has been approved. You can sign in now:</p>' ||
            '<p><b>Sign in:</b> <a href="%s/login">%s/login</a><br>' ||
            '<b>Username:</b> %s</p>' ||
            '<p>Use the password you chose when you signed up.</p>' ||
            '<p>— Atfal Taskboard</p>',
            r.full_name, cname, site_url, site_url, r.email)
        )
      );
    end if;
  exception when others then
    null; -- email is best-effort; approval already committed above
  end;

  return json_build_object('user_id', nid, 'email', r.email, 'full_name', r.full_name, 'city_name', cname);
end $$;

create or replace function public.atfal_reject_signup(p_token uuid, p_request_id uuid, p_review_note text default null)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users; r public.atfal_signup_requests;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  select * into r from public.atfal_signup_requests where id = p_request_id for update;
  if not found then raise exception 'Signup request not found'; end if;
  if r.status <> 'pending' then raise exception 'This request was already reviewed'; end if;
  update public.atfal_signup_requests
  set status = 'rejected', review_note = p_review_note, reviewed_by = u.id, reviewed_at = now()
  where id = p_request_id;
end $$;

-- Surface email/contact_no in the existing admin user list too.
create or replace function public.atfal_list_users(p_token uuid)
returns json
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  return coalesce((select json_agg(json_build_object(
    'id', us.id, 'username', us.username, 'display_name', us.display_name,
    'role', us.role, 'city_id', us.city_id, 'city_name', c.name, 'active', us.active,
    'email', us.email, 'contact_no', us.contact_no)
    order by us.role, c.name)
    from public.atfal_users us left join public.atfal_cities c on c.id = us.city_id), '[]'::json);
end $$;
