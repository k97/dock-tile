"use client";

import * as React from "react";
import { Sun, Monitor, Moon } from "lucide-react";
import { useTheme } from "next-themes";
import { cn } from "@/lib/utils";
import { trackThemeChange } from "@/lib/analytics";

type Theme = "light" | "system" | "dark";

export function ThemeSwitcher() {
  // next-themes seeds `theme` from localStorage during the FIRST client render,
  // while the server rendered it undefined — so keying the active highlight off
  // `theme` directly is a hydration mismatch. Which theme is *selected* (notably
  // "system") is never written to <html>, so unlike the rest of the site this
  // can't be themed in CSS; the highlight has to wait for mount. The icons do
  // not — rendering them eagerly is what keeps the old empty-circles placeholder
  // from popping into icons on every load.
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);
  const active = mounted ? theme : undefined;

  const themes: { value: Theme; icon: React.ReactNode; label: string }[] = [
    { value: "light", icon: <Sun className="h-4 w-4" />, label: "Light" },
    { value: "system", icon: <Monitor className="h-4 w-4" />, label: "System" },
    { value: "dark", icon: <Moon className="h-4 w-4" />, label: "Dark" },
  ];

  return (
    <div className="flex items-center gap-0.5 p-1 rounded-full bg-muted/50 border border-border/50">
      {themes.map(({ value, icon, label }) => (
        <button
          key={value}
          onClick={() => {
            setTheme(value);
            trackThemeChange(value);
          }}
          className={cn(
            "flex items-center justify-center w-7 h-7 rounded-full transition-all duration-200",
            active === value
              ? "bg-background shadow-sm text-foreground"
              : "text-muted-foreground hover:text-foreground"
          )}
          aria-label={label}
        >
          {icon}
        </button>
      ))}
    </div>
  );
}
