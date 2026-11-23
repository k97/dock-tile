// JSON-LD structured data (schema.org) for search engines and AI answer
// engines. Every field is wired to siteConfig or the en-AU i18n content —
// the variant SSR renders, i.e. what crawlers actually see. Never hardcode
// values here that already live in config.ts or i18n.ts.
import { siteConfig } from "@/lib/config";
import { localisedContent } from "@/lib/i18n";

const content = localisedContent["en-AU"];
const m = content.marketing;

// Dock Tile is made and published by the studio, Happy Machines Company. The
// app's `sameAs` (its GitHub repo) is what disambiguates "Dock Tile" the app
// from Apple's NSDockTile API when AI engines resolve the entity. The `@id`s
// let engines join the page's blocks into one graph.
const organization = {
  "@type": "Organization",
  "@id": `${siteConfig.authorUrl}/#organization`,
  name: siteConfig.authorName,
  url: siteConfig.authorUrl,
};

export const websiteSchema = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  "@id": `${siteConfig.siteUrl}/#website`,
  name: siteConfig.appName,
  url: siteConfig.siteUrl,
  publisher: organization,
};

export const softwareApplicationSchema = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "@id": `${siteConfig.siteUrl}/#app`,
  name: siteConfig.appName,
  description: siteConfig.description,
  url: siteConfig.siteUrl,
  applicationCategory: "UtilitiesApplication",
  operatingSystem: "macOS 15.0 or later",
  processorRequirements: "Apple silicon (arm64)",
  softwareVersion: siteConfig.latestVersion,
  downloadUrl: siteConfig.downloadUrl,
  releaseNotes: `${siteConfig.siteUrl}/release-notes`,
  screenshot: `${siteConfig.siteUrl}/assets/stage/dock-tiles.webp`,
  offers: {
    "@type": "Offer",
    price: 0,
    priceCurrency: "USD",
  },
  isAccessibleForFree: true,
  license: `${siteConfig.githubUrl}/blob/main/LICENSE`,
  author: organization,
  publisher: organization,
  sameAs: [siteConfig.githubUrl],
  // The homepage's own copy, so the schema can't claim what the page doesn't.
  featureList: [
    ...m.introPoints.map((p) => `${p.lead}: ${p.body}`),
    `${m.smartAddTitle} ${m.smartAddBody}`,
    `${m.menuBarTitle} ${m.menuBarBody}`,
    `${m.ghostTitle} ${m.ghostBody}`,
    `${m.dockLockLead} ${m.dockLockBody}`,
    ...m.details.map((d) => `${d.lead}: ${d.body}`),
  ],
};

export const faqPageSchema = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: content.faq.map((item) => ({
    "@type": "Question",
    name: item.question,
    acceptedAnswer: { "@type": "Answer", text: item.answer },
  })),
};
