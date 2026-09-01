# GA4 Baseline — 2026-06-18 → 2026-08-31

The first real read of Dock Tile's production analytics, captured 2026-08-31 via the Data API
(property `542196919`). **This is the pre-change baseline**: it predates the icon-detection rework
(`5e2ac2e`) and any GA4 console fixes, so it is what "after" gets compared against.

Access, credentials and the property/stream IDs are in
[`.claude/rules/analytics.md`](../.claude/rules/analytics.md) — not repeated here.

Instrumentation shipped in **v1.3.0** (commit `11b9a05`, 2026-06-18), so this window is everything
that has ever been collected.

## Totals

| Metric | Value |
|---|---|
| Total users | **119** |
| New users | 123 |
| Sessions | 1,173 |
| Events | 13,879 |

## Events

| Event | Count | Users |
|---|---:|---:|
| `user_engagement` | 3,912 | 117 |
| `popover_opened` | 3,022 | 83 |
| `icon_style_changed` | 1,961 | 22 |
| `app_launched` | 1,474 | 116 |
| `session_start` | 1,140 | 108 |
| `app_launched_from_tile` | 886 | 65 |
| **`tile_updated`** | **340** | 53 |
| `configure_gear_tapped` | 206 | 52 |
| **`tile_created`** | **190** | 70 |
| `tile_added_to_dock` | 173 | 67 |
| `first_open` | 123 | 109 |
| `dock_lock_move_succeeded` | 118 | 10 |
| `helper_migration_run` | 80 | 29 |
| `setting_changed` | 78 | 28 |
| `os_update` | 34 | 15 |
| `tile_hidden` | 31 | 7 |
| **`tile_removed`** (= tile DELETED) | **31** | 22 |
| `app_update` | 25 | 9 |
| `dock_lock_move_started` | 19 | 5 |
| `relocation_prompted` | 10 | 3 |
| `relocation_move_started` | 8 | 3 |
| `dock_lock_move_failed` | 7 | 4 |
| `relocation_move_failed` | 7 | 3 |
| `relocation_move_succeeded` | 1 | 1 |

Naming trap: **`tile_removed` means the tile was DELETED**; `tile_hidden` is un-docked.

## Monthly trend (events / users)

| Event | Jun | Jul | Aug |
|---|---|---|---|
| `first_open` | 15/12 | 26/23 | **82/75** |
| `tile_created` | 10/5 | 22/10 | **158/56** |
| `tile_added_to_dock` | 16/3 | 25/13 | 132/52 |
| `tile_updated` | 67/5 | 60/13 | 213/39 |
| `tile_removed` | 4/3 | 3/2 | 24/17 |
| `tile_hidden` | 27/4 | 3/2 | 1/1 |
| `icon_style_changed` | 18/3 | 76/11 | **1867/11** |

Growth is real and accelerating — new users 12 → 23 → 75.

## What the data CANNOT see

Checked 2026-09-01: querying `2026-01-01 → 2026-06-17` returns **no data at all** — instrumentation
shipped in v1.3.0 and there is nothing earlier to recover. So the blind spots are:

- **Anyone still on v1.0–v1.2.x who has never updated.** Dock Tile shipped for months before
  analytics existed; those users are invisible unless/until they update.
- **Anyone who opted out** (opt-out, default ON — a minority, unmeasurable by definition).

**Retention is NOT one of them.** The 2-month `eventDataRetention` governs event/user-level data
used in Explorations, funnels and path analysis — standard aggregate reports are unaffected, which
is why every table here reaches back to June. Fixing retention buys analysis depth, not counts.

## Version spread — the install base is stuck behind

| Version | Users |
|---|---:|
| **1.8.5** | **86** |
| 1.3.0 | 8 |
| 1.8.1 | 8 |
| 1.8.6 | 7 |
| **1.8.8** (current) | **7** |
| 1.8.4 | 6 |
| 1.4.5 | 5 |
| others (1.4.x–1.7.x) | 1–3 each |

Two consequences:

1. **86 of 119 users run 1.8.5** — the version with the `icon_style_changed` anomaly below. The
   bug's blast radius is most of the install base, not a fringe.
2. **Only 7 users are on the current release, and 8 are still on 1.3.0 from June.** Sparkle uptake
   is slow enough that *shipping* a fix and *delivering* it are very different events. Worth
   investigating on its own — it also means any post-fix measurement will lag by weeks.

## The two findings that matter

### 1. The drop-off is BEFORE tile creation

