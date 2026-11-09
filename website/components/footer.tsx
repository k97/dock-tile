"use client";

import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import { usePathname } from "next/navigation";
import { useLocale } from "@/components/locale-provider";
import { ThemeSwitcher } from "@/components/theme-switcher";
import { siteConfig } from "@/lib/config";
import { trackExternalLinkClick } from "@/lib/analytics";
import { withReferral } from "@/lib/referral";
import { isActiveRoute } from "@/lib/nav";
import { bugReportUrl, featureRequestUrl } from "@/lib/feedback";

const STUDIO_URL = withReferral(siteConfig.authorUrl);

// The line under every page: the studio's ©, the theme switcher, the two
// feedback links (GitHub issues) and the legal pages.
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

      <div className="order-3 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 justify-self-center text-sm md:justify-self-end">
        {/* Feedback first, then the legal pair, a hairline between the two kinds. */}
        {[
          { href: featureRequestUrl, label: content.marketing.featureRequest },
          { href: bugReportUrl, label: content.marketing.bugReport },
        ].map(({ href, label }) => (
          <a
            key={label}
            href={href}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackExternalLinkClick(href, "footer")}
            className="hit-area inline-flex items-center gap-0.5 text-muted-foreground transition-colors duration-300 hover:text-foreground"
          >
            {label}
            <ArrowUpRight aria-hidden className="h-3 w-3 opacity-60" />
            <span className="sr-only"> {content.marketing.opensInNewTab}</span>
          </a>
        ))}
        <span aria-hidden className="h-3.5 w-px bg-border" />
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
