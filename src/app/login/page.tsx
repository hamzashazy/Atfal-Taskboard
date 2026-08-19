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
    <div className="card animate-fade-up mx-auto mt-[8vh] w-full max-w-sm">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/atfal-logo-icon.png" alt="Atfal" className="mb-2 h-12 w-12 rounded-xl object-cover" />
      <h1 className="text-lg font-bold">Sign in</h1>
      <p className="mt-1 text-sm text-gray-500">City heads and admins only.</p>
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
          {busy ? <span className="spinner" /> : null} {busy ? "Signing in…" : "Login"}
        </button>
      </form>
      <p className="mt-4 text-center text-sm text-gray-500">
        New city head?{" "}
        <Link href="/signup" className="text-brand-700 underline">
          Request access
        </Link>
      </p>
    </div>
  );
}
