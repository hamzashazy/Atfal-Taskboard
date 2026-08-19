-- Self-service signup, admin approval: city heads can request an account
-- instead of an admin creating one manually. Every request is reviewed by
-- an admin before a real atfal_users row (and login access) is created.

alter table public.atfal_users
  add column email text,
  add column contact_no text;

create table public.atfal_signup_requests (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text not null,
  contact_no text not null,
  city_id int not null references public.atfal_cities(id),
  password_hash text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  review_note text,
  reviewed_by uuid references public.atfal_users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Only one live pending request per email at a time (friendlier duplicate
-- handling still happens in atfal_signup(); this is the DB-level backstop).
create unique index atfal_signup_requests_pending_email_idx
  on public.atfal_signup_requests (lower(email))
  where (status = 'pending');

create index atfal_signup_requests_status_idx on public.atfal_signup_requests(status, created_at);

alter table public.atfal_signup_requests enable row level security;
-- No policies: identical to atfal_users/atfal_sessions — every access goes
-- through the security-definer RPCs in 004_signup_functions.sql.
