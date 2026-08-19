import { CATEGORY_LABEL, STATUS_LABEL } from "@/lib/meta";
import type { Category, Status } from "@/lib/types";

const STATUS_STYLE: Record<Status, string> = {
  pending: "bg-gray-100 text-gray-600",
  in_progress: "bg-blue-50 text-blue-700",
  submitted: "bg-amber-50 text-amber-700",
  approved: "bg-brand-50 text-brand-700",
  returned: "bg-red-50 text-red-700",
};

export function StatusChip({ status }: { status: Status }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap ${STATUS_STYLE[status]}`}
    >
      <span className="h-2 w-2 rounded-full bg-current" />
      {STATUS_LABEL[status]}
    </span>
  );
}

export function OverdueChip() {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-red-50 px-2.5 py-0.5 text-xs font-semibold text-red-700 whitespace-nowrap">
      <span className="h-2 w-2 rounded-full bg-current" />
      Overdue
    </span>
  );
}

export function CategoryChip({ category }: { category: Category }) {
  return (
    <span className="rounded-md bg-brand-50 px-2 py-0.5 text-xs text-brand-900 whitespace-nowrap">
      {CATEGORY_LABEL[category]}
    </span>
  );
}
