"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CategoryChip, StatusChip } from "@/components/Chips";
import { rpc, waShareUrl } from "@/lib/api";
import { CATEGORIES, CATEGORY_LABEL, fmtDate, fmtTime } from "@/lib/meta";
import { Session } from "@/lib/session";
import { sb } from "@/lib/supabase";
import { toast } from "@/lib/toast";
import type { Assignment, Category, City, SessionUser, SignupRequest, Task, UserRow } from "@/lib/types";

type Tab = "new" | "review" | "tasks" | "cities" | "users" | "signups";

export default function AdminPage() {
  const [me, setMe] = useState<SessionUser | null>(null);
  const [tab, setTab] = useState<Tab>("new");
  const [cities, setCities] = useState<City[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [signups, setSignups] = useState<SignupRequest[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const s = Session.get();
    if (!s || s.role !== "admin") {
      window.location.href = "/login";
      return;
    }
    setMe(s);
  }, []);

  const load = useCallback(async () => {
    const [c, t, a] = await Promise.all([
      sb.from("atfal_cities").select("*").order("name"),
      sb.from("atfal_tasks").select("*").order("created_at", { ascending: false }),
      sb.from("atfal_assignments").select("*"),
    ]);
    const err = c.error ?? t.error ?? a.error;
    if (err) {
      toast.error("Failed to load: " + err.message);
      setLoading(false);
      return;
    }
    setCities(c.data as City[]);
    setTasks(t.data as Task[]);
    setAssignments(a.data as Assignment[]);
    setLoading(false);
  }, []);

  const loadUsers = useCallback(async (token: string) => {
    try {
      setUsers(await rpc<UserRow[]>("atfal_list_users", { p_token: token }));
    } catch (ex) {
      toast.error((ex as Error).message);
    }
  }, []);

  const loadSignups = useCallback(async (token: string) => {
    try {
      setSignups(
        await rpc<SignupRequest[]>("atfal_list_signup_requests", { p_token: token, p_status: "pending" }),
      );
    } catch (ex) {
      toast.error((ex as Error).message);
    }
  }, []);

  useEffect(() => {
    if (me) {
      load();
      loadUsers(me.token);
      loadSignups(me.token);
    }
  }, [me, load, loadUsers, loadSignups]);

  const reviewQueue = useMemo(
    () =>
      assignments
        .filter((a) => a.status === "submitted")
        .sort((x, y) => (x.submitted_at ?? "").localeCompare(y.submitted_at ?? "")),
    [assignments],
  );

  if (!me) return null;
  if (loading) return <AdminSkeleton />;
  const refresh = () => load();

  return (
    <div>
      <div className="mb-4 flex flex-wrap gap-1 border-b-2 border-gray-200">
        {(
          [
            ["new", "➕ New Task"],
            ["review", "🔎 Review"],
            ["tasks", "📋 All Tasks"],
            ["cities", "🏙️ Cities"],
            ["users", "👤 Users"],
            ["signups", "🆕 Signups"],
          ] as [Tab, string][]
        ).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`rounded-t-lg px-3.5 py-2 text-sm font-semibold ${
              tab === key ? "text-brand-700 shadow-[inset_0_-2px_0_#a92425]" : "text-gray-500"
            }`}
          >
            {label}
            {key === "review" && reviewQueue.length > 0 && (
              <span className="ml-1 rounded-full bg-red-600 px-2 text-xs text-white">
                {reviewQueue.length}
              </span>
            )}
            {key === "signups" && signups.length > 0 && (
              <span className="ml-1 rounded-full bg-red-600 px-2 text-xs text-white">
                {signups.length}
              </span>
            )}
          </button>
        ))}
      </div>

      {tab === "new" && <NewTask me={me} cities={cities} onCreated={refresh} />}
      {tab === "review" && (
        <ReviewQueue me={me} queue={reviewQueue} tasks={tasks} cities={cities} onChange={refresh} />
      )}
      {tab === "tasks" && (
        <AllTasks me={me} tasks={tasks} assignments={assignments} onChange={refresh} />
      )}
      {tab === "cities" && <Cities me={me} cities={cities} onChange={refresh} />}
      {tab === "users" && (
        <Users me={me} users={users} cities={cities} onChange={() => loadUsers(me.token)} />
      )}
      {tab === "signups" && (
        <Signups me={me} requests={signups} onChange={() => loadSignups(me.token)} />
      )}
    </div>
  );
}

