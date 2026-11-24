import { Lock, LockOpen } from "lucide-react";
import { ScaleToFit } from "@/components/scale-to-fit";

/* Dock Lock: two displays; the Dock (pill) roams between them (blue,
   unlocked), then locks onto the anchor and turns green. Fixed 330×170 px
   so the pill's 25% / 75% keyframe positions land on each screen's centre.
   Base classes are the locked resting state (reduced motion).
   Its own file so the /dock-lock page doesn't pull in home-sections.tsx. */
export function DockLockMock({ dark = false }: { dark?: boolean }) {
  return (
    // `dark`: on an always-dark band, a near-black well instead of the muted one.
    <div className={dark ? "rounded-2xl border border-white/5 bg-zinc-950 p-8" : "rounded-2xl bg-muted p-5"}>
      <ScaleToFit>
        <div className="relative grid h-42.5 w-82.5 grid-cols-2 items-center">
          <div className="px-3">
            <div className="h-32 rounded-lg border border-white/10 bg-zinc-900" />
          </div>
          <div className="px-3">
            <div className="dock-lock-anchor h-32 rounded-lg border border-emerald-400/30 bg-zinc-900" />
          </div>
          <span className="dock-lock-pill absolute bottom-9.25 left-[calc(75%-40px)] flex h-6 w-20 items-center justify-center rounded-full border border-emerald-400/60 bg-emerald-400/25 shadow-[0_0_14px_rgba(52,211,153,0.45)]">
            <LockOpen className="dock-lock-open h-3.5 w-3.5 text-sky-300" />
            <Lock className="dock-lock-closed absolute h-3.5 w-3.5 text-emerald-300" />
          </span>
        </div>
      </ScaleToFit>
    </div>
  );
}
