# Website: Simplified Chinese test (homepage + FAQ)

Owner decision 2026-11-23 (issue #43, option B): a small Simplified Chinese test of the homepage and
the FAQ, judged after 2–3 months on Chinese visitors and downloads; re-read after the 7 Dec review.
Not the full #43 (five languages). Chinese is the only non-English browser language above 5% of site
visitors (10% over 90 days, ~13/month); Search Console has no non-English queries yet.

## Owner answers to the plan gate (2026-11-23)

1. **Machine-first Chinese goes live and indexed now**; a native pass improves it when a reviewer
   turns up. The review sheet marks every row `needs_review`.
2. **Pipeline: review sheet + drift check**, not `l10n.py` (it reads String Catalogs, not
   `lib/i18n.ts`). `docs/l10n/website-zh-Hans.md` holds English | Chinese | status, and a small
   check (`website/scripts/check-zh.mjs`, run beside lint) fails when an English string's text no
   longer matches the English recorded in the sheet, so an English edit can't leave stale Chinese
   unnoticed. Deviation from "the app's pipeline", chosen by the owner.
3. **Keep/drop:** keep if `/zh-Hans*` pages produce at least the baseline download rate below over
   ~3 months; expand if Chinese queries appear in Search Console; drop if near-zero use. Small sample
   (~13 Chinese-language visitors a month): read as direction, not proof.

**Baseline (GA4 522915118, 90 days to 2026-11-22, English pages only):** 38 Chinese-language users,
47 sessions; 18 of them clicked Download (47%), against 112 of 419 users overall (27%). Chinese
visitors already convert well in English, so the bar is high. GA4 query: users and
`download_click` + `copy_link_click` users filtered by `pagePath` starting `/zh-Hans`, vs the same
for `language = Chinese` on English pages.

Reviews: the scheduled 2026-12-07 review (a T3 scheduled task, not a file) reports early indexing
and visits; a second scheduled review ~3 months after launch applies the keep/drop rule.

## Goal and success criteria

1. `/zh-Hans` and `/zh-Hans/faq` serve the homepage and FAQ in Simplified Chinese, server-rendered
   (crawlable without JS), with every visible string from `lib/i18n.ts`, not a translation of the page
   in the browser.
2. All other routes are unchanged byte-for-byte in their English copy; `/privacy`, `/terms` and
   `/release-notes` stay English only and are linked from the Chinese pages as such.
3. `hreflang` alternates (`en`, `zh-Hans`, `x-default` → English) on `/`, `/faq`, `/zh-Hans`,
   `/zh-Hans/faq`; both Chinese URLs in the sitemap; canonicals self-referencing.
4. JSON-LD on Chinese pages in Chinese: SoftwareApplication (`inLanguage: "zh-Hans"`) on
   `/zh-Hans`, FAQPage on `/zh-Hans/faq` only (the FAQPage rule).
5. Chinese visitors can find it: a language link in the footer ("简体中文" on English pages,
   "English" on Chinese pages). No auto-redirect and no banner (owner: no surprises; a redirect would
   also hide the English page from Chinese-language crawlers).
6. Analytics: no new events; GA4 reads the test by page path (`/zh-Hans*`) and `download_click` /
   `copy_link_click` there.
7. Checks: lint, tsc, build; `audit-meta.mjs` and `extract-jsonld.mjs` on both Chinese routes (built
   HTML); 390 px overflow sweep on both; no hydration errors; owner looks at it on the dev server
   before commit (layout rule).

## Design

- **Locale model.** Add `"zh-Hans"` to `Locale`. `LocaleProvider` becomes route-aware: on a path
  under `/zh-Hans` the locale is `zh-Hans` (server and client, via `usePathname`, so SSR is Chinese);
  elsewhere the existing en-AU default + browser swap to en-US/en-GB is unchanged. `detectLocale`
  never returns `zh-Hans` (no browser-driven switch into Chinese).
- **Routes.** `app/zh-Hans/page.tsx` and `app/zh-Hans/faq/page.tsx` render the same components as `/`
  and `/faq`, with their own `metadata` (Chinese title/description, canonical, `alternates.languages`,
  openGraph incl. the explicit og image). A `app/zh-Hans/layout.tsx` wraps children in
  `<div lang="zh-Hans">` — shortcut: the root `<html lang="en">` stays (the root layout cannot know
  the route without making every page dynamic); element-level `lang` + hreflang + Chinese content is
  what crawlers and screen readers use. Upgrade to a `[lang]` segment if the test grows.
- **Links that must follow the locale:** nav (Features → `/zh-Hans#features`, FAQ →
  `/zh-Hans/faq`; Privacy stays `/privacy`), the logo (home of the current locale), "See all
  questions" → `/zh-Hans/faq`, the hero Dock's Configure… (same-page anchor, unchanged). A single
  `localePath(locale, path)` helper in `lib/nav.ts`; `isActiveRoute` must treat `/zh-Hans/faq` as FAQ.
- **Copy.** A full `"zh-Hans"` entry in `localisedContent` (marketing, faq, the remaining top-level
  keys) — TypeScript forces the same shape. The ~32 strings hardcoded in components (scan in this
  session: e.g. "Downloading…", "Download for macOS", "Contact support", "Still stuck?", the FAQ page
  header, the mock macOS UI labels) move to `i18n.ts` first, English values unchanged.
  - Mock macOS UI labels take the **app's own** zh-Hans strings from `Localizable.xcstrings`
    (添加磁贴, 配置磁贴…, 打开Dock Tile…, 退出Dock Tile, 本周最常用, 新建磁贴, 添加 …) so the page
    matches the app a Chinese user will install.
  - Terms from `docs/l10n/GLOSSARY.md`: 磁贴 (tile), 程序坞 (Dock), 弹出面板 (popover), 访达
    (Finder), App切换器, 无障碍, 浅色/深色; register 你; full-width punctuation; "Dock Tile" never
    translated.
  - Third-party app names in the mocks stay as macOS shows them in Chinese (e.g. 信息 for Messages,
    音乐 Music, 播客 Podcasts, 系统设置 System Settings, 访达 Finder); brand apps unchanged.
- **FAQ slugs (gate F1).** `slugify` strips non-Latin text, so Chinese questions would lose their
  slugs (empty homepage FAQ, duplicate accordion ids, dead `#slug` links). Each FAQ entry gets an
  explicit `slug` field, taken from today's English question; `slugify` stays for nothing else. The
  English slugs (and `TOP_QUESTIONS`) are unchanged.
- **Floor guard (gate F2).** `hero.tsx`'s literal `macOS 15+` stays literal in that file
  (`MacOSFloorGuardTests` requires the file to state the floor); the guard's regexes are English, so
  the Chinese copy's macOS versions are checked by hand against the English (15 and 26).
- **Locale-aware "home" (gate F3).** The logo's scroll-to-hero (`header.tsx`) and the Features
  current state (`currentFor` in `lib/nav.ts`) key on `"/"`; both take the locale's home
  (`/zh-Hans`). `isActiveRoute` treats `/zh-Hans/faq` as FAQ.
- **JSON-LD (gate F6).** Chinese pages emit their own nodes: `SoftwareApplication` with `@id`
  `…/zh-Hans#app`, `inLanguage: "zh-Hans"`, a Chinese description from the zh content (not
  `siteConfig.description`), `sameAs` the English `…/#app` node and the GitHub repo; the WebSite and
  Organization nodes are shared unchanged.
- **Known limits:** the Header sits outside the `lang` wrapper; `/zh-hans` (lower case) 404s; English
  pages change only by the footer's "简体中文" link (criterion 2 reads "copy unchanged except that
  link"); the `innerText` diff covers `/` and `/faq`.
- **Quality bar (risk).** The translation is machine-first, like the app's zh-Hans (all
  `needs_review` today). A review sheet `docs/l10n/website-zh-Hans.md` (English | Chinese | notes)
  goes with it for a native reviewer; the page ships only after the owner's go.