/* ---------- New Task ---------- */
function NewTask({ me, cities, onCreated }: { me: SessionUser; cities: City[]; onCreated: () => void }) {
  const [title, setTitle] = useState("");
  const [desc, setDesc] = useState("");
  const [category, setCategory] = useState<Category>("attendance");
  const [due, setDue] = useState("");
  const [url, setUrl] = useState("");
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [error, setError] = useState("");
  const [doneMsg, setDoneMsg] = useState("");
  const [waLink, setWaLink] = useState("");
  const [busy, setBusy] = useState(false);

  const active = cities.filter((c) => c.active);

  function toggleAll() {
    setSelected(selected.size < active.length ? new Set(active.map((c) => c.id)) : new Set());
  }
  function toggle(id: number) {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setSelected(next);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (selected.size === 0) {
      setError("Select at least one city.");
      return;
    }
    setBusy(true);
    try {
      await rpc("atfal_create_task", {
        p_token: me.token,
        p_title: title,
        p_description: desc || null,
        p_category: category,
        p_due_date: due || null,
        p_attachment_url: url || "",
        p_city_ids: [...selected],
      });
      const names = active.filter((c) => selected.has(c.id)).map((c) => c.name);
      const cityTxt = names.length > 5 ? `${names.length} cities` : names.join(", ");
      setDoneMsg(`✔ Task created and assigned to ${cityTxt}.`);
      toast.success("Task created.");
      setWaLink(
        waShareUrl(
          `📋 *New Atfal Task*\n${title}\nCategory: ${CATEGORY_LABEL[category]}` +
            (due ? `\nDue: ${fmtDate(due)}` : "") +
            `\nCities: ${cityTxt}\n\nUpdate status here: ${window.location.origin}/city`,
        ),
      );
      setTitle("");
      setDesc("");
      setDue("");
      setUrl("");
      setSelected(new Set());
      onCreated();
    } catch (ex) {
      setError((ex as Error).message);
    }
    setBusy(false);
  }

  return (
    <div className="card max-w-2xl">
      <form onSubmit={submit}>
        <label className="label">Title *</label>
        <input
          className="input"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
          placeholder="e.g. Submit August attendance sheet"
        />
        <label className="label">Description (Urdu is fine)</label>
        <textarea
          className="input min-h-20"
          value={desc}
          onChange={(e) => setDesc(e.target.value)}
          placeholder="Details, instructions…"
        />
        <div className="flex gap-2.5">
          <div className="flex-1">
            <label className="label">Category *</label>
            <select
              className="input"
              value={category}
              onChange={(e) => setCategory(e.target.value as Category)}
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {CATEGORY_LABEL[c]}
                </option>
              ))}
            </select>
          </div>
          <div className="flex-1">
            <label className="label">Due date</label>
            <input type="date" className="input" value={due} onChange={(e) => setDue(e.target.value)} />
          </div>
        </div>
        <label className="label">Attachment link (Google Sheet / Form / Doc)</label>
        <input
          className="input"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="https://docs.google.com/..."
        />
        <label className="label">
          Assign to cities *{" "}
          <button
            type="button"
            onClick={toggleAll}
            className="btn btn-ghost ml-2 px-2.5 py-0.5 text-xs font-semibold"
          >
            Select all / none
          </button>
        </label>
        <div className="grid max-h-56 grid-cols-2 gap-1 overflow-y-auto rounded-lg border border-gray-200 p-2 sm:grid-cols-3 md:grid-cols-4">
          {active.map((c) => (
            <label key={c.id} className="flex items-center gap-1.5 text-sm font-normal">
              <input type="checkbox" checked={selected.has(c.id)} onChange={() => toggle(c.id)} />
              {c.name}
            </label>
          ))}
        </div>
        <p className="mt-2 min-h-5 text-sm text-red-600">{error}</p>
        <button className="btn" disabled={busy}>
          {busy ? "Creating…" : "Create & assign task"}
        </button>
      </form>
      {doneMsg && (
        <div className="mt-3 border-t border-gray-200 pt-3">
          <p className="text-sm text-brand-700">{doneMsg}</p>
          <a
            href={waLink}
            target="_blank"
            rel="noopener noreferrer"
            className="btn mt-2 inline-block bg-[#25D366] hover:bg-[#1faa53]"
          >
            📲 Share to WhatsApp
          </a>
        </div>
      )}
    </div>
  );
}

