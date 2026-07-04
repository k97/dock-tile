"use client";

import * as React from "react";
import {
  ArrowDownToLine,
  Bug,
  Clock,
  Ghost,
  Globe,
  Grid3X3,
  Link2,
  List,
  Lock,
  Play,
  Folder,
  MessagesSquare,
  Code2,
  ShieldCheck,
  Sparkles,
  Wrench,
} from "lucide-react";
import { Reveal } from "@/components/reveal";
import { DownloadActionButton } from "@/components/action-button";
import { Footer } from "@/components/footer";
import { siteConfig } from "@/lib/config";

/* Preset tint palette — colorTop → colorBottom, straight from the app */
const PRESETS = [
  { name: "Red", top: "#FF6B6B", bottom: "#FF3B30" },
  { name: "Orange", top: "#FFA94D", bottom: "#FF9500" },
  { name: "Green", top: "#6BCF7F", bottom: "#34C759" },
  { name: "Blue", top: "#4DABF7", bottom: "#007AFF" },
  { name: "Purple", top: "#B197FC", bottom: "#AF52DE" },
  { name: "Pink", top: "#FF6B9D", bottom: "#FF2D55" },
  { name: "Gray", top: "#ADB5BD", bottom: "#8E8E93" },
];

/* Smart Add categories with their real identities */
const SMART_CATEGORIES = [
  { name: "Browse", icon: Globe, top: "#4DABF7", bottom: "#007AFF", chip: "By category" },
  { name: "Watch", icon: Play, top: "#FF6B9D", bottom: "#FF2D55", chip: "By category" },
  { name: "Ship", icon: Code2, top: "#7B79EC", bottom: "#5E5CE6", chip: "Opened together" },
  { name: "Chat", icon: MessagesSquare, top: "#6BCF7F", bottom: "#34C759", chip: "Most used this week" },
  { name: "Work", icon: Folder, top: "#4DABF7", bottom: "#007AFF", chip: "By category" },
];

const ICON_STYLES = [
  { label: "Default", background: "linear-gradient(to bottom, #4DABF7, #007AFF)", glyph: "text-white" },
  { label: "Dark", background: "linear-gradient(to bottom, #2C2C2E, #1C1C1E)", glyph: "text-[#4DA3FF]" },
  { label: "Clear", background: "linear-gradient(to bottom, #F0F0F2, #E0E0E4)", glyph: "text-[#6E6E73]" },
  { label: "Tinted", background: "linear-gradient(to bottom, #8E8E93, #636366)", glyph: "text-white" },
];

function Eyebrow({ children, dark = false }: { children: string; dark?: boolean }) {
  return (
    <span
      className={`mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] ${
        dark ? "text-white/30" : "text-zinc-400"
      }`}
    >
      {children}
    </span>
  );
}

