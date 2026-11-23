"use client";

import * as React from "react";
import { Sun, Monitor, Moon } from "lucide-react";
import { useTheme } from "next-themes";
import { cn } from "@/lib/utils";
import { trackThemeChange } from "@/lib/analytics";
import { useHydrated } from "@/lib/use-client-value";

type Theme = "light" | "system" | "dark";

/** Lives on the signature-dark footer band, so it is white-on-dark in both themes. */
export function ThemeSwitcher() {
  // next-themes seeds `theme` from localStorage during the FIRST client render,
  // while the server rendered it undefined — so keying the active highlight off
  // `theme` directly is a hydration mismatch. Which theme is *selected* (notably
  // "system") is never written to <html>, so unlike the rest of the site this
  // can't be themed in CSS; the highlight has to wait for mount. The icons do
  // not — rendering them eagerly is what keeps the old empty-circles placeholder
  // from popping into icons on every load.
  const { theme, setTheme } = useTheme();
  const mounted = useHydrated();
  const active = mounted ? theme : undefined;

  const themes: { value: Theme; icon: React.ReactNode; label: string }[] = [
    { value: "light", icon: <Sun className="h-4 w-4" />, label: "Light" },
    { value: "system", icon: <Monitor className="h-4 w-4" />, label: "System" },
    { value: "dark", icon: <Moon className="h-4 w-4" />, label: "Dark" },
  ];

  return (
    <div className="flex items-center gap-0.5 p-1 rounded-full border bg-white/6 border-white/10">
      {themes.map(({ value, icon, label }) => (
        <button
          key={value}
          onClick={() => {
            setTheme(value);
            trackThemeChange(value);
          }}
          className={cn(
            // `hit-area` lifts the 28px segment to a 40px-tall target without
            // resizing the pill; the pseudo-element stays inside the segment's
            // own width so neighbouring segments never overlap.
            "hit-area flex items-center justify-center w-7 h-7 rounded-full",
            "transition-[color,background-color,box-shadow,scale] duration-200 active:scale-96",
            active === value ? "bg-white/15 shadow-sm text-white" : "text-white/55 hover:text-white"
          )}
          aria-label={label}
        >
          {icon}
        </button>
      ))}
    </div>
  );
}
