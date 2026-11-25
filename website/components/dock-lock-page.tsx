"use client";

import * as React from "react";
import { ChevronsUpDown, Lock } from "lucide-react";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { DownloadActionButton } from "@/components/action-button";
import { DockLockMock } from "@/components/dock-lock-mock";
import { TileFace } from "@/components/dock-demo";
import { FAQ_ANSWER, FAQ_CARD, FAQ_TRIGGER } from "@/components/faq-card";
import { GuideLayout } from "@/components/guide-layout";
import { Footer } from "@/components/footer";
import { InlineTile, tileGap } from "@/components/inline-tile";
import { JsonLd } from "@/components/json-ld";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { ScaleToFit } from "@/components/scale-to-fit";
import { trackFaqOpen } from "@/lib/analytics";
import { HERO_BG_DARK } from "@/lib/assets";

const reveal = (ms: number) => ({ "--reveal-delay": `${ms}ms` }) as React.CSSProperties;
const blockTitle = "mb-4 text-title text-foreground";

/* The hero wallpaper, cropped and hue-shifted to teal like the homepage intro's blues (owner,
   2026-11-24: each section its own scene). Always the dark dither: the text on it is white. */
function TealWallpaper() {
  return (
    <>
      <div
        aria-hidden
        className="hero-texture"
        style={
          {
            "--hero-bg": `url("${HERO_BG_DARK}")`,
            "--hero-bg-dark": `url("${HERO_BG_DARK}")`,
            backgroundSize: "160%",
            backgroundPosition: "30% 40%",
            filter: "hue-rotate(150deg) saturate(0.7)",
          } as React.CSSProperties
        }
      />
      <div aria-hidden className="absolute inset-0 bg-linear-to-b from-zinc-950/30 to-zinc-950/70" />
    </>
  );
}


/* A numbered pin: the same number as its step in the list under the pane. */
function Pin({ n, className = "" }: { n: number; className?: string }) {
  return (
    <span
      aria-hidden
      className={`absolute flex h-5 w-5 items-center justify-center rounded-full bg-emerald-500 text-[11px] font-semibold text-white shadow-[0_0_0_2px_var(--color-background)] ${className}`}
    >
      {n}
    </span>
  );
}

/* Settings → Dock Lock, as the app draws it once set up, with the Accessibility primer beside it.
   Every label is the app's own (settings.dockLock.*, i18n `dockLockPane`). Fixed 520×220, scaled. */
function DockLockPaneMock() {
  const { content } = useLocale();
  const p = content.marketing.dockLockPane;
  const row = "flex h-10 items-center justify-between gap-3 px-3 text-[13px] text-zinc-900 dark:text-zinc-100";
  return (
    <ScaleToFit>
      <div aria-hidden className="relative h-55 w-130 font-ui">
        {/* the Settings window */}
        <div className="absolute top-0 left-0 w-82.5 overflow-hidden rounded-xl border border-black/10 bg-white shadow-[0_12px_32px_rgba(0,0,0,0.12)] dark:border-white/10 dark:bg-zinc-900">
          <div className="flex h-9 items-center gap-2 px-3">
            <span className="h-2.5 w-2.5 rounded-full bg-[#FF5F57]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#FEBC2E]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#28C840]" />
            <span className="ml-2 text-[13px] font-semibold text-zinc-900 dark:text-zinc-100">{p.title}</span>
          </div>
          <div className="px-3 pb-3">
            <div className="rounded-lg bg-black/4 dark:bg-white/6">
              <div className={row}>
                <span>{p.toggle}</span>
                <span className="relative">
                  {/* macOS switch, on */}
                  <span className="flex h-4 w-7 items-center justify-end rounded-full bg-[#007AFF] p-0.5 dark:bg-[#0A84FF]">
                    <span className="h-3 w-3 rounded-full bg-white shadow" />
                  </span>
                  <Pin n={1} className="-top-3 -right-4" />
                </span>
              </div>
              <div className="mx-3 border-t border-black/8 dark:border-white/10" />
              <div className={row}>
                <span>{p.anchor}</span>
                <span className="relative">
                  {/* macOS pop-up button */}
                  <span className="flex h-5.5 items-center gap-1.5 rounded-md border border-black/10 bg-white pr-1 pl-2 text-[12px] shadow-sm dark:border-white/10 dark:bg-zinc-700">
                    {p.display}
                    <ChevronsUpDown className="h-3 w-3 opacity-60" />
                  </span>
                  <Pin n={3} className="-top-3 -right-4" />
                </span>
              </div>
            </div>
            <p className="mt-3 flex items-center gap-1.5 px-1 text-[12px] font-medium text-zinc-800 dark:text-zinc-200">
              <Lock className="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" />
              {p.lockedTo}
            </p>
            <p className="mt-1.5 px-1 text-[11px] leading-snug text-zinc-500 dark:text-zinc-400">{p.note}</p>
          </div>
        </div>
        {/* the Accessibility primer the app shows before macOS asks */}
        <div className="absolute top-6 right-0 flex w-42.5 flex-col items-center rounded-xl border border-black/10 bg-white p-4 text-center shadow-[0_16px_40px_rgba(0,0,0,0.18)] dark:border-white/10 dark:bg-zinc-800">
          <Pin n={2} className="-top-2.5 -left-2.5" />
          <span className="mb-3 h-10 w-10 drop-shadow-[0_1px_2px_rgba(0,0,0,0.2)]">
            <TileFace gradient="linear-gradient(to bottom, #52DFA8, #10B981)" darkGlyph="#52DFA8" glyph="lock" shaded />
          </span>
          <span className="text-[13px] leading-tight font-semibold text-zinc-900 dark:text-zinc-100">{p.primerTitle}</span>
          <span className="mt-4 flex w-full gap-2">
            <span className="flex h-6 flex-1 items-center justify-center rounded-md bg-black/6 text-[12px] text-zinc-900 dark:bg-white/10 dark:text-zinc-100">
              {p.notNow}
            </span>
            <span className="flex h-6 flex-1 items-center justify-center rounded-md bg-[#007AFF] text-[12px] text-white dark:bg-[#0A84FF]">
              {p.continue}
            </span>
          </span>
        </div>
      </div>
    </ScaleToFit>
  );
}

