"use client";

import * as React from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useTheme } from "next-themes";
import { siteConfig } from "@/lib/config";
import { DownloadActionButton } from "@/components/action-button";

const navLinks = [
  { label: "Features", href: "/#features" },
  { label: "Privacy", href: "/privacy" },
  { label: "FAQ", href: "/faq" },
];

export function Header() {
  const pathname = usePathname();
  const navRef = React.useRef<HTMLElement>(null);
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);
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
  // frosted-white pill reading as "stuck in light mode" against an otherwise
  // dark page. Light theme keeps today's section-tone sampling unchanged.
  const isDarkSite = mounted && resolvedTheme === "dark";
  const pillOverDark = isDarkSite ? false : overDark;

  // Content colours flip to stay legible on whichever pill tone is showing.
  // Logo, each link, and the download button all share this exact horizontal
  // rhythm (px-2.5 → md:px-3) so the three gaps between them — logo↔links,
  // link↔link, link↔button — resolve to the same visual distance instead of
  // stacking mismatched paddings on top of the nav's own `gap`.
  const linkBase =
    "rounded-full px-2.5 py-1.5 text-center text-[13px] transition-colors duration-300 md:px-3";
  const linkIdle = pillOverDark
    ? "text-zinc-600 hover:bg-black/5 hover:text-zinc-900"
    : "text-white/80 hover:bg-white/10 hover:text-white";
  const linkActive = pillOverDark ? "bg-black/5 text-zinc-900" : "bg-white/10 text-white";
  const logoHover = pillOverDark ? "hover:bg-black/5" : "hover:bg-white/10";
  const logoText = pillOverDark ? "text-zinc-900" : "text-white";

  return (
    // The hero sits mt-3 (md:mt-4) off the viewport; the nav repeats that same
    // gap inside the hero, so viewport→hero and hero→nav read as one rhythm:
    // top = hero inset ×2 (12+12px, md 16+16px).
    <header className="fixed top-6 left-1/2 z-50 -translate-x-1/2 md:top-8">
      <nav
        ref={navRef}
        data-over={pillOverDark ? "dark" : "light"}
        className="glass-nav flex items-center gap-1 rounded-full py-1.5 pl-2 pr-1.5 md:pl-3"
      >
        <Link
          href="/"
          className={`flex shrink-0 items-center gap-2 rounded-full py-1.5 pl-1 pr-2.5 transition-colors duration-300 md:pr-3 ${logoHover}`}
        >
          <Image
            src="/assets/dock-tile-icon-only.svg"
            alt={siteConfig.appName}
            width={24}
            height={24}
            className="h-6 w-6 shrink-0"
          />
          <span
            className={`hidden whitespace-nowrap text-sm font-semibold tracking-tight md:inline ${logoText}`}
          >
            {siteConfig.appName}
          </span>
        </Link>

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
            visual distance from FAQ as FAQ sits from Features. */}
        <DownloadActionButton
          tone={pillOverDark ? "dark" : "light"}
          size="sm"
          label="Download"
          className="ml-2.5 md:ml-3"
        />
      </nav>
    </header>
  );
}
