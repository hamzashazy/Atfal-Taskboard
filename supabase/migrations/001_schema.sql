-- ATFAL Taskboard: fully isolated from CRM tables. All tables prefixed atfal_.
-- Auth is self-contained (atfal_users + atfal_sessions); does NOT touch auth.users.

create table public.atfal_cities (
  id serial primary key,
  name text not null unique,
  region text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.atfal_users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text not null,
  display_name text not null,
  role text not null check (role in ('admin','city_head')),
  city_id int references public.atfal_cities(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint atfal_city_head_needs_city check (role <> 'city_head' or city_id is not null)
);

create table public.atfal_sessions (
  token uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.atfal_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days'
);

create table public.atfal_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text not null check (category in ('attendance','finance','inventory','announcement','poc_data','other')),
  due_date date,
  attachment_url text,
  created_by uuid references public.atfal_users(id),
  archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.atfal_assignments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.atfal_tasks(id) on delete cascade,
  city_id int not null references public.atfal_cities(id),
  status text not null default 'pending' check (status in ('pending','in_progress','submitted','approved','returned')),
  note text,
  proof_url text,
  review_note text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (task_id, city_id)
);

create table public.atfal_activity (
  id bigserial primary key,
  assignment_id uuid references public.atfal_assignments(id) on delete cascade,
  actor_name text not null,
  action text not null,
  detail text,
  created_at timestamptz not null default now()
);

create index atfal_assignments_city_idx on public.atfal_assignments(city_id, status);
create index atfal_assignments_task_idx on public.atfal_assignments(task_id);
create index atfal_activity_assignment_idx on public.atfal_activity(assignment_id);
create index atfal_sessions_user_idx on public.atfal_sessions(user_id);

-- RLS: dashboard data is publicly readable; credentials/sessions are not.
-- There are NO insert/update/delete policies anywhere: every write goes
-- through security-definer RPCs that validate an atfal_sessions token.
alter table public.atfal_cities enable row level security;
alter table public.atfal_users enable row level security;
alter table public.atfal_sessions enable row level security;
alter table public.atfal_tasks enable row level security;
alter table public.atfal_assignments enable row level security;
alter table public.atfal_activity enable row level security;

create policy "atfal cities public read" on public.atfal_cities for select using (true);
create policy "atfal tasks public read" on public.atfal_tasks for select using (true);
create policy "atfal assignments public read" on public.atfal_assignments for select using (true);
create policy "atfal activity public read" on public.atfal_activity for select using (true);
-- atfal_users / atfal_sessions: no policies at all -> deny all direct access.
