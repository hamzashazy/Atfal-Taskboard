// Sends a push notification to one or more users' registered devices via
// Firebase Cloud Messaging. Called from Postgres (atfal_notify(), see
// supabase/migrations/007_push_notifications.sql) — never called directly
// by the web or mobile clients.
//
// Setup (see README.md in this folder for the full walkthrough):
//   1. supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<the whole JSON file, one line>'
//   2. supabase functions deploy send-push
//   3. In the SQL editor: select vault.create_secret('<service_role_key>', 'supabase_service_role_key');

import { createClient } from "npm:@supabase/supabase-js@2";
import admin from "npm:firebase-admin@12";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");

if (FIREBASE_SERVICE_ACCOUNT_JSON && admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)),
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
    // Not configured yet — respond OK so the caller (best-effort by design)
    // doesn't treat this as an error, but do nothing.
    return new Response(JSON.stringify({ skipped: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), { status: 200 });
  }

  const { user_ids, title, body, data } = await req.json();
  if (!Array.isArray(user_ids) || user_ids.length === 0 || !title || !body) {
    return new Response(JSON.stringify({ error: "user_ids, title and body are required" }), { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: rows, error } = await supabase
    .from("atfal_push_tokens")
    .select("device_token")
    .in("user_id", user_ids);
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const tokens = (rows ?? []).map((r) => r.device_token as string);
  if (tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const stringData: Record<string, string> = {};
  for (const [k, v] of Object.entries(data ?? {})) stringData[k] = String(v);

  const result = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: stringData,
  });

  // Clean up tokens FCM says are no longer valid (app uninstalled, etc.)
  const dead: string[] = [];
  result.responses.forEach((r, i) => {
    if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
      dead.push(tokens[i]);
    }
  });
  if (dead.length > 0) {
    await supabase.from("atfal_push_tokens").delete().in("device_token", dead);
  }

  return new Response(
    JSON.stringify({ sent: result.successCount, failed: result.failureCount }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
