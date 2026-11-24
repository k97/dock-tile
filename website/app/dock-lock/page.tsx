import type { Metadata } from "next";
import { DockLockPage } from "@/components/dock-lock-page";
import { siteConfig } from "@/lib/config";
import { languageAlternates } from "@/lib/nav";
import { dockLockFaqSchema } from "@/lib/schema";

// Keep/drop at the 2027-03-01 review: docs/superpowers/plans/2026-11-23-website-dock-lock-page.md
const title = "Stop the Mac Dock jumping to your other monitor";
const description =
  "With more than one display, the Mac Dock jumps to the screen you push the pointer against. Dock Lock, free with Dock Tile, keeps it on the display you choose.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/dock-lock", languages: languageAlternates("/dock-lock") },
  openGraph: {
    title,
    description,
    url: "/dock-lock",
    siteName: siteConfig.appName,
    type: "website",
    // Defining openGraph here drops the root file-convention image, so re-add it.
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function DockLock() {
  return <DockLockPage schema={dockLockFaqSchema} />;
}
