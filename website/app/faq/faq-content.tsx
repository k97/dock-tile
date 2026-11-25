"use client";

import * as React from "react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { ContactCta } from "@/components/contact-cta";
import { FAQ_ANSWER, FAQ_CARD, FAQ_TRIGGER } from "@/components/faq-card";
import { Footer } from "@/components/footer";
import { GuideLayout } from "@/components/guide-layout";
import { Reveal } from "@/components/reveal";
import { useLocale } from "@/components/locale-provider";
import { trackExternalLinkClick, trackFaqOpen } from "@/lib/analytics";
import { bugReportUrl, featureRequestUrl } from "@/lib/feedback";
import { ArrowUpRight, Bug, Lightbulb } from "lucide-react";

// The page's groups, in order, by slug; headings are `marketing.faqGroups` by position.
// Every question must be in one group: a dev warning names any that is not (it would vanish).
const FAQ_GROUPS = [
  [
    "what-macos-version-do-i-need",
    "is-it-available-on-the-app-store",
    "is-dock-tile-free",
    "how-do-i-group-apps-into-folders-in-the-mac-dock",
    "how-is-a-tile-different-from-a-folder-in-the-dock",
    "how-do-i-create-a-new-tile",
    "how-many-tiles-can-i-create",
  ],
  [
    "can-i-change-a-tiles-icon-after-creating-it",
    "can-i-reorder-apps-within-a-tile",
    "can-i-add-folders-to-a-tile",
    "whats-the-difference-between-grid-and-list-layout",
    "why-doesnt-right-click-show-a-context-menu",
    "do-tiles-sync-across-macs",
    "how-do-i-back-up-my-tiles",
  ],
  ["how-do-i-stop-the-dock-moving-to-my-other-display", "what-is-a-dock-tile-extension"],
  ["what-does-dock-tile-change-on-my-mac", "how-do-i-uninstall-a-tile", "how-do-i-uninstall-dock-tile"],
];
// Anchors for the group headings (the "On this page" list), by position; English on both locales
const FAQ_GROUP_IDS = ["getting-started", "using-tiles", "dock-lock-and-displays", "your-mac-and-removing-it"];

export function FaqContent() {
  const { content } = useLocale();
  const m = content.marketing;
  const [openItem, setOpenItem] = React.useState<string | undefined>(undefined);
  const groups = FAQ_GROUPS.map((slugs) =>
    slugs.map((slug) => content.faq.find((f) => f.slug === slug)).filter((f) => f !== undefined),
  );
  if (process.env.NODE_ENV === "development") {
    const grouped = new Set(FAQ_GROUPS.flat());
    const missing = content.faq.filter((f) => !grouped.has(f.slug)).map((f) => f.slug);
    if (missing.length) console.warn("FAQ: not in any group, so not shown:", missing);
  }

  // Handle initial hash on mount and hash changes
  React.useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.slice(1); // Remove the #
      if (hash) {
        // Check if hash matches any FAQ slug
        const matchingFaq = content.faq.find(
          (item) => item.slug === hash
        );
        if (matchingFaq) {
          const slug = matchingFaq.slug;
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
        (item) => item.slug === value
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
      <section data-nav-tone="dark" className="relative mx-3 mt-3 overflow-hidden rounded-[2.5rem] border border-white/10 bg-black px-6 pb-16 pt-28 text-center md:mx-4 md:mt-4 md:pb-20 md:pt-36">
        <div className="grain" />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-zinc-900/60" />
        <div className="relative z-10">
          <span
            className="reveal mb-3 block text-[14px] font-semibold tracking-[0.01em] text-white/75"
            style={{ "--reveal-delay": "0ms" } as React.CSSProperties}
          >
            {m.footerFaq}
          </span>
          <h1
            className="reveal text-3xl heading-display text-white md:text-5xl"
            style={{ "--reveal-delay": "80ms" } as React.CSSProperties}
          >
            {m.homeFaqTitleA}
            <br />
            <span className="text-white/40">{m.homeFaqTitleB}</span>
          </h1>
        </div>
      </section>

      {/* The questions in GuideLayout: its "On this page" list is the groups + Help shape */}
      <GuideLayout
        items={[
          ...FAQ_GROUP_IDS.map((id, g) => ({ id, title: m.faqGroups[g] })),
          { id: "help-shape", title: m.feedbackTitle },
        ]}
      >
        {/* One accordion, so one question is open at a time across groups; the group
            headings sit between its items. No fade-in: body text never fades. */}
        <Accordion
          type="single"
          collapsible
          className="flex w-full flex-col gap-3"
          value={openItem}
          onValueChange={handleValueChange}
        >
          {groups.map((items, g) => (
            <React.Fragment key={m.faqGroups[g]}>
              <h2 id={FAQ_GROUP_IDS[g]} className={`scroll-mt-28 text-lg font-semibold tracking-[-0.02em] text-foreground ${g === 0 ? "mb-1" : "mt-10 mb-1"}`}>
                {m.faqGroups[g]}
              </h2>
              {items.map((item) => (
                <AccordionItem key={item.slug} value={item.slug} id={item.slug} className={FAQ_CARD}>
                  <AccordionTrigger className={FAQ_TRIGGER}>{item.question}</AccordionTrigger>
                  <AccordionContent className={FAQ_ANSWER}>{item.answer}</AccordionContent>
                </AccordionItem>
              ))}
            </React.Fragment>
          ))}
        </Accordion>

        {/* Reached the end without an answer: ask for it, or report what broke.
            Same card surface as the questions above, so it reads as their
            continuation rather than an ad. */}
        <Reveal className="mt-16">
          <h2 id="help-shape" className="mb-4 scroll-mt-28 text-lg font-semibold tracking-[-0.02em] text-foreground">{m.feedbackTitle}</h2>
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
        </Reveal>
        {/* Body text never fades in */}
        <p className="mt-4 text-sm text-muted-foreground">{m.feedbackNote}</p>
      </GuideLayout>

      {/* Contact CTA, styled like the homepage's Download section */}
      <ContactCta
        title={m.faqCtaTitle}
        subtitle={m.faqCtaSubtitle}
      />

      <Footer />
    </main>
  );
}
