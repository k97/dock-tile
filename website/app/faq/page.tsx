import type { Metadata } from "next";
import { JsonLd } from "@/components/json-ld";
import { siteConfig } from "@/lib/config";
import { faqPageSchema } from "@/lib/schema";
import { FaqContent } from "./faq-content";

const title = `Frequently Asked Questions - ${siteConfig.appName}`;
const description =
  "Answers to common Dock Tile questions — macOS 26 (Tahoe) requirements, creating and customising tiles, Ghost Mode, backups, and Grid vs List layouts.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/faq" },
  openGraph: {
    title,
    description,
    url: "/faq",
    siteName: siteConfig.appName,
    type: "website",
    // Defining openGraph here drops the root file-convention image, so re-add it.
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function FAQPage() {
  return (
    <>
      <JsonLd data={faqPageSchema} />
      <FaqContent />
    </>
  );
}
