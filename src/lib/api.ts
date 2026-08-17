import { sb } from "./supabase";
import { Session } from "./session";

/** Call a database function; throws a clean Error with the Postgres message. */
export async function rpc<T = unknown>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await sb.rpc(fn, args);
  if (error) {
    const msg = (error.message || "Request failed").replace(/^AUTH: /, "");
    if (/session invalid|expired/i.test(msg)) {
      Session.clear();
      window.location.href = "/login";
    }
    throw new Error(msg);
  }
  return data as T;
}

export async function logout() {
  const s = Session.get();
  if (s?.token) {
    try {
      await rpc("atfal_logout", { p_token: s.token });
    } catch {
      /* session already gone */
    }
  }
  Session.clear();
  window.location.href = "/";
}

export function waShareUrl(text: string): string {
  return "https://wa.me/?text=" + encodeURIComponent(text);
}