**70 of ~119 users ever created a tile — roughly 43% never made one.** Of those who did, almost all
docked it (67 of 70), and only 16% ever deleted one (31 deletions against 190 creations).

So retention of the core action is strong; **acquisition of it is not**. Whatever loses people
happens between first launch and first tile. This is the highest-value product question the data
raises, and nothing currently instrumented explains it — the funnel between `first_open` and
`tile_created` is unmeasured.

### 2. `icon_style_changed` is anomalous on 1.8.5 — and it is what started the whole icon investigation

The event only fires on an actual style *change*, yet:

| Version | events/users | per user |
|---|---|---|
| 1.4.x–1.8.4 | 3–30 | **2–6** |
| **1.8.5** | **1874 / 14** | **134** |
| 1.8.6 | 24 / 1 | 24 |

August daily distribution shows it is **episodic bursts, not a steady leak**:

| Date | events | users | per user |
|---|---:|---:|---:|
| typical day | 1–3 | 1–2 | 1–2 |
| **Aug 10** | 324 | 2 | 162 |
| **Aug 11** | 859 | 2 | 430 |
| **Aug 21** | 548 | 1 | 548 |

Three days account for 1,731 of August's 1,867 events. Crucially the bursts land on days with
**below-average** user activity (Aug 24, the busiest day of the month at 245 popover opens, produced
2 flips) — an idle-machine, environmental trigger, not interaction-driven.

Nobody toggles appearance 548 times a day. This is the signal that led to the appearance-detection
investigation and the eventual rework (record folded into
[icon-rendering-history.md](icon-rendering-history.md)). **The root cause was never reproduced** — it did not recur on the maintainer's Mac — so this
table is the only evidence it happened, and the metric to watch after the fix ships.

## Configuration problems found — 1, 2 and 3 FIXED 2026-09-01

> **Fixed 2026-09-01** via the Admin API once `ga4-fetch@dock-tile.iam.gserviceaccount.com` was
> granted **Editor** on the property:
> - `eventDataRetention` **TWO_MONTHS → FOURTEEN_MONTHS**
> - **7 custom dimensions** registered — `app_role` (user-scoped), `style`, `source`, `setting`,
>   `enabled`, `layout`, `reason` (event-scoped) — and **1 custom metric**, `app_count`
> - **`tile_created` and `tile_added_to_dock` marked as key events** (once per session)
>
> **Registration is forward-only**: parameters sent before today are still lost, so breakdowns by
> `style` etc. only work from 2026-09-01 onward. Problem 4 (site in a separate property) is
> unchanged and still blocks any site→download→activation funnel.

### The original findings, for the record

1. **Zero custom dimensions, zero custom metrics.** `customDimensions` and `customMetrics` both
   returned `{}`. Every parameter the app sends — `source` (Smart Add vs blank), `app_count`,
   `layout`, `setting`, `style`, `reason` — and the `app_role` user property are **discarded from
   all reports**. The instrumentation cost is being paid and none of the value collected.
   Registering `style` is what would let the next `icon_style_changed` burst name itself instead of
   being inferred from counts.
2. **`eventDataRetention: TWO_MONTHS`** (user data is 14 months). Should be 14. Not retroactive —
   every day it stays wrong loses another day permanently. Standard aggregate reports are unaffected,
   which is why this table was recoverable back to June.
3. **Key events are Firebase's defaults only** — `purchase`, `in_app_purchase`, two subscription
   events, `first_open`. Meaningless for a free app; no Dock Tile event is marked.
4. **The marketing site is in a different property.** Property `542196919` has exactly two streams:
   the macOS app (`15108725514`) and an unused web stream `G-HQ9B3CKMKN` ("dashboard", created
   2026-07-09). The site's `G-PP04F8Z0EP` is elsewhere, so **no site→download→activation funnel is
   possible** — which is exactly the funnel finding #1 needs.

## Instrumentation gaps in the app

- **3 declared events never fire**: `tile_shown`, `tint_color_changed`, `layout_mode_changed`.
- **`tile_updated` undercounts.** It only fires when the tile is already pinned; the `.saveOnly`
  branch (edits to a hidden or never-pinned tile) logs nothing.
- **No lifetime inventory.** `DockTileConfiguration` has no `createdAt`, so nothing on disk records
  when a tile was made — pre-v1.3.0 activity is unrecoverable, and "how many tiles does a typical
  user have" cannot be answered from lifecycle events alone. A periodic state snapshot would fix it.
