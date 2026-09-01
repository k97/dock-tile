# TODO — document how Dock Tile renders icons (for future agents)

Raised by Karthik 2026-09-01, during the declarative-icon spike. **Not started.**

## Why

Dock Tile's icon rendering is ~2,100 lines across four files with **no single document explaining
how it fits together**:

| File | Lines |
|---|---|
| `DockTile/Utilities/IconGenerator.swift` | 974 |
| `DockTile/Managers/IconStyleManager.swift` | 465 |
| `DockTile/Components/DockTileIconPreview.swift` | 404 |
| `DockTile/Utilities/IconDepthMetrics.swift` | 255 |

What exists today is partial and scattered: `.claude/rules/icon-system.md` (generation + styles),
`.claude/rules/icon-style-detection.md` (the event-driven detection, added 2026-08-31),
`docs/dark-mode-icon-rendering.md` (why the Dark variant looks as it does). None of them explains
the **end-to-end path** — config → `IconGenerator` → four `.icns` variants → helper bundle →
Launch Services → Dock — or the **invariants that keep the baked renderer and the live preview from
drifting** (`IconDepthMetrics` is the shared seam precisely because they drifted before).

This matters more now, not less: the declarative-icon work (see
[runtime-icon-packaging-research.md](../../runtime-icon-packaging-research.md)) will add a **second**
rendering path alongside the legacy one, gated on macOS version. Two paths with no map is how the
duplicate-poller class of bug happens.

## The task, in three parts

Karthik asked for these specifically:

1. **`/superpowers:requesting-code-review`** over the icon rendering surface. It has never had a
   focused review; recent sessions found real defects by accident (unknown values collapsing to
   Default, in-place icon swap breaking the code-signature seal, two independent pollers).
2. **`/superpowers:systematic-debugging`** for anything the review surfaces — root cause before
   fixes, per the standing rule.
3. **`/superpowers:writing-skills`** to produce the durable artifact: a repo skill (`.claude/skills/`,
   which already exists and holds many) that lets a future agent understand and safely change icon
   rendering **without** re-deriving it from 2,100 lines.

## What the skill must cover

- **End-to-end flow**, both paths once declarative lands, and which macOS versions take which.
- **The shared seams and why they exist**: `IconDepthMetrics` (baked renderer + live preview must
  not drift), `emojiInkFit`, `glyphSizeRatio`'s safe-area caps, `IconWeight`'s dual SwiftUI/AppKit
  mappings that must agree.
- **The non-obvious constraints**, each of which cost real time to discover:
  - `NSBitmapImageRep` with explicit pixel dimensions, never `lockFocus()` (wrong pixel counts)
  - helpers must have `Assets.car` stripped or the main app's icon wins
  - never set `NSApp.applicationIconImage` at runtime (Dock size mismatch)
  - no baked tile shadow — the Dock adds its own
  - the emoji sheen mask ordering (`EmojiSheenMaskTests` guards a real shipped bug)
  - rewriting a resource in a signed bundle **breaks the seal**
- **The appearance authoring model** from the spike: three authorable appearances, `clear` not
  authorable, default-belongs-in-the-specializations-list, layer swap not layer fill.
- **How to verify a change** — which tests guard what, and how to eyeball a rendered icon
  (the render-and-measure scripts from the spike are a good starting point).

## Sequencing

Do this **after** the declarative-icon design is settled, so the skill documents the system as it
will be rather than needing an immediate rewrite. But do it **before** the implementation lands, so
the skill guides the work instead of being archaeology afterwards.
