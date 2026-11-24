"use client";

import * as React from "react";
import { Layers, Lock, Monitor, PanelBottom } from "lucide-react";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { DownloadActionButton } from "@/components/action-button";
import { DockLockMock } from "@/components/dock-lock-mock";
import { TileFace } from "@/components/dock-demo";
import { FAQ_ANSWER, FAQ_CARD, FAQ_TRIGGER } from "@/components/faq-card";
import { Footer } from "@/components/footer";
import { InlineTile } from "@/components/inline-tile";
import { JsonLd } from "@/components/json-ld";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { trackFaqOpen } from "@/lib/analytics";

const reveal = (ms: number) => ({ "--reveal-delay": `${ms}ms` }) as React.CSSProperties;
const blockTitle = "mb-4 text-title text-foreground";
// Paired with `dockLockPageBenefits` in lib/i18n.ts by position — reorder both together.
const benefitIcons = [Lock, Monitor, Layers, PanelBottom];

/**
 * /dock-lock and /zh-Hans/dock-lock (the route's locale picks the copy): the page that answers
 * "the Dock keeps moving to my other monitor" and offers Dock Lock. A centred dark header (the
 * Download is here), a row of four benefits, a prose column, its own questions, then Download.
 */
export function DockLockPage({ schema }: { schema: Record<string, unknown> }) {
  const { content } = useLocale();
  const m = content.marketing;
  const dot = <span className="h-1 w-1 rounded-full bg-white/20" />;

  return (
    <main className="bg-background">
      <JsonLd data={schema} />

      {/* Centred like the other subpage headers: the homepage's Dock Lock band owns the split text +
          animation layout, so the animation sits under "Why the Dock moves" here */}
      <section
        data-nav-tone="dark"
        className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] border border-white/10 bg-zinc-900 px-6 pt-28 pb-16 text-center md:mx-4 md:mt-4 md:pt-36 md:pb-20"
      >
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-950/40" />
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

      {/* The homepage's small-feature row: name on its own line, one muted sentence */}
      <section className="mx-auto max-w-6xl px-4 pt-16 sm:px-6 md:px-10 md:pt-24">
        <ul className="grid grid-cols-1 gap-x-8 gap-y-10 px-2 sm:grid-cols-2 lg:grid-cols-4">
          {m.dockLockPageBenefits.map((b, i) => {
            const Icon = benefitIcons[i];
            return (
              <Reveal as="li" key={b.lead} delay={i * 60} className="flex flex-col">
                <span className="mb-4 flex h-9 w-9 items-center justify-center rounded-xl bg-foreground/6 text-foreground">
                  <Icon strokeWidth={1.5} className="h-4.5 w-4.5" />
                </span>
                <p className="text-lead font-medium text-foreground">{b.lead}</p>
                <p className="mt-1 text-lead text-muted-foreground">{b.body}</p>
              </Reveal>
            );
          })}
        </ul>
      </section>

      <section className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
        <Reveal>
          <h2 className={blockTitle}>{m.dockLockPageWhyTitle}</h2>
          <p className="text-lead text-muted-foreground">{m.dockLockPageWhyBody}</p>
          <div className="mt-8">
            <DockLockMock />
          </div>
        </Reveal>

        <Reveal className="mt-16 md:mt-20">
          <h2 className={blockTitle}>{m.dockLockPageStepsTitle}</h2>
          <ol className="flex flex-col gap-5 rounded-2xl border border-border bg-card p-6 md:p-8">
            {m.dockLockPageSteps.map((step, i) => (
              <li key={step} className="flex gap-4">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-emerald-400/15 text-sm font-semibold text-emerald-700 dark:text-emerald-300">
                  {i + 1}
                </span>
                <span className="pt-0.5 text-lead text-foreground">{step}</span>
              </li>
            ))}
          </ol>
          <div className="mt-5 flex items-start gap-3">
            <Lock className="mt-0.5 h-5 w-5 shrink-0 text-emerald-600 dark:text-emerald-400" />
            <p className="text-[15px] leading-relaxed text-muted-foreground">{m.dockLockPageStepsNote}</p>
          </div>
        </Reveal>

        <Reveal className="mt-16 md:mt-20">
          <h2 className={blockTitle}>{m.dockLockPageWithoutTitle}</h2>
          <p className="text-lead text-muted-foreground">{m.dockLockPageWithoutBody}</p>
        </Reveal>

        <Reveal className="mt-16 md:mt-20">
          <h2 className={blockTitle}>{m.dockLockPageFaqTitle}</h2>
        </Reveal>
        <Accordion
          type="single"
          collapsible
          className="flex w-full flex-col gap-3"
          onValueChange={(value) => {
            if (value) trackFaqOpen(value);
          }}
        >
          {m.dockLockPageFaq.map((item, i) => (
            <Reveal key={item.question} delay={i * 60}>
              <AccordionItem value={item.question} className={FAQ_CARD}>
                <AccordionTrigger className={FAQ_TRIGGER}>{item.question}</AccordionTrigger>
                <AccordionContent className={FAQ_ANSWER}>{item.answer}</AccordionContent>
              </AccordionItem>
            </Reveal>
          ))}
        </Accordion>
      </section>

      {/* The closing ask, like the homepage's Download section; follows the prose column, so only md:pt-12 */}
      <section className="mx-auto flex max-w-400 flex-col items-center px-4 pt-8 pb-24 text-center sm:px-6 md:px-10 md:pt-12 md:pb-50">
        <Reveal className="flex flex-col items-center">
          <h2 className="mx-auto max-w-132 text-section text-foreground">
            {m.dockLockPageClosingA}{" "}
            <span className="whitespace-nowrap">
              <InlineTile tilt="rotate-6">
                <TileFace gradient="linear-gradient(to bottom, #52DFA8, #10B981)" darkGlyph="#52DFA8" glyph="lock" shaded />
              </InlineTile>{" "}
              {m.dockLockPageClosingB}
            </span>
          </h2>
          <div className="mt-10 flex flex-col items-center gap-5">
            <DownloadActionButton tone="adaptive" location="dock_lock_page" size="lg" label={m.ctaButton} />
            <p className="max-w-md text-[15px] leading-relaxed text-pretty text-muted-foreground">{m.dockLockPageClosingNote}</p>
          </div>
        </Reveal>
      </section>

      <Footer />
    </main>
  );
}
