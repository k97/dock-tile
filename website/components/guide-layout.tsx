"use client";

import * as React from "react";
import { DownloadActionButton } from "@/components/action-button";
import Image from "next/image";
import { useLocale } from "@/components/locale-provider";
import type { DownloadLocation } from "@/lib/analytics";
import { asset } from "@/lib/assets";
import { siteConfig } from "@/lib/config";

export type GuideItem = { id: string; title: string };

/** A heading's text as an anchor id: "Disclaimer of Warranties" → "disclaimer-of-warranties". */
export const slugify = (text: string) =>
  text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");

/** The section the reader is in: the last one whose top has passed 30% of the viewport. */
function useActiveSection(ids: readonly string[]) {
  const [active, setActive] = React.useState(ids[0]);
  const key = ids.join(" ");
  React.useEffect(() => {
    const els = key
      .split(" ")
      .map((id) => document.getElementById(id))
      .filter((el): el is HTMLElement => !!el);
    // A scroll listener, not an IntersectionObserver: a jump (a contents link, an instant scroll)
    // carries a heading past any observed line without the observer firing.
    let frame = 0;
    const update = () => {
      frame = 0;
      const passed = els.filter((el) => el.getBoundingClientRect().top < window.innerHeight * 0.3);
      setActive((passed.at(-1) ?? els[0])?.id);
    };
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      cancelAnimationFrame(frame);
    };
  }, [key]);
  return active;
}

/**
 * The subpages' reading layout (owner, 2026-11-24, first on /dock-lock): from lg up, a sticky
 * "On this page" list that follows the scroll and a small Download card beside the content; below
 * lg the content simply follows the header. Each item's `id` must be on a heading in `children`
 * that carries `scroll-mt-28` (the nav pill covers the top of the viewport).
 */
export function GuideLayout({
  items,
  location,
  children,
}: {
  items: readonly GuideItem[];
  /** The Download card's analytics location */
  location: DownloadLocation;
  children: React.ReactNode;
}) {
  const { content } = useLocale();
  const m = content.marketing;
  const active = useActiveSection(items.map((i) => i.id));

  return (
    <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6 md:px-10 md:py-24 lg:grid lg:grid-cols-[12rem_minmax(0,1fr)] lg:gap-16">
      <aside className="hidden lg:block">
        <div className="sticky top-28 flex flex-col gap-8">
          <nav aria-label={m.onThisPage}>
            <p className="mb-3 text-xs font-semibold tracking-[0.08em] text-muted-foreground uppercase">{m.onThisPage}</p>
            <ul className="flex flex-col border-l border-border">
              {items.map(({ id, title }) => (
                <li key={id}>
                  <a
                    href={`#${id}`}
                    aria-current={active === id ? "location" : undefined}
                    className={`-ml-px block border-l py-1.5 pl-4 text-[14px] leading-snug transition-colors ${active === id ? "border-foreground font-medium text-foreground" : "border-transparent text-muted-foreground hover:text-foreground"}`}
                  >
                    {title}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
          <div className="flex flex-col items-start gap-3 rounded-2xl border border-border bg-card p-4">
            <div className="flex items-center gap-2">
              {/* the nav pill's mark (already loaded), not a tile: this card is the app, on every page */}
              <Image src={asset("/assets/dock-tile-icon-only.svg")} alt="" width={24} height={24} unoptimized className="h-6 w-6" />
              <span className="text-[15px] font-semibold text-foreground">{siteConfig.appName}</span>
            </div>
            <DownloadActionButton tone="adaptive" location={location} size="sm" label={m.footerDownload} />
            <p className="text-xs text-muted-foreground">{m.ctaMetaOpenSource}</p>
          </div>
        </div>
      </aside>
      <div className="mx-auto max-w-3xl min-w-0 lg:mx-0">{children}</div>
    </div>
  );
}