/**
 * /dock-lock and /zh-Hans/dock-lock (the route's locale picks the copy): the page that answers
 * "the Dock keeps moving to my other monitor" and offers Dock Lock. Laid out as a guide, not as
 * homepage sections (owner, 2026-11-24): the teal header (Download), then a sticky "On this page"
 * list beside four sections (Why the Dock moves with the clickable displays,
 * Fix it with the Settings pane and its numbered steps, Without an app as a comparison table, the
 * questions), then a teal closing strip.
 */
export function DockLockPage({ schema }: { schema: Record<string, unknown> }) {
  const { locale, content } = useLocale();
  const m = content.marketing;
  const dot = <span className="h-1 w-1 rounded-full bg-white/20" />;
  const items = [
    { id: "why", title: m.dockLockPageWhyTitle },
    { id: "fix", title: m.dockLockPageStepsTitle },
    { id: "without", title: m.dockLockPageWithoutTitle },
    { id: "questions", title: m.dockLockPageFaqTitle },
  ];
  const section = "scroll-mt-28";

  return (
    <main className="bg-background">
      <JsonLd data={schema} />
      {/* The header's wallpaper is this page's largest paint: fetch it before first paint, not
          after the CSS is parsed. Always the dark one (the header is dark in both themes); React
          hoists the <link> into <head>. */}
      <link rel="preload" as="image" fetchPriority="high" type="image/webp" href={HERO_BG_DARK} />

      {/* Centred like the other subpage headers: the homepage's Dock Lock band owns the split text +
          animation layout, so the animation sits under "Why the Dock moves" here */}
      <section
        data-nav-tone="dark"
        className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] edge-hairline bg-zinc-900 px-6 pt-28 pb-16 text-center md:mx-4 md:mt-4 md:pt-36 md:pb-20"
      >
        <TealWallpaper />
        <div className="relative z-10 mx-auto flex max-w-2xl flex-col items-center">
          <span className="reveal mb-3 block text-[14px] font-semibold tracking-[0.01em] text-white/75" style={reveal(0)}>
            {m.dockLockPageEyebrow}
          </span>
          <h1 className="reveal text-4xl heading-display text-white md:text-5xl" style={reveal(80)}>
            {m.dockLockPageTitle}
          </h1>
          <p className="reveal mt-5 max-w-lg text-lead text-white/70" style={reveal(160)}>
            {m.dockLockPageAnswer}
          </p>
          <div className="reveal mt-10 flex flex-col items-center gap-5" style={reveal(240)}>
            <DownloadActionButton tone="light" location="dock_lock_page" size="lg" label={m.ctaButton} />
            <p className="flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-xs font-medium text-white/40">
              <span>{m.ctaMetaOpenSource}</span>
              {dot}
              <span>{m.dockLockPageMetaNoAccount}</span>
              {dot}
              <span>{m.ctaMetaMacOS}</span>
              {dot}
              <span>{m.ctaMetaAppleSilicon}</span>
            </p>
          </div>
        </div>
      </section>

      <GuideLayout items={items}>
          <section id="why" className={section}>
            {/* Prose never fades in (owner, 2026-11-24); the animation does */}
            <h2 className={blockTitle}>{m.dockLockPageWhyTitle}</h2>
            <p className="text-lead text-muted-foreground">{m.dockLockPageWhyBody}</p>
            <Reveal className="mt-8">
              <DockLockMock />
            </Reveal>
          </section>

          <section id="fix" className={`mt-20 md:mt-28 ${section}`}>
            <h2 className={blockTitle}>{m.dockLockPageStepsTitle}</h2>
            <Reveal className="mt-6 rounded-2xl bg-foreground/4 p-6 md:p-10">
              <DockLockPaneMock />
            </Reveal>
            {/* Same numbers as the pins on the pane */}
            <ol className="mt-8 flex flex-col gap-5">
              {m.dockLockPageSteps.map((step, i) => (
                <li key={step} className="flex gap-4">
                  <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-500 text-sm font-semibold text-white">
                    {i + 1}
                  </span>
                  <span className="text-lead text-foreground">{step}</span>
                </li>
              ))}
            </ol>
            <p className="mt-6 text-[15px] leading-relaxed text-muted-foreground">{m.dockLockPageStepsNote}</p>
          </section>

          <section id="without" className={`mt-20 md:mt-28 ${section}`}>
            <h2 className={blockTitle}>{m.dockLockPageWithoutTitle}</h2>
            <p className="text-lead text-muted-foreground">{m.dockLockPageWithoutBody}</p>
            {/* A real table: answer engines lift comparisons from table markup */}
            <div className="mt-8 overflow-hidden rounded-2xl border border-border bg-card">
              <table className="w-full table-fixed text-left text-[14px] leading-snug md:text-[15px]">
                <thead className="bg-muted">
                  <tr>
                    <td className="w-[34%] p-3 md:p-4" />
                    <th scope="col" className="p-3 font-semibold text-muted-foreground md:p-4">
                      {m.dockLockPageCompare.builtIn}
                    </th>
                    <th scope="col" className="p-3 font-semibold text-foreground md:p-4">
                      <span className="inline-flex items-center gap-1.5">
                        <Lock className="h-3.5 w-3.5 shrink-0 text-emerald-600 dark:text-emerald-400" />
                        {m.dockLockPageCompare.dockLock}
                      </span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {m.dockLockPageCompare.rows.map((r) => (
                    <tr key={r.label} className="border-t border-border align-top">
                      <th scope="row" className="p-3 font-medium text-foreground md:p-4">
                        {r.label}
                      </th>
                      <td className="p-3 text-muted-foreground md:p-4">{r.builtIn}</td>
                      <td className="bg-emerald-500/6 p-3 text-foreground md:p-4">{r.dockLock}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section id="questions" className={`mt-20 md:mt-28 ${section}`}>
            <h2 className={blockTitle}>{m.dockLockPageFaqTitle}</h2>
            <Accordion
              type="single"
              collapsible
              className="flex w-full flex-col gap-3"
              onValueChange={(value) => {
                if (value) trackFaqOpen(value);
              }}
            >
              {m.dockLockPageFaq.map((item) => (
                <AccordionItem key={item.question} value={item.question} className={FAQ_CARD}>
                  <AccordionTrigger className={FAQ_TRIGGER}>{item.question}</AccordionTrigger>
                  <AccordionContent className={FAQ_ANSWER}>{item.answer}</AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </section>
      </GuideLayout>

      {/* The closing ask on the header's teal wallpaper, text left and Download right: not the
          homepage's centred Download section */}
      <section data-nav-tone="dark" className="relative mx-3 mb-3 overflow-hidden rounded-[2.5rem] edge-hairline bg-zinc-900 md:mx-4 md:mb-4">
        <TealWallpaper />
        <div className="relative z-10 mx-auto flex max-w-6xl flex-col items-start gap-8 px-6 py-14 md:flex-row md:items-center md:justify-between md:px-10 md:py-20">
          <div>
            <Reveal>
              <h2 className="max-w-132 text-section text-white">
                {m.dockLockPageClosingA}{tileGap(locale)}
                <span className="whitespace-nowrap">
                  <InlineTile tilt="rotate-6">
                    <TileFace gradient="linear-gradient(to bottom, #52DFA8, #10B981)" darkGlyph="#52DFA8" glyph="lock" shaded />
                  </InlineTile>{tileGap(locale)}
                  {m.dockLockPageClosingB}
                </span>
              </h2>
            </Reveal>
            <p className="mt-4 max-w-md text-[15px] leading-relaxed text-pretty text-white/70">{m.dockLockPageClosingNote}</p>
          </div>
          <DownloadActionButton tone="light" location="dock_lock_page" size="lg" label={m.ctaButton} />
        </div>
      </section>

      <Footer />
    </main>
  );
}
