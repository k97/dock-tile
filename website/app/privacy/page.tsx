import type { Metadata } from "next";
import { siteConfig } from "@/lib/config";
import { PrivacyContent } from "./privacy-content";

const title = `Privacy Policy - ${siteConfig.appName}`;
const description =
  "How Dock Tile handles your data — optional anonymous analytics with an in-app opt-out, on-device Smart Add suggestions, and what's stored on your Mac.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/privacy" },
  openGraph: {
    title,
    description,
    url: "/privacy",
    siteName: siteConfig.appName,
    type: "website",
    // Defining openGraph here drops the root file-convention image, so re-add it.
    images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630 }],
  },
};

export default function PrivacyPage() {
  return <PrivacyContent />;
}
