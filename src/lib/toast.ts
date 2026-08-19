export type Toast = { id: number; kind: "success" | "error" | "info"; text: string };

let id = 0;
let listeners: ((t: Toast) => void)[] = [];

function push(kind: Toast["kind"], text: string) {
  const t: Toast = { id: ++id, kind, text };
  listeners.forEach((l) => l(t));
}

export const toast = {
  success: (text: string) => push("success", text),
  error: (text: string) => push("error", text),
  info: (text: string) => push("info", text),
  subscribe(fn: (t: Toast) => void) {
    listeners.push(fn);
    return () => {
      listeners = listeners.filter((l) => l !== fn);
    };
  },
};