/* ---------- Review Queue ---------- */
function ReviewQueue({
  me,
  queue,
  tasks,
  cities,
  onChange,
}: {
  me: SessionUser;
  queue: Assignment[];
  tasks: Task[];
  cities: City[];
  onChange: () => void;
}) {
  const taskById = new Map(tasks.map((t) => [t.id, t]));
  const cityById = new Map(cities.map((c) => [c.id, c]));
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [busyId, setBusyId] = useState<string | null>(null);

  async function review(id: string, status: "approved" | "returned") {
    const note = notes[id] ?? "";
    if (status === "returned" && !note) {
      toast.error("Add a review note so the city knows what to fix.");
      return;
    }
    setBusyId(id);
    try {
      await rpc("atfal_update_status", {
        p_token: me.token,
        p_assignment_id: id,
        p_status: status,
        p_review_note: note || null,
      });
      onChange();
      toast.success(status === "approved" ? "Submission approved." : "Sent back to city.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusyId(null);
  }

  if (queue.length === 0)
    return <div className="card text-sm text-gray-500">No submissions waiting for review.</div>;

  return (
    <div>
      {queue.map((a) => {
        const t = taskById.get(a.task_id);
        const c = cityById.get(a.city_id);
        return (
          <div key={a.id} className="card mb-3">
            <h3 className="font-semibold">
              {t?.title ?? "?"} — <span className="text-brand-700">{c?.name ?? "?"}</span>
            </h3>
            <div className="my-1.5 flex flex-wrap items-center gap-2">
              {t && <CategoryChip category={t.category} />}
              <StatusChip status={a.status} />
              <span className="text-xs text-gray-400">
                Submitted: {a.submitted_at ? fmtTime(a.submitted_at) : "—"}
              </span>
            </div>
            {a.note && (
              <p className="text-sm text-gray-600">
                <b>Note:</b> {a.note}
              </p>
            )}
            {a.proof_url ? (
              <p className="mt-1 text-sm">
                <a
                  className="text-brand-700 underline"
                  href={a.proof_url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  🔗 Open proof
                </a>
              </p>
            ) : (
              <p className="mt-1 text-xs text-gray-400">No proof link attached.</p>
            )}
            <label className="label">Review note (required if returning)</label>
            <input
              className="input"
              placeholder="Feedback for the city head…"
              value={notes[a.id] ?? ""}
              onChange={(e) => setNotes({ ...notes, [a.id]: e.target.value })}
            />
            <div className="mt-2.5 flex gap-2">
              <button className="btn" onClick={() => review(a.id, "approved")} disabled={busyId === a.id}>
                {busyId === a.id ? <span className="spinner" /> : "✅"} Approve
              </button>
              <button
                className="btn btn-danger"
                onClick={() => review(a.id, "returned")}
                disabled={busyId === a.id}
              >
                {busyId === a.id ? <span className="spinner" /> : "↩"} Return
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ---------- All Tasks ---------- */
function AllTasks({
  me,
  tasks,
  assignments,
  onChange,
}: {
  me: SessionUser;
  tasks: Task[];
  assignments: Assignment[];
  onChange: () => void;
}) {
  const counts = useMemo(() => {
    const m = new Map<string, { total: number; approved: number; submitted: number }>();
    for (const a of assignments) {
      const c = m.get(a.task_id) ?? { total: 0, approved: 0, submitted: 0 };
      c.total++;
      if (a.status === "approved") c.approved++;
      if (a.status === "submitted") c.submitted++;
      m.set(a.task_id, c);
    }
    return m;
  }, [assignments]);

  const [busyId, setBusyId] = useState<string | null>(null);

  async function archive(id: string, archived: boolean) {
    setBusyId(id);
    try {
      await rpc("atfal_archive_task", { p_token: me.token, p_task_id: id, p_archived: archived });
      onChange();
      toast.success(archived ? "Task archived." : "Task unarchived.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusyId(null);
  }
  async function remove(id: string) {
    if (!confirm("Delete this task for ALL cities? This cannot be undone. (Archiving is usually better.)"))
      return;
    setBusyId(id);
    try {
      await rpc("atfal_delete_task", { p_token: me.token, p_task_id: id });
      onChange();
      toast.success("Task deleted.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusyId(null);
  }

  return (
    <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-gray-50 text-left text-xs text-gray-500">
            <th className="p-2">Task</th>
            <th className="p-2">Category</th>
            <th className="p-2">Due</th>
            <th className="p-2">Progress</th>
            <th className="p-2">Waiting</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {tasks.map((t) => {
            const c = counts.get(t.id) ?? { total: 0, approved: 0, submitted: 0 };
            return (
              <tr key={t.id} className={`border-t border-gray-100 ${t.archived ? "opacity-50" : ""}`}>
                <td className="p-2 font-semibold">
                  {t.title}
                  {t.archived ? " (archived)" : ""}
                </td>
                <td className="p-2 whitespace-nowrap">{CATEGORY_LABEL[t.category]}</td>
                <td className="p-2 whitespace-nowrap">{fmtDate(t.due_date)}</td>
                <td className="p-2 whitespace-nowrap">
                  {c.approved}/{c.total} approved
                </td>
                <td className="p-2">
                  {c.submitted > 0 ? (
                    <span className="rounded-full bg-amber-50 px-2 py-0.5 text-xs font-semibold text-amber-700">
                      {c.submitted} to review
                    </span>
                  ) : (
                    "—"
                  )}
                </td>
                <td className="p-2 text-right whitespace-nowrap">
                  <button
                    className="btn btn-ghost mr-1 px-2.5 py-1 text-xs"
                    onClick={() => archive(t.id, !t.archived)}
                    disabled={busyId === t.id}
                  >
                    {t.archived ? "Unarchive" : "Archive"}
                  </button>
                  <button
                    className="btn btn-danger px-2.5 py-1 text-xs"
                    onClick={() => remove(t.id)}
                    disabled={busyId === t.id}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            );
          })}
          {tasks.length === 0 && (
            <tr>
              <td className="p-3 text-gray-400" colSpan={6}>
                No tasks yet.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

/* ---------- Cities ---------- */
function Cities({ me, cities, onChange }: { me: SessionUser; cities: City[]; onChange: () => void }) {
  const [name, setName] = useState("");
  const [region, setRegion] = useState("");

  const [busy, setBusy] = useState(false);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      await rpc("atfal_create_city", { p_token: me.token, p_name: name, p_region: region || null });
      setName("");
      setRegion("");
      onChange();
      toast.success(`City "${name}" added.`);
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusy(false);
  }
  async function setActive(id: number, active: boolean) {
    try {
      await rpc("atfal_set_city_active", { p_token: me.token, p_city_id: id, p_active: active });
      onChange();
      toast.success(active ? "City activated." : "City deactivated.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
  }

  return (
    <div>
      <form onSubmit={add} className="card mb-3 flex max-w-lg items-end gap-2.5">
        <div className="flex-1">
          <label className="label">New city name</label>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>
        <div className="flex-1">
          <label className="label">Region</label>
          <input
            className="input"
            value={region}
            onChange={(e) => setRegion(e.target.value)}
            placeholder="Punjab"
          />
        </div>
        <button className="btn" disabled={busy}>
          {busy ? <span className="spinner" /> : null} Add
        </button>
      </form>
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 text-left text-xs text-gray-500">
              <th className="p-2">City</th>
              <th className="p-2">Region</th>
              <th className="p-2">Status</th>
              <th className="p-2"></th>
            </tr>
          </thead>
          <tbody>
            {cities.map((c) => (
              <tr key={c.id} className={`border-t border-gray-100 ${c.active ? "" : "opacity-50"}`}>
                <td className="p-2 font-semibold">{c.name}</td>
                <td className="p-2">{c.region ?? "—"}</td>
                <td className="p-2">{c.active ? "Active" : "Inactive"}</td>
                <td className="p-2 text-right">
                  <button
                    className="btn btn-ghost px-2.5 py-1 text-xs"
                    onClick={() => setActive(c.id, !c.active)}
                  >
                    {c.active ? "Deactivate" : "Activate"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/* ---------- Users ---------- */
function Users({
  me,
  users,
  cities,
  onChange,
}: {
  me: SessionUser;
  users: UserRow[];
  cities: City[];
  onChange: () => void;
}) {
  const [username, setUsername] = useState("");
  const [display, setDisplay] = useState("");
  const [role, setRole] = useState<"city_head" | "admin">("city_head");
  const [cityId, setCityId] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [rowBusyId, setRowBusyId] = useState<string | null>(null);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (role === "city_head" && !cityId) {
      setError("City heads need a city.");
      return;
    }
    setBusy(true);
    try {
      await rpc("atfal_create_user", {
        p_token: me.token,
        p_username: username,
        p_password: password,
        p_display_name: display,
        p_role: role,
        p_city_id: cityId ? Number(cityId) : null,
      });
      setUsername("");
      setDisplay("");
      setPassword("");
      setCityId("");
      onChange();
      toast.success("User created.");
    } catch (ex) {
      setError((ex as Error).message);
    }
    setBusy(false);
  }
  async function resetPw(id: string, uname: string) {
    const pw = prompt(`New password for "${uname}" (min 6 chars):`);
    if (!pw) return;
    setRowBusyId(id);
    try {
      await rpc("atfal_reset_password", { p_token: me.token, p_user_id: id, p_new_password: pw });
      toast.success(`Password updated for ${uname}.`);
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setRowBusyId(null);
  }
  async function setActive(id: string, active: boolean) {
    setRowBusyId(id);
    try {
      await rpc("atfal_set_user_active", { p_token: me.token, p_user_id: id, p_active: active });
      onChange();
      toast.success(active ? "User enabled." : "User disabled.");
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setRowBusyId(null);
  }

  return (
    <div>
      <form onSubmit={add} className="card mb-3 max-w-2xl">
        <div className="flex gap-2.5">
          <div className="flex-1">
            <label className="label">Username</label>
            <input
              className="input"
              autoCapitalize="none"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
          </div>
          <div className="flex-1">
            <label className="label">Display name</label>
            <input
              className="input"
              value={display}
              onChange={(e) => setDisplay(e.target.value)}
              required
            />
          </div>
        </div>
        <div className="flex gap-2.5">
          <div className="flex-1">
            <label className="label">Role</label>
            <select
              className="input"
              value={role}
              onChange={(e) => setRole(e.target.value as "city_head" | "admin")}
            >
              <option value="city_head">City Head</option>
              <option value="admin">Admin</option>
            </select>
          </div>
          <div className="flex-1">
            <label className="label">City (for city heads)</label>
            <select className="input" value={cityId} onChange={(e) => setCityId(e.target.value)}>
              <option value="">—</option>
              {cities
                .filter((c) => c.active)
                .map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
            </select>
          </div>
        </div>
        <label className="label">Password (min 6 chars)</label>
        <input
          className="input"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={6}
        />
        <p className="mt-2 min-h-5 text-sm text-red-600">{error}</p>
        <button className="btn" disabled={busy}>
          {busy ? <span className="spinner" /> : null} Create user
        </button>
      </form>

      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 text-left text-xs text-gray-500">
              <th className="p-2">Username</th>
              <th className="p-2">Name</th>
              <th className="p-2">Contact</th>
              <th className="p-2">Role</th>
              <th className="p-2">City</th>
              <th className="p-2">Status</th>
              <th className="p-2"></th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id} className={`border-t border-gray-100 ${u.active ? "" : "opacity-50"}`}>
                <td className="p-2 font-semibold">{u.username}</td>
                <td className="p-2">{u.display_name}</td>
                <td className="p-2 text-xs text-gray-500">{u.contact_no ?? "—"}</td>
                <td className="p-2">{u.role === "admin" ? "Admin" : "City Head"}</td>
                <td className="p-2">{u.city_name ?? "—"}</td>
                <td className="p-2">{u.active ? "Active" : "Disabled"}</td>
                <td className="p-2 text-right whitespace-nowrap">
                  <button
                    className="btn btn-ghost mr-1 px-2.5 py-1 text-xs"
                    onClick={() => resetPw(u.id, u.username)}
                    disabled={rowBusyId === u.id}
                  >
                    Reset password
                  </button>
                  <button
                    className="btn btn-ghost px-2.5 py-1 text-xs"
                    onClick={() => setActive(u.id, !u.active)}
                    disabled={rowBusyId === u.id}
                  >
                    {u.active ? "Disable" : "Enable"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/* ---------- Signups ---------- */
function Signups({
  me,
  requests,
  onChange,
}: {
  me: SessionUser;
  requests: SignupRequest[];
  onChange: () => void;
}) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [notes, setNotes] = useState<Record<string, string>>({});

  async function approve(r: SignupRequest) {
    setBusyId(r.id);
    try {
      await rpc("atfal_approve_signup", { p_token: me.token, p_request_id: r.id });
      onChange();
      toast.success(`${r.full_name} approved — an email is on its way.`);
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusyId(null);
  }

  async function reject(r: SignupRequest) {
    setBusyId(r.id);
    try {
      await rpc("atfal_reject_signup", {
        p_token: me.token,
        p_request_id: r.id,
        p_review_note: notes[r.id] || null,
      });
      onChange();
      toast.success(`${r.full_name}'s request was rejected.`);
    } catch (ex) {
      toast.error((ex as Error).message);
    }
    setBusyId(null);
  }

  if (requests.length === 0)
    return <div className="card text-sm text-gray-500">No signup requests waiting for review.</div>;

  return (
    <div>
      {requests.map((r) => (
        <div key={r.id} className="card mb-3">
          <h3 className="font-semibold">
            {r.full_name} — <span className="text-brand-700">{r.city_name}</span>
          </h3>
          <div className="mt-1 text-sm text-gray-600">
            {r.email} · {r.contact_no}
          </div>
          <div className="mt-1 text-xs text-gray-400">Requested {fmtTime(r.created_at)}</div>
          <label className="label">Rejection note (optional)</label>
          <input
            className="input"
            placeholder="Reason, if rejecting…"
            value={notes[r.id] ?? ""}
            onChange={(e) => setNotes({ ...notes, [r.id]: e.target.value })}
          />
          <div className="mt-2.5 flex gap-2">
            <button className="btn" onClick={() => approve(r)} disabled={busyId === r.id}>
              {busyId === r.id ? <span className="spinner" /> : "✅"} Approve
            </button>
            <button className="btn btn-danger" onClick={() => reject(r)} disabled={busyId === r.id}>
              {busyId === r.id ? <span className="spinner" /> : "✕"} Reject
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

/* ---------- Loading skeleton ---------- */
function AdminSkeleton() {
  return (
    <div className="animate-fade-up">
      <div className="mb-4 flex gap-1">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="skeleton h-8 w-24" />
        ))}
      </div>
      <div className="skeleton h-72 w-full max-w-2xl rounded-xl" />
    </div>
  );
}
