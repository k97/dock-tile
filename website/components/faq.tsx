"use client";

import * as React from "react";
import Link from "next/link";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Button } from "@/components/ui/button";
import { useLocale } from "@/components/locale-provider";
import { slugify } from "@/lib/i18n";
import { trackFaqOpen } from "@/lib/analytics";

const HOMEPAGE_FAQ_COUNT = 4;

export function FAQ() {
  const { content } = useLocale();
  const [openItem, setOpenItem] = React.useState<string | undefined>(undefined);

  // Only show first 4 FAQs on homepage
  const displayedFaqs = content.faq.slice(0, HOMEPAGE_FAQ_COUNT);

  // Update URL hash when accordion item changes
  const handleValueChange = (value: string | undefined) => {
    setOpenItem(value);
    if (value) {
      // Track FAQ open event
      const matchingFaq = content.faq.find(
        (item) => slugify(item.question) === value
      );
      if (matchingFaq) {
        trackFaqOpen(matchingFaq.question);
      }
    }
  };

  return (
    <section className="px-4 py-12 md:py-16 max-w-2xl mx-auto">
      <h2 className="text-2xl md:text-3xl font-display text-center mb-8">
        Frequently Asked Questions
      </h2>

      <Accordion
        type="single"
        collapsible
        className="w-full"
        value={openItem}
        onValueChange={handleValueChange}
      >
        {displayedFaqs.map((item) => {
          const slug = slugify(item.question);
          return (
            <AccordionItem key={slug} value={slug} id={slug}>
              <AccordionTrigger className="text-left">
                {item.question}
              </AccordionTrigger>
              <AccordionContent className="text-muted-foreground">
                {item.answer}
              </AccordionContent>
            </AccordionItem>
          );
        })}
      </Accordion>

      {content.faq.length > HOMEPAGE_FAQ_COUNT && (
        <div className="mt-6 text-center">
          <Button variant="outline" className="rounded-xl" asChild>
            <Link href="/faq">More FAQs</Link>
          </Button>
        </div>
      )}
    </section>
  );
}
