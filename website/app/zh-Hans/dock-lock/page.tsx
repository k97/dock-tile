import type { Metadata } from "next";
import { DockLockPage } from "@/components/dock-lock-page";
import { siteConfig } from "@/lib/config";
import { zhPageMeta } from "@/lib/i18n";
import { languageAlternates } from "@/lib/nav";
import { dockLockFaqSchemaZh } from "@/lib/schema";

export const metadata: Metadata = {
  title: zhPageMeta.dockLockTitle,
  description: zhPageMeta.dockLockDescription,
  alternates: { canonical: "/zh-Hans/dock-lock", languages: languageAlternates("/dock-lock") },
  openGraph: {
    title: zhPageMeta.dockLockTitle,
    description: zhPageMeta.dockLockDescription,
    url: "/zh-Hans/dock-lock",
    siteName: siteConfig.appName,
    type: "website",
    locale: "zh_CN",
    // Defining openGraph here drops the root file-convention image, so re-add it (English card).
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function ZhDockLock() {
  return <DockLockPage schema={dockLockFaqSchemaZh} />;
}
