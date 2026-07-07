"use client";

import * as React from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useTheme } from "next-themes";
import { Menu, X } from "lucide-react";
import { siteConfig } from "@/lib/config";
import { DownloadActionButton } from "@/components/action-button";

const navLinks = [
  { label: "Features", href: "/#features" },
  { label: "Privacy", href: "/privacy" },
  { label: "FAQ", href: "/faq" },
];

export function Header() {
  const pathname = usePathname();
  const headerRef = React.useRef<HTMLElement>(null);
  const navRef = React.useRef<HTMLElement>(null);
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);
  // Which tone of section sits behind the nav right now. Drives an inverse
  // pill: light frost over dark sections, dark frost over light ones.
  const [overDark, setOverDark] = React.useState(true);
  // Mobile only: the three text links collapse behind a hamburger so the
  // floating pill fits within the viewport with gutters instead of overflowing.
  const [menuOpen, setMenuOpen] = React.useState(false);

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

  // Route change closes the mobile menu.
  React.useEffect(() => setMenuOpen(false), [pathname]);

  // While open, dismiss on Escape, an outside tap, or a resize up to desktop
  // (where the inline nav takes over and the menu no longer exists).
  React.useEffect(() => {
    if (!menuOpen) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setMenuOpen(false);
    const onDown = (e: PointerEvent) => {
      if (!headerRef.current?.contains(e.target as Node)) setMenuOpen(false);
    };
    const onResize = () => window.innerWidth >= 768 && setMenuOpen(false);
    window.addEventListener("keydown", onKey);
    window.addEventListener("pointerdown", onDown);
    window.addEventListener("resize", onResize);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("pointerdown", onDown);
      window.removeEventListener("resize", onResize);
    };
  }, [menuOpen]);

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
  const iconBtn = pillOverDark
    ? "text-zinc-700 hover:bg-black/5 hover:text-zinc-900"
    : "text-white/85 hover:bg-white/10 hover:text-white";

  return (
    // The hero sits mt-3 (md:mt-4) off the viewport; the nav repeats that same
    // gap inside the hero, so viewport→hero and hero→nav read as one rhythm:
    // top = hero inset ×2 (12+12px, md 16+16px).
    <header ref={headerRef} className="fixed top-6 left-1/2 z-50 -translate-x-1/2 md:top-8">
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

        {/* Desktop: links inline. Hidden on mobile, where they move into the menu. */}
        {navLinks.map((link) => {
          const isActive = pathname.startsWith(link.href);
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`hidden md:block ${linkBase} ${isActive ? linkActive : linkIdle}`}
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

        {/* Mobile: hamburger toggles the links menu; hidden from md up. */}
        <button
          type="button"
          aria-label={menuOpen ? "Close menu" : "Open menu"}
          aria-expanded={menuOpen}
          aria-controls="mobile-nav-menu"
          onClick={() => setMenuOpen((o) => !o)}
          className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full transition-colors duration-300 md:hidden ${iconBtn}`}
        >
          {menuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </nav>

      {/* Mobile links menu — mirrors the pill's tone, drops in under its right edge
          (by the hamburger). Hidden from md up; instant on close, springs in on open. */}
      {menuOpen && (
        <div
          id="mobile-nav-menu"
          data-over={pillOverDark ? "dark" : "light"}
          className="glass-nav absolute top-full right-0 mt-2 flex min-w-44 flex-col gap-0.5 rounded-2xl p-1.5 [transform-origin:top_right] motion-safe:animate-[dock-scale-in_180ms_var(--ease-out-strong)] md:hidden"
        >
          {navLinks.map((link) => {
            const isActive = pathname.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setMenuOpen(false)}
                className={`block w-full rounded-xl px-3 py-2 text-left text-[13px] transition-colors duration-300 ${isActive ? linkActive : linkIdle}`}
              >
                {link.label}
              </Link>
            );
          })}
        </div>
      )}
    </header>
  );
}
