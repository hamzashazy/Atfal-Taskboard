"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CategoryChip, OverdueChip, StatusChip } from "@/components/Chips";
import { rpc } from "@/lib/api";
import { fmtDate, isOverdue } from "@/lib/meta";
import { Session } from "@/lib/session";
import { sb } from "@/lib/supabase";
import { toast } from "@/lib/toast";
import type { Assignment, SessionUser, Task } from "@/lib/types";

type Tab = "todo" | "done" | "account";

export default function CityPage() {
  const [me, setMe] = useState<SessionUser | null>(null);
  const [tab, setTab] = useState<Tab>("todo");
  const [tasks, setTasks] = useState<Map<string, Task>>(new Map());
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [openSubmit, setOpenSubmit] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);

  useEffect(() => {
    const s = Session.get();
    if (!s || s.role !== "city_head") {
      window.location.href = "/login";
      return;
    }
    setMe(s);
  }, []);

  const load = useCallback(async (cityId: number) => {
    const [t, a] = await Promise.all([
      sb.from("atfal_tasks").select("*").eq("archived", false),
      sb.from("atfal_assignments").select("*").eq("city_id", cityId),
    ]);
    if (t.error || a.error) {
      toast.error("Failed to load: " + (t.error ?? a.error)!.message);
      setLoading(false);
      return;
    }
    const byId = new Map((t.data as Task[]).map((x) => [x.id, x]));
    setTasks(byId);
    setAssignments((a.data as Assignment[]).filter((x) => byId.has(x.task_id)));
    setLoading(false);
  }, []);

  useEffect(() => {
    if (me?.city_id) load(me.city_id);
  }, [me, load]);

  const { todo, done } = useMemo(() => {
    const order: Record<string, number> = { returned: 0, pending: 1, in_progress: 2 };
    const todo = assignments
      .filter((a) => ["pending", "in_progress", "returned"].includes(a.status))
      .sort(
        (x, y) =>
          order[x.status] - order[y.status] ||
          (tasks.get(x.task_id)?.due_date ?? "9999").localeCompare(
            tasks.get(y.task_id)?.due_date ?? "9999",
          ),
      );
    const done = assignments
      .filter((a) => ["submitted", "approved"].includes(a.status))
      .sort((x, y) => (y.submitted_at ?? "").localeCompare(x.submitted_at ?? ""));
    return { todo, done };
  }, [assignments, tasks]);

  async function setStatus(id: string, status: string, note?: string | null, proof?: string | null) {
    if (!me) return;
    setBusyId(id);
    try {
      await rpc("atfal_update_status", {
        p_token: me.token,
        p_assignment_id: id,
        p_status: status,
        p_note: note ?? null,
        p_proof_url: proof ?? null,
      });
      setOpenSubmit(null);
      await load(me.city_id!);
      if (status === "submitted") toast.success("Task submitted for review.");
      else if (status === "in_progress") toast.success("Marked as in progress.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusyId(null);
  }

  if (!me) return null;
  if (loading) return <CitySkeleton />;

  return (
    <div>
      <h1 className="mb-3 text-lg font-bold">📍 {me.city_name} — Task List</h1>
      <div className="mb-4 flex gap-1 border-b-2 border-gray-200">
        <TabBtn active={tab === "todo"} onClick={() => setTab("todo")}>
          To Do{" "}
          {todo.length > 0 && (
            <span className="ml-1 rounded-full bg-red-600 px-2 text-xs text-white">{todo.length}</span>
          )}
        </TabBtn>
        <TabBtn active={tab === "done"} onClick={() => setTab("done")}>
          History
        </TabBtn>
        <TabBtn active={tab === "account"} onClick={() => setTab("account")}>
          My Account{" "}
          {(!me.email || !me.contact_no) && (
            <span className="ml-1 inline-block h-2 w-2 rounded-full bg-red-600" title="Profile incomplete" />
          )}
        </TabBtn>
      </div>

      {tab === "todo" &&
        (todo.length === 0 ? (
          <div className="card text-sm text-gray-500">🎉 Nothing pending — all caught up!</div>
        ) : (
          todo.map((a) => (
            <TaskCard
              key={a.id}
              a={a}
              t={tasks.get(a.task_id)!}
              editable
              busy={busyId === a.id}
              openSubmit={openSubmit === a.id}
              onStart={() => setStatus(a.id, "in_progress")}
              onToggleSubmit={() => setOpenSubmit(openSubmit === a.id ? null : a.id)}
              onSubmit={(note, proof) => setStatus(a.id, "submitted", note, proof)}
            />
          ))
        ))}

      {tab === "done" &&
        (done.length === 0 ? (
          <div className="card text-sm text-gray-500">Nothing submitted yet.</div>
        ) : (
          done.map((a) => <TaskCard key={a.id} a={a} t={tasks.get(a.task_id)!} />)
        ))}

      {tab === "account" && (
        <div className="flex flex-col gap-4">
          <ProfileSection me={me} onSaved={(u) => setMe(u)} />
          <ChangePassword token={me.token} />
        </div>
      )}
    </div>
  );
}

function TabBtn({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={`rounded-t-lg px-3.5 py-2 text-sm font-semibold ${
        active ? "text-brand-700 shadow-[inset_0_-2px_0_#a92425]" : "text-gray-500"
      }`}
    >
      {children}
    </button>
  );
}

function TaskCard({
  a,
  t,
  editable,
  busy,
  openSubmit,
  onStart,
  onToggleSubmit,
  onSubmit,
}: {
  a: Assignment;
  t: Task;
  editable?: boolean;
  busy?: boolean;
  openSubmit?: boolean;
  onStart?: () => void;
  onToggleSubmit?: () => void;
  onSubmit?: (note: string | null, proof: string | null) => void;
}) {
  const [note, setNote] = useState(a.note ?? "");
  const [proof, setProof] = useState(a.proof_url ?? "");
  const od = isOverdue(t, a.status);

  return (
    <div className={`card mb-3 border-l-4 ${od ? "border-l-red-500" : "border-l-gray-200"}`}>
      <h3 className="font-semibold">{t.title}</h3>
      <div className="my-1.5 flex flex-wrap items-center gap-2">
        <CategoryChip category={t.category} />
        <StatusChip status={a.status} />
        {od && <OverdueChip />}
        <span className="text-xs text-gray-400">Due: {fmtDate(t.due_date)}</span>
      </div>
      {t.description && <p className="text-sm whitespace-pre-wrap text-gray-600">{t.description}</p>}
      {t.attachment_url && (
        <p className="mt-1 text-sm">
          <a
            className="text-brand-700 underline"
            href={t.attachment_url}
            target="_blank"
            rel="noopener noreferrer"
          >
            📎 Task attachment / form
          </a>
        </p>
      )}
      {a.status === "returned" && a.review_note && (
        <p className="mt-1 text-sm text-red-600">
          <b>Returned by admin:</b> {a.review_note}
        </p>
      )}
      {a.proof_url && (
        <p className="mt-1 text-xs text-gray-400">
          Your proof:{" "}
          <a className="underline" href={a.proof_url} target="_blank" rel="noopener noreferrer">
            {a.proof_url}
          </a>
        </p>
      )}
      {a.note && <p className="mt-1 text-xs text-gray-400">Your note: {a.note}</p>}

      {editable && (
        <div className="mt-2.5 flex flex-wrap gap-2">
          {a.status === "pending" && (
            <button className="btn" onClick={onStart} disabled={busy}>
              {busy ? <span className="spinner" /> : "▶"} Start
            </button>
          )}
          <button className="btn bg-amber-600 hover:bg-amber-700" onClick={onToggleSubmit} disabled={busy}>
            📤 Submit{a.status === "returned" ? " again" : ""}
          </button>
        </div>
      )}

      {editable && openSubmit && (
        <div className="mt-3 border-t border-gray-200 pt-3">
          <label className="label">Note (optional — Urdu is fine)</label>
          <textarea className="input min-h-20" value={note} onChange={(e) => setNote(e.target.value)} />
          <label className="label">Proof link (Google Sheet / Drive photo — optional)</label>
          <input
            className="input"
            placeholder="https://..."
            value={proof}
            onChange={(e) => setProof(e.target.value)}
          />
          <div className="mt-2.5 flex gap-2">
            <button className="btn" onClick={() => onSubmit?.(note || null, proof || null)} disabled={busy}>
              {busy ? <span className="spinner" /> : "✅"} Confirm submit
            </button>
            <button className="btn btn-ghost" onClick={onToggleSubmit} disabled={busy}>
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function ProfileSection({ me, onSaved }: { me: SessionUser; onSaved: (u: SessionUser) => void }) {
  const [email, setEmail] = useState(me.email ?? "");
  const [contactNo, setContactNo] = useState(me.contact_no ?? "");
  const [busy, setBusy] = useState(false);
  const incomplete = !me.email || !me.contact_no;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const updated = await rpc<{ email: string | null; contact_no: string | null }>(
        "atfal_update_profile",
        { p_token: me.token, p_email: email, p_contact_no: contactNo },
      );
      const next = { ...me, ...updated };
      Session.set(next);
      onSaved(next);
      toast.success("Profile updated.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusy(false);
  }

  return (
    <div className="card max-w-sm">
      <h3 className="font-semibold">
        {incomplete ? "⚠️ Complete your profile" : "Your profile"}
      </h3>
      {incomplete && (
        <p className="mt-1 text-sm text-gray-500">
          Add your email and masool number so the markaz can reach you directly.
        </p>
      )}
      <form onSubmit={submit}>
        <label className="label">Email</label>
        <input
          type="email"
          className="input"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
        />
        <label className="label">Masool number</label>
        <input
          type="tel"
          className="input"
          value={contactNo}
          onChange={(e) => setContactNo(e.target.value)}
          placeholder="03xx-xxxxxxx"
        />
        <button className="btn mt-3" disabled={busy}>
          {busy ? <span className="spinner" /> : null} Save profile
        </button>
      </form>
    </div>
  );
}

function ChangePassword({ token }: { token: string }) {
  const [oldPw, setOldPw] = useState("");
  const [newPw, setNewPw] = useState("");
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    try {
      await rpc("atfal_change_password", { p_token: token, p_old: oldPw, p_new: newPw });
      setMsg({ ok: true, text: "Password updated ✔" });
      setOldPw("");
      setNewPw("");
    } catch (ex) {
      setMsg({ ok: false, text: (ex as Error).message });
    }
  }

  return (
    <div className="card max-w-sm">
      <h3 className="font-semibold">Change password</h3>
      <form onSubmit={submit}>
        <label className="label">Current password</label>
        <input
          type="password"
          className="input"
          value={oldPw}
          onChange={(e) => setOldPw(e.target.value)}
          required
        />
        <label className="label">New password (min 6 characters)</label>
        <input
          type="password"
          className="input"
          value={newPw}
          onChange={(e) => setNewPw(e.target.value)}
          required
          minLength={6}
        />
        {msg && (
          <p className={`mt-2 text-sm ${msg.ok ? "text-brand-700" : "text-red-600"}`}>{msg.text}</p>
        )}
        <button className="btn mt-2">Update password</button>
      </form>
    </div>
  );
}

function CitySkeleton() {
  return (
    <div className="animate-fade-up">
      <div className="skeleton mb-3 h-6 w-56" />
      <div className="mb-4 flex gap-2">
        <div className="skeleton h-8 w-20" />
        <div className="skeleton h-8 w-20" />
        <div className="skeleton h-8 w-24" />
      </div>
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="skeleton mb-3 h-28 w-full rounded-xl" />
      ))}
    </div>
  );
}
