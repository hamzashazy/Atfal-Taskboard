"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { rpc } from "@/lib/api";
import { Session } from "@/lib/session";
import type { SessionUser } from "@/lib/types";

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const s = Session.get();
    if (s?.role === "admin") router.replace("/admin");
    else if (s?.role === "city_head") router.replace("/city");
  }, [router]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const data = await rpc<SessionUser>("atfal_login", {
        p_username: username,
        p_password: password,
      });
      Session.set(data);
      window.location.href = data.role === "admin" ? "/admin" : "/city";
    } catch (ex) {
      setError((ex as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="card mx-auto mt-[8vh] w-full max-w-sm">
      <h1 className="text-lg font-bold">Sign in</h1>
      <p className="mt-1 text-sm text-gray-500">
        City heads and admins only. Viewing the{" "}
        <Link href="/" className="text-emerald-700 underline">
          dashboard
        </Link>{" "}
        needs no login.
      </p>
      <form onSubmit={submit}>
        <label className="label" htmlFor="u">
          Username
        </label>
        <input
          id="u"
          className="input"
          autoCapitalize="none"
          autoComplete="username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
        />
        <label className="label" htmlFor="p">
          Password
        </label>
        <input
          id="p"
          type="password"
          className="input"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        <p className="mt-2 min-h-5 text-sm text-red-600">{error}</p>
        <button className="btn w-full" disabled={busy}>
          {busy ? "Signing in…" : "Login"}
        </button>
      </form>
    </div>
  );
}
