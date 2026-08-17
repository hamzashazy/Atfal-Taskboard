# Database migrations

The live schema is applied to the shared Supabase project (qpbjckuphrfjupqrtiai)
as migrations `atfal_taskboard_schema` and `atfal_taskboard_functions`.

To move to a dedicated Supabase project later:
1. Create the new project.
2. Run the two SQL files here (001 then 002) in its SQL editor.
3. Re-seed cities/users (or export-import the atfal_* tables).
4. Update NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY in Vercel.