export function FeaturesContent() {
  return (
    <main className="bg-zinc-100">
      {/* Hero band */}
      <section className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] bg-black px-6 pb-24 pt-36 text-center md:mx-4 md:mt-4 md:pt-44">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
        <div className="relative z-10">
          <span className="reveal mb-4 block text-[10px] font-bold uppercase tracking-[0.2em] text-emerald-400">
            Features
          </span>
          <h1 className="reveal mx-auto max-w-3xl text-4xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-6xl" style={{ "--reveal-delay": "80ms" } as React.CSSProperties}>
            Everything your Dock never had.
          </h1>
          <p className="reveal mx-auto mt-6 max-w-xl text-lg font-light text-white/60" style={{ "--reveal-delay": "160ms" } as React.CSSProperties}>
            Tiles you design, popovers you tune, suggestions that build themselves —
            all native, all on-device.
          </p>
        </div>
      </section>

      {/* 01 — Custom tiles (light) */}
      <section className="mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
        <Reveal>
          <Eyebrow>01 / Custom tiles</Eyebrow>
          <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-5xl">
            Design tiles that look like they shipped with macOS.
          </h2>
          <p className="max-w-lg text-lg font-light leading-relaxed text-zinc-500">
            Seven tint gradients plus any custom colour. SF Symbols or emoji, six
            curated icon weights, and a Liquid-Glass depth pass — sheen, contact
            shadow, glass stroke — baked into every icon.
          </p>
        </Reveal>
        <Reveal delay={120}>
          <div className="rounded-[2.5rem] bg-white p-8 shadow-sm md:p-12">
            <div className="grid grid-cols-4 gap-4">
              {PRESETS.map((p, i) => (
                <span
                  key={p.name}
                  className="squircle relative w-full overflow-hidden"
                  style={{ background: `linear-gradient(to bottom, ${p.top}, ${p.bottom})` }}
                  title={p.name}
                >
                  <span className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/20 to-transparent" />
                  {i === 4 ? (
                    <Wrench className="absolute top-1/2 left-1/2 h-[38%] w-[38%] -translate-x-1/2 -translate-y-1/2 text-white" />
                  ) : (
                    <Sparkles className="absolute top-1/2 left-1/2 h-[38%] w-[38%] -translate-x-1/2 -translate-y-1/2 text-white" />
                  )}
                </span>
              ))}
              <span className="squircle relative flex w-full items-center justify-center overflow-hidden bg-zinc-100 text-3xl">
                🚀
              </span>
            </div>
            <p className="mt-6 text-center text-[11px] font-medium uppercase tracking-wider text-zinc-400">
              Presets, custom colours, symbols & emoji
            </p>
          </div>
        </Reveal>
      </section>

      {/* 02 — Popovers (dark) */}
      <section className="relative mx-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-950/40" />
        <div className="relative mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
          <Reveal className="order-2 md:order-1">
            <div className="flex flex-col gap-4 sm:flex-row">
              {/* Grid popover mock */}
              <div className="popover-surface flex-1 rounded-2xl p-3">
                <p className="pb-2 pt-1 text-center text-[13px] font-medium text-zinc-800">Grid</p>
                <div className="grid grid-cols-3 gap-2">
                  {[...Array(6)].map((_, i) => (
                    <span key={i} className="flex aspect-square items-center justify-center rounded-xl bg-black/5">
                      <Grid3X3 className="h-4 w-4 text-zinc-400" />
                    </span>
                  ))}
                </div>
              </div>
              {/* List popover mock */}
              <div className="popover-surface flex-1 rounded-2xl p-3">
                <p className="pb-2 pt-1 text-[13px] font-semibold text-zinc-800">List</p>
                <div className="flex flex-col gap-1">
                  {["Music", "Podcasts", "Kayo"].map((n) => (
                    <span key={n} className="flex items-center gap-2 rounded px-2 py-1.5 text-[13px] text-zinc-700 odd:bg-black/5">
                      <List className="h-3.5 w-3.5 text-zinc-400" />
                      {n}
                    </span>
                  ))}
                </div>
              </div>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              {["Popover size", "Tile size", "Spacing", "Labels", "Hover highlight", "Animation"].map((chip) => (
                <span key={chip} className="glass rounded-full px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-white/70">
                  {chip}
                </span>
              ))}
            </div>
          </Reveal>
          <Reveal delay={120} className="order-1 md:order-2">
            <Eyebrow dark>02 / Popovers</Eyebrow>
            <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl">
              Grid or list. Sized your way.
            </h2>
            <p className="max-w-lg text-lg font-light leading-relaxed text-white/60">
              Each tile opens a native popover — an icon grid like an iOS folder, or a
              compact list. Appearance controls tune size, spacing and labels for every
              tile at once, and running tiles pick the change up immediately.
            </p>
          </Reveal>
        </div>
      </section>

      {/* 03 — Smart Add (light) */}
      <section className="mx-auto max-w-400 px-6 py-24 md:px-10 md:py-32">
        <Reveal className="mx-auto mb-14 max-w-2xl text-center">
          <Eyebrow>03 / Smart Add</Eyebrow>
          <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-5xl">
            Press +, get tiles built from how you actually work.
          </h2>
          <p className="text-lg font-light leading-relaxed text-zinc-500">
            Dock Tile watches which apps you launch together and how often — entirely
            on your Mac — and offers ready-made tiles the moment you add one.
          </p>
        </Reveal>
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-5">
          {SMART_CATEGORIES.map((c, i) => {
            const Icon = c.icon;
            return (
              <Reveal key={c.name} delay={i * 60}>
                <div className="flex flex-col items-center gap-3 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
                  <span
                    className="squircle relative flex h-14 w-14 items-center justify-center overflow-hidden"
                    style={{ background: `linear-gradient(to bottom, ${c.top}, ${c.bottom})` }}
                  >
                    <span className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/20 to-transparent" />
                    <Icon className="relative h-6 w-6 text-white" />
                  </span>
                  <p className="text-sm font-bold text-zinc-900">{c.name}</p>
                  <span className="flex items-center gap-1 rounded-full bg-zinc-100 px-2.5 py-1 text-[10px] font-medium text-zinc-500">
                    {c.chip === "Most used this week" ? (
                      <Clock className="h-2.5 w-2.5" />
                    ) : c.chip === "Opened together" ? (
                      <Link2 className="h-2.5 w-2.5" />
                    ) : (
                      <Grid3X3 className="h-2.5 w-2.5" />
                    )}
                    {c.chip}
                  </span>
                </div>
              </Reveal>
            );
          })}
        </div>
        <Reveal className="mt-10 flex justify-center">
          <div className="flex items-center gap-3 rounded-2xl bg-zinc-900 px-4 py-3">
            <ShieldCheck className="h-5 w-5 text-emerald-400" />
            <p className="text-[13px] font-medium text-white/80">
              Learned on your Mac. Never leaves your device.
            </p>
          </div>
        </Reveal>
      </section>

      {/* 04 — Dock Lock (dark) */}
      <section className="relative mx-3 overflow-hidden rounded-[2.5rem] bg-zinc-900 md:mx-4">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-950/40" />
        <div className="relative mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
          <Reveal>
            <Eyebrow dark>04 / Dock Lock</Eyebrow>
            <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl">
              Multi-monitor? The Dock stays where you put it.
            </h2>
            <p className="max-w-lg text-lg font-light leading-relaxed text-white/60">
              Pin the Dock to one display and it stops hopping between screens. Pick
              the anchor display once — Dock Lock re-asserts it after reboots,
              unplugs and re-plugs.
            </p>
          </Reveal>
          <Reveal delay={120}>
            <div className="relative flex h-64 items-center justify-center gap-6 rounded-2xl border border-white/5 bg-zinc-950 px-6 md:gap-8">
              <div className="flex h-32 w-full max-w-48 items-end justify-center rounded-lg border border-white/10 bg-zinc-900 pb-2">
                <span className="h-4 w-1/2 rounded-full bg-white/10 opacity-40" />
              </div>
              <div className="flex h-32 w-full max-w-48 items-end justify-center rounded-lg border border-emerald-400/30 bg-zinc-900 pb-2">
                <span className="flex h-4 w-1/2 items-center justify-center rounded-full border border-emerald-400/50 bg-emerald-400/20">
                  <Lock className="h-2 w-2 text-emerald-400" />
                </span>
              </div>
              <span className="glass absolute top-6 left-1/2 -translate-x-1/2 rounded-xl px-4 py-2 text-[10px] font-bold uppercase tracking-widest text-white">
                Locked to display 2
              </span>
            </div>
          </Reveal>
        </div>
      </section>

      {/* 05 — Icon styles (light) */}
      <section className="mx-auto grid max-w-400 items-center gap-12 px-6 py-24 md:grid-cols-2 md:gap-20 md:px-10 md:py-32">
        <Reveal>
          <Eyebrow>05 / Tahoe icon styles</Eyebrow>
          <h2 className="mb-6 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-5xl">
            Four appearances, baked ahead of time.
          </h2>
          <p className="max-w-lg text-lg font-light leading-relaxed text-zinc-500">
            Every tile ships with Default, Dark, Clear and Tinted variants that follow
            the macOS icon appearance instantly — the Dark style even lifts your
            tile&rsquo;s own tint so it stays readable on near-black.
          </p>
        </Reveal>
        <Reveal delay={120}>
          <div className="flex justify-center gap-4 rounded-[2.5rem] bg-white p-8 shadow-sm md:gap-6 md:p-12">
            {ICON_STYLES.map((s) => (
              <div key={s.label} className="flex flex-col items-center gap-2">
                <span className="squircle relative h-16 w-16 overflow-hidden md:h-20 md:w-20" style={{ background: s.background }}>
                  <span className="absolute inset-x-0 top-0 h-1/2 bg-linear-to-b from-white/15 to-transparent" />
                  <Sparkles className={`absolute top-1/2 left-1/2 h-7 w-7 -translate-x-1/2 -translate-y-1/2 ${s.glyph}`} />
                </span>
                <span className="text-[10px] font-medium text-zinc-400">{s.label}</span>
              </div>
            ))}
          </div>
        </Reveal>
      </section>

      {/* 06 — The rest, bento */}
      <section className="mx-auto max-w-400 px-6 pb-24 md:px-10 md:pb-32">
        <Reveal className="mb-12 text-center">
          <Eyebrow>06 / And the quiet stuff</Eyebrow>
          <h2 className="text-3xl font-semibold tracking-[-0.05em] leading-[1.05] text-zinc-900 md:text-4xl">
            Details you&rsquo;ll stop noticing. That&rsquo;s the point.
          </h2>
        </Reveal>
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {[
            {
              icon: ArrowDownToLine,
              title: "Start at login",
              body: "Tiles warm up at login so the first click is instant.",
            },
            {
              icon: Ghost,
              title: "Ghost mode",
              body: "Tiles hide from Cmd-Tab by default. Or show them — your call.",
            },
            {
              icon: Bug,
              title: "Missing-app detection",
              body: "Uninstalled apps get flagged, never silently broken.",
            },
            {
              icon: ShieldCheck,
              title: "Signed & auto-updating",
              body: "Notarized by Apple, updated via Sparkle in the background.",
            },
          ].map((f, i) => {
            const Icon = f.icon;
            return (
              <Reveal key={f.title} delay={i * 60}>
                <div className="flex h-full flex-col gap-4 rounded-3xl border border-zinc-200 bg-white p-6">
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-zinc-100">
                    <Icon className="h-5 w-5 text-zinc-600" />
                  </span>
                  <div>
                    <h3 className="mb-1 font-bold text-zinc-900">{f.title}</h3>
                    <p className="text-sm leading-relaxed text-zinc-500">{f.body}</p>
                  </div>
                </div>
              </Reveal>
            );
          })}
        </div>
      </section>

      {/* CTA */}
      <section className="relative mx-3 mb-3 flex flex-col items-center overflow-hidden rounded-[2.5rem] bg-black px-6 py-24 text-center md:mx-4 md:mb-4">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
        <Reveal className="relative z-10">
          <h2 className="mb-10 text-4xl font-semibold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl">
            Bring order to your Dock.
          </h2>
          <div className="flex justify-center">
            <DownloadActionButton tone="light" size="lg" label="Download Dock Tile" />
          </div>
          <div className="mt-8 flex items-center justify-center gap-4 text-xs font-medium text-white/40">
            <span>Free download</span>
            <span className="h-1 w-1 rounded-full bg-white/20" />
            <span>v{siteConfig.latestVersion}</span>
            <span className="h-1 w-1 rounded-full bg-white/20" />
            <span>macOS 26+</span>
          </div>
        </Reveal>
      </section>

      <Footer />
    </main>
  );
}
