# Atfal Taskboard

Task management platform for Atfal operations across 25+ cities. Replaces
WhatsApp-group task tracking with a central platform; WhatsApp stays for
notifications via share links.

## Portals

| Route | Who | What |
|---|---|---|
| `/` | Everyone (no login) | Public dashboard: city leaderboard, task × city matrix, activity feed |
| `/login` | — | Username/password sign-in |
| `/city` | City heads | Their city's task list: start, submit with note + proof link, history, change password |
| `/admin` | Markaz admins | Create tasks (assign to one/many/all cities), review & approve/return submissions, manage tasks, cities, users |

## Stack

- **Next.js 15** (App Router, TypeScript, Tailwind v4) on **Vercel**
- **Supabase Postgres** — dedicated project `woygwtwrcunvcjrwbril`
  (atfaalalburhan account, ap-south-1), tables prefixed `atfal_`
- **Auth**: self-contained (bcrypt password hashes + session tokens in
  `atfal_users`/`atfal_sessions`); all writes go through SECURITY DEFINER SQL
  functions that validate the token. Row Level Security allows public read of
  dashboard data only; credentials/sessions are inaccessible to the API role.

## Task lifecycle

```
pending → in_progress → submitted → approved
                            ↓ (admin returns with note)
                        returned → submitted → …
```

City heads can only move their own city's assignments to `in_progress`/`submitted`.
Only admins can `approve`/`return`. Approved assignments are locked.

## Development

```bash
npm install
npm run dev
```

Supabase URL/key are baked in with env-var overrides:
`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (the anon key is
public by design; RLS is the security boundary).

## Credentials

Initial account credentials live in `CREDENTIALS.md` (git-ignored — never
commit it). Admins manage users in `/admin` → Users.

## Moving to a dedicated Supabase project

See `supabase/migrations/README.md` — run `001_schema.sql` + `002_functions.sql`
on the new project, re-seed, and update the env vars in Vercel.
