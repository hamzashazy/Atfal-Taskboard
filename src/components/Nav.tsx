"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Session } from "@/lib/session";
import { logout } from "@/lib/api";
import type { SessionUser } from "@/lib/types";

export default function Nav() {
  const [user, setUser] = useState<SessionUser | null>(null);
  useEffect(() => setUser(Session.get()), []);

  return (
    <nav className="bg-emerald-800 text-white">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-3 px-4 py-2.5">
        <Link href="/" className="text-lg font-bold">
          🕌 Atfal Taskboard
        </Link>
        <Link href="/" className="rounded-md px-2 py-1 text-sm text-emerald-100 hover:bg-emerald-700">
          Dashboard
        </Link>
        {user?.role === "admin" && (
          <Link href="/admin" className="rounded-md px-2 py-1 text-sm text-emerald-100 hover:bg-emerald-700">
            Admin Portal
          </Link>
        )}
        {user?.role === "city_head" && (
          <Link href="/city" className="rounded-md px-2 py-1 text-sm text-emerald-100 hover:bg-emerald-700">
            My Tasks
          </Link>
        )}
        <span className="flex-1" />
        {user ? (
          <>
            <span className="text-xs text-emerald-200">{user.display_name}</span>
            <button
              onClick={() => logout()}
              className="rounded-md px-2 py-1 text-sm text-emerald-100 hover:bg-emerald-700"
            >
              Logout
            </button>
          </>
        ) : (
          <Link href="/login" className="rounded-md px-2 py-1 text-sm text-emerald-100 hover:bg-emerald-700">
            Login
          </Link>
        )}
      </div>
    </nav>
  );
}
