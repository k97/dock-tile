# The dip is a new-install surge ending, not the redesign

**Answer.** The data does not support the claim that the homepage redesign caused the dip. What dropped is new app instances, and only against a surge that began on **Oct 22, nine days before the first redesign deploy (Oct 31)**. Main-app installs ran at 1.6 a day before the surge and 3.1 a day during it (Oct 22–Nov 8). Since Nov 9 they have run at 2.1 a day, which is at or above the pre-surge baseline. Returning use did not fall either: main-app returning users and sessions reached their highest levels in the week after the Nov 9 redesign. The figure that dropped hard, the all-instance 7-day active users (97 to 59), counts every tile's helper as a user, so it swings with how many tiles new people create. One fact does fit the owner's suspicion: the surge ended in the same week as the Nov 9 redesign. Measured against the surge, the post-Nov 9 install rate is lower at p ≈ 0.07. But China drove much of the surge and also fell back the most (0.72 → 0.31 installs a day), while US installs held steady (0.56 → 0.62 a day). That pattern looks like an outside mention fading, not English homepage copy. **Verdict: not supported, and not settled.** The website's own analytics stream is in a property the service account cannot see. `download_click` ÷ homepage sessions before and after each deploy would settle the question, and that data was not reachable. Separately, the section analysis finds real problems in the post-features part of the page, whatever caused the dip. It now carries 9 ideas where July had 4, the first card after the features section repeats the features section, Dock Lock lost its own chapter, and the ending's ask is weaker.

Raw notes and every GA response are in `research_notes/Website redesign and app usage/`: `01 Data access and what can be measured.md`, `02 App usage around the deploys.md`, `03 Homepage versions compared.md`, and `ga-data/`.

## 1. What could and could not be measured

- **The website stream is out of reach.** Property `542196919` holds only the app stream `15108725514` and the unused web stream `G-HQ9B3CKMKN`. The service account can see one other property, `526370803`, whose only stream is `G-QCKFMP437P` (Spades Audio). `G-PP04F8Z0EP` (`website/lib/analytics.ts`) is in neither. Sources: Admin API `properties/542196919/dataStreams`, `accountSummaries`, `properties/526370803/dataStreams` (note 01). So there are **no website sessions, homepage views, scroll depth, `download_click` counts, source/medium or landing pages in this report.**
- **The website tracking code did not change in a way that would stop events.** The only edits to `website/app/layout.tsx` since July are the font swaps in `93a3295` and `3d778c8`. gtag config is untouched. `DownloadActionButton` still fires `download_click` (`website/components/action-button.tsx`). `website/lib/analytics.ts` is unchanged since July. This is a static read, not proof that tags fire in production.
- **Helpers count as users.** Each tile is its own bundle running Firebase (`.claude/rules/analytics.md`). On a typical day about 30 instances are active, of which about 8 are the main app (`daily_role`). `app_role` is set after the automatic `first_open`, so `newUsers` filtered to `main` is always 0. The usable install series is **`firstSessionDate` with `customUser:app_role = main`**.
- **No year-ago comparison exists.** The `2025-08-01..2025-11-21` query returns zero rows, because instrumentation began 2026-06-18. The app stream carries no acquisition source: all 460 new users are `(direct)/(none)` (`firstopen_source`).

## 2. The data

