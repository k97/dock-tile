"use client";

import * as React from "react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Footer } from "@/components/footer";
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
    <div className="min-h-screen flex flex-col">
      <div className="flex-1 pt-26 pb-12 px-4">
        <main className="max-w-2xl mx-auto">
          <h1 className="text-xl md:text-3xl font-display mb-12 text-center">Frequently Asked Questions</h1>

          <Accordion
            type="single"
            collapsible
            className="w-full"
            value={openItem}
            onValueChange={handleValueChange}
          >
            {content.faq.map((item) => {
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
        </main>
      </div>
      <Footer />
    </div>
  );
}
