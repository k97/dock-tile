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
    <footer className="mx-auto grid max-w-[1600px] grid-cols-1 items-center justify-items-center gap-6 px-6 py-12 md:grid-cols-[1fr_auto_1fr] md:px-10">
      <p className="order-2 justify-self-center text-sm text-muted-foreground md:order-1 md:justify-self-start">
        © {currentYear}{" "}
        <a
          href={siteConfig.authorUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="font-semibold transition-colors duration-300 hover:text-foreground"
          onClick={() => trackExternalLinkClick(siteConfig.authorUrl, "footer")}
        >
          {siteConfig.authorName}
        </a>
        . {content.footerMessage}.
      </p>

      <div className="order-1 md:order-2">
        <ThemeSwitcher />
      </div>

      <div className="order-3 flex items-center gap-6 justify-self-center text-sm md:justify-self-end">
        <Link
          href="/privacy"
          className="text-muted-foreground transition-colors duration-300 hover:text-foreground"
        >
          {content.privacy}
        </Link>
        <Link
          href="/terms"
          className="text-muted-foreground transition-colors duration-300 hover:text-foreground"
        >
          {content.terms}
        </Link>
        <a
          href={siteConfig.githubUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-muted-foreground transition-colors duration-300 hover:text-foreground"
          onClick={() => trackExternalLinkClick(siteConfig.githubUrl, "footer")}
        >
          GitHub
        </a>
      </div>
    </footer>
  );
}
