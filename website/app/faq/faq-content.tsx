"use client";

import * as React from "react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { ContactCta } from "@/components/contact-cta";
import { Footer } from "@/components/footer";
import { Reveal } from "@/components/reveal";
import { useLocale } from "@/components/locale-provider";
import { slugify } from "@/lib/i18n";
import { trackExternalLinkClick, trackFaqOpen } from "@/lib/analytics";
import { bugReportUrl, featureRequestUrl } from "@/lib/feedback";
import { ArrowUpRight, Bug, Lightbulb } from "lucide-react";

export function FaqContent() {
  const { content } = useLocale();
  const m = content.marketing;
  const [openItem, setOpenItem] = React.useState<string | undefined>(undefined);

  // Handle initial hash on mount and hash changes
  React.useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.slice(1); // Remove the #
      if (hash) {
        // Check if hash matches any FAQ slug
        const matchingFaq = content.faq.find(
          (item) => slugify(item.question) === hash
        );
        if (matchingFaq) {
          const slug = slugify(matchingFaq.question);
          setOpenItem(slug);
          // Scroll to the element after a short delay to ensure accordion is open
          setTimeout(() => {
            const element = document.getElementById(slug);
            if (element) {
              element.scrollIntoView({ behavior: "smooth", block: "center" });
            }
          }, 100);
        }
      }
    };

    // Check hash on mount
    handleHashChange();

    // Listen for hash changes
    window.addEventListener("hashchange", handleHashChange);
    return () => window.removeEventListener("hashchange", handleHashChange);
  }, [content.faq]);

  // Update URL hash when accordion item changes
  const handleValueChange = (value: string | undefined) => {
    setOpenItem(value);
    if (value) {
      // Update URL without scrolling
      window.history.replaceState(null, "", `#${value}`);
      // Track FAQ open event
      const matchingFaq = content.faq.find(
        (item) => slugify(item.question) === value
      );
      if (matchingFaq) {
        trackFaqOpen(matchingFaq.question);
      }
    } else {
      // Remove hash from URL
      window.history.replaceState(null, "", window.location.pathname);
    }
  };

  return (
    <main className="bg-background">
      {/* Dark hero band */}
      <section data-nav-tone="dark" className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] bg-black px-6 pb-16 pt-28 text-center md:mx-4 md:mt-4 md:pb-20 md:pt-36">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
        <div className="relative z-10">
          <span
            className="reveal mb-3 block text-[14px] font-semibold tracking-[0.01em] text-white/75"
            style={{ "--reveal-delay": "0ms" } as React.CSSProperties}
          >
            FAQ
          </span>
          <h1
            className="reveal text-3xl heading-display text-white md:text-5xl"
            style={{ "--reveal-delay": "80ms" } as React.CSSProperties}
          >
            Questions,
            <br />
            <span className="text-white/40">answered.</span>
          </h1>
        </div>
      </section>

      {/* Light accordion section */}
      <section className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
        <Accordion
          type="single"
          collapsible
          className="flex w-full flex-col gap-3"
          value={openItem}
          onValueChange={handleValueChange}
        >
          {/* Each card reveals on its own short delay rather than the whole
              list fading up as one slab. Capped at 300ms so a long FAQ never
              leaves the last cards waiting. */}
          {content.faq.map((item, i) => {
            const slug = slugify(item.question);
            return (
              <Reveal key={slug} delay={Math.min(i * 60, 300)}>
                <AccordionItem
                  value={slug}
                  id={slug}
                  // Layered, transparent shadows give the card depth on any
                  // surface and lift a touch on open; the hairline border stays
                  // only to keep the closed cards legible against the zinc-100
                  // page. Explicit properties — never `transition-all`.
                  className="relative overflow-hidden rounded-2xl border border-border bg-card shadow-[0_1px_2px_rgba(0,0,0,0.03),0_4px_12px_-6px_rgba(0,0,0,0.06)] transition-[border-color,box-shadow] duration-300 data-[state=open]:border-zinc-300 data-[state=open]:shadow-[0_1px_2px_rgba(0,0,0,0.04),0_12px_28px_-12px_rgba(0,0,0,0.14)] dark:data-[state=open]:border-zinc-700 before:absolute before:bottom-0 before:left-0 before:top-0 before:w-1 before:bg-emerald-400 before:opacity-0 before:transition-opacity data-[state=open]:before:opacity-100"
                >
                  <AccordionTrigger className="px-6 py-5 text-left text-[15px] font-semibold text-balance text-foreground hover:no-underline [&>svg]:text-muted-foreground">
                    {item.question}
                  </AccordionTrigger>
                  <AccordionContent className="px-6 pb-6 text-[15px] leading-relaxed text-pretty text-muted-foreground">
                    {item.answer}
                  </AccordionContent>
                </AccordionItem>
              </Reveal>
            );
          })}
        </Accordion>

        {/* Reached the end without an answer: ask for it, or report what broke.
            Same card surface as the questions above, so it reads as their
            continuation rather than an ad. */}
        <Reveal className="mt-16">
          <h2 className="mb-4 text-lg font-semibold tracking-[-0.02em] text-foreground">{m.feedbackTitle}</h2>
          <div className="grid gap-3 sm:grid-cols-2">
            {[
              { href: featureRequestUrl, Icon: Lightbulb, title: m.featureRequest, body: m.featureRequestBody },
              { href: bugReportUrl, Icon: Bug, title: m.bugReport, body: m.bugReportBody },
            ].map(({ href, Icon, title, body }) => (
              <a
                key={title}
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => trackExternalLinkClick(href, "faq")}
                className="group pressable flex gap-4 rounded-2xl border border-border bg-card p-5 shadow-[0_1px_2px_rgba(0,0,0,0.03),0_4px_12px_-6px_rgba(0,0,0,0.06)] transition-[border-color,box-shadow,scale] duration-300 hover:border-zinc-300 hover:shadow-[0_1px_2px_rgba(0,0,0,0.04),0_12px_28px_-12px_rgba(0,0,0,0.14)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500 dark:hover:border-zinc-700"
              >
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-foreground/6 text-foreground">
                  <Icon strokeWidth={1.5} className="h-4.5 w-4.5" />
                </span>
                <span className="flex-1">
                  <span className="flex items-center gap-1 text-[15px] font-semibold text-foreground">
                    {title}
                    {/* the arrow nudges toward where the link goes; a child moves, not the card */}
                    <ArrowUpRight
                      aria-hidden
                      className="h-3.5 w-3.5 text-muted-foreground transition-transform duration-300 group-hover:-translate-y-px group-hover:translate-x-px motion-reduce:transition-none"
                    />
                  </span>
                  <span className="mt-1 block text-sm leading-relaxed text-muted-foreground">{body}</span>
                  <span className="sr-only"> {m.opensInNewTab}</span>
                </span>
              </a>
            ))}
          </div>
          <p className="mt-4 text-sm text-muted-foreground">{m.feedbackNote}</p>
        </Reveal>
      </section>

      {/* Compact dark CTA band */}
      <ContactCta
        title="Still stuck?"
        subtitle="Send a note and you'll usually hear back within a day."
      />

      <Footer />
    </main>
  );
}
