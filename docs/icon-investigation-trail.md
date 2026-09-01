# How a GA4 audit turned into rewriting icon rendering

**2026-08-31 → 2026-09-01.** The connective tissue between three documents that each hold a piece:
[analytics-baseline-2026-08.md](analytics-baseline-2026-08.md) (the data),
[macos-appearance-detection-research.md](macos-appearance-detection-research.md) (the platform
research and the rework), [runtime-icon-packaging-research.md](runtime-icon-packaging-research.md)
(the spike that changed the direction).

> **Lifecycle (Karthik, 2026-09-01):** THIS doc, `macos-appearance-detection-research.md` and
> `runtime-icon-packaging-research.md` are working artefacts — once the feature ships, **fold all
> three into one** durable doc (or the agent skill from
> [the documentation TODO](superpowers/plans/2026-09-01-icon-rendering-documentation-todo.md)) and
> delete the originals. Carry over: the dead-end table, the appearance authoring model (three
> authorable appearances, default-belongs-in-the-list, layer swap not layer fill), and the OSS
> compiler defects. Drop: the blow-by-blow.
> **`analytics-baseline-2026-08.md` stays separate** — it is a dated measurement of the product, not
> icon documentation, and it is what post-ship numbers get compared against.

This file exists so nobody re-treads the dead ends, and so the wrong turns are on record next to
the conclusions they preceded. **Every dead end below was closed by evidence — do not reopen one
without new evidence.**

## The chain

1. **"Review the GA analytics, and can we count tiles created/deleted/updated?"** The counts existed
   (190 / 31 / 340). What stood out instead was `icon_style_changed`: **1,874 events from 14 users
   on v1.8.5**, against a 2–6/user baseline. The event only fires on an actual *change*.
2. **Hypothesis: an unsynchronized CFPreferences read returns a stale value.** Plausible, matched
   the codebase's own documented cold-cache pattern for Dock reads. **Wrong** — research showed the
   documented staleness failure mode is a value that *sticks*, not one that flaps. Also the
   reflexive fix (`CFPreferencesAppSynchronize`) is documented as prohibited with the constant we
   were passing.
3. **Real defects found instead**, all confirmed: `IconStyle.from` collapsed *unrecognised* values
   into `.defaultStyle`, so one anomalous read became two style changes and two icon rewrites; the
   in-place icon swap **breaks the bundle's code-signature seal** (verified on a live install); two
   independent pollers (1 s and 2 s) nobody intended; two of three notification observers do not
   exist on macOS 26.
4. **Rebuilt detection event-driven, no timer** — KVO primary, verified end to end at ≤10 ms.
   Committed as `5e2ac2e`.
5. **Then it stalled.** In real use, KVO delivery to an *idle* helper goes silent while the OS is
   provably still emitting; the tile stays stale until clicked or the Mac wakes. Never explained.
   Not App Nap (tested, refuted with an A/B).
6. **Karthik's question broke the frame**: *"we ship all four themed icons in every helper — why is
   this happening?"* Because macOS never sees them. `CFBundleIconFile` names **one** file; the other
   three are a private stash we copy from. That reframed the problem from *"make detection
   reliable"* to **"why does detection exist at all?"** — and the answer is that Dock Tile stores
   mutable state inside a signed, immutable artifact.
7. **Spike: can the icon be declarative instead?** Three routes died (below). Then **Karthik found
   [viraptor/actool](https://github.com/viraptor/actool)** — an MIT cleanroom reimplementation of
   the tool everyone said couldn't ship. It compiles a `.icon` on any Mac, output pixel-identical to
   Apple's on Dock-Tile-shaped icons.
8. **Where it landed:** the detection subsystem can be **deleted** for Tahoe rather than fixed —
   and survives only as a quarantined pre-macOS-15 fallback, itself scheduled for deletion when the
   floor rises.

## Dead ends — closed, with the evidence

| Route | Why it died |
|---|---|
| Stale-read hypothesis for the oscillation | Documented failure mode is *sticking*, not flapping; and the reflexive synchronize fix is prohibited for that domain constant |
| Raw `.icon` in a bundle at runtime | 4 wirings tried, generic placeholder every time — macOS does not consume an uncompiled `.icon` |
| Ship one `.icns`, let Tahoe auto-generate variants | Pinned tile stayed full-colour in a Dark Dock. The HIG line about the system generating missing variants applies to the **new** icon format, not legacy `.icns` apps |
| `NSDockTilePlugIn` | Never loads ad-hoc-signed; the Dock's plugin host has no `disable-library-validation`. Fatal regardless, since helpers are generated on user machines and can only ever be ad-hoc |
| "One owner across processes" (main app pushes to helpers) | Its four justifications were refuted or absorbed by simpler fixes — see §G2 of the appearance research |
| App Nap as the KVO-stall cause | A/B with `NSAppSleepDisabled`: the nap-disabled helper was the one that stalled |

## Wrong calls, and how each was caught

Recorded because the *method* generalises, not the mistakes.

- **"Helper bundles inflate GA4 user counts."** Asserted as a headline finding. Disproven by
  arithmetic on the real data: main-app-only and helper-only events had overlapping user sets, so
  they share one instance ID per Mac.
- **"We reproduced the oscillation."** Eleven alternating flips looked exactly like the production
  bug. They were Karthik clicking System Settings. A concurrent independent probe showed the OS had
  emitted every one of those changes.
- **"Those `ClearLight`/`ClearDark` values are guesses — remove them."** Removed on the strength of
  a capture that only clicked the `*Automatic` options. They are real; three live user selections
  were silently ignored until restored. **An absent observation is not an observation of absence.**
- **"actool can't run on user machines, so runtime generation is off the table."** True of *Apple's*
  actool; the research never asked whether anyone had reimplemented it. That unasked question was
  the whole answer.

**What caught three of these four: an independent control measurement** — a standalone probe logging
what the OS actually emitted, running alongside the thing being judged. Dock Tile's own logs show
what the app did, never whether the input was real. The fourth was caught by a human asking a
goal-level question.

## Two lessons worth keeping

- **Put an expensive subsystem's existence on trial, not just its bugs.** A full day went into
  hardening detection before anyone asked whether it should exist. The winning alternative was
  already quoted in our own research, filed as background explaining the subsystem rather than as a
  candidate to replace it.
- **Rationale docs are not decision records.** `dark-mode-icon-rendering.md` defends *which* dark
  treatment to render; it was mistaken for a decision to *have* one. Git shows the subsystem entered
  as a bug fix whose framing pre-assumed rendering our own variants. That choice was never actually
  made — which is why the spike's geometry and appearance questions are being put to Karthik as
  first-time decisions.
