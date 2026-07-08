"use client";

import * as React from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { siteConfig } from "@/lib/config";
import { asset } from "@/lib/assets";
import { DownloadActionButton } from "@/components/action-button";

const navLinks = [
  { label: "Features", href: "/#features" },
  { label: "Privacy", href: "/privacy" },
  { label: "FAQ", href: "/faq" },
];

export function Header() {
  const pathname = usePathname();
  const navRef = React.useRef<HTMLElement>(null);
  // Arms the pill's 300ms tone cross-fade only after hydration (CSS
  // `.glass-nav[data-ready]`), so any load-time tone correction snaps into
  // place instead of visibly animating on first paint.
  const [ready, setReady] = React.useState(false);
  React.useEffect(() => setReady(true), []);
  // Which tone of section sits behind the nav right now. Drives an inverse
  // pill: light frost over dark sections, dark frost over light ones.
  const [overDark, setOverDark] = React.useState(true);

  React.useEffect(() => {
    let raf = 0;
    const sample = () => {
      raf = 0;
      const nav = navRef.current;
      if (!nav) return;
      const r = nav.getBoundingClientRect();
      // Sample the content just below the nav's centre; decorative overlays
      // are pointer-events:none so elementFromPoint returns the real section.
      const el = document.elementFromPoint(r.left + r.width / 2, r.bottom + 10);
      const toned = el?.closest<HTMLElement>("[data-nav-tone]");
      setOverDark(toned?.dataset.navTone !== "light");
    };
    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(sample);
    };
    sample();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, [pathname]);

  // The site's own dark theme takes over the pill's tone outright: a bright
  // frosted-white pill reads as "stuck in light mode" against an otherwise
  // dark page. That override is pure CSS (`.dark .glass-nav` + the `dark:`
  // variants below) keyed off the pre-paint `.dark` class — NOT React state —
  // so the first frame is already right for dark-theme visitors. Light theme
  // keeps the section-tone sampling unchanged.
  //
  // Content colours flip to stay legible on whichever pill tone is showing.
  // Logo, each link, and the download button all share this exact horizontal
  // rhythm (px-2.5 → md:px-3) so the three gaps between them — logo↔links,
  // link↔link, link↔button — resolve to the same visual distance instead of
  // stacking mismatched paddings on top of the nav's own `gap`.
  // The !overDark branch already IS the dark-pill look, so only the overDark
  // branch needs `dark:` overrides.
  const linkBase =
    "rounded-full px-2.5 py-1.5 text-center text-[13px] transition-colors duration-300 md:px-3";
  const linkIdle = overDark
    ? "text-zinc-600 hover:bg-black/5 hover:text-zinc-900 dark:text-white/80 dark:hover:bg-white/10 dark:hover:text-white"
    : "text-white/80 hover:bg-white/10 hover:text-white";
  const linkActive = overDark
    ? "bg-black/5 text-zinc-900 dark:bg-white/10 dark:text-white"
    : "bg-white/10 text-white";
  const logoHover = overDark ? "hover:bg-black/5 dark:hover:bg-white/10" : "hover:bg-white/10";
  const logoText = overDark ? "text-zinc-900 dark:text-white" : "text-white";

  return (
    // The hero sits mt-3 (md:mt-4) off the viewport; the nav repeats that same
    // gap inside the hero, so viewport→hero and hero→nav read as one rhythm:
    // top = hero inset ×2 (12+12px, md 16+16px).
    <header className="fixed top-6 left-1/2 z-50 -translate-x-1/2 md:top-8">
      <nav
        ref={navRef}
        data-over={overDark ? "dark" : "light"}
        data-ready={ready || undefined}
        className="glass-nav flex items-center gap-1 rounded-full py-1.5 pl-2 pr-2 md:pl-3 md:pr-1.5"
      >
        <Link
          href="/"
          className={`flex shrink-0 items-center gap-2 rounded-full py-1.5 pl-1 pr-2.5 transition-colors duration-300 md:pr-3 ${logoHover}`}
        >
          <Image
            src={asset("/assets/dock-tile-icon-only.svg")}
            alt={siteConfig.appName}
            width={24}
            height={24}
            unoptimized
            className="h-6 w-6 shrink-0"
          />
          {/* The wordmark stays visible on mobile too — with Download gone from
              the mobile pill there's room, and nothing else on a phone screen
              says the app's name. Only sub-360px viewports drop it, where the
              pill would otherwise touch the viewport edges. */}
          <span
            className={`hidden whitespace-nowrap text-sm font-semibold tracking-tight min-[360px]:inline ${logoText}`}
          >
            {siteConfig.appName}
          </span>
        </Link>

        {/* The three links stay inline at every width — on mobile they ARE the
            nav's content, since Download drops out (below). */}
        {navLinks.map((link) => {
          const isActive = pathname.startsWith(link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`${linkBase} ${isActive ? linkActive : linkIdle}`}
            >
              {link.label}
            </Link>
          );
        })}

        {/* Button contrasts with the pill: dark button on the light pill, light on the dark.
            ml matches the link/logo padding above so its solid pill sits the same
            visual distance from FAQ as FAQ sits from Features.
            md+ only: on a phone nobody installs a macOS app from the nav — the
            links are the contextual actions there (the hero + final CTA still
            offer Download), and the pill fits the viewport without it. */}
        <DownloadActionButton
          tone={overDark ? "adaptive" : "light"}
          size="sm"
          label="Download"
          className="max-md:hidden md:ml-3"
        />
      </nav>
    </header>
  );
}
