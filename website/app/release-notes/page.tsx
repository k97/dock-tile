import type { Metadata } from "next";
import type { CSSProperties } from "react";
import { Footer } from "@/components/footer";
import { ReleaseTimeline } from "@/components/release-timeline";
import { Reveal } from "@/components/reveal";
import { siteConfig } from "@/lib/config";
import { getReleases } from "@/lib/releases";

const title = `Release Notes - ${siteConfig.appName}`;
const description = `Release notes and version history for ${siteConfig.appName} — new features, fixes, and improvements in every update to the macOS Dock utility.`;

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/release-notes" },
  openGraph: {
    title,
    description,
    url: "/release-notes",
    siteName: siteConfig.appName,
    type: "website",
    // Defining openGraph here drops the root file-convention image, so re-add it.
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

// Revalidate hourly so edited notes / new releases appear without a redeploy.
export const revalidate = 3600;

export default async function ReleaseNotesPage() {
  const releases = await getReleases();
  return (
    <main className="bg-background">
      {/* Dark shell */}
      <section data-nav-tone="dark" className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] bg-black pb-20 pt-28 md:mx-4 md:mt-4 md:pb-28 md:pt-36">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent via-zinc-950/20 to-zinc-900/60" />

        <div className="relative z-10 mx-auto max-w-3xl px-6 md:px-8">
          {/* Header — same centered treatment as the FAQ / Privacy pages */}
          <div className="mb-16 text-center">
            <span
              className="reveal mb-3 block text-[12px] font-bold uppercase tracking-[0.2em] text-white/60"
              style={{ "--reveal-delay": "0ms" } as CSSProperties}
            >
              Release Notes
            </span>
            <h1
              className="reveal text-3xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl"
              style={{ "--reveal-delay": "80ms" } as CSSProperties}
            >
              What&apos;s
              <br />
              <span className="text-white/40">new.</span>
            </h1>
            <p
              className="reveal mt-4 text-sm font-light text-white/40"
              style={{ "--reveal-delay": "160ms" } as CSSProperties}
            >
              {siteConfig.appName} checks for updates automatically.
            </p>
          </div>

          <ReleaseTimeline releases={releases} />

          <Reveal className="mt-16 border-t border-white/10 pt-8">
            <p className="text-sm font-light text-white/40">
              For the latest updates, follow the{" "}
              <a
                href={siteConfig.releaseNotesUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="font-medium text-emerald-400 underline underline-offset-4 transition-colors hover:text-emerald-300"
              >
                GitHub releases page
              </a>
              .
            </p>
          </Reveal>
        </div>
      </section>

      <Footer />
    </main>
  );
}
