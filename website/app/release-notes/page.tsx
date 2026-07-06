import type { Metadata } from "next";
import { Github, RefreshCw, ShieldCheck } from "lucide-react";
import { Footer } from "@/components/footer";
import { Reveal } from "@/components/reveal";
import { siteConfig } from "@/lib/config";

export const metadata: Metadata = {
  title: `Release Notes - ${siteConfig.appName}`,
  description: `Release notes and changelog for ${siteConfig.appName}, a macOS utility app.`,
};

type ReleaseGroup = {
  heading: string;
  items: string[];
};

type Release = {
  version: string;
  date: string;
  intro: string;
  groups: ReleaseGroup[];
};

const releases: Release[] = [
  {
    version: "1.1.1",
    date: "26 March 2026",
    intro: "Code quality improvements and updated app icon.",
    groups: [
      {
        heading: "Under the Hood",
        items: [
          "Extracted shared utilities to reduce code duplication (~200 lines removed)",
          "Fixed a bug where some app icons displayed incorrectly in the detail view",
          "Tile uninstall no longer briefly freezes the UI",
          "Faster debounce when editing tile names",
          "Updated development app icon",
        ],
      },
    ],
  },
  {
    version: "1.1.0",
    date: "26 March 2026",
    intro: "Auto-updates, expanded icon library, and a proper About window.",
    groups: [
      {
        heading: "Auto-Updates",
        items: [
          "Sparkle 2.x integration for seamless in-app updates",
          "Automatic daily update checks in the background",
          "Check for Updates from the app menu or About window",
          "Secure EdDSA signature verification for all updates",
        ],
      },
      {
        heading: "SF Symbol Picker",
        items: [
          "Expanded from ~170 to 6,000+ SF Symbols loaded from the system",
          "28 categories matching Apple's SF Symbols app",
          "Keyword-based search powered by system search data",
          "Filtered out wide symbols that don't work well as icons",
          "Bolder semibold weight for better icon visibility",
          "Increased max icon scale for SF Symbols",
        ],
      },
      {
        heading: "Improvements",
        items: [
          "Custom About window with version info and Check for Updates button",
          "Icon picker now fills available window height",
          "Fixed version numbering to match release tags",
        ],
      },
    ],
  },
  {
    version: "1.0.0",
    date: "8 February 2026",
    intro: `Initial release of ${siteConfig.appName}.`,
    groups: [
      {
        heading: "Features",
        items: [
          "Create custom Dock tiles with personalised icons",
          "Add multiple apps to each tile for quick access",
          "Choose from SF Symbols or emojis for tile icons",
          "Customise icon colours with preset or custom gradients",
          "Grid and list view layouts for tile popovers",
          "Ghost Mode - tiles hidden from Cmd+Tab by default",
          "App Mode - optional visibility in App Switcher with context menu support",
          "Drag to reorder apps within tiles",
          "Multi-select apps for batch removal",
          "Dynamic grid sizing based on app count",
          "Full support for macOS icon styles (Default, Dark, Clear, Tinted)",
        ],
      },
    ],
  },
];

export default function ReleaseNotesPage() {
  return (
    <main className="bg-zinc-100">
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
              <span className="glass flex items-center gap-2 rounded-full px-4 py-1.5 text-[10px] font-bold uppercase tracking-wider text-white/70">
                <ShieldCheck className="h-3 w-3 text-emerald-400" />
                Signed &amp; notarized
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

          {/* Timeline */}
          <div className="relative">
            {/* Vertical line */}
            <div className="absolute bottom-0 left-1.25 top-2 w-px bg-linear-to-b from-white/15 via-white/10 to-transparent" />

            <div className="flex flex-col gap-12">
              {releases.map((release, index) => {
                const isLatest = index === 0;
                return (
                  <Reveal
                    key={release.version}
                    delay={index * 80}
                    className="relative pl-10 md:pl-12"
                  >
                    {/* Timeline node */}
                    <span
                      className={`absolute left-0 top-7 h-2.75 w-2.75 rounded-full ${
                        isLatest
                          ? "bg-emerald-400 shadow-[0_0_12px_#34D399] ring-4 ring-emerald-400/20"
                          : "bg-white/20"
                      }`}
                    />

                    {/* Glass card */}
                    <article
                      className={`rounded-3xl border bg-white/5 p-8 backdrop-blur-sm ${
                        isLatest ? "border-emerald-400/20" : "border-white/10"
                      }`}
                    >
                      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
                        <div className="flex items-center gap-3">
                          <span className="rounded-full bg-emerald-400 px-3 py-1 text-[11px] font-bold text-emerald-950">
                            v{release.version}
                          </span>
                          {isLatest && (
                            <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-400">
                              Latest
                            </span>
                          )}
                        </div>
                        <span className="text-sm tabular-nums text-white/40">
                          {release.date}
                        </span>
                      </div>

                      <p className="mb-6 text-[15px] font-light leading-relaxed text-white/60">
                        {release.intro}
                      </p>

                      <div className="flex flex-col gap-6">
                        {release.groups.map((group) => (
                          <section key={group.heading}>
                            <h3 className="mb-3 text-[10px] font-bold uppercase tracking-[0.2em] text-white/80">
                              {group.heading}
                            </h3>
                            <ul className="flex flex-col gap-2.5">
                              {group.items.map((item) => (
                                <li
                                  key={item}
                                  className="relative pl-5 text-sm font-light leading-relaxed text-white/60"
                                >
                                  <span className="absolute left-0 top-2.25 h-1.5 w-1.5 rounded-full bg-emerald-400/40" />
                                  {item}
                                </li>
                              ))}
                            </ul>
                          </section>
                        ))}
                      </div>
                    </article>
                  </Reveal>
                );
              })}
            </div>
          </div>

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
