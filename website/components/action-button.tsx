"use client";

import * as React from "react";
import { ArrowRight, Check, Download, Loader2 } from "lucide-react";
import { siteConfig } from "@/lib/config";
import { trackDownloadClick } from "@/lib/analytics";

/**
 * Signature CTA: pill with a nested circular icon. Two fixed tones —
 * "light" (white pill, dark circle) for dark sections, "dark" inverted
 * for light sections — plus "adaptive": the dark button that inverts to
 * light under the site's dark theme, purely via CSS `dark:` variants (the
 * header uses it on the light-frost pill, which the dark theme forces to
 * dark frost before first paint). Whole button scales on hover, circle
 * shifts tone.
 */
export function ActionButton({
  children,
  icon,
  tone = "light",
  size = "md",
  onClick,
  href,
  className = "",
}: {
  children: React.ReactNode;
  icon?: React.ReactNode;
  tone?: "light" | "dark" | "adaptive";
  size?: "sm" | "md" | "lg";
  onClick?: () => void;
  href?: string;
  className?: string;
}) {
  const pill =
    tone === "light"
      ? "bg-white text-zinc-900"
      : tone === "adaptive"
        ? "bg-zinc-900 text-white dark:bg-white dark:text-zinc-900"
        : "bg-zinc-900 text-white";
  const circle =
    tone === "light"
      ? "bg-zinc-900 text-white group-hover:bg-zinc-700"
      : tone === "adaptive"
        ? "bg-white text-zinc-900 group-hover:bg-zinc-200 dark:bg-zinc-900 dark:text-white dark:group-hover:bg-zinc-700"
        : "bg-white text-zinc-900 group-hover:bg-zinc-200";
  const dims =
    size === "lg"
      ? { pad: "pl-7 pr-2 py-2 gap-4", text: "text-base font-semibold", circ: "h-12 w-12" }
      : size === "sm"
        ? { pad: "pl-4 pr-1 py-1 gap-2", text: "text-[11px] font-bold uppercase tracking-widest", circ: "h-7 w-7" }
        : { pad: "pl-6 pr-1.5 py-1.5 gap-3", text: "text-sm font-semibold", circ: "h-10 w-10" };

  const content = (
    <>
      <span className={dims.text}>{children}</span>
      <span
        className={`flex ${dims.circ} items-center justify-center rounded-full transition-colors duration-300 ${circle}`}
      >
        {icon ?? <ArrowRight className="h-[45%] w-[45%]" />}
      </span>
    </>
  );
  // `transition-transform` covers `scale` in Tailwind v4, so one declaration
  // animates both the hover growth and `.pressable:active`'s 0.96 press.
  const base = `group pressable inline-flex items-center rounded-full ${dims.pad} ${pill} transition-transform duration-200 ease-(--ease-out-strong) hover:scale-105 ${className}`;

  if (href) {
    return (
      <a href={href} onClick={onClick} className={base}>
        {content}
      </a>
    );
  }
  return (
    <button type="button" onClick={onClick} className={base}>
      {content}
    </button>
  );
}

/** Download CTA with the ready → downloading → downloaded state machine. */
export function DownloadActionButton({
  tone = "light",
  size = "md",
  label,
  className = "",
}: {
  tone?: "light" | "dark" | "adaptive";
  size?: "sm" | "md" | "lg";
  label?: string;
  className?: string;
}) {
  const [state, setState] = React.useState<"ready" | "downloading" | "downloaded">(
    "ready",
  );

  const handleClick = () => {
    if (state !== "ready") return;
    trackDownloadClick();
    setState("downloading");
    window.location.href = siteConfig.downloadUrl;
    window.setTimeout(() => {
      setState("downloaded");
      window.setTimeout(() => setState("ready"), 4000);
    }, 2000);
  };

  // Every glyph stays mounted and the three cross-fade in place — scale 0.25→1,
  // opacity 0→1, blur 4px→0. Swapping by unmount gives you an enter with no
  // exit; keeping them stacked gives both, with no motion library.
  const glyphs = [
    { key: "ready", node: <Download className="h-full w-full" /> },
    { key: "downloading", node: <Loader2 className="h-full w-full animate-spin" /> },
    { key: "downloaded", node: <Check className="h-full w-full" /> },
  ] as const;

  const icon = (
    <span className="relative flex h-[45%] w-[45%] items-center justify-center">
      {glyphs.map(({ key, node }) => (
        <span
          key={key}
          aria-hidden={state !== key}
          className={`absolute inset-0 flex items-center justify-center transition-[opacity,scale,filter] duration-300 ease-[cubic-bezier(0.2,0,0,1)] ${
            state === key ? "scale-100 opacity-100 blur-none" : "scale-25 opacity-0 blur-xs"
          }`}
        >
          {node}
        </span>
      ))}
    </span>
  );

  return (
    <ActionButton
      tone={tone}
      size={size}
      icon={icon}
      onClick={handleClick}
      className={className}
    >
      {state === "downloading"
        ? "Downloading…"
        : state === "downloaded"
          ? "Downloaded"
          : (label ?? "Download for macOS")}
    </ActionButton>
  );
}
