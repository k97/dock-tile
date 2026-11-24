# Homepage versions compared

Sources: `website/app/page.tsx`, `website/components/home-sections.tsx`, `hero.tsx`, `closing-band.tsx`, `closer-look.tsx` and the `marketingBase` block of `website/lib/i18n.ts`, read with `git show <commit>:<path>`. `website/components/features.tsx` is dead code (`website/CLAUDE.md`), so the section the owner calls "features" is `CustomTilesStory` (`id="features"`).

Heights are **estimates from the Tailwind classes at a 1440 × 900 desktop window, not measured renders.** Each is rounded to the nearest 0.1 screen (900 px). Section padding was `md:py-32` (128 px) through `f64c259` and is `md:py-50` (200 px) at HEAD (`design-system.md` "One spacing rhythm").

## The four versions

### A. `74958d2`: July 11, the simple version

| # | Section | Heading (copy key) | Purpose | Tone | ≈ height |
|---|---|---|---|---|---|
| 1 | Hero | "Group your apps. / Declutter your Dock." + eyebrow "For macOS 26+" | what it is + live Dock demo + Download | dark | 0.9 (`min-h-[92vh]`) |
| 2 | CustomTilesStory | "Features / 01 — Customised tiles with the simple editor." | how a tile looks; two columns: copy + Customise screenshot + caption | light | 0.8 |
| 3 | DockLockStory | "Features / 02 — The Dock stays put." | a specific pain (Dock jumping between displays); two columns, animated two-display mock | **dark** | 0.6 |
| 4 | PowerUserSection | "Power user — Built for the power user." | 3 cards: Grid or list (live popover), Smart Add, Ghost mode; 14 px body | light | 1.0 (3-across ≥ 1280 px; stacked below) |
| 5 | FinalCta | "Get organised today." | **an explicit ask**: Download + Open source · version · macOS 26+ + support link + Spades Audio pill | **dark** | 0.6 |

After the features section: 3 sections, about 2.2 screens, **4 product ideas** (Dock Lock, Grid/List, Smart Add, Ghost), then one CTA. Light and dark alternate after the hero: light, dark, light, dark.

### B. `9553148`: Oct 19, just before the Oct 31 changes

Same structure and copy as A. The eyebrow becomes "Apple silicon · macOS 15+" and the final CTA meta gains "Apple silicon". This is the version that was live through the Oct 22 surge start.

### C. `f64c259`: Oct 31, before the Nov 9 changes

