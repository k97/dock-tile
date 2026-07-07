import type { Metadata } from "next";
import { siteConfig } from "@/lib/config";
import { PrivacyContent } from "./privacy-content";

export const metadata: Metadata = {
  title: `Privacy Policy - ${siteConfig.appName}`,
  description: `Privacy policy for ${siteConfig.appName}, a macOS utility app.`,
};

export default function PrivacyPage() {
  return <PrivacyContent />;
}
