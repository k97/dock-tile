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
import { trackFaqOpen } from "@/lib/analytics";

export default function FAQPage() {
  const { content } = useLocale();
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
            className="reveal mb-3 block text-[12px] font-bold uppercase tracking-[0.2em] text-white/60"
            style={{ "--reveal-delay": "0ms" } as React.CSSProperties}
          >
            FAQ
          </span>
          <h1
            className="reveal text-3xl font-bold tracking-[-0.05em] leading-[1.05] text-white md:text-5xl"
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
        <Reveal>
          <Accordion
            type="single"
            collapsible
            className="flex w-full flex-col gap-3"
            value={openItem}
            onValueChange={handleValueChange}
          >
            {content.faq.map((item) => {
              const slug = slugify(item.question);
              return (
                <AccordionItem
                  key={slug}
                  value={slug}
                  id={slug}
                  className="relative overflow-hidden rounded-2xl border border-border bg-card transition-colors last:border-b data-[state=open]:border-zinc-300 dark:data-[state=open]:border-zinc-700 before:absolute before:bottom-0 before:left-0 before:top-0 before:w-1 before:bg-emerald-400 before:opacity-0 before:transition-opacity data-[state=open]:before:opacity-100"
                >
                  <AccordionTrigger className="px-6 py-5 text-left text-[15px] font-semibold text-foreground hover:no-underline [&>svg]:text-muted-foreground">
                    {item.question}
                  </AccordionTrigger>
                  <AccordionContent className="px-6 pb-6 text-[15px] font-light leading-relaxed text-muted-foreground">
                    {item.answer}
                  </AccordionContent>
                </AccordionItem>
              );
            })}
          </Accordion>
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
