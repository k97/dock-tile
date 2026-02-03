"use client";

import Link from "next/link";
import { useLocale } from "@/components/locale-provider";
import { ThemeSwitcher } from "@/components/theme-switcher";
import { siteConfig } from "@/lib/config";
import { trackExternalLinkClick } from "@/lib/analytics";

export function Footer() {
  const { content } = useLocale();
  const currentYear = new Date().getFullYear();

  return (
    <footer className="border-t border-border px-4 py-6 mt-8">
      <div className="max-w-4xl mx-auto">
        {/* Main footer row - three columns */}
        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          {/* Left: Privacy • Terms • © Year Author */}
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Link
              href="/privacy"
              className="hover:text-foreground transition-colors"
            >
              {content.privacy}
            </Link>
            <span>•</span>
            <Link
              href="/terms"
              className="hover:text-foreground transition-colors"
            >
              {content.terms}
            </Link>
            <span>•</span>
            <span>
              © {currentYear}{" "}
              <a
                href={siteConfig.authorUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-foreground transition-colors font-semibold"
                onClick={() => trackExternalLinkClick(siteConfig.authorUrl, "footer")}
              >
                {siteConfig.authorName}
              </a>
            </span>
          </div>

          {/* Center: Theme switcher */}
          <ThemeSwitcher />

          {/* Right: Made with care message */}
          <p className="text-sm text-muted-foreground">
            {content.footerMessage}
          </p>
        </div>
      </div>
    </footer>
  );
}
