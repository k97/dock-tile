// Which nav/footer link is "current" — one rule for both, so they never disagree.
//
// Route links are current on their own route (or a sub-route). Section links
// (the homepage's Features) are current on "/" while their section is on screen;
// `usePathname()` never includes the #hash, so a "/#features" href can't be
// matched as a route — it needs the section the header's scroll sampling reports.

export type NavLink = {
  label: string;
  href: string;
  /** `data-nav-section` value of the homepage section this link scrolls to. */
  section?: string;
};

export const NAV_LINKS: readonly NavLink[] = [
  { label: "Features", href: "/#features", section: "features" },
  { label: "Privacy", href: "/privacy" },
  { label: "FAQ", href: "/faq" },
];

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
  if (link.section) return pathname === "/" && activeSection === link.section ? "location" : undefined;
  return isActiveRoute(pathname, link.href) ? "page" : undefined;
}
