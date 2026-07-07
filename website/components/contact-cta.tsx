"use client";

import { Mail } from "lucide-react";
import { DownloadActionButton } from "@/components/action-button";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { siteConfig } from "@/lib/config";
import { trackContactClick } from "@/lib/analytics";

/**
 * Compact dark contact band that sits above the footer — shared by the FAQ
 * and legal pages so their page endings stay identical.
 */
export function ContactCta({ title, subtitle }: { title: string; subtitle: string }) {
  const { content } = useLocale();

  return (
    <section data-nav-tone="dark" className="relative mx-3 mb-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4 md:mb-4">
      <div className="grain" />
      <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-950/40" />
      <Reveal className="relative z-10 flex flex-col items-center justify-between gap-8 px-8 py-16 md:flex-row md:px-12">
        <div className="text-center md:text-left">
          <h2 className="mb-2 text-xl font-semibold tracking-[-0.05em] leading-[1.05] text-white md:text-2xl">
            {title}
          </h2>
          <p className="text-sm font-light text-white/50">{subtitle}</p>
        </div>
        <div className="flex flex-wrap items-center justify-center gap-4">
          <a
            href={`mailto:${siteConfig.contactEmail}`}
            onClick={trackContactClick}
            className="pressable flex items-center gap-2 rounded-full border border-white/10 px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-white/5"
          >
            <Mail className="h-4 w-4" />
            Contact support
          </a>
          <DownloadActionButton tone="light" label={content.downloadButton} />
        </div>
      </Reveal>
    </section>
  );
}
