import type { Metadata } from "next";
import { HomePage } from "@/components/home-page";
import { siteConfig } from "@/lib/config";
import { zhPageMeta } from "@/lib/i18n";
import { languageAlternates } from "@/lib/nav";
import { softwareApplicationSchemaZh } from "@/lib/schema";

export const metadata: Metadata = {
  title: zhPageMeta.homeTitle,
  description: zhPageMeta.homeDescription,
  alternates: { canonical: "/zh-Hans", languages: languageAlternates("/") },
  openGraph: {
    title: zhPageMeta.homeTitle,
    description: zhPageMeta.homeDescription,
    url: "/zh-Hans",
    siteName: siteConfig.appName,
    type: "website",
    locale: "zh_CN",
    // Defining openGraph here drops the root file-convention image, so re-add it (English card).
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function ZhHome() {
  return <HomePage schema={softwareApplicationSchemaZh} />;
}
