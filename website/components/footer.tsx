"use client";

import Link from "next/link";
import { ArrowUpRight, Heart } from "lucide-react";
import { usePathname } from "next/navigation";
import { useLocale } from "@/components/locale-provider";
import { ThemeSwitcher } from "@/components/theme-switcher";
import { HmcMark } from "@/components/hmc-mark";
import { siteConfig } from "@/lib/config";
import { trackContactClick, trackDownloadClick, trackExternalLinkClick } from "@/lib/analytics";
import { withReferral } from "@/lib/referral";
import { isActiveRoute } from "@/lib/nav";
import { bugReportUrl, featureRequestUrl } from "@/lib/feedback";

const STUDIO_URL = withReferral(siteConfig.authorUrl);

type FooterLink = {
  label: string;
  href: string;
  /** Opens in a new tab with a ↗ (a mailto link gets the ↗ too, without the new tab). */
  external?: boolean;
  onClick?: () => void;
};

const linkClass =
  "inline-flex w-fit items-center gap-1 text-[14px] transition-colors duration-300 hover:text-foreground";

// The footer under every page: the studio's mark and line, three link columns,
// then "© YYYY, Made with ♥ for macOS" and the theme switcher.
export function Footer() {
  const { content } = useLocale();
  const m = content.marketing;
  const pathname = usePathname();
  const currentYear = new Date().getFullYear();

  const columns: { title: string; links: FooterLink[] }[] = [
    {
      title: siteConfig.appName,
      links: [
        { label: m.footerFeatures, href: "/#features" },
        { label: m.footerWhatsNew, href: "/release-notes" },
        { label: m.footerFaq, href: "/faq" },
        { label: m.footerDownload, href: siteConfig.downloadUrl, onClick: trackDownloadClick },
      ],
    },
    {
      title: m.footerResources,
      links: [
        { label: m.footerGithub, href: siteConfig.githubUrl, external: true },
        { label: m.featureRequest, href: featureRequestUrl, external: true },
        { label: m.bugReport, href: bugReportUrl, external: true },
        { label: m.footerContact, href: `mailto:${siteConfig.contactEmail}`, onClick: trackContactClick },
      ],
    },
    {
      title: m.footerCompany,
      links: [
        { label: m.footerAbout, href: STUDIO_URL, external: true },
        { label: siteConfig.spadesAudioName, href: withReferral(siteConfig.spadesAudioUrl), external: true },
        { label: content.privacy, href: "/privacy" },
        { label: content.terms, href: "/terms" },
      ],
    },
  ];

  return (
    <footer className="border-t border-border/60">
      <div className="mx-auto grid max-w-270 grid-cols-2 gap-x-8 gap-y-10 px-6 pt-16 pb-12 lg:grid-cols-4">
        {/* The studio: last on phones, first column from lg up. */}
        <div className="order-last col-span-2 lg:order-first lg:col-span-1">
          <a
            href={STUDIO_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackExternalLinkClick(STUDIO_URL, "footer")}
            className="group flex w-fit flex-col gap-6"
          >
            <HmcMark className="h-11 w-11 text-foreground opacity-60 transition-opacity duration-300 group-hover:opacity-100" />
            <span className="flex flex-col gap-1">
              <span className="text-[14px] font-medium text-muted-foreground transition-colors duration-300 group-hover:text-foreground">
                {siteConfig.authorName}
              </span>
              <span className="text-[13px] text-muted-foreground/80">{m.footerStudioTagline}</span>
            </span>
            <span className="sr-only"> {m.opensInNewTab}</span>
          </a>
        </div>

        {columns.map((col) => (
          <div key={col.title} className="flex flex-col gap-4">
            <h2 className="text-[14px] font-semibold text-foreground">{col.title}</h2>
            <nav aria-label={col.title} className="flex flex-col gap-2.5">
              {col.links.map((link) => {
                const internal = link.href.startsWith("/");
                const current = internal && isActiveRoute(pathname, link.href);
                const tone = current ? "text-foreground" : "text-muted-foreground";
                const inner = (
                  <>
                    {link.label}
                    {/* ↗ = leaves the site: a new tab, or (mailto) the mail app */}
                    {(link.external || link.href.startsWith("mailto:")) && (
                      <ArrowUpRight aria-hidden className="h-3 w-3 opacity-60" />
                    )}
                    {link.external && <span className="sr-only"> {m.opensInNewTab}</span>}
                  </>
                );
                if (internal) {
                  return (
                    <Link key={link.label} href={link.href} aria-current={current ? "page" : undefined} className={`${linkClass} ${tone}`}>
                      {inner}
                    </Link>
                  );
                }
                return (
                  <a
                    key={link.label}
                    href={link.href}
                    {...(link.external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
                    onClick={() => (link.onClick ? link.onClick() : trackExternalLinkClick(link.href, "footer"))}
                    className={`${linkClass} ${tone}`}
                  >
                    {inner}
                  </a>
                );
              })}
            </nav>
          </div>
        ))}
      </div>

      <div className="mx-auto max-w-270 border-t border-border/60 px-6">
        <div className="flex items-center justify-between py-6">
          <p className="flex items-center gap-1 text-[13px] text-muted-foreground">
            © {currentYear}, {m.footerMadeWithA}
            <Heart role="img" aria-label={m.footerLove} className="h-3.5 w-3.5 fill-orange-500 text-orange-500" />
            {m.footerMadeWithB}
          </p>
          <ThemeSwitcher />
        </div>
      </div>
    </footer>
  );
}
