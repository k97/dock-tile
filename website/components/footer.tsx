"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useLocale } from "@/components/locale-provider";
import { ThemeSwitcher } from "@/components/theme-switcher";
import { siteConfig } from "@/lib/config";
import { trackExternalLinkClick } from "@/lib/analytics";
import { withReferral } from "@/lib/referral";
import { isActiveRoute } from "@/lib/nav";

const STUDIO_URL = withReferral(siteConfig.authorUrl);

// The legal line under every page: the studio's ©, the theme switcher, and
// the legal pages. Everything else lives once in the page above it.
export function Footer() {
  const { content } = useLocale();
  const pathname = usePathname();
  const currentYear = new Date().getFullYear();

  return (
    <footer className="mx-auto grid max-w-[1600px] grid-cols-1 items-center justify-items-center gap-6 px-6 py-12 md:grid-cols-[1fr_auto_1fr] md:px-10">
      <p className="order-2 justify-self-center text-sm text-muted-foreground md:order-1 md:justify-self-start">
        © {currentYear}{" "}
        <a
          href={STUDIO_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="font-semibold transition-colors duration-300 hover:text-foreground"
          onClick={() => trackExternalLinkClick(STUDIO_URL, "footer")}
        >
          {siteConfig.authorName}
        </a>
      </p>

      <div className="order-1 md:order-2">
        <ThemeSwitcher />
      </div>

      <div className="order-3 flex items-center gap-6 justify-self-center text-sm md:justify-self-end">
        {[
          { href: "/privacy", label: content.privacy },
          { href: "/terms", label: content.terms },
        ].map(({ href, label }) => {
          const current = isActiveRoute(pathname, href);
          return (
            <Link
              key={href}
              href={href}
              aria-current={current ? "page" : undefined}
              className={`hit-area transition-colors duration-300 hover:text-foreground ${
                current ? "text-foreground" : "text-muted-foreground"
              }`}
            >
              {label}
            </Link>
          );
        })}
      </div>
    </footer>
  );
}
