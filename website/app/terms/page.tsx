import type { Metadata } from "next";
import { siteConfig } from "@/lib/config";
import { TermsContent } from "./terms-content";

const title = `Terms of Use - ${siteConfig.appName}`;
const description =
  "Terms of use for the Dock Tile macOS app, covering the licence, direct-download distribution, and automatic updates.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/terms" },
  openGraph: {
    title,
    description,
    url: "/terms",
    siteName: siteConfig.appName,
    type: "website",
    // Defining openGraph here drops the root file-convention image, so re-add it.
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function TermsPage() {
  return <TermsContent />;
}
