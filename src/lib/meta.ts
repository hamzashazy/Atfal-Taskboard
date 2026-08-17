import type { Category, Status, Task } from "./types";

export const STATUS_LABEL: Record<Status, string> = {
  pending: "Pending",
  in_progress: "In Progress",
  submitted: "Submitted",
  approved: "Approved",
  returned: "Returned",
};

export const CATEGORY_LABEL: Record<Category, string> = {
  attendance: "📋 Attendance",
  finance: "💰 Finance",
  inventory: "📦 Inventory",
  announcement: "📢 Announcement",
  poc_data: "👥 POC / Data",
  other: "📝 Other",
};

export const CATEGORIES = Object.keys(CATEGORY_LABEL) as Category[];

export function fmtDate(d: string | null): string {
  if (!d) return "—";
  return new Date(d.length === 10 ? d + "T00:00:00" : d).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

export function fmtTime(d: string): string {
  return new Date(d).toLocaleString("en-GB", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function isOverdue(task: Pick<Task, "due_date">, status: Status): boolean {
  return (
    !!task.due_date &&
    !["approved", "submitted"].includes(status) &&
    new Date(task.due_date + "T23:59:59") < new Date()
  );
}
