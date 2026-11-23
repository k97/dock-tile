"use client";

import { Mail } from "lucide-react";
import { DownloadActionButton } from "@/components/action-button";
import { TileFace } from "@/components/dock-demo";
import { InlineTile } from "@/components/inline-tile";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { siteConfig } from "@/lib/config";
import { trackContactClick } from "@/lib/analytics";

/**
 * The FAQ, release-notes and legal pages' last ask, styled like the homepage's
 * Download section (owner, 2026-11-22): on the page background, a centred
 * heading with its tilted tile, the page's own line, then Contact + Download.
 */
export function ContactCta({ title, subtitle }: { title: string; subtitle: string }) {
  const { content } = useLocale();

  return (
    <section className="mx-auto flex max-w-400 flex-col items-center px-4 pt-8 pb-24 text-center sm:px-6 md:px-10 md:pt-12 md:pb-50">
      <Reveal className="flex flex-col items-center">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          {title}{" "}
          {/* The hero's green Comms tile: a conversation. */}
          <InlineTile tilt="rotate-6">
            <TileFace gradient="linear-gradient(to bottom, #52DFA8, #10B981)" darkGlyph="#52DFA8" glyph="chat" shaded />
          </InlineTile>
        </h2>
        <p className="mt-6 max-w-150 text-lead text-muted-foreground">{subtitle}</p>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          {/* h-13 = the md Download pill's height, so the pair lines up */}
          <a
            href={`mailto:${siteConfig.contactEmail}`}
            onClick={trackContactClick}
            className="pressable flex h-13 items-center gap-2 rounded-full border border-foreground/15 px-6 text-sm font-semibold text-foreground transition-[background-color,scale] duration-200 hover:bg-foreground/5"
          >
            <Mail className="h-4 w-4" />
            Contact support
          </a>
          <DownloadActionButton tone="adaptive" location="contact_cta" label={content.downloadButton} />
        </div>
      </Reveal>
    </section>
  );
}
