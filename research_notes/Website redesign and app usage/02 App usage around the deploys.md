# App usage around the website deploys

Property `542196919`, pulled 2026-11-21. Nov 21 is a partial day, and ISO week 47 (Nov 16–22) holds 6 days of data. All raw data is in `ga-data/`.

## Timeline

| Date (AEDT) | Website (`git log -- website/`) | App release (git tag) |
|---|---|---|
| Jul 7–11 | homepage consolidation + polish (`b3d15b5` … `74958d2`) | 1.8.x |
| Sep 7 / Sep 21 / Oct 2 | — | 2.0.0–2.0.1 / 2.0.2 / 2.0.3 |
| Oct 12–20 | `9553148` Apple silicon note (Oct 19) | 2.1.0, 2.2.0, 2.2.1, 2.2.2, 2.3.0 (5 languages), 2.3.1 (silent Sparkle installs), 2.4.0 |
| Oct 22–23 | — | 2.5.0, 2.5.1 |
| Oct 28–30 | — | 2.6.0, 2.6.1, 2.6.2 |
| **Oct 31** (00:08) | `79f00bf` closing Dock ending, `414f489` Features rewrite + closer look, `f64c259` | 2.6.3 |
| Nov 4 / Nov 7 | — | 2.6.4 / 2.7.0 (menu bar) |
| **Nov 9** (15:39) | `2da40a7` two big cards, `93a3295` typography + closing Dock demo + feedback links, `6320feb` Dock Lock into bento, `63789d3` | 2.7.1 |
| Nov 10 | — | 2.7.2 |
| **Nov 18** | `3d778c8` Allo font | — |

## 1. Weekly installs, main app vs helpers (`firstSessionDate`, filtered on `customUser:app_role`)

Query: `install_date_main` / `install_date_helper` (dimension `firstSessionDate`, metric `totalUsers`, filter `app_role = main | helper`, 2026-09-01..11-21), summed per ISO week by `weekly_installs.py`.

| ISO week (starts) | main installs | new helpers (≈ new tiles docked) |
|---|---:|---:|
| 36 (Aug 31) | 12 | 14 |
| 37 (Sep 7) | 21 | 20 |
| 38 (Sep 14) | 14 | 19 |
| 39 (Sep 21) | 14 | 14 |
| 40 (Sep 28) | 14 | 12 |
| 41 (Oct 5) | 16 | 12 |
| 42 (Oct 12) | 6 | 11 |
| 43 (Oct 19) | 15 | 18 |
| **44 (Oct 26)** | **21** | **29** |
| **45 (Nov 2)** | **21** | **28** |
| 46 (Nov 9) | 12 | 15 |
| 47 (Nov 16, 6 days) | 15 | 25 |

Weeks 36–43 average 14.0 main installs a week. The Poisson 95% band for one week at that rate is about 7 to 21. Weeks 44–45 sit at the top of the band. Week 46 (12) is inside it, and week 47 is on pace for about 17.

## 2. Daily rates in windows around each deploy (`windows.py` → `ga-data/windows-output.tsv`)

Each cell is the mean per day, with ±1.96·√n / days as the Poisson 95% band, and n = the window total.

| Series | Sep 21–Oct 21 (baseline) | Oct 22–30 (before deploy 1) | Oct 31–Nov 8 (after Oct 31) | Nov 9–17 (after Nov 9) | Nov 18–20 (after Allo) |
|---|---|---|---|---|---|
| main installs | 1.6 ±0.5 (51) | 3.3 ±1.2 (30) | 2.9 ±1.1 (26) | 1.9 ±0.9 (17) | 2.7 ±1.8 (8) |
| new helpers | 1.6 ±0.4 (50) | 4.6 ±1.4 (41) | 3.7 ±1.3 (33) | 2.3 ±1.0 (21) | 5.7 ±2.7 (17) |
| `first_open` events (all instances) | 3.3 ±0.6 (103) | 8.1 ±1.9 (73) | 6.8 ±1.7 (61) | 5.1 ±1.5 (46) | 7.0 ±3.0 (21) |
| `tile_created` users | 1.6 ±0.4 (49) | 3.1 ±1.2 (28) | 2.3 ±1.0 (21) | 1.8 ±0.9 (16) | 1.3 ±1.3 (4) |
| `tile_added_to_dock` users | 1.5 ±0.4 (47) | 3.2 ±1.2 (29) | 2.7 ±1.1 (24) | 1.6 ±0.8 (14) | 1.3 ±1.3 (4) |
| main DAU | 5.4 ±0.8 | 8.9 ±1.9 | 7.1 ±1.7 | 8.7 ±1.9 | 8.0 ±3.2 |
| main active, returning | 4.2 ±0.7 | 6.1 ±1.6 | 5.4 ±1.5 | **7.2 ±1.8** | 6.3 ±2.8 |
| main active, new | 1.6 ±0.4 | 3.6 ±1.2 | 2.6 ±1.0 | 2.0 ±0.9 | 2.0 ±1.6 |
| all DAU (main + helpers) | 21.9 ±1.6 | 32.9 ±3.7 | 30.0 ±3.6 | 30.1 ±3.6 | 32.0 ±6.4 |
| `app_launched` users | 14.3 ±1.3 | 18.2 ±2.8 | 19.6 ±2.9 | 22.9 ±3.1 | 21.3 ±5.2 |

