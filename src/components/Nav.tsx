"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Session } from "@/lib/session";
import { logout } from "@/lib/api";
import type { SessionUser } from "@/lib/types";

function NavLink({ href, children, onClick }: { href: string; children: React.ReactNode; onClick?: () => void }) {
  const pathname = usePathname();
  const active = pathname === href;
  return (
    <Link
      href={href}
      onClick={onClick}
      className={`rounded-md px-2.5 py-1.5 text-sm font-medium transition-colors ${
        active ? "bg-brand-700 text-white" : "text-brand-100 hover:bg-brand-700/70"
      }`}
    >
      {children}
    </Link>
  );
}

export default function Nav() {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  useEffect(() => setUser(Session.get()), []);
  useEffect(() => setOpen(false), [pathname]);

  return (
    <nav className="sticky top-0 z-40 bg-brand-800 text-white shadow-sm">
      <div className="mx-auto flex max-w-6xl items-center gap-1 px-4 py-2.5">
        <Link
          href={user ? "/" : "/login"}
          className="mr-1 flex items-center gap-2 text-lg font-bold whitespace-nowrap"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/atfal-logo-icon.png" alt="" className="h-8 w-8 rounded-lg object-cover" />
          Atfal Taskboard
        </Link>

        {/* desktop links */}
        <div className="hidden items-center gap-1 sm:flex">
          {user && <NavLink href="/">Dashboard</NavLink>}
          {user?.role === "admin" && <NavLink href="/admin">Admin Portal</NavLink>}
          {user?.role === "city_head" && <NavLink href="/city">My Tasks</NavLink>}
        </div>

        <span className="flex-1" />

        {/* desktop account area */}
        <div className="hidden items-center gap-2 sm:flex">
          {user ? (
            <>
              <span className="flex items-center gap-1.5 text-xs text-brand-200">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand-600 text-[11px] font-bold text-white">
                  {user.display_name.slice(0, 1).toUpperCase()}
                </span>
                {user.display_name}
              </span>
              <button
                onClick={() => logout()}
                className="rounded-md px-2.5 py-1.5 text-sm font-medium text-brand-100 transition-colors hover:bg-brand-700/70"
              >
                Logout
              </button>
            </>
          ) : (
            <NavLink href="/login">Login</NavLink>
          )}
        </div>

        {/* mobile hamburger */}
        <button
          className="rounded-md p-1.5 text-brand-100 hover:bg-brand-700/70 sm:hidden"
          onClick={() => setOpen((o) => !o)}
          aria-label="Toggle menu"
          aria-expanded={open}
        >
          {open ? (
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M6 6l12 12M18 6l-12 12" strokeLinecap="round" />
            </svg>
          ) : (
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M4 7h16M4 12h16M4 17h16" strokeLinecap="round" />
            </svg>
          )}
        </button>
      </div>

      {/* mobile menu */}
      {open && (
        <div className="animate-fade-up flex flex-col gap-1 border-t border-brand-700 px-4 pb-3 pt-2 sm:hidden">
          {user && (
            <NavLink href="/" onClick={() => setOpen(false)}>
              Dashboard
            </NavLink>
          )}
          {user?.role === "admin" && (
            <NavLink href="/admin" onClick={() => setOpen(false)}>
              Admin Portal
            </NavLink>
          )}
          {user?.role === "city_head" && (
            <NavLink href="/city" onClick={() => setOpen(false)}>
              My Tasks
            </NavLink>
          )}
          {user ? (
            <>
              <div className="mt-1 border-t border-brand-700 pt-2 text-xs text-brand-200">
                Signed in as <b>{user.display_name}</b>
              </div>
              <button
                onClick={() => logout()}
                className="rounded-md px-2.5 py-1.5 text-left text-sm font-medium text-brand-100 hover:bg-brand-700/70"
              >
                Logout
              </button>
            </>
          ) : (
            <NavLink href="/login" onClick={() => setOpen(false)}>
              Login
            </NavLink>
          )}
        </div>
      )}
    </nav>
  );
}
