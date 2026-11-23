"use client";

import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { DownloadActionButton } from "@/components/action-button";
import { DownloadMeta } from "@/components/hero";
import { AppGridFace, aiAppIcons } from "@/components/home-sections";
import { InlineTile } from "@/components/inline-tile";

/**
 * The homepage's last ask, on the page background just above the footer:
 * a headline (with its tilted tile, like every section heading) and Download.
 */
export function DownloadSection() {
  const { content } = useLocale();
  const m = content.marketing;

  return (
    <section className="mx-auto flex max-w-400 flex-col items-center px-4 pb-24 text-center sm:px-6 md:px-10 md:pb-50">
      <Reveal className="flex flex-col items-center">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          {m.downloadTitleA}{" "}
          <span className="whitespace-nowrap">
            <InlineTile tilt="rotate-6">
              <AppGridFace icons={aiAppIcons} />
            </InlineTile>{" "}
            {m.downloadTitleB}
          </span>
        </h2>
        <div className="mt-10 flex flex-col items-center gap-5">
          {/* adaptive: dark on the light page, light under the dark theme */}
          <DownloadActionButton tone="adaptive" location="download_section" size="lg" label={m.ctaButton} />
          {/* Open source (GitHub) · Apple silicon · macOS floor */}
          <DownloadMeta variant="page" />
        </div>
      </Reveal>
    </section>
  );
}
