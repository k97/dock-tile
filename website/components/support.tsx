"use client";

import { useLocale } from "@/components/locale-provider";
import { siteConfig } from "@/lib/config";
import { trackContactClick } from "@/lib/analytics";

export function Support() {
  const { content } = useLocale();

  return (
    <section className="px-4 py-8 md:py-12 max-w-2xl mx-auto text-center">
      <h2 className="text-2xl md:text-3xl font-display mb-4">
        {content.supportTitle}
      </h2>
      <p className="text-muted-foreground">
        {content.supportText}{" "}
        <a
          href={`mailto:${siteConfig.contactEmail}`}
          className="text-primary underline underline-offset-4 hover:text-primary/80 transition-colors"
          onClick={trackContactClick}
        >
          {content.supportLink}
        </a>
        .
      </p>
    </section>
  );
}
