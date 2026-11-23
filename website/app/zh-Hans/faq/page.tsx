import type { Metadata } from "next";
import { JsonLd } from "@/components/json-ld";
import { siteConfig } from "@/lib/config";
import { zhPageMeta } from "@/lib/i18n";
import { languageAlternates } from "@/lib/nav";
import { faqPageSchemaZh } from "@/lib/schema";
import { FaqContent } from "@/app/faq/faq-content";

export const metadata: Metadata = {
  title: zhPageMeta.faqTitle,
  description: zhPageMeta.faqDescription,
  alternates: { canonical: "/zh-Hans/faq", languages: languageAlternates("/faq") },
  openGraph: {
    title: zhPageMeta.faqTitle,
    description: zhPageMeta.faqDescription,
    url: "/zh-Hans/faq",
    siteName: siteConfig.appName,
    type: "website",
    locale: "zh_CN",
    // Defining openGraph here drops the root file-convention image, so re-add it (English card).
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function ZhFaqPage() {
  return (
    <>
      <JsonLd data={faqPageSchemaZh} />
      <FaqContent />
    </>
  );
}
