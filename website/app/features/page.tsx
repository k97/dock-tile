import type { Metadata } from "next";
import { siteConfig } from "@/lib/config";
import { FeaturesContent } from "@/components/features-content";

export const metadata: Metadata = {
  title: `Features — ${siteConfig.appName}`,
  description:
    "Custom Dock tiles, grid and list popovers, Smart Add suggestions, Dock Lock, Tahoe icon styles and more — everything Dock Tile adds to your Mac.",
};

export default function FeaturesPage() {
  return <FeaturesContent />;
}