- **Typography.** Allo is Latin-only; Chinese falls back to the system font (PingFang SC on Mac).
  `heading-display` and `text-section` use −0.04em tracking, too tight for CJK: under `:lang(zh-Hans)`
  tracking goes to 0 (CSS only). Headings with a tilted tile keep the tile, split A/B like English.
- **Out of scope:** `/privacy`, `/terms`, `/release-notes` in Chinese; a Chinese OG card (Chinese
  pages use the English card; noted on #43); Baidu (needs ICP hosting).

## Steps

1. Move the hardcoded component strings into `i18n.ts` (English unchanged). Verify the English pages
   render identical text (diff `document.body.innerText` of `/` and `/faq` before/after).
2. `Locale` + route-aware `LocaleProvider` + `localePath`; nav/logo/footer/"See all questions" links.
3. `zh-Hans` content entry (machine-first, glossary, app strings) + review sheet.
4. Routes, metadata, hreflang (also on `/` and `/faq`), sitemap, JSON-LD, footer language link,
   `:lang(zh-Hans)` tracking.
5. Checks (criteria 7); owner review on the dev server; `stage-gate --dev`; commit; push on "push".
6. Rules: content-i18n.md "Locale model" (no longer "no locale routing" — one test route), seo-geo.md
   (hreflang), #43 comment; add "evaluate the zh-Hans test" to the 7 Dec scheduled review, plus a
   second review ~3 months after launch.
