# Website copy review (2026-11-21)

**Verdict:** the site described Dock Tile as three different products — a "launcher" (page title),
an "icon" maker (search/social description) and "iOS-style folders" (hero) — and never said what a
tile is, so the hero carried the whole explanation and overclaimed it ("one click"). Fixed by
picking one category (folders for the Dock), defining a tile in the hero, putting "Free" next to
every Download, and plain words for the jargon.

Inputs: every page's visible text, extracted from the dev build
(`scratchpad/site-copy.txt`), a cold read by a fresh agent given only that text (it disclosed
standing project context), and the app's own strings (`DockTile/Constants/AppStrings.swift`).
Context doc drafted alongside: `website/.claude/product-marketing-context.md`.

## Changed (uncommitted; `git checkout -- website/lib website/components` reverts)

| Where | Before | After | Why |
|---|---|---|---|
| Page title (`siteConfig.tagline`) | A native macOS launcher, built for the Dock | iOS-style folders for your Mac's Dock | One category; "launcher" is Raycast/Alfred's shelf |
| Meta / OG / JSON-LD description | Create custom app icons for your apps and folders, with one-click access… | Put a group of apps behind one Dock icon. Click it and they pop up, like a folder on your iPhone. Free and open source, for macOS 15+ on Apple silicon. | Read as an icon changer; now says the mechanism, price and fit |
| Hero line | iOS-style folders for the macOS Dock. Group apps into beautiful tiles and launch anything in one click. | Put a group of apps behind one Dock icon. Click it and they pop up, like a folder on your iPhone. | Defines a tile; "one click" was false (tile, then app); drops "beautiful" |
| Line under every Download | Open source | Free & open source | Price is the first question; was only mid-page |
| Window-capture body | …in the popover your tile opens… in colour or mono | …in the same panel that pops up from the Dock… on colour or plain white | No "popover", no "mono" |
| Smart Add title | Tiles that build themselves. | Ready-made tiles from the apps you use. | The body says you pick and tweak them |
| Ghost body | Tiles stay out of Cmd-Tab and the App Switcher by default — … invisible when you don't. | Tiles stay out of the app switcher (Command-Tab) by default, so it lists only the apps you're actually using. | Cmd-Tab and the App Switcher are one thing; tiles aren't invisible |
| Ghost footnote | Per-tile control. Surface any tile on demand. | Want one in Command-Tab? Switch it on for that tile. | "Surface on demand" is vague; matches the app's Show in App Switcher |
| Dock Lock footnote | Remembers your pick for every display setup. | Remembers a display for each desk you work at. | Engineering phrasing |
| Keyboard one-liner | Arrow keys move through a popover. | Arrow keys move through a tile's apps. | Jargon |
| FAQ: macOS version | …drawn by the system's Liquid Glass icon pipeline… | …follow your Icon and widget style (Light, Dark, Clear or Tinted)… | Jargon |
| FAQ: App Store | …helper bundles that require permissions not allowed in sandboxed App Store apps. | …builds a small app for each tile and edits your Dock, which apps from the App Store aren't allowed to do. | Jargon |
| FAQ: context menu | "Ghost Mode" (hidden from Cmd+Tab) | Ghost mode (hidden from Command-Tab) | One spelling of each term |
| FAQ: folders / reorder / backup | "Yes!", "In In This Tile", "backup my tiles" | "Yes.", "In the tile's In This Tile list", "back up my tiles" | Voice, grammar |
| FAQ: new | — | **Is Dock Tile free?** · **What does Dock Tile change on my Mac?** | Price and trust were answered only on Terms |

Terms fixed: **Command-Tab** in prose (Apple's spelling), **Ghost mode** (lower-case m). Floor
guard (`MacOSFloorGuardTests` patterns) re-checked: pass.

## Not changed — recommend

1. **Headings chosen today stay** ("Set up for you. Out of your way.", "Pick your apps. Pick a look.
   Done.", "All your apps. One tile."). The cold read flags "All your apps. One tile." as
   contradicting a page about many tiles, and "Done." as an overclaim; an imperative ending ("Tidy
   your Dock today.") was the July version's strength. Owner's call.
2. **OG image** still carries the old tagline ("Organise your Mac Dock with ease", "Pin, Group,
   Launch", "DockTile" tooltip) and its alt text says so. Regenerate with the new line.
3. **Uninstall Dock Tile** has no answer anywhere (FAQ covers removing a tile). Needs the steps
   verified against the app (Dock entries, `~/Library/Application Support/DockTile/`, login item).
4. **Release notes** (from GitHub) read like commit messages ("Light up Update on…"); write the
   next ones as "Update now lights up when…".
5. "Ghost mode" is a website-only name (the app's toggle is "Show in App Switcher"); fine now that
   the body explains it, but don't introduce more site-only names.

## Round 2 (owner decisions, 2026-11-21)

- Final heading → "Tidy your ▦ Dock today."; the other headings stay.
- OG image kept; alt text corrected (tile is magnified, not open; folder added).
- FAQ: "How do I uninstall Dock Tile?" (steps + leftover folders; Bin in AU/GB, Trash in US).
- Release notes: only 2.7.1 and 2.7.2 used the commit voice; rewrites drafted in the scratchpad,
  awaiting approval before `gh release edit`. Voice rule added to `.claude/rules/ci-release.md`.
- Design unchanged (copy-only pass).

## Epistemics

Read in full: every page's rendered text, `lib/i18n.ts`, `lib/config.ts`, the Terms section the
new FAQ answer quotes. Not checked: phone widths (the longer "Free & open source" meta line wraps
on the narrowest phones, as the old one could), dark theme, Safari. Unverified: whether "Free &
open source" reads better than "Free · Open source" at small size.
