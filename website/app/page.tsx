import type { Metadata } from "next";
import { HomePage } from "@/components/home-page";
import { softwareApplicationSchema } from "@/lib/schema";
import { languageAlternates } from "@/lib/nav";

// Title, description and openGraph come from the root layout; only the alternates are the page's.
export const metadata: Metadata = {
  alternates: { canonical: "/", languages: languageAlternates("/") },
};

export default function Home() {
  return <HomePage schema={softwareApplicationSchema} />;
}
