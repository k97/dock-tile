"use client";

import dynamic from "next/dynamic";

// Agentation: a dev-only toolbar for annotating the page and handing the notes to
// a coding agent. Loaded lazily and only in `next dev`, so production pages never
// fetch it. Its licence (PolyForm Shield) is a non-compete: fine for our own dev use.
const Agentation = dynamic(() => import("agentation").then((m) => m.Agentation), { ssr: false });

export function DevAgentation() {
  if (process.env.NODE_ENV !== "development") return null;
  return <Agentation />;
}
