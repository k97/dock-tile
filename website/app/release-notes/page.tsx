import type { Metadata } from "next";
import { Github, RefreshCw } from "lucide-react";
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
          {/* Headline */}
          <Reveal className="mb-16">
            <span className="mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-400">
              Release Notes
            </span>
            <h1 className="mb-4 text-3xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl">
              What&apos;s new
            </h1>
            <p className="mb-8 text-lg font-light text-white/60">
              {siteConfig.appName} checks for updates automatically.
            </p>
            <div className="flex flex-wrap items-center gap-2">
              <span className="glass flex items-center gap-2 rounded-full px-4 py-1.5 text-[10px] font-bold uppercase tracking-wider text-white/70">
                <RefreshCw className="h-3 w-3 text-emerald-400" />
                macOS 26+
              </span>
              <a
                href={siteConfig.githubUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="glass flex items-center gap-2 rounded-full px-4 py-1.5 text-[10px] font-bold uppercase tracking-wider text-white/70 transition-colors hover:bg-white/10 hover:text-white"
              >
                <Github className="h-3 w-3" />
                GitHub
              </a>
            </div>
          </Reveal>

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