Daily main installs (`install_date_main`):
`10-15..10-21: 1 0 0 0 0 1 0` → `10-22..10-31: 4 5 2 3 3 5 1 3 4 4` → `11-01..11-08: 1 7 1 0 6 2 3 2` → `11-09..11-17: 3 2 2 2 1 1 1 2 3` → `11-18..11-21: 0 2 6 2`

- **The surge began on Oct 22**, nine days before the first website deploy and on the day 2.5.0 shipped. In the week before it, Oct 15–21, main installs were nearly zero.
- **Surge vs. after Nov 9:** 56 installs in 18 days (Oct 22–Nov 8), then 17 in the 9 days of Nov 9–17. A binomial test of the 73 installs split 18:9 gives z ≈ −1.8, two-sided p ≈ 0.07. That is borderline, and it compares against a surge, not a baseline.
- **After Nov 9 vs. the baseline:** 27 installs in 13 days (Nov 9–21) = 2.1 a day, against 1.6 a day before the surge. There is no decline against the baseline.
- Day of week (Sep 21–Nov 20): Sunday is lowest for installs (1.4 a day) and for main DAU (5.5). Nov 14–15 (Sat–Sun) at 1 each fits that.

## 3. Rolling 7-day and 28-day actives: probably the chart behind the worry (`all_active_7_28`, `main_active_daily_dau`)

| Date | all 7-day | all 28-day | main 7-day | main 28-day |
|---|---:|---:|---:|---:|
| Oct 20 | 49 | 103 | 19 | 68 |
| Oct 29 | 89 | 140 | 37 | 77 |
| Nov 10 | **97** | 179 | 37 | 87 |
| Nov 16 | **59** | 177 | 28 | 90 |
| Nov 19 | 64 | 180 | 33 | **92** |

The all-instance 7-day count fell 39%, from 97 to 59. That is the dip a GA overview card shows. Two things drive it: helpers, and the end of the surge in new instances. The main-app 28-day count is at its highest level yet (92).

## 4. Where the surge came from (`main_country_install`, `country.py`)

Main installs by country and window, with the window lengths in days:

| Country | base Sep 21–Oct 21 (31 d) | surge Oct 22–Nov 8 (18 d) | after Nov 9–21 (13 d) |
|---|---:|---:|---:|
| United States | 9 (0.29/d) | 10 (0.56/d) | 8 (0.62/d) |
| China | 7 (0.23/d) | **13 (0.72/d)** | 4 (0.31/d) |
| Japan | 4 | 2 | 1 |
| Australia | 1 | 4 | 2 |
| everyone else | 30 | 27 | 12 |

- China supplied about a quarter of the surge, and it is the country that fell back hardest. The US rate went up during the surge and stayed up after the Nov 9 redesign.
- The site is English-only (`content-i18n.md`), while the app gained zh-Hans on Oct 18 (2.3.0). A Chinese-language mention after that release fits these numbers, but it is unverified: the app stream records no acquisition source, `firstUserSource` = `(direct)`.
- `firstopen_country_periods.tsv` also shows Italy with 15 new users but 4 active in Oct 31–Nov 21. That looks like one person creating many tiles, each a new helper "user". It illustrates why `newUsers` cannot serve as a downloads metric.

## 5. Download counts per release (GitHub, cumulative, includes Sparkle updates)

`gh api repos/k97/dock-tile/releases`, DMG `download_count` per release, read 2026-11-21:

| Window | Releases live | DMG downloads | per day |
|---|---|---:|---:|
| Sep 21–Oct 1 | 2.0.2 | 62 | 5.6 |
| Oct 2–11 | 2.0.3 | 55 | 5.5 |
| Oct 12–21 | 2.1.0–2.4.0 (7 releases) | 96 | 9.6 |
| Oct 22–30 | 2.5.0–2.6.2 (5) | 118 | 13.1 |
| Oct 31–Nov 8 | 2.6.3, 2.6.4, 2.7.0 | 91 | 10.1 |
| Nov 9–21 | 2.7.1, 2.7.2 | 118 | 9.1 |

These counts are confounded. Every release triggers Sparkle downloads of its DMG (the appcast points at it, and `app_update` shows 103 events from 31 users Oct 25–Nov 21, `update_events_version.tsv`), and older DMGs keep accruing from direct links. Even so, downloads after Nov 9 did not collapse.

## 6. Returning and engaged use rose; it did not fall (`weekly_events.tsv`)

| ISO week | `popover_opened` | `app_launched` (events) | `session_start` | `first_open` users |
|---|---:|---:|---:|---:|
| 43 | 1277 | 1045 | 581 | 30 |
| 44 | 1159 | 718 | 614 | 45 |
| 45 | 1185 | 842 | 559 | 46 |
| 46 | **1307** | 997 | **686** | 23 |
| 47 (6 d) | 1037 | 719 | 621 | 26 |

Week 46 had the most popover opens and sessions of any week in the window. The fall shows up only in `first_open`, meaning new instances.
