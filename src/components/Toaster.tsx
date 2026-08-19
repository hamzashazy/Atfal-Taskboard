"use client";

import { useEffect, useState } from "react";
import { toast, type Toast } from "@/lib/toast";

const STYLE: Record<Toast["kind"], string> = {
  success: "border-l-emerald-600 text-emerald-900",
  error: "border-l-red-600 text-red-900",
  info: "border-l-blue-600 text-blue-900",
};

const ICON: Record<Toast["kind"], string> = {
  success: "✅",
  error: "⚠️",
  info: "ℹ️",
};

export default function Toaster() {
  const [items, setItems] = useState<Toast[]>([]);

  useEffect(
    () =>
      toast.subscribe((t) => {
        setItems((cur) => [...cur, t]);
        setTimeout(() => setItems((cur) => cur.filter((x) => x.id !== t.id)), 4500);
      }),
    [],
  );

  if (items.length === 0) return null;

  return (
    <div className="fixed inset-x-0 bottom-4 z-50 flex flex-col items-center gap-2 px-4 sm:inset-x-auto sm:right-4 sm:items-end">
      {items.map((t) => (
        <div
          key={t.id}
          role="status"
          className={`animate-toast-in flex w-full max-w-sm items-start gap-2 rounded-lg border-l-4 bg-white px-3.5 py-2.5 text-sm font-medium shadow-lg ring-1 ring-black/5 ${STYLE[t.kind]}`}
        >
          <span>{ICON[t.kind]}</span>
          <span className="flex-1">{t.text}</span>
          <button
            onClick={() => setItems((cur) => cur.filter((x) => x.id !== t.id))}
            className="text-gray-400 hover:text-gray-600"
            aria-label="Dismiss"
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  );
}
