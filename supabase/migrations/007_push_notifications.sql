-- Push notifications, same architecture as the signup approval email:
-- a Postgres function fires an async pg_net call to a Supabase Edge
-- Function (send-push), which does the actual FCM delivery. Nothing here
-- sends anything until you've done the Firebase-side setup described in
-- supabase/functions/send-push/README.md — every call is wrapped so a
-- missing/misconfigured setup never blocks the real action (task creation,
-- status updates, etc.) that triggered it.

create table public.atfal_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.atfal_users(id) on delete cascade,
  device_token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now()
);

create index atfal_push_tokens_user_idx on public.atfal_push_tokens(user_id);

alter table public.atfal_push_tokens enable row level security;
-- No policies: same pattern as every other user-linked table — only the
-- SECURITY DEFINER RPCs below may touch it.

create or replace function public.atfal_register_push_token(p_token uuid, p_device_token text, p_platform text)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare u public.atfal_users;
begin
  u := public.atfal_auth(p_token);
  if p_platform not in ('android', 'ios') then raise exception 'Invalid platform'; end if;
  insert into public.atfal_push_tokens (user_id, device_token, platform)
  values (u.id, p_device_token, p_platform)
  on conflict (device_token) do update set user_id = u.id, platform = p_platform;
end $$;

create or replace function public.atfal_unregister_push_token(p_token uuid, p_device_token text)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  perform public.atfal_auth(p_token); -- must be a valid session to unregister
  delete from public.atfal_push_tokens where device_token = p_device_token;
end $$;

-- Internal helper — fires a best-effort push to a set of users. Never
-- raises: a missing Edge Function / secret just means no push goes out.
create or replace function public.atfal_notify(p_user_ids uuid[], p_title text, p_body text, p_data jsonb default '{}'::jsonb)
returns void
language plpgsql set search_path = public, extensions, pg_temp
as $$
declare service_key text;
begin
  if coalesce(array_length(p_user_ids, 1), 0) = 0 then return; end if;
  begin
    select decrypted_secret into service_key from vault.decrypted_secrets where name = 'supabase_service_role_key';
    if service_key is not null then
      perform net.http_post(
        url := 'https://woygwtwrcunvcjrwbril.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object('Authorization', 'Bearer ' || service_key, 'Content-Type', 'application/json'),
        body := jsonb_build_object('user_ids', to_jsonb(p_user_ids), 'title', p_title, 'body', p_body, 'data', p_data)
      );
    end if;
  exception when others then
    null; -- best-effort; never let a notification failure break the caller
  end;
end $$;
-- Internal only — no auth check of its own (it trusts its SECURITY DEFINER
-- callers below), so it must never be reachable directly over the API.
revoke execute on function public.atfal_notify(uuid[], text, text, jsonb) from public, anon, authenticated;

-- ---------- Hook the notifier into existing write paths ----------

-- New task assigned → notify each assigned city's head.
create or replace function public.atfal_create_task(
  p_token uuid, p_title text, p_description text, p_category text,
  p_due_date date, p_attachment_url text, p_city_ids int[])
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; tid uuid; cid int; aid uuid; head_ids uuid[];
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
  select array_agg(id) into head_ids from public.atfal_users
  where role = 'city_head' and active and city_id = any(p_city_ids);
  perform public.atfal_notify(head_ids, 'New task: ' || trim(p_title), 'Tap to view details.');
  return tid;
end $$;

-- Status changes → notify whoever needs to act next.
create or replace function public.atfal_update_status(
  p_token uuid, p_assignment_id uuid, p_status text,
  p_note text default null, p_proof_url text default null, p_review_note text default null)
returns void
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare u public.atfal_users; a public.atfal_assignments; t public.atfal_tasks; admin_ids uuid[]; cname text;
begin
  u := public.atfal_auth(p_token);
  select * into a from public.atfal_assignments where id = p_assignment_id for update;
  if not found then raise exception 'Assignment not found'; end if;
  select * into t from public.atfal_tasks where id = a.task_id;
  select name into cname from public.atfal_cities where id = a.city_id;

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
    if p_status = 'submitted' then
      select array_agg(id) into admin_ids from public.atfal_users where role = 'admin' and active;
      perform public.atfal_notify(admin_ids, coalesce(cname, 'A city') || ' submitted a task',
        coalesce(t.title, '') || ' is ready for review.');
    end if;
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
    if p_status in ('approved', 'returned') then
      perform public.atfal_notify(
        array(select id from public.atfal_users where city_id = a.city_id and role = 'city_head' and active),
        case when p_status = 'approved' then 'Approved: ' else 'Returned: ' end || coalesce(t.title, ''),
        case when p_status = 'returned' then coalesce(p_review_note, 'Check the admin''s note.') else 'Nice work!' end
      );
    end if;
  end if;

  insert into public.atfal_activity (assignment_id, actor_name, action, detail)
  values (p_assignment_id, u.display_name, 'status:' || p_status,
          coalesce(p_review_note, p_note));
end $$;
