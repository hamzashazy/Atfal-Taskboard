# Database migrations

Run the SQL files here in order (001 through 007) in the project's SQL editor.

To move to a dedicated Supabase project:
1. Create the new project.
2. Run all the SQL files here, in order, in its SQL editor.
3. Re-seed cities/users (or export-import the atfal_* tables).
4. Update NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY in Vercel.

## Signup approval emails (003/004)

`atfal_approve_signup()` sends the "you're approved" email via Resend's API,
called through `pg_net` — but only once a Resend API key is stored in
Supabase Vault. Approving a signup works fine without it; the email is just
skipped until the key is set. One-time setup, run in the SQL editor (never
commit the key to git):

```sql
select vault.create_secret('re_xxxxxxxx', 'resend_api_key');
```

Get the key from resend.com (free tier). No domain verification needed —
mail sends from Resend's shared `onboarding@resend.dev` sender out of the
box; switch to a verified domain sender later by editing the `from` address
in `atfal_approve_signup()`.

## Push notifications (007)

`atfal_notify()` fires on task assignment, submission, and approval/return,
calling a Supabase Edge Function (`supabase/functions/send-push`) via
`pg_net` — same fail-open pattern as the email above. Full setup (Firebase
project, service account, Edge Function deploy) is in
`supabase/functions/send-push/README.md`. The last step is a Vault secret,
run here once you've deployed the function:

```sql
select vault.create_secret('<service_role key, from Project Settings → API>', 'supabase_service_role_key');
```
