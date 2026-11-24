// Which nav/footer link is "current" — one rule for both, so they never disagree.
//
// Route links are current on their own route (or a sub-route). Section links
// (the homepage's Features) are current on the locale's home while their section is
// on screen; `usePathname()` never includes the #hash, so a "/#features" href can't be
// matched as a route — it needs the section the header's scroll sampling reports.
import type { Locale } from "@/lib/i18n";

export type NavLink = {
  label: string;
  href: string;
  /** `data-nav-section` value of the homepage section this link scrolls to. */
  section?: string;
};

/** The Chinese test (/zh-Hans, /zh-Hans/faq, /zh-Hans/dock-lock) is the only locale with its own routes. */
const ZH_PREFIX = "/zh-Hans";

/** The route's own locale, or null where the browser decides (every English page). */
export function localeForPath(pathname: string): Locale | null {
  return isActiveRoute(pathname, ZH_PREFIX) ? "zh-Hans" : null;
}

/** A page's path in a locale: "/faq" → "/zh-Hans/faq", "/#features" → "/zh-Hans#features".
 *  Only the pages in ZH_PAGES (and "/") have Chinese versions; pass anything else unchanged. */
export function localePath(locale: Locale, path: string): string {
  if (locale !== "zh-Hans") return path;
  return path === "/" ? ZH_PREFIX : ZH_PREFIX + (path.startsWith("/#") ? path.slice(1) : path);
}

/** The pages besides "/" that exist in both languages. */
const ZH_PAGES = ["/faq", "/dock-lock"];

/** The same page in the other language: a page with a Chinese version maps to it, anything else to
 *  that language's home (the footer's language link). */
export function otherLanguagePath(pathname: string): string {
  const zh = localeForPath(pathname) === "zh-Hans";
  const english = zh ? pathname.slice(ZH_PREFIX.length) || "/" : pathname;
  return localePath(zh ? "en-AU" : "zh-Hans", ZH_PAGES.includes(english) ? english : "/");
}

/** hreflang alternates for a page that exists in both languages ("/" or one of ZH_PAGES). */
export function languageAlternates(path: string) {
  return { en: path, "zh-Hans": localePath("zh-Hans", path), "x-default": path };
}

/** The nav pill's links, in the page's language and pointing at its pages. */
export function navLinks(locale: Locale, labels: { features: string; dockLock: string; faq: string }): NavLink[] {
  return [
    { label: labels.features, href: localePath(locale, "/#features"), section: "features" },
    { label: labels.dockLock, href: localePath(locale, "/dock-lock") },
    { label: labels.faq, href: localePath(locale, "/faq") },
  ];
}

/** Exact route, or a sub-route after a "/" — never a lookalike ("/privacy-old"). */
export function isActiveRoute(pathname: string, href: string): boolean {
  return pathname === href || pathname.startsWith(`${href}/`);
}

/** The aria-current value for a link, or undefined when it isn't current. */
export function currentFor(
  link: NavLink,
  pathname: string,
  activeSection: string | null,
): "page" | "location" | undefined {
  if (link.section) {
    const home = localePath(localeForPath(pathname) ?? "en-AU", "/");
    return pathname === home && activeSection === link.section ? "location" : undefined;
  }
  return isActiveRoute(pathname, link.href) ? "page" : undefined;
}