| # | Section | Heading | Change from B |
|---|---|---|---|
| 1 | Hero | unchanged | — |
| 2 | CustomTilesStory | "Features / 01 — Pick your apps. Pick a look. Done." | stacked and centred; **full-width window capture with 4 "closer look" hotspots** (`closer-look.tsx`: `max-w-300`, aspect 2269/1725 ≈ 912 px tall) → about 1.5 screens |
| 3 | DockLockStory | unchanged | still its own dark band |
| 4 | PowerUserSection | unchanged | Grid/List, Smart Add, Ghost |
| 5 | **ClosingBand** | "All your apps. One tile." | replaces FinalCta: hero wallpaper, Download + meta, then a 240 px popover zone and a **closing Dock** (GitHub · What's new · Contact \| Studio). Spades Audio and the support link moved into the Dock. About 0.7 screens |

After the features section: still 3 sections, about 2.3 screens, the same 4 ideas. The ending now presents a tagline instead of an ask, and 4 more destinations sit under the Download button.

### D. HEAD (`2da40a7`, `93a3295`, `6320feb`, `63789d3` on Nov 9; `3d778c8` on Nov 18)

| # | Section | Heading | Purpose / contents | Tone | ≈ height |
|---|---|---|---|---|---|
| 1 | Hero | "Group your apps. / Declutter your Dock." (no eyebrow); `DownloadMeta` "v2.7.2 · Open source · Apple silicon · macOS 15+" under the button | what it is + demo + Download | dark | 0.9 |
| 2 | CustomTilesStory | "Pick your apps. Pick a look. ▦ Done." | window capture + hotspots | light | 1.7 |
| 3 | **DetailsSection** (new) | "More than ✦ a tile in your Dock." | 2 big cards: **Style** (auto-playing interactive customiser) and **Menu bar** (menu mock); then a row of 4 one-liners (Keyboard friendly, Folders too, Grid or list, In your language) | light | 1.4 |
| 4 | PowerUserSection | "Built for the ⚡ power user." | Smart Add, **Dock Lock** (moved in from its own section), Ghost mode; 18 px body | light | 1.0 at ≥ 1280 px, **about 2.2 when stacked below 1280 px** (`xl:grid-cols-3`, `max-w-md` column) |
| 5 | ClosingBand | "All your apps. One tile." | Download + meta, then a closing Dock that **auto-plays** (hovers link tiles, opens Studio) | dark | 0.7 |

After the features section: 3 sections, **about 3.1 screens at ≥ 1280 px and about 4.3 below**, and **9 product ideas** (Style, Menu bar, Keyboard, Folders, Grid/List, Languages, Smart Add, Dock Lock, Ghost) before the CTA. Once the hero ends there are **three light sections back to back**, with no dark break until the closing band. Each of those three has a centred heading with the same tilted inline tile (`design-system.md` "Every homepage section heading carries one tilted tile").

## Findings, in the post-features part

1. **The same idea appears twice.** The features body says "show the tile as a grid of its apps, or give it a symbol or an emoji, in colour or mono" (`tilesBody`). The first big card says "Show a grid of the tile's own apps, or a symbol or an emoji, in full colour or Mono" (`customBody`). Features' closer-look hotspots already cover Style and Background (`tilesSpotStyle*`, `tilesSpotBackground*`). So the first thing after the features section is the features section again, as a toy.
2. **More ideas competing.** Four ideas after the features section in A–C, nine in D. The row of 4 one-liners is already a cut-down list (`design-system.md`: login, updates, revert and missing apps were cut), but these are minor conveniences that answer no buyer question on their own.
3. **Dock Lock lost its own chapter.** In A–C it was the only section built around a named problem ("Stop the Dock from jumping between screens"), on a dark band that also broke up the page. In D it is the middle card of a bento. Below 1280 px it is the second card in a stacked column, roughly 4½–5 screens down the page (estimate).
4. **The ending's ask got weaker.** A/B: "Get organised today." + Download. C/D: "All your apps. One tile." + Download, followed 240 px later by a second Dock with 4 non-download destinations. In D that Dock moves by itself, which pulls the eye away from the button above it. Download appears in the hero, the nav (md+) and the closing band in all versions. There has never been a mid-page CTA.
5. **The path from features to the next Download got longer.** About 2.2 screens (A/B), about 2.3 (C), about 3.1–4.3 (D).
6. **Buyer questions**, per version:

| Question | A (Jul) | B (Oct 19) | C (Oct 31) | D (now) |
|---|---|---|---|---|
| What is it? | hero | hero | hero | hero |
| Why me? (a pain I have) | Dock Lock section; Ghost | same | same | buried in bento; Details cards show capability, not pain |
| Does it work on my Mac? | eyebrow "macOS 26+" (wrong floor at the time) | "Apple silicon · macOS 15+" eyebrow + CTA meta | same | `DownloadMeta` under both Downloads ✓ |
| Is it safe? | "Open source" link; Smart Add privacy note | same | same | same; no signed/notarised or "what it installs" note on the homepage (`content-i18n.md` keeps "Signed & notarized" on legal pages only) |
| How do I get it / what does it cost? | Download ×3; "free" never stated | same | same | same |
| Ask at the end | "Get organised today." | same | tagline only | tagline only + moving Dock |

7. **What D does better:** the requirement line under every Download, the 18 px body (A's bento body was 14 px), the feedback links, an interactive customiser that teaches the styles, and Dock Lock copy that is accurate per display setup.
