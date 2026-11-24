// JSON-LD structured data (schema.org) for search engines and AI answer
// engines. Every field is wired to siteConfig or the i18n content the page's SSR
// renders (en-AU; zh-Hans for the /zh-Hans nodes), i.e. what crawlers actually see. Never hardcode
// values here that already live in config.ts or i18n.ts.
import { siteConfig } from "@/lib/config";
import { localisedContent, zhPageMeta } from "@/lib/i18n";

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
  featureList: featureList(m),
};

export const faqPageSchema = faqSchema(content.faq);

// The Chinese pages (/zh-Hans, /zh-Hans/faq): their own app node in Chinese, tied to the
// English one by sameAs; the WebSite and Organization nodes are shared unchanged.
const zh = localisedContent["zh-Hans"];

export const softwareApplicationSchemaZh = {
  ...softwareApplicationSchema,
  "@id": `${siteConfig.siteUrl}/zh-Hans#app`,
  url: `${siteConfig.siteUrl}/zh-Hans`,
  inLanguage: "zh-Hans",
  description: zhPageMeta.homeDescription,
  sameAs: [`${siteConfig.siteUrl}/#app`, siteConfig.githubUrl],
  featureList: featureList(zh.marketing),
};

export const faqPageSchemaZh = { ...faqSchema(zh.faq), inLanguage: "zh-Hans" };

// /dock-lock and /zh-Hans/dock-lock: only the questions those pages show.
export const dockLockFaqSchema = faqSchema(m.dockLockPageFaq);
export const dockLockFaqSchemaZh = { ...faqSchema(zh.marketing.dockLockPageFaq), inLanguage: "zh-Hans" };

// The homepage's own copy, so the schema can't claim what the page doesn't.
function featureList(m: (typeof localisedContent)[keyof typeof localisedContent]["marketing"]) {
  return [
    ...m.introPoints.map((p) => `${p.lead}: ${p.body}`),
    `${m.smartAddTitle} ${m.smartAddBody}`,
    `${m.menuBarTitle} ${m.menuBarBody}`,
    `${m.ghostTitle} ${m.ghostBody}`,
    `${m.dockLockLead} ${m.dockLockBody}`,
    ...m.details.map((d) => `${d.lead}: ${d.body}`),
  ];
}

function faqSchema(faq: readonly { question: string; answer: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faq.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: { "@type": "Answer", text: item.answer },
    })),
  };
}
