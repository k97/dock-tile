# Product Marketing Context

*Last updated: 2026-11-21. V1 auto-drafted from the repo (site copy, app strings, release notes, the
2026-11 analytics read). Owner to correct; marked `(unverified)` where it rests on no source in the repo.*

## Product Overview
**One-liner:** Folders for the Mac's Dock: put a group of apps behind one Dock icon, click it, and they
pop up.
**What it does:** Each tile is a real Dock icon. Click it and its apps and folders open in a popover
(grid or list) right above the Dock. You set tiles up in the Dock Tile app; Smart Add can suggest
ready-made tiles from the apps you use most.
**Product category:** Dock folders / Dock organiser for macOS. Not a launcher (search-first tools)
and not an icon changer: both are shelves the site has used and both mislead.
**Product type:** Native macOS app (Apple silicon, macOS 15+), direct download, auto-updating.
**Business model:** Free, MIT open source, no account. Published by Happy Machines Company, which also
makes Spades Audio (paid).

## Target Audience
**Who:** Mac users whose Dock has outgrown the screen; people with several app "modes" (work, dev,
media, AI tools); multi-display users whose Dock wanders.
**Primary use case:** Shrink a crowded Dock without losing one-click-ish access to apps.
**Jobs to be done:**
- Keep the Dock short but every app close at hand.
- Group apps by task, the way iPhone folders do.
- Keep the Dock on one display (Dock Lock).

## Problems & Pain Points
**Core problem:** The Dock grows until icons shrink and nothing is findable; macOS's own Dock folders
(stacks) only hold aliases in a folder and look nothing like apps.
**What it costs them:** Hunting for icons; giving up on the Dock for Spotlight; a Dock that jumps to
the wrong screen.
**Emotional tension:** Clutter, and the itch of a Mac that doesn't look "set up".

## Competitive Landscape (from general knowledge, unverified)
**Direct:** other Dock and app-grid organisers.
**Secondary:** macOS Dock stacks, Launchpad-style folders (check what macOS 26 still offers), Spotlight.
**Indirect:** keyboard launchers — search instead of browse.

## Differentiation
- A tile is a real Dock icon: it sits, magnifies and tooltips like any app.
- The popover is the native one, anchored to the icon; grid or list.
- Tile icons follow macOS 26 Light/Dark/Clear/Tinted styles (compiled icons).
- Smart Add builds tiles from on-device usage; nothing leaves the Mac.
- Menu bar list of tiles; Dock Lock; Ghost (hidden from the app switcher).
- Free, open source, no account.

## Objections
| Objection | Response |
|-----------|----------|
| Is it safe to install something that edits my Dock? | Open source; what it changes is listed on Privacy/Terms; it asks before restarting the Dock. |
| Why not the App Store? | It builds a small app per tile and edits the Dock, which App Store apps can't. |
| What does it cost? | Nothing; MIT; no account. |
| Will it work on my Mac? | Apple silicon, macOS 15+. Intel not supported. |
**Anti-persona:** keyboard-only launcher users; Intel Macs; people who keep the Dock hidden and never
use it (the menu bar list is their only hook).

## Switching Dynamics
**Push:** a Dock too long to read; a Dock on the wrong screen.
**Pull:** iPhone-style folders in the Dock; ready-made tiles; looks native.
**Habit:** Spotlight / launchers already work "well enough".
**Anxiety:** an app that restarts and rewrites the Dock.

## Customer Language
No verbatim customer quotes in the repo yet. Feedback lives in `docs/feedback/` (gitignored, private).
**Words to use:** Dock, folder, group, tile (after it is defined), click, pop up, your apps.
**Words to avoid on the homepage:** launcher, popover (say "pops up"), helper bundle, sandboxed,
pipeline, "surface", "on demand", "one click" (it is two: the tile, then the app).
**Glossary:**
| Term | Meaning |
|------|---------|
| Tile | One Dock icon that holds a group of apps and folders |
| Popover | The panel a tile opens above the Dock (site prose: "pops up") |
| App Grid | A tile icon showing its own apps as a 2×2 / 3×3 grid |
| Mono | Plain tile with a coloured symbol: white, black in Dark (site prose: "plain background") |
| Ghost mode | Site name for a tile hidden from the app switcher (app label: "Show in App Switcher" off) |
| Smart Add | Suggested tiles from the + button |
| Dock Lock | Keeps the Dock on one chosen display |

## Brand Voice
**Tone:** calm, plain, Mac-native. Confident without superlatives.
**Style:** short declaratives; the visitor's own task first, then the feature; spelling-neutral where
possible (en-AU default, US override).
**Personality:** tidy, considerate, quietly delightful, honest (privacy page is the benchmark).

## Proof Points
Open source (GitHub); six UI languages; frequent releases (dated notes); no testimonials yet.

## Goals
**Conversion action:** Download (tracked as `download_click`; no location parameter yet).
