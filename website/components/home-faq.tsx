"use client";

import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { TileFace } from "@/components/dock-demo";
import { InlineTile } from "@/components/inline-tile";
import { useLocale } from "@/components/locale-provider";
import { Reveal } from "@/components/reveal";
import { slugify } from "@/lib/i18n";
import { trackFaqOpen } from "@/lib/analytics";
import { FAQ_ANSWER, FAQ_CARD, FAQ_TRIGGER } from "@/components/faq-card";

// The questions a first-time visitor asks before downloading, by /faq slug.
// The copy lives once, in `content.faq`.
const TOP_QUESTIONS = [
  "is-dock-tile-free",
  "what-macos-version-do-i-need",
  "is-it-available-on-the-app-store",
  "what-does-dock-tile-change-on-my-mac",
  "how-do-i-uninstall-dock-tile",
];

export function HomeFaq() {
  const { content } = useLocale();
  const m = content.marketing;
  const items = TOP_QUESTIONS.map((slug) => content.faq.find((f) => slugify(f.question) === slug)).filter(
    (f) => f !== undefined,
  );
  if (process.env.NODE_ENV === "development" && items.length !== TOP_QUESTIONS.length) {
    console.warn("HomeFaq: a TOP_QUESTIONS slug no longer matches a question in content.faq");
  }

  return (
    <section className="mx-auto max-w-400 px-4 py-24 sm:px-6 md:px-10 md:py-50">
      <Reveal className="mb-12 text-center md:mb-13">
        <h2 className="mx-auto max-w-132 text-section text-foreground">
          {m.homeFaqTitleA}{" "}
          <span className="whitespace-nowrap">
            <InlineTile tilt="-rotate-6">
              <TileFace gradient="linear-gradient(to bottom, #818CF8, #4F46E5)" darkGlyph="#818CF8" glyph="question" shaded />
            </InlineTile>{" "}
            {m.homeFaqTitleB}
          </span>
        </h2>
      </Reveal>

      <Accordion
        type="single"
        collapsible
        className="mx-auto flex w-full max-w-3xl flex-col gap-3"
        onValueChange={(slug) => {
          const item = items.find((f) => slugify(f.question) === slug);
          if (item) trackFaqOpen(item.question);
        }}
      >
        {items.map((item, i) => {
          const slug = slugify(item.question);
          return (
            <Reveal key={slug} delay={i * 60}>
              <AccordionItem value={slug} className={FAQ_CARD}>
                <AccordionTrigger className={FAQ_TRIGGER}>{item.question}</AccordionTrigger>
                <AccordionContent className={FAQ_ANSWER}>{item.answer}</AccordionContent>
              </AccordionItem>
            </Reveal>
          );
        })}
      </Accordion>

      <Reveal className="mt-10 flex justify-center">
        <Link
          href="/faq"
          className="pressable group inline-flex h-13 items-center gap-2 rounded-full border border-foreground/15 px-6 text-sm font-semibold text-foreground transition-[background-color,scale] duration-200 hover:bg-foreground/5"
        >
          {m.homeFaqMore}
          <ArrowRight className="h-4 w-4 transition-transform duration-200 group-hover:translate-x-0.5" />
        </Link>
      </Reveal>
    </section>
  );
}
