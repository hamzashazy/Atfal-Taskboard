"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { rpc } from "@/lib/api";
import { sb } from "@/lib/supabase";
import type { City } from "@/lib/types";

export default function SignupPage() {
  const [cities, setCities] = useState<City[]>([]);
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [contactNo, setContactNo] = useState("");
  const [cityId, setCityId] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  useEffect(() => {
    sb.from("atfal_cities")
      .select("*")
      .eq("active", true)
      .order("name")
      .then(({ data }) => setCities((data as City[]) ?? []));
  }, []);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (password !== confirm) {
      setError("Passwords don't match.");
      return;
    }
    setBusy(true);
    try {
      await rpc("atfal_signup", {
        p_full_name: fullName,
        p_email: email,
        p_contact_no: contactNo,
        p_city_id: cityId ? Number(cityId) : null,
        p_password: password,
      });
      setDone(true);
    } catch (ex) {
      setError((ex as Error).message);
    }
    setBusy(false);
  }

  if (done) {
    return (
      <div className="card animate-fade-up mx-auto mt-[8vh] w-full max-w-sm text-center">
        <div className="mb-2 text-3xl">✅</div>
        <h1 className="text-lg font-bold">Request submitted</h1>
        <p className="mt-2 text-sm text-gray-500">
          An admin will review your request. You&apos;ll get an email once it&apos;s approved — then
          you can sign in with the email and password you just chose.
        </p>
        <Link href="/login" className="btn mt-4 inline-block">
          Back to sign in
        </Link>
      </div>
    );
  }

  return (
    <div className="card animate-fade-up mx-auto mt-[4vh] w-full max-w-sm">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/atfal-logo-icon.png" alt="Atfal" className="mb-2 h-12 w-12 rounded-xl object-cover" />
      <h1 className="text-lg font-bold">Request access</h1>
      <p className="mt-1 text-sm text-gray-500">
        For city heads without an account yet. An admin reviews every request before it&apos;s active.{" "}
        Already have one? <Link href="/login" className="text-brand-700 underline">Sign in</Link>.
      </p>
      <form onSubmit={submit}>
        <label className="label" htmlFor="name">
          Full name
        </label>
        <input id="name" className="input" value={fullName} onChange={(e) => setFullName(e.target.value)} required />

        <label className="label" htmlFor="email">
          Email
        </label>
        <input
          id="email"
          type="email"
          className="input"
          autoCapitalize="none"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />

        <label className="label" htmlFor="contact">
          Contact number
        </label>
        <input
          id="contact"
          type="tel"
          className="input"
          value={contactNo}
          onChange={(e) => setContactNo(e.target.value)}
          required
        />

        <label className="label" htmlFor="city">
          City
        </label>
        <select id="city" className="input" value={cityId} onChange={(e) => setCityId(e.target.value)} required>
          <option value="" disabled>
            Select your city…
          </option>
          {cities.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>

        <label className="label" htmlFor="password">
          Password
        </label>
        <input
          id="password"
          type="password"
          className="input"
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          minLength={6}
          required
        />

        <label className="label" htmlFor="confirm">
          Confirm password
        </label>
        <input
          id="confirm"
          type="password"
          className="input"
          autoComplete="new-password"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          minLength={6}
          required
        />

        <p className="mt-2 min-h-5 text-sm text-red-600">{error}</p>
        <button className="btn w-full" disabled={busy}>
          {busy ? <span className="spinner" /> : null} {busy ? "Submitting…" : "Request access"}
        </button>
      </form>
    </div>
  );
}