The noise band throughout is Poisson 95%: ±1.96·√n / days, where n is the window total. Windows are cut at the deploy days, Australia/Melbourne time (the property's zone, the same zone as the commit times). Every query is in `ga-data/q1.json` and `q2.json`, and the windowing is in `ga-data/windows.py`.

### 2.1 Main-app installs: the core metric (`firstSessionDate`, metric `totalUsers`, filter `app_role = main`, 2026-09-01..11-21)

| Window | Installs per day | n |
|---|---|---:|
| Sep 21–Oct 21 (baseline) | **1.6 ±0.5** | 51 |
| Oct 22–30 (surge, before any redesign) | **3.3 ±1.2** | 30 |
| Oct 31–Nov 8 (after deploy 1) | 2.9 ±1.1 | 26 |
| Nov 9–17 (after deploy 2) | 1.9 ±0.9 | 17 |
| Nov 18–20 (after the font change) | 2.7 ±1.8 | 8 |
| Nov 9–21 combined | 2.1 | 27 |

By ISO week (`weekly_installs.py`): 12, 21, 14, 14, 14, 16, 6, 15 for weeks 36–43 (mean 14.0; the 95% band for one week is about 7–21). Then **21, 21** for weeks 44–45, then 12 for week 46, then 15 in the first 6 days of week 47. The daily series jumps on Oct 22 (the 2.5.0 release day) from almost nothing in Oct 15–21 (1, 0, 0, 0, 0, 1, 0) to 4, 5, 2, 3, 3, 5, 1, 3, 4, 4. Surge against after-Nov-9: a binomial split of the 73 installs gives z ≈ −1.8, p ≈ 0.07. After-Nov-9 against the baseline: no decline (2.1 against 1.6 a day).

### 2.2 New users split into new and returning (`newVsReturning`, filter `app_role = main`)

| Window | main active, new / day | main active, returning / day |
|---|---|---|
| Baseline | 1.6 ±0.4 | 4.2 ±0.7 |
| Oct 22–30 | 3.6 ±1.2 | 6.1 ±1.6 |
| Oct 31–Nov 8 | 2.6 ±1.0 | 5.4 ±1.5 |
| Nov 9–17 | 2.0 ±0.9 | **7.2 ±1.8** |
| Nov 18–20 | 2.0 ±1.6 | 6.3 ±2.8 |

The new-user series moves with the surge. The returning series rose and then stayed level. The website cannot move returning users directly, and they did not fall.

### 2.3 Activation (`eventName` in `tile_created`, `tile_added_to_dock`; metric `totalUsers` per day)

| Window | `tile_created` users / day | `tile_added_to_dock` users / day | new helpers / day (`firstSessionDate`, `app_role = helper`) |
|---|---|---|---|
| Baseline | 1.6 ±0.4 | 1.5 ±0.4 | 1.6 ±0.4 |
| Oct 22–30 | 3.1 ±1.2 | 3.2 ±1.2 | 4.6 ±1.4 |
| Oct 31–Nov 8 | 2.3 ±1.0 | 2.7 ±1.1 | 3.7 ±1.3 |
| Nov 9–17 | 1.8 ±0.9 | 1.6 ±0.8 | 2.3 ±1.0 |
| Nov 18–20 | 1.3 ±1.3 | 1.3 ±1.3 | 5.7 ±2.7 |

Activation follows installs. It goes up with the surge and comes back to the baseline after it.

### 2.4 Probably the chart behind the worry: rolling actives (`activeUsers`, `active7DayUsers`, `active28DayUsers` by `date`)

| Date | all instances, 7-day | all instances, 28-day | main, 7-day | main, 28-day |
|---|---:|---:|---:|---:|
| Oct 20 | 49 | 103 | 19 | 68 |
| Nov 10 | **97** | 179 | 37 | 87 |
| Nov 16 | **59** | 177 | 28 | 90 |
| Nov 19 | 64 | 180 | 33 | **92** |

The all-instance 7-day count fell 39%. Main-app 28-day actives are at their highest level yet.

### 2.5 Engagement by ISO week (`weekly_events`)

| Week | `popover_opened` | `session_start` | `first_open` users |
|---|---:|---:|---:|
| 43 (Oct 19) | 1277 | 581 | 30 |
| 44 (Oct 26) | 1159 | 614 | 45 |
| 45 (Nov 2) | 1185 | 559 | 46 |
| **46 (Nov 9)** | **1307** | **686** | 23 |
| 47 (6 days) | 1037 | 621 | 26 |

Week 46, the first week after the Nov 9 redesign, had the most popover opens and sessions in the window.

### 2.6 Where the surge came from (`firstSessionDate` × `country`, filter `app_role = main`)

| Country | Sep 21–Oct 21 (31 d) | Oct 22–Nov 8 (18 d) | Nov 9–21 (13 d) |
|---|---|---|---|
| United States | 9 (0.29/d) | 10 (0.56/d) | 8 (0.62/d) |
| China | 7 (0.23/d) | **13 (0.72/d)** | 4 (0.31/d) |
| others | 35 | 33 | 15 |

The site is English-only (`website/.claude/rules/content-i18n.md`). The app gained zh-Hans on Oct 18 (2.3.0). A Chinese-language mention around Oct 22 would fit these numbers, but it is unverified.

### 2.7 Other explanations checked

- **Releases and silent updates.** Sparkle has installed updates silently since 2.3.1 (`ci-release.md`). Updates do not create new instances: helper-new counts stayed near 9–14 a week through the Oct 12–18 release burst (`weekly_role_newret`). `app_update` spikes on Nov 13 (22 events) and Nov 16 (15) are 2.7.2 reaching existing users, and they do not touch installs.
- **Downloads.** GitHub DMG `download_count` (`gh api repos/k97/dock-tile/releases`, cumulative, Sparkle updates included) ran 13.1 a day Oct 22–30, 10.1 Oct 31–Nov 8 and 9.1 Nov 9–21, against 5.5 in early October. Downloads did not collapse after Nov 9.
- **Day of week.** Sunday is the lowest day for installs (1.4 a day). The Nov 14–15 weekend (1 each) fits that pattern.
- **Seasonality.** There is no prior year to compare against.
- **Old host.** `docktile.rkarthik.co` serves the appcast to builds ≤ 1.8.8 (`seo-geo.md`). It affects updates, not new installs.
- **GitHub repo as a source.** 0–8 views a day for the last 14 days (`traffic/views`). It is not a channel.
- **Tracking breakage on the site.** None found in the code (§1). It cannot be confirmed without the site property.

## 3. The homepage sections after the hero and features, version by version

Heights are estimates from the Tailwind classes at a 1440 × 900 window, in screens, not measured renders. The full tables are in note 03.

| | **A** `74958d2` (Jul 11) | **B** `9553148` (Oct 19) | **C** `f64c259` (Oct 31) | **D** HEAD (Nov 9 + Nov 18) |
|---|---|---|---|---|
| Features section | "Customised tiles with the simple editor." two-column screenshot, ≈0.8 | same | "Pick your apps. Pick a look. Done." full-width capture + 4 hotspots, ≈1.5 | same + inline tile, ≈1.7 |
| Post-features 1 | **Dock Lock**, own dark band: "The Dock stays put." ≈0.6 | same | same | **Details** (light): "More than ✦ a tile in your Dock." Style customiser card + Menu bar card + 4 one-liners, ≈1.4 |
| Post-features 2 | Power-user bento (light): Grid or list · Smart Add · Ghost, ≈1.0 | same | same | Power-user bento (light): Smart Add · **Dock Lock** · Ghost, ≈1.0 (≈2.2 below 1280 px) |
| Post-features 3 | Final CTA (dark): "Get organised today." + Download + support + Spades pill, ≈0.6 | same + "Apple silicon" | Closing band: "All your apps. One tile." + Download + closing Dock, ≈0.7 | same; the closing Dock auto-plays, ≈0.7 |
| Ideas after the features section | 4 | 4 | 4 | **9** |
| Light/dark rhythm after the hero | L · D · L · D | same | same | **L · L · L** · D |
| Screens from the end of features to the next Download | ≈2.2 | ≈2.2 | ≈2.3 | **≈3.1 (≈4.3 below 1280 px)** |
| Closing ask | an imperative | an imperative | a tagline; 4 other links under the button | a tagline; a moving Dock under the button |

Sources: `git show <commit>:website/app/page.tsx`, `…/components/home-sections.tsx`, `…/lib/i18n.ts` (`marketingBase`), `website/components/closing-band.tsx`, `website/components/closer-look.tsx`.

What changed in the post-features part, in order of weight:

1. **The first card repeats the features section.** `tilesBody`: "show the tile as a grid of its apps, or give it a symbol or an emoji, in colour or mono". `customBody`: "Show a grid of the tile's own apps, or a symbol or an emoji, in full colour or Mono". The closer-look hotspots already cover Style and Background (`website/lib/i18n.ts`).
2. **More than twice as many ideas compete.** In A–C each post-features section carried one message. D adds a section of 6 ideas ahead of the bento. The 4 one-liners (keyboard, folders, grid/list, languages) are conveniences that answer no buyer question.
3. **Dock Lock lost its chapter.** It was the only section framed around a problem the visitor has ("Stop the Dock from jumping between screens"), and its dark band gave the page a pause. In D it is the middle bento card (`6320feb`). Below 1280 px, where `xl:grid-cols-3` stacks the bento, it sits roughly 4½–5 screens down the page.
4. **Three light sections in a row.** Each has a centred 44 px heading with a tilted inline tile (`design-system.md`). The repeated shape and the missing dark break make the stretch read as one long scroll.
5. **The ending asks less.** "Get organised today." became "All your apps. One tile." (`79f00bf`). Since `93a3295`, an auto-playing Dock with GitHub · What's new · Contact · Studio sits 240 px below the button.
6. **Buyer questions.** *What is it?* The hero answers it in every version. *Why me?* Weaker in D (point 3). *Does it work on my Mac?* Better in D, with `DownloadMeta` "Apple silicon · macOS 15+" under both Downloads. *Is it safe?* Unchanged everywhere: an "Open source" link and the Smart Add privacy line. *What does it cost?* No version says it is free (no "free" in `website/lib/i18n.ts`, then or now). *How do I get it?* Download in the hero, the nav (md+) and the end. There has never been a mid-page CTA.

D also improved several things that should be kept: requirements under every Download, the 18 px body (A's bento body was 14 px), the feedback links, and a customiser that teaches the styles by letting visitors try them.

## 4. Design options for the post-features part

The site data is not reachable, so two prerequisites apply to every option. **(a)** Give `ga4-fetch` Viewer on the `G-PP04F8Z0EP` property, or read it in the GA UI. **(b)** Add a `location` parameter to `download_click` (hero / nav / mid / closing) and register it as a custom dimension the same day. Registration is forward-only (`analytics.md`). Today every click sends `event_label: "download_button"` (`website/lib/analytics.ts`), so no comparison can tell which button converted.

**How to read any option after two weeks** (the same recipe for all four). In the website property, use a free-form exploration filtered to landing page `/`. Compare the 14 days before the ship with the 14 days after, aligned to the same weekdays. The primary metric is `download_click` event count ÷ sessions. The secondary metrics are the share of sessions with a `scroll` event (GA4's enhanced measurement fires it at 90% depth) and `download_click` by `location`. A rule of thumb for noise: with conversion rate p and S sessions per window, a relative change smaller than about 2.8·√(2(1−p)/(p·S)) is noise. At p = 10% and S = 1,000 that is about 38%. App installs are too sparse to judge a site change in 2 weeks. At about 2 a day, a 30% change needs about 10 weeks per side to detect (80% power), and a 50% change about 3½ weeks. So use them only as a 4-week lagging check: `firstSessionDate` × `totalUsers`, filtered to `customUser:app_role = main`.

### Option 1: Back to four ideas (the July shape, current polish)
- **What changes:** remove `DetailsSection`. Dock Lock goes back to its own dark band right after the features section (`DockLockStory` at `f64c259`, with today's copy). The bento becomes Smart Add · Menu bar · Ghost. The 4 one-liners either move under the bento or go.
- **Why:** it restores one message per section and the light/dark/light/dark chaptering, and it puts back the one problem-led section. The post-features part shrinks from about 3.1 to about 2.4 screens.
- **Trade-off:** the interactive customiser card is lost from the homepage. The owner chose it on Nov 9, and Option 2 is the way to keep it. Menu bar drops from a big card to a bento card.
- **Measure:** download_click per session, plus 90%-scroll share (shorter page, more sessions should reach the end).

### Option 2: One demo, then problems
- **What changes:** the interactive customiser moves into the features section as the "Pick a look" proof, replacing or following the closer-look capture, so the styles are shown once. After it come three problem-led cards: "The Dock jumps between screens" → Dock Lock, "Too much in ⌘Tab" → Ghost, "Don't know where to start" → Smart Add. Menu bar becomes a fourth card or a one-liner. Then the closing band.
- **Why:** it removes the repetition in point 1, and each remaining card answers "why me?" with a pain the visitor may have rather than a capability.
- **Trade-off:** it means rewriting the copy, and each problem line has to be checked against the app (`content-i18n.md`). Putting the customiser in the features section makes that section heavier, so the closer-look capture and the toy must not both stay at full size.
- **Measure:** download_click per session. If section views are added (one `section_view` event per `data-nav-section`), compare the drop-off between the features section and the closing band.

### Option 3: Keep the content, fix the ask (smallest change)
- **What changes:** add one compact Download row (button + `DownloadMeta`) after the bento. Give the closing band an imperative headline back, for example "Get organised today." Stop the closing Dock from auto-playing, or drop it below the meta line at a smaller size, so nothing moves under the button.
- **Why:** it addresses points 5 and 6 (the long path to the next Download, and the weak ending) without touching the section design the owner chose. With `location` on `download_click`, it also shows how many clicks the end of the page earns.
- **Trade-off:** the page keeps its 9 ideas and its repetition, and a mid-page button can feel pushy on a calm page.
- **Measure:** download_click per session, plus the share of clicks with `location = mid | closing`.

### Option 4: Answer "is it safe, what does it cost" where the one-liners are
- **What changes:** replace the 4 one-liners with a 4-item trust row. "Free and open source (MIT)" links to GitHub. "Apple silicon · macOS 15+" is the requirement. "Your data stays on your Mac" covers Smart Add on-device, with analytics optional and anonymous, and links to Privacy. "Why not the App Store?" links to the FAQ answer about helper bundles.
- **Why:** no version answers the cost and safety questions on the homepage, and a direct-download app that installs helper bundles has to earn trust. The row costs no extra height, because it takes the one-liners' slot.
- **Trade-off:** `content-i18n.md` keeps "Signed & notarized" on the legal pages only, so leave that claim out unless the owner changes the rule. Every line must match Privacy/Terms as re-verified on 2026-11-09.
- **Measure:** download_click per session, plus clicks through to `/privacy` and `/faq` from `/` (page_view with the previous page path).

Suggested order: complete the two prerequisites, ship Option 3 alone to get a clean read on the ask, then choose between Option 1 and Option 2 for the structure. Option 4 can ride with either.

## 5. Open questions

1. **Which property holds `G-PP04F8Z0EP`, and can `ga4-fetch` get Viewer on it?** Until then, nobody can test the causal question. The first pull should be source/medium and country for Oct 22–Nov 8, to identify the surge.
2. **What started the Oct 22 surge?** China accounts for about a quarter of it. Was there a post, a listing or a newsletter around the 2.5.0 release?
3. **Which chart prompted the worry?** If it was GA's default "Active users" card, it includes helpers. A main-only exploration (`app_role = main`) is the honest default.
4. **When did each Vercel deploy go live?** I used commit times (Oct 31 00:08, Nov 9 15:39, Nov 18). The exact push and deploy times are unverified.
5. **Should "Signed & notarized" stay off the homepage?** It matters for Option 4.
6. **Is a section-view event wanted?** Without one, per-section drop-off can only be inferred from the single 90% scroll event.
