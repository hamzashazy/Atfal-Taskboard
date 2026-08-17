import { createClient } from "@supabase/supabase-js";

// The anon key is safe to publish — all data access is governed by RLS,
// and every write goes through token-validated SQL functions.
const url =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://qpbjckuphrfjupqrtiai.supabase.co";
const anonKey =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwYmpja3VwaHJmanVwcXJ0aWFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NzUzMzYsImV4cCI6MjA3ODM1MTMzNn0.65dicN3QzcIK0WGUY0mZlXm8KmyqAjGWEqeav1PSB6E";

export const sb = createClient(url, anonKey);
