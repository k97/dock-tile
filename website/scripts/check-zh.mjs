// Drift check for the Simplified Chinese test pages (run beside lint: `npm run check:zh`).
//
// docs/l10n/website-zh-Hans.md records, per key, the English a Chinese string was translated
// from. This fails (exit 1) when an English string in lib/i18n.ts no longer equals the English
// in the sheet (the Chinese is stale), when a key is in one but not the other, or when the
// sheet's Chinese differs from lib/i18n.ts (a reviewed row not copied over, or the reverse).
// `meta.*` rows (page titles and descriptions) keep their English in siteConfig and the FAQ
// page, which this can't import, so only their Chinese is compared.
//
// Node 22.18+ runs lib/i18n.ts directly (type stripping); no dependencies.
import { readFileSync } from "node:fs";

const root = new URL("..", import.meta.url);
const sheetPath = new URL("../docs/l10n/website-zh-Hans.md", root);
const { localisedContent, zhPageMeta } = await import(new URL("lib/i18n.ts", root));

/** Every string a locale shows on / and /faq, by a stable key (legal pages stay English). */
function flatten(content) {
  const out = new Map();
  const walk = (prefix, value) => {
    if (typeof value === "string") out.set(prefix, value);
    else if (Array.isArray(value)) value.forEach((v, i) => walk(`${prefix}.${i}`, v));
    else for (const [k, v] of Object.entries(value)) walk(prefix ? `${prefix}.${k}` : k, v);
  };
  const { faq, ...rest } = content;
  delete rest.legal; // English-only pages
  delete rest.names; // rows of their own, below
  walk("", rest);
  for (const item of faq) {
    out.set(`faq.${item.slug}.question`, item.question);
    out.set(`faq.${item.slug}.answer`, item.answer);
  }
  return out;
}

const en = flatten(localisedContent["en-AU"]);
const zh = flatten(localisedContent["zh-Hans"]);
for (const [name, value] of Object.entries(localisedContent["zh-Hans"].names)) {
  en.set(`names.${name}`, name); // a name's English is its key
  zh.set(`names.${name}`, value);
}
for (const [k, v] of Object.entries(zhPageMeta)) zh.set(`meta.${k}`, v);

// Sheet rows: | `key` | English | 简体中文 | status | note |  (a literal | is written \|)
const sheet = new Map();
for (const line of readFileSync(sheetPath, "utf8").split("\n")) {
  if (!line.startsWith("| `")) continue;
  const cells = line
    .slice(1, -1)
    .split(/(?<!\\)\|/)
    .map((c) => c.trim().replaceAll("\\|", "|"));
  sheet.set(cells[0].replaceAll("`", ""), { english: cells[1], chinese: cells[2] });
}

const problems = [];
for (const [key, english] of en) {
  const row = sheet.get(key);
  if (!row) problems.push(`${key}: in lib/i18n.ts, missing from the sheet`);
  else if (row.english !== english)
    problems.push(`${key}: English changed — the Chinese is stale\n    sheet: ${row.english}\n    i18n:  ${english}`);
}
for (const [key, chinese] of zh) {
  const row = sheet.get(key);
  if (!row) {
    if (!en.has(key)) problems.push(`${key}: in lib/i18n.ts (zh-Hans), missing from the sheet`);
  } else if (row.chinese !== chinese) problems.push(`${key}: sheet and lib/i18n.ts Chinese differ\n    sheet: ${row.chinese}\n    i18n:  ${chinese}`);
}
for (const key of en.keys()) if (!zh.has(key)) problems.push(`${key}: no zh-Hans string in lib/i18n.ts`);
for (const key of sheet.keys()) if (!en.has(key) && !zh.has(key)) problems.push(`${key}: in the sheet, gone from lib/i18n.ts`);

if (problems.length) {
  console.error(`check:zh — ${problems.length} problem(s):\n- ${problems.join("\n- ")}`);
  process.exit(1);
}
console.log(`check:zh — ${sheet.size} rows match lib/i18n.ts`);
