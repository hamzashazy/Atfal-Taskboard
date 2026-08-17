-- ATFAL Taskboard RPC layer. Every write path validates a session token.
-- Requires pgcrypto (Supabase installs it in the "extensions" schema).

-- Internal auth helper (not callable from the API).
create or replace function public.atfal_auth(p_token uuid)
returns public.atfal_users
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users;
begin
  select us.* into u
  from public.atfal_sessions s
  join public.atfal_users us on us.id = s.user_id
  where s.token = p_token and s.expires_at > now() and us.active;
  if not found then
    raise exception 'AUTH: session invalid or expired';
  end if;
  return u;
end $$;
revoke execute on function public.atfal_auth(uuid) from public, anon, authenticated;

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
    'display_name', u.display_name, 'role', u.role, 'city_id', u.city_id, 'city_name', cname);
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
    'display_name', u.display_name, 'role', u.role, 'city_id', u.city_id, 'city_name', cname);
end $$;

create or replace function public.atfal_logout(p_token uuid)
returns void
language sql security definer set search_path = public, pg_temp
as $$ delete from public.atfal_sessions where token = p_token; $$;

create or replace function public.atfal_change_password(p_token uuid, p_old text, p_new text)
returns void
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.password_hash <> extensions.crypt(p_old, u.password_hash) then
    raise exception 'AUTH: current password incorrect';
  end if;
  if length(p_new) < 6 then raise exception 'Password must be at least 6 characters'; end if;
  update public.atfal_users set password_hash = extensions.crypt(p_new, extensions.gen_salt('bf'))
  where id = u.id;
end $$;

create or replace function public.atfal_create_task(
  p_token uuid, p_title text, p_description text, p_category text,
  p_due_date date, p_attachment_url text, p_city_ids int[])
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; tid uuid; cid int; aid uuid;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  if coalesce(array_length(p_city_ids,1),0) = 0 then raise exception 'Select at least one city'; end if;
  insert into public.atfal_tasks (title, description, category, due_date, attachment_url, created_by)
  values (trim(p_title), p_description, p_category, p_due_date, nullif(trim(p_attachment_url),''), u.id)
  returning id into tid;
  foreach cid in array p_city_ids loop
    insert into public.atfal_assignments (task_id, city_id) values (tid, cid)
    on conflict (task_id, city_id) do nothing
    returning id into aid;
    if aid is not null then
      insert into public.atfal_activity (assignment_id, actor_name, action, detail)
      values (aid, u.display_name, 'assigned', trim(p_title));
    end if;
  end loop;
  return tid;
end $$;

create or replace function public.atfal_delete_task(p_token uuid, p_task_id uuid)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  delete from public.atfal_tasks where id = p_task_id;
end $$;

create or replace function public.atfal_archive_task(p_token uuid, p_task_id uuid, p_archived boolean)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  update public.atfal_tasks set archived = p_archived where id = p_task_id;
end $$;

create or replace function public.atfal_update_status(
  p_token uuid, p_assignment_id uuid, p_status text,
  p_note text default null, p_proof_url text default null, p_review_note text default null)
returns void
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; a public.atfal_assignments;
begin
  u := public.atfal_auth(p_token);
  select * into a from public.atfal_assignments where id = p_assignment_id for update;
  if not found then raise exception 'Assignment not found'; end if;

  if u.role = 'city_head' then
    if a.city_id is distinct from u.city_id then
      raise exception 'AUTH: this task belongs to another city';
    end if;
    if a.status = 'approved' then
      raise exception 'Task already approved and locked';
    end if;
    if p_status not in ('in_progress','submitted') then
      raise exception 'City heads can only set status to in_progress or submitted';
    end if;
    update public.atfal_assignments set
      status = p_status,
      note = coalesce(p_note, note),
      proof_url = coalesce(nullif(trim(p_proof_url),''), proof_url),
      submitted_at = case when p_status = 'submitted' then now() else submitted_at end,
      updated_at = now()
    where id = p_assignment_id;
  elsif u.role = 'admin' then
    if p_status not in ('pending','in_progress','submitted','approved','returned') then
      raise exception 'Invalid status';
    end if;
    update public.atfal_assignments set
      status = p_status,
      review_note = coalesce(p_review_note, review_note),
      reviewed_at = case when p_status in ('approved','returned') then now() else reviewed_at end,
      updated_at = now()
    where id = p_assignment_id;
  end if;

  insert into public.atfal_activity (assignment_id, actor_name, action, detail)
  values (p_assignment_id, u.display_name, 'status:' || p_status,
          coalesce(p_review_note, p_note));
end $$;

create or replace function public.atfal_create_city(p_token uuid, p_name text, p_region text default null)
returns int
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users; cid int;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  insert into public.atfal_cities (name, region) values (trim(p_name), p_region) returning id into cid;
  return cid;
end $$;

create or replace function public.atfal_set_city_active(p_token uuid, p_city_id int, p_active boolean)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  update public.atfal_cities set active = p_active where id = p_city_id;
end $$;

create or replace function public.atfal_create_user(
  p_token uuid, p_username text, p_password text, p_display_name text,
  p_role text, p_city_id int default null)
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; nid uuid;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  if length(p_password) < 6 then raise exception 'Password must be at least 6 characters'; end if;
  insert into public.atfal_users (username, password_hash, display_name, role, city_id)
  values (lower(trim(p_username)), extensions.crypt(p_password, extensions.gen_salt('bf')),
          trim(p_display_name), p_role, p_city_id)
  returning id into nid;
  return nid;
end $$;

create or replace function public.atfal_reset_password(p_token uuid, p_user_id uuid, p_new_password text)
returns void
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  if length(p_new_password) < 6 then raise exception 'Password must be at least 6 characters'; end if;
  update public.atfal_users
  set password_hash = extensions.crypt(p_new_password, extensions.gen_salt('bf'))
  where id = p_user_id;
  delete from public.atfal_sessions where user_id = p_user_id;
end $$;

create or replace function public.atfal_set_user_active(p_token uuid, p_user_id uuid, p_active boolean)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if u.role <> 'admin' then raise exception 'AUTH: admin only'; end if;
  update public.atfal_users set active = p_active where id = p_user_id;
  if not p_active then delete from public.atfal_sessions where user_id = p_user_id; end if;
end $$;

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
    'role', us.role, 'city_id', us.city_id, 'city_name', c.name, 'active', us.active)
    order by us.role, c.name)
    from public.atfal_users us left join public.atfal_cities c on c.id = us.city_id), '[]'::json);
end $$;
