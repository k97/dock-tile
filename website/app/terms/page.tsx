import type { Metadata } from "next";
import { siteConfig } from "@/lib/config";
import { TermsContent } from "./terms-content";

export const metadata: Metadata = {
  title: `Terms of Use - ${siteConfig.appName}`,
  description: `Terms of use for ${siteConfig.appName}, a macOS utility app.`,
};

export default function TermsPage() {
  return <TermsContent />;
}
