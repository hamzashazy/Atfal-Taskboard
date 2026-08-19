"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { StatusChip } from "@/components/Chips";
import { CATEGORIES, CATEGORY_LABEL, STATUS_LABEL, fmtDate, fmtTime, isOverdue } from "@/lib/meta";
import { Session } from "@/lib/session";
import { sb } from "@/lib/supabase";
import type { Activity, Assignment, Category, City, Status, Task } from "@/lib/types";

const CELL: Record<Status, { letter: string; cls: string }> = {
  pending: { letter: "P", cls: "bg-gray-100 text-gray-500" },
  in_progress: { letter: "I", cls: "bg-blue-50 text-blue-700" },
  submitted: { letter: "S", cls: "bg-amber-50 text-amber-700" },
  approved: { letter: "A", cls: "bg-brand-50 text-brand-700" },
  returned: { letter: "R", cls: "bg-red-50 text-red-700" },
};

export default function DashboardPage() {
  const [cities, setCities] = useState<City[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [activity, setActivity] = useState<Activity[]>([]);
  const [category, setCategory] = useState<"" | Category>("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [authChecked, setAuthChecked] = useState(false);

  useEffect(() => {
    if (!Session.get()) {
      window.location.href = "/login";
      return;
    }
    setAuthChecked(true);
  }, []);

  const load = useCallback(async () => {
    setRefreshing(true);
    const [c, t, a, act] = await Promise.all([
      sb.from("atfal_cities").select("*").eq("active", true).order("name"),
      sb.from("atfal_tasks").select("*").eq("archived", false).order("created_at", { ascending: false }),
      sb.from("atfal_assignments").select("*"),
      sb.from("atfal_activity").select("*").order("created_at", { ascending: false }).limit(20),
    ]);
    const err = c.error ?? t.error ?? a.error ?? act.error;
    if (err) {
      setError(err.message);
      setLoading(false);
      setRefreshing(false);
      return;
    }
    setCities(c.data as City[]);
    setTasks(t.data as Task[]);
    setAssignments(a.data as Assignment[]);
    setActivity(act.data as Activity[]);
    setError("");
    setLoading(false);
    setRefreshing(false);
  }, []);

  useEffect(() => {
    if (!authChecked) return;
    load();
    const iv = setInterval(load, 5 * 60 * 1000);
    return () => clearInterval(iv);
  }, [authChecked, load]);

  const visibleTasks = useMemo(
    () => (category ? tasks.filter((t) => t.category === category) : tasks),
    [tasks, category],
  );

  const model = useMemo(() => {
    const taskById = new Map(tasks.map((t) => [t.id, t]));
    const taskIds = new Set(visibleTasks.map((t) => t.id));
    const asg = assignments.filter((a) => taskIds.has(a.task_id));
    const approved = asg.filter((a) => a.status === "approved").length;
    const submitted = asg.filter((a) => a.status === "submitted").length;
    const overdue = asg.filter((a) => {
      const t = taskById.get(a.task_id);
      return t && isOverdue(t, a.status);
    }).length;

    const board = cities
      .map((c) => {
        const mine = asg.filter((a) => a.city_id === c.id);
        const done = mine.filter((a) => a.status === "approved").length;
        const od = mine.filter((a) => {
          const t = taskById.get(a.task_id);
          return t && isOverdue(t, a.status);
        }).length;
        return { city: c, total: mine.length, done, od, pct: mine.length ? done / mine.length : 0 };
      })
      .sort((x, y) => y.pct - x.pct || x.od - y.od || x.city.name.localeCompare(y.city.name));

    const byKey = new Map(asg.map((a) => [`${a.task_id}|${a.city_id}`, a]));
    return {
      taskById,
      asgById: new Map(assignments.map((a) => [a.id, a])),
      cityById: new Map(cities.map((c) => [c.id, c])),
      byKey,
      totals: { approved, submitted, overdue, count: asg.length },
      board,
    };
  }, [cities, tasks, visibleTasks, assignments]);

  const pct = model.totals.count ? Math.round((model.totals.approved / model.totals.count) * 100) : 0;

  if (!authChecked || loading) return <DashboardSkeleton />;

  return (
    <div>
      {error && (
        <p className="card mb-3 flex items-center justify-between text-sm text-red-600">
          <span>⚠️ Failed to load: {error}</span>
          <button className="btn btn-ghost px-2.5 py-1 text-xs" onClick={load}>
            Retry
          </button>
        </p>
      )}

      <div className="mb-1 flex items-center justify-between">
        <h1 className="text-lg font-bold">Public Dashboard</h1>
        <button
          className="btn btn-ghost px-2.5 py-1 text-xs"
          onClick={load}
          disabled={refreshing}
          title="Refresh now"
        >
          {refreshing ? <span className="spinner" /> : "↻"} Refresh
        </button>
      </div>

      {/* stat tiles */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Tile icon="📌" big={String(visibleTasks.length)} cap="Active tasks" />
        <Tile icon="📈" big={`${pct}%`} cap="Overall completion" />
        <Tile icon="⏳" big={String(model.totals.submitted)} cap="Awaiting review" />
        <Tile icon="🚨" big={String(model.totals.overdue)} cap="Overdue" alert={model.totals.overdue > 0} />
      </div>

      {/* leaderboard */}
      <h2 className="mt-6 mb-1 font-bold">🏆 City Leaderboard</h2>
      <p className="mb-2 text-xs text-gray-500">
        Completion = approved assignments ÷ total assignments (active tasks only).
      </p>
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 text-left text-xs text-gray-500">
              <th className="p-2">#</th>
              <th className="p-2">City</th>
              <th className="p-2">Completion</th>
              <th className="p-2"></th>
              <th className="p-2">Done</th>
              <th className="p-2">Total</th>
              <th className="p-2">Overdue</th>
            </tr>
          </thead>
          <tbody>
            {model.board.map((r, i) => (
              <tr key={r.city.id} className="border-t border-gray-100">
                <td className="p-2">{i + 1}</td>
                <td className="p-2 font-semibold whitespace-nowrap">{r.city.name}</td>
                <td className="w-32 p-2">
                  <div className="h-2 min-w-[90px] overflow-hidden rounded bg-gray-100">
                    <div
                      className="h-full rounded-l bg-brand-700"
                      style={{ width: `${Math.round(r.pct * 100)}%` }}
                    />
                  </div>
                </td>
                <td className="p-2">{Math.round(r.pct * 100)}%</td>
                <td className="p-2">{r.done}</td>
                <td className="p-2">{r.total}</td>
                <td className="p-2">
                  {r.od > 0 ? (
                    <span className="rounded-full bg-red-50 px-2 py-0.5 text-xs font-semibold text-red-700">
                      {r.od}
                    </span>
                  ) : (
                    "0"
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* matrix */}
      <h2 className="mt-6 mb-2 font-bold">🗺️ Task × City Matrix</h2>
      <div className="mb-2 flex flex-wrap items-center gap-3">
        <select
          className="input w-auto"
          value={category}
          onChange={(e) => setCategory(e.target.value as "" | Category)}
        >
          <option value="">All categories</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {CATEGORY_LABEL[c]}
            </option>
          ))}
        </select>
        <div className="flex flex-wrap gap-3 text-xs text-gray-500">
          <span><b>P</b> Pending</span>
          <span><b>I</b> In Progress</span>
          <span><b>S</b> Submitted</span>
          <span><b>A</b> Approved</span>
          <span><b>R</b> Returned</span>
          <span>· Not assigned</span>
        </div>
      </div>
      <div className="max-h-[60vh] overflow-auto rounded-xl border border-gray-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs text-gray-500">
              <th className="sticky top-0 z-10 min-w-44 bg-gray-50 p-2">Task</th>
              {cities.map((c) => (
                <th key={c.id} className="sticky top-0 bg-gray-50 p-2" title={c.name}>
                  {c.name.slice(0, 3)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {visibleTasks.map((t) => (
              <tr key={t.id} className="border-t border-gray-100">
                <td className="p-2">
                  <div className="font-semibold">{t.title}</div>
                  <div className="text-xs text-gray-400">
                    {CATEGORY_LABEL[t.category]} · due {fmtDate(t.due_date)}
                  </div>
                </td>
                {cities.map((c) => {
                  const a = model.byKey.get(`${t.id}|${c.id}`);
                  if (!a)
                    return (
                      <td key={c.id} className="p-2 text-center text-gray-300">
                        ·
                      </td>
                    );
                  const cell = CELL[a.status];
                  const od = isOverdue(t, a.status);
                  return (
                    <td
                      key={c.id}
                      className="p-1 text-center"
                      title={`${c.name} — ${STATUS_LABEL[a.status]}${od ? " (overdue)" : ""}`}
                    >
                      <span
                        className={`inline-block h-6 w-6 rounded-md text-xs leading-6 font-bold ${cell.cls}`}
                      >
                        {cell.letter}
                      </span>
                    </td>
                  );
                })}
              </tr>
            ))}
            {visibleTasks.length === 0 && (
              <tr>
                <td className="p-3 text-sm text-gray-400" colSpan={cities.length + 1}>
                  No tasks yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* activity */}
      <h2 className="mt-6 mb-2 font-bold">🕐 Recent Activity</h2>
      <div className="card">
        {activity.length === 0 && <p className="text-sm text-gray-400">No activity yet.</p>}
        <ul>
          {activity.map((ev) => {
            const a = ev.assignment_id ? model.asgById.get(ev.assignment_id) : undefined;
            const t = a ? model.taskById.get(a.task_id) : undefined;
            const c = a ? model.cityById.get(a.city_id) : undefined;
            return (
              <li key={ev.id} className="border-b border-gray-100 py-2 text-sm last:border-0">
                <b>{ev.actor_name}</b> · {t?.title ?? ""} {c ? `(${c.name})` : ""} →{" "}
                {ev.action.startsWith("status:") ? (
                  <StatusChip status={ev.action.slice(7) as Status} />
                ) : (
                  "assigned"
                )}
                <div className="text-xs text-gray-400">
                  {fmtTime(ev.created_at)}
                  {ev.detail ? ` · ${ev.detail}` : ""}
                </div>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}

function Tile({ icon, big, cap, alert }: { icon: string; big: string; cap: string; alert?: boolean }) {
  return (
    <div className="card hover:shadow-md">
      <div className="mb-1 text-lg">{icon}</div>
      <div className={`text-3xl font-bold ${alert ? "text-red-600" : ""}`}>{big}</div>
      <div className="text-xs text-gray-500">{cap}</div>
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div className="animate-fade-up">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="card">
            <div className="skeleton mb-2 h-8 w-14" />
            <div className="skeleton h-3 w-20" />
          </div>
        ))}
      </div>
      <div className="skeleton mt-6 mb-2 h-6 w-48" />
      <div className="skeleton h-40 w-full rounded-xl" />
      <div className="skeleton mt-6 mb-2 h-6 w-56" />
      <div className="skeleton h-64 w-full rounded-xl" />
    </div>
  );
}
