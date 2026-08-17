import { createClient } from "@supabase/supabase-js";

// The anon key is safe to publish — all data access is governed by RLS,
// and every write goes through token-validated SQL functions.
const url =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://woygwtwrcunvcjrwbril.supabase.co";
const anonKey =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndveWd3dHdyY3VudmNqcndicmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5NTAzMjgsImV4cCI6MjEwMjUyNjMyOH0.MQfDxX2gL1LoJEFy7y-gxlYJjBEWCYjyS1rVGiSfsh4";

export const sb = createClient(url, anonKey);
