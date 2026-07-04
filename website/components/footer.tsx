"use client";

import Link from "next/link";
import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackExternalLinkClick } from "@/lib/analytics";

export function Footer() {
  const { content } = useLocale();
  const currentYear = new Date().getFullYear();

  return (
    <footer className="mx-auto flex max-w-[1600px] flex-col items-center justify-between gap-6 px-6 py-12 md:flex-row md:px-10">
      <p className="text-sm text-zinc-400">
        © {currentYear}{" "}
        <a
          href={siteConfig.authorUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="font-semibold transition-colors duration-300 hover:text-zinc-900"
          onClick={() => trackExternalLinkClick(siteConfig.authorUrl, "footer")}
        >
          {siteConfig.authorName}
        </a>
        . {content.footerMessage}.
      </p>
      <div className="flex items-center gap-6 text-sm">
        <Link href="/privacy" className="text-zinc-400 transition-colors duration-300 hover:text-zinc-900">
          {content.privacy}
        </Link>
        <Link href="/terms" className="text-zinc-400 transition-colors duration-300 hover:text-zinc-900">
          {content.terms}
        </Link>
        <a
          href={siteConfig.githubUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-zinc-400 transition-colors duration-300 hover:text-zinc-900"
          onClick={() => trackExternalLinkClick(siteConfig.githubUrl, "footer")}
        >
          GitHub
        </a>
      </div>
    </footer>
  );
}
