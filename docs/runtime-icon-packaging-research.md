# Runtime Icon Packaging — Can a Helper Bundle Ship a Declarative Icon?

> How this investigation started and every dead end it closed: [icon-investigation-trail.md](icon-investigation-trail.md)

Why this exists: Dock Tile generates each tile's icon **at runtime on the user's Mac** (custom tint
× SF Symbol/emoji, rendered by `IconGenerator`) and installs it into an ad-hoc-signed helper bundle
as `AppIcon.icns`, then **swaps the file in place** whenever the macOS 26 "Icon & widget style"
(Default/Dark/Clear/Tinted) or Light/Dark appearance changes. That swap requires appearance-change
*detection*, which has proven unreliable (see
[macos-appearance-detection-research.md](macos-appearance-detection-research.md) and
[icon-style-detection.md](../.claude/rules/icon-style-detection.md)). The goal under evaluation:
**delete detection entirely** by shipping something *declarative* in the helper bundle that macOS
itself renders correctly in every appearance mode — the way it does for normal apps. The candidate
is Icon Composer's `.icon` document (the repo's example,
[docs/v2/icons/hanger-appicon.icon](v2/icons/hanger-appicon.icon/), is a ~1.5 KB `icon.json` plus
three PNGs in `Assets/` — trivially generatable at runtime without Xcode). The decisive unknown:
**does macOS 26 consume a `.icon` from inside a bundle at runtime, uncompiled, or is it strictly an
authoring format that `actool` must compile into `Assets.car`?**

**Every claim below is tagged.** `[DOCUMENTED]` = Apple developer documentation, HIG, release notes
or a shipped man page, linked. `[SOURCE]` = open source / a shipped header, man page or tool.
`[OBSERVED]` = reproduced first-hand or reported by the community with no Apple documentation
behind it. `[APPLE STAFF]` = an Apple engineer on the record. `[INFERENCE]` = my own reasoning from
the above. `[NEEDS LOCAL VERIFICATION]` = could not be settled from sources; a local experiment in
§4 covers it. Where nothing exists, the note says **undocumented** rather than guessing.

**Method limits, stated up front.** This is a web-research + repo-reading pass: no command was run
on this machine. `developer.apple.com/forums` content is quoted via fetch/search summaries;
attribution confidence is noted per item. The spike checklist at the end is written to be executed
mechanically on this Mac (macOS 26.6.2, Xcode 26 installed).

---

## Summary — what the evidence says

1. **The `.icon` document is an authoring format. Every known consumer compiles it; none renders
   it in a shipped bundle.** Apple's own documentation frames it exclusively as a build-time input
   ("add the Icon Composer file to your Xcode project… Xcode automatically generates app icon
   images at build time"), and every non-Xcode toolchain that has adopted Tahoe icons — Qt,
   Electron, Tauri, Wails, emacs-plus, .NET — does it the same way: run **`actool`** on a Mac with
   Xcode, ship the compiled **`Assets.car`** plus a legacy `.icns`, and point
   **`CFBundleIconName`** at the compiled asset. Nobody, anywhere, reports macOS rendering a raw
   `.icon` placed in a bundle. (§1, §2b) No Apple statement rules it out *explicitly* either — the
   definitive answer is one 20-minute local experiment (§4, experiment 2), but plan on **NO**.

2. **The declarative payoff is real — for the compiled artifact.** Once an `Assets.car` containing
   the layered icon (`IconImageStack`/`IconGroup`/gradient/color renditions) is in the bundle, the
   *system* renders Default/Dark/Clear/Tinted and Light/Dark variants at display time with zero
   app-side code — Apple: "The system automatically renders your app icon for the different
   platforms, appearances, and sizes from your single Icon Composer file." That is exactly the
   "delete detection" property we want. The problem is purely **how a user's Mac, with no Xcode,
   gets a per-tile `Assets.car`**. (§2a, §2c)

3. **`actool` cannot run on user machines and cannot be redistributed.** It ships inside Xcode
   (the `/usr/bin/actool` shim requires a full Xcode via `xcode-select`), and the Wails
   maintainers state the constraint plainly: "actool is proprietary as well as Icon Composer so
   it's not possible to generate the new liquid icons without access to a Mac [with Xcode]."
   Runtime compilation on users' Macs is off the table. (§2b)

4. **`Assets.car` is an undocumented binary format, but it is not unwritable.** The format is
   reverse-engineered (BOM container, CoreUI renditions — Timac 2018); read-side tooling is mature
   (acextract, AssetCatalogTinkerer, Samra, assetutil); and **payload patching of classic bitmap
   renditions has been demonstrated in production** (Appdome: recompress lzfse BGRA payload,
   rewrite offsets). Nothing public has yet patched the *Tahoe layered-icon* rendition types
   (IconImageStack / PackedImage / Named Gradient), which is precisely what a per-tile template
   would need. Feasibility is a local binary-diff experiment away (§4, experiments 6–7). This is
   the highest-ceiling option and the highest-risk one. (§2c)

5. **There is one sanctioned zero-detection path available today, at a design cost: ship ONE
   static icon and let Tahoe generate the variants.** The HIG: "the system automatically generates
   variants you don't provide" — and this repo has already observed Tahoe's system-generated
   dark/clear/tinted treatment applied to `.icns`-only third-party apps
   ([icon-system rule](../.claude/rules/icon-system.md), App Icon Loading). A helper that ships
   only its Default `.icns` needs **no detection, no swap, no seal break** — macOS restyles it.
   What it gives up is Dock Tile's hand-designed Dark variant (tinted-glyph-on-near-black). Whether
   the system's automatic treatment of our full-bleed squircle icons is acceptable is a visual
   judgement — 10 minutes with the style switcher (§4, experiment 1). **Do this experiment first;
   if the system treatment looks good, the entire redesign collapses into a deletion.** (§2c, §3)

6. **`NSDockTilePlugIn` does answer §C8's open question — YES, it can draw the full tile icon for
   a pinned, not-running app** (loaded by the Dock's own XPC process at login or when the tile is
   added; the host app never has to launch). But it does not *delete* appearance handling — it
   relocates the drawing code into the Dock's always-active process, where the delivery problems
   that plague idle helpers shouldn't apply. It is a fallback that fixes *detection reliability*,
   not one that achieves *declarativeness* — and whether plugin-drawn content receives Tahoe's
   icon-style treatment at all is unknown. (§2d, §3a)

7. **Recommended posture for the plan**: run §4 experiments 1–3 before designing anything. They
   settle, in order: (a) is the system's automatic restyling of a single static icon good enough
   (if yes: delete everything); (b) does raw `.icon` render (almost certainly no, but it's cheap
   and decisive); (c) does a per-tile compiled `Assets.car` in an ad-hoc-signed helper give
   flawless all-mode rendering with zero code (the ceiling the template-patch option would buy).
   Only then weigh the template patch (§2c) against keeping the current detection design.

---

## 1. The `.icon` format itself

### 1a. What Apple documents about the format

- **The official page** — *Creating your app icon using Icon Composer* — describes the document
  and its role, entirely in build-time terms:
  > "Use Icon Composer to create a single multilayer file that you can add to your Xcode project
  > to represent your Liquid Glass app icon everywhere your app icon appears across iOS, iPadOS,
  > macOS, watchOS, and the App Store."
  >
  > "The system automatically renders your app icon for the different platforms, appearances, and
  > sizes from your single Icon Composer file."
  >
  > "Before building your app, add the Icon Composer file to your Xcode project to include it in
  > your app's bundle." · "Xcode automatically generates app icon images at build time for those
  > releases from the Icon Composer file."

  `[DOCUMENTED]` Source: https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer

  Note the second-last sentence's ambiguity ("to include *it* in your app's bundle") — read
  literally it could mean the `.icon` itself ships. Community consensus is that only compiled
  output ships (§1b), and forum posters state it outright ("The .icon file itself is not bundled
  in the app; only its compiled output (in Assets.car) is included" — developer thread 794485,
  no Apple badge). `[OBSERVED — forum, no Apple staff]` Whether any real Tahoe app ships a raw
  `.icon` is trivially checkable locally. **[NEEDS LOCAL VERIFICATION]** (§4, experiment 0b)
- **The JSON schema is not documented by Apple anywhere.** No reference page describes
  `icon.json`'s keys. The format is, however, plain JSON + loose PNG/SVG layers and has been
  community-documented and re-implemented:
  - `giginet/apple-icon-composer-skill` maintains an `icon-schema.json` it calls "the
    authoritative definition of the `icon.json` format for both Icon Composer 1.x and 2.x —
    including per-slot specialization overrides (appearance, idiom, localization), the Liquid
    Glass property set on groups (lighting, specular, blur-material, refractivity, translucency,
    shadow)". `[OBSERVED — community schema]`
    Source: https://github.com/giginet/apple-icon-composer-skill
  - Third-party generators already write valid `.icon` bundles without Icon Composer:
    `StewartLynch/IconComposerLite` ("packages them into an .icon bundle alongside an icon.json…
    the same format Xcode's Icon Composer tool produces") and `ethbak/icon-composer-mcp` (CLI/MCP
    that creates and manipulates `.icon` bundles). `[OBSERVED]`
    Source: https://github.com/StewartLynch/IconComposerLite ·
    https://github.com/ethbak/icon-composer-mcp
  - The repo's own example confirms the shape: `hanger-appicon.icon/icon.json` is 74 lines —
    a document-level `fill` (linear-gradient of display-p3 colors with an orientation), one
    `groups[]` entry with `blur-material`, `specular`, `translucency`, a `shadow`, and three
    `layers[]` referencing PNGs by `image-name` (light/dark/tinted variants) with per-layer
    `scale`/`translation-in-points`, plus `supported-platforms`. The three referenced PNGs
    (~1024 px) sit in `Assets/`. `[SOURCE — this repo]`

  **Consequence** `[INFERENCE]`: *authoring* a per-tile `.icon` at runtime is trivial for Dock
  Tile — gradient fill = the tile tint, one glyph layer per appearance = one PNG render each,
  which `IconGenerator` already knows how to draw. The open question was never authoring; it is
  consumption.
- **Icon Composer itself** is a free standalone app ("compatible with macOS Sequoia and later"),
  and the WWDC25 session *Say hello to the new look of app icons* introduces the appearance modes
  without ever describing a runtime file format contract. `[DOCUMENTED]`
  Source: https://developer.apple.com/icon-composer/ ·
  https://developer.apple.com/videos/play/wwdc2025/220/

### 1b. What Xcode 26 / actool produce from a `.icon`

- **`actool` compiles the `.icon`; for macOS it emits three artifacts.** Frank Krueger (invoking
  actool by hand for .NET builds):
  > "This will produce 3 files: (1) `MyIcon.icns` — backwards compatible icon for macOS 11.0 and
  > later (2) `Assets.car` — the archived assets that contain the new fully layered icon for
  > macOS 26. (3) `assetcatalog_generated_info.plist`"

  with the command
  `actool MyApp/MyIcon.icon --app-icon MyIcon --compile . --output-partial-info-plist … --minimum-deployment-target 11.0 --platform macosx --target-device mac`.
  `[OBSERVED — widely replicated]` Source: https://praeclarum.org/2025/09/12/app-icons.html
- **Info.plist result: `CFBundleIconName`** — the partial plist's entries must be merged into the
  app's Info.plist; the key every manual adopter reports is `CFBundleIconName` set to the
  `--app-icon` name. Apple documents the key as "the name of the asset that represents the app
  icon", required for "apps that provide icons in the asset catalog". The legacy `CFBundleIconFile`
  → `.icns` pairing stays alongside for older systems. `[DOCUMENTED]` + `[OBSERVED]`
  Source: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconname ·
  https://successfulsoftware.net/2025/09/26/updating-application-icons-for-macos-26-tahoe-and-liquid-glass/ ·
  https://www.hendrik-erz.de/post/supporting-liquid-glass-icons-in-apps-without-xcode
- **What's inside the compiled car**: per `assetutil --info`, the layered icon compiles to new
  rendition types — "Assets.car can contain an iconstack that has all the vector layers, color
  data etc for the glass icon and the traditional MultiSized Image with all the icon size
  variants for legacy macOS versions"; a correctly compiled car shows `IconImageStack`,
  `IconGroup`, `Named Gradient`, `Color`, and `PackedImage` renditions. `[OBSERVED — forum +
  issue reports]` Source: https://developer.apple.com/forums/thread/794485 ·
  https://github.com/manaflow-ai/cmux/issues/8517
- **Known toolchain gotchas** (matter for our own compile step and for reading others' failures):
  - A `.icon` with **more than 4 groups** fails to compile to a usable resource; macOS hides the
    `.icon` extension in Finder, a repeated source of confusion. `[OBSERVED]`
    Source: https://forum.xojo.com/t/how-to-create-app-icons-for-macos-26-and-maintain-compatibility-with-older-oss/86527
  - **Xcode 26.x actool has shipped flattening bugs**: release builds emitting a *non-layered*
    icon (missing `IconImageStack`), which renders oversized in the App Switcher; and the
    undocumented `--enable-icon-stack-fallback-generation=disabled` escape hatch that worked in
    Xcode 26 beta 6 "stopped working in Xcode 26.1+". Validate every compiled car with
    `assetutil --info`, never by eyeball. `[OBSERVED]`
    Source: https://github.com/manaflow-ai/cmux/issues/8517 ·
    https://developer.apple.com/forums/thread/794485
  - The car's internal image names contain **random UUIDs per compilation** (broke Electron's
    universal-binary SHA comparison) — two compiles of the same input are not byte-identical.
    Relevant to any template-diff plan (§2c): diff *one* template against a patched copy, never
    two independent compiles. `[OBSERVED]`
    Source: https://github.com/electron/universal/issues/148
  - Community fallback-ordering note (Sarah Reichelt): name the Icon Composer file the same as
    the legacy `AppIcon` asset "and your app will use the new one and fall back to the old one if
    required". `[OBSERVED]` Source: https://mjtsai.com/blog/2025/06/23/icon-composer-notes/
- **Apple's own docs never mention actool/Assets.car/CFBundleIconName in the Icon Composer
  context** — the pipeline is abstracted behind Xcode's UI. The command-line contract above is
  entirely community-established (consistent across at least five independent write-ups).
  `[DOCUMENTED — absence]` + `[OBSERVED]`

---

## 2. Runtime consumption — the decisive question

### 2a. Does anything render a `.icon` without compilation?

- **No Apple documentation, release note, or staff statement says macOS renders a `.icon` found
  in a bundle.** Everything Apple publishes describes the `.icon` as input to Xcode and describes
  the *system* as rendering appearances "from your single Icon Composer file" — via the build
  products. No page describes a runtime lookup path for `.icon`; `CFBundleIconFile` is documented
  only for `.icns`, `CFBundleIconName` only for asset-catalog assets. **Undocumented in the
  direction we'd need; consistently documented in the compile-time direction.**
  `[DOCUMENTED — absence]`
  Source: https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer ·
  https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconname
- **The community negative evidence is strong and uniform.** Electron's feature request for
  `.icon` support states the ecosystem's position as fact: "macOS 26 introduced the new layered
  .icon format… Electron's nativeImage / app.dock.setIcon() can't load .icon, forcing developers
  to ship pre-rendered images and lose system-driven variants" — i.e. even *Apple's own
  image-loading APIs reachable from AppKit* don't consume it, let alone a loose file in
  Resources. Every adopter thread (Electron, Tauri, Wails, Qt, Xojo, .NET, emacs-plus) converges
  on compile-then-ship; none reports a runtime path, and none reports even *trying* the raw
  `.icon` and having it work. `[OBSERVED]`
  Source: https://github.com/electron/electron/issues/48476 ·
  https://github.com/tauri-apps/tauri/issues/14207 · https://github.com/wailsapp/wails/issues/4909
- **What macOS 26 demonstrably consumes at runtime is the compiled `Assets.car`.** The
  system-side rendering is real and dynamic: the Dock/App Switcher/Finder resolve the layered
  `IconImageStack` per appearance mode at display time (which is why a car that *lacks* the stack
  renders visibly wrong in the App Switcher), and Apple's HIG commits the system to generating
  "variants you don't provide". So the *declarative* property Dock Tile wants exists — one
  artifact, zero app-side appearance code — but the artifact is the car, not the `.icon`.
  `[OBSERVED + DOCUMENTED]`
  Source: https://github.com/manaflow-ai/cmux/issues/8517 ·
  https://developer.apple.com/design/human-interface-guidelines/app-icons
- **Verdict**: treat runtime `.icon` consumption as **NO pending one cheap decisive experiment**
  (§4, experiment 2 — place the repo's `hanger-appicon.icon` in a scratch app under every
  plausible Info.plist spelling and watch Finder/Dock). Absence of documentation plus a unanimous
  ecosystem is not proof; a 20-minute test is. **[NEEDS LOCAL VERIFICATION — expected NO]**
  `[INFERENCE]`

### 2b. How non-Xcode build systems adopt Tahoe appearances

Investigated concretely; **all of them pre-compile with actool on a Mac with Xcode at build
time**. That is a NO for our runtime case — none of these projects generates icons per-user on
end-user machines; their icon is fixed at release time, which is exactly the property Dock Tile
lacks.

| Ecosystem | Mechanism | Source |
|---|---|---|
| **Electron** (Zettlr guide, electron-builder, electron/universal) | Icon Composer → `actool … --app-icon Icon --include-all-app-icons … --platform macosx` → ship `Assets.car` in `Contents/Resources` + `CFBundleIconName`, keep `.icns` for older macOS. electron-builder's interim workaround: build a throwaway Xcode project, extract its `Assets.car`, copy it in an afterPack hook. "You will need to have access to a Mac with Xcode installed." | https://www.hendrik-erz.de/post/supporting-liquid-glass-icons-in-apps-without-xcode · https://github.com/electron-userland/electron-builder/issues/9254 · https://github.com/electron/universal/issues/148 `[OBSERVED]` |
| **Qt / C++** (Perfect Table Plan) | Same manual pipeline in Qt Creator: `xcrun actool application.icon --compile …`, validate with `xcrun assetutil --info`, "place *both* Assets.car and your old .icns file in the Resource folder… (*before* you sign it)", add `CFBundleIconName`. | https://successfulsoftware.net/2025/09/26/updating-application-icons-for-macos-26-tahoe-and-liquid-glass/ `[OBSERVED]` |
| **Tauri** | `.icon` "does not currently work with `tauri icon`"; community CLI `tauri-liquid-icon` automates the actool compile + project config. Open feature requests #14207, #14979. | https://github.com/tauri-apps/tauri/issues/14207 · https://libraries.io/npm/tauri-liquid-icon `[OBSERVED]` |
| **Wails (Go)** | Open issue; the constraint stated flat: "actool is proprietary as well as Icon Composer so it's not possible to generate the new liquid icons without access to a Mac." | https://github.com/wailsapp/wails/issues/4909 `[OBSERVED]` |
| **Emacs (emacs-plus, Homebrew)** | `.icon` compiled with `actool icon.icon --compile . --app-icon Emacs` **ahead of distribution**; the produced `Assets.car` "goes into `Emacs.app/Contents/Resources/`" and the install step copies it into the locally-built app — the closest published analogue to installing a car into a locally-generated bundle. | https://www.d12frosted.io/posts/2026-01-08-emacs-plus-liquid-glass-icons `[OBSERVED]` |
| **.NET / MAUI** | Build system "does not handle the new layered icon format"; Krueger's manual actool invocation is the workaround. | https://praeclarum.org/2025/09/12/app-icons.html `[OBSERVED]` |
| **JetBrains** | 31 YouTrack issues tagged `tahoe`; no published icon-pipeline detail found in this pass. **Undocumented here** — not evidence either way. | https://youtrack.jetbrains.com/issues?q=tag:+%7Btahoe%7D |
| **Go/Fyne** | Nothing found in this pass. **Undocumented here.** | — |

`actool` availability `[OBSERVED + INFERENCE]`: it lives at
`/Applications/Xcode.app/Contents/Developer/usr/bin/actool`; the `/usr/bin` shim requires a full
Xcode selected via `xcode-select` (Command Line Tools alone do not carry it — reported across the
threads above). It is Apple-proprietary and not redistributable, so Dock Tile cannot bundle it,
and users' Macs cannot be assumed to have Xcode. **Runtime compilation is not an option.**

### 2c. Sanctioned (or at least feasible) runtime paths, enumerated

Every candidate for giving a *runtime-generated* bundle appearance-variant icons without running
actool on the user's Mac:

1. **Loose `.icns` with variant naming / multiple `CFBundleIconFile`-family keys — does not
   exist.** No Info.plist key selects a dark/clear/tinted `.icns`. `CFBundleIconFile` is "the file
   containing the bundle's icon" (singular, no appearance dimension); `CFBundleIconFiles` (plural)
   and `CFBundleIcons` are iOS-family keys for *sizes*, not appearances. The macOS appearance
   dimension lives only in asset-catalog renditions. **Undocumented; no such mechanism.**
   `[DOCUMENTED — absence]`
   Source: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile ·
   https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfiles
2. **An IconServices / LaunchServices API to hand the system variant images — does not exist
   publicly.** IconServices' entire public surface is two terse man pages (see the appearance
   research §C9); `NSWorkspace.setIcon(_:forFile:)` sets a single *custom* icon image with no
   appearance dimension (and a Finder custom icon *suppresses* system restyling rather than
   participating in it — untested claim, low confidence). **Undocumented.** `[DOCUMENTED —
   absence]` + `[INFERENCE]`
3. **The `.icon` placed as `CFBundleIconFile`/`CFBundleIconName` value** — covered in §2a;
   expected NO, one experiment settles it. **[NEEDS LOCAL VERIFICATION]**
4. **Ship ONE static icon; accept the system-generated variants.** The one *sanctioned* path.
   HIG: "You can design app icon variants for every appearance variant, and the system
   automatically generates variants you don't provide." Tahoe demonstrably applies generated
   dark/clear/tinted treatment to `.icns`-only apps — this repo has already observed it via
   `NSWorkspace.shared.icon(forFile:)` for VS Code-class apps
   ([icon-system rule](../.claude/rules/icon-system.md), App Icon Loading `[OBSERVED — this
   repo]`), and Howard Oakley documents the (harsher) treatment of *non-squircle* legacy icons
   ("sin bin of a grey square"); Dock Tile's icons are already full-bleed squircles, so the
   sin-bin penalty shouldn't apply. Cost: Dock Tile's designed Dark variant (lifted-tint glyph on
   near-black) is replaced by whatever the system synthesises. `[DOCUMENTED + OBSERVED]`
   Source: https://developer.apple.com/design/human-interface-guidelines/app-icons ·
   https://eclecticlight.co/2025/06/22/last-week-on-my-mac-tahoe-the-iconoclast/
5. **A precompiled `Assets.car` template whose payloads are patched at runtime.** Status of the
   format and its writers:
   - The `.car` format is **undocumented and reverse-engineered** — "the car file format is
     evidently not documented by Apple" (Timac, the canonical write-up: BOM container, CARHEADER,
     RENDITIONS tree of (key, CTSI-headed data) pairs; parsed via private `CoreUI.framework`).
     `[OBSERVED — community RE]` Source: https://blog.timac.org/2018/1018-reverse-engineering-the-car-file-format/
   - **Readers** are mature: `acextract`, `AssetCatalogTinkerer`, `Samra` (bills itself an
     "explorer & editor"), `cartools` (built on private CoreUI/CoreThemeDefinition), `carutil`,
     and Apple's own shipped **`assetutil`** — which however only *thins* ("removing unrequested
     scale factors, device idioms, subtypes…"), it does not author or insert. `[SOURCE — shipped
     man page]` + `[OBSERVED]`
     Source: https://keith.github.io/xcode-man-pages/assetutil.1.html ·
     https://github.com/bartoszj/acextract · https://github.com/insidegui/AssetCatalogTinkerer ·
     https://github.com/NSAntoine/Samra · https://github.com/showxu/cartools ·
     https://github.com/vaguilar/carutil
   - **Writers exist, with two distinct approaches.** (a) `ThemeEngine` edits and saves `.car`
     files through the private `CoreThemeDefinition` framework — a runtime dependency on private
     API. (b) **Appdome patches image payloads with no Apple code at all**, in production, for
     app-resigning: "Compress the bitmap received. We used lzfse format. Change the data inside
     the appropriate csi header to the new compressed data… Update the matching offset-lengths for
     this record along with all dependent offsets." Constraints they document: payloads must be
     32-bit **BGRA** bitmaps, canvas width **rounded up to a multiple of 16**, lzfse compression,
     pre-scaled to each rendition's size. `[OBSERVED — shipped commercial tooling]`
     Source: https://www.appdome.com/dev-sec-blog/editing-assets-car-file-with-no-apple-tools/
   - **The unproven part is Tahoe-specific**: Appdome's technique predates the layered icon; the
     new `IconImageStack`/`IconGroup`/`Named Gradient`/`Color`/`PackedImage` rendition types
     (§1b) have no published reverse engineering and no published patcher. Dock Tile's per-tile
     variation maps *suspiciously well* onto them — tint = the gradient/color renditions, glyph =
     the layer `PackedImage`s — but whether a payload swap inside those renditions yields a valid,
     renderable stack is unknown. **Undocumented; [NEEDS LOCAL VERIFICATION]** (§4, experiments
     6–7: binary-diff two compiles differing in one color / one layer PNG; then attempt one
     payload swap).
   - A simpler sub-variant worth testing before the stack patch: **does a plain `.appiconset`
     asset catalog (not `.icon`) accept explicit dark/clear/tinted image variants for a macOS 26
     target**, the way iOS 18 app icons do? If actool compiles per-appearance *classic* PNG
     renditions the Dock honours, a template car's patch surface becomes ordinary bitmaps —
     squarely inside Appdome-proven territory. Nothing found documenting this either way for
     macOS. **Undocumented; [NEEDS LOCAL VERIFICATION]** (§4, experiment 5).
6. **Runtime car authoring via private CoreUI/CoreThemeDefinition** (the ThemeEngine route,
   linked into Dock Tile): technically demonstrated by others, but a hard private-API dependency
   in a shipping app — a bigger liability than everything the appearance research just removed
   (`lsregister`, SPI notifications). Recorded for completeness, not proposed. `[INFERENCE]`

### 2d. The GitHub re-find: runtime Dock-icon projects on modern macOS

The prior investigation (§C8 of the appearance research) was cut short after finding "a repo doing
exactly this use case on Tahoe" for `NSDockTilePlugIn`. Re-found candidates, with mechanisms:

- **`wondertwins/bad-dock`** — the strongest candidate (active into April 2026, i.e. Tahoe-era).
  Native SwiftUI app that streams arbitrary content into its Dock icon; README: "For the custom
  icon to survive quitting the app, you need a `NSDockTilePlugin` — a tiny dylib bundle that
  macOS loads into the Dock's own process." Structure:
  `Contents/PlugIns/DockPlugin.docktileplugin`, ad-hoc signed ("Ad-hoc code signing is required
  for macOS to respect the app bundle's icon and plugin"); notes `NSDockTilePlugin` is "not
  allowed on the Mac App Store" (irrelevant to us). Confirms the plugin replaces the **entire
  tile image**, not just badges. `[OBSERVED]` Source: https://github.com/wondertwins/bad-dock
- **`rrroyal/AutomaticDockTile`** — "Change the dock tile icon on theme switch": an
  `NSDockTilePlugIn` that observes the effective appearance and redraws the tile on Light/Dark
  flips — **Dock Tile's exact use case**, demonstrated via the plugin mechanism (Big Sur era;
  Tahoe behaviour untested there). `[OBSERVED]` Source: https://github.com/rrroyal/AutomaticDockTile
- **`dagronf/DSFDockTile`** — packaged library: "applications can display a custom DockTile image
  even when not running using the NSDockTilePlugin protocol." `[OBSERVED]`
  Source: https://github.com/dagronf/DSFDockTile
- **`CartBlanche/MacDockTileSample`** — plugin reads the host app's defaults domain and updates on
  distributed notifications while the app isn't running. `[OBSERVED]`
  Source: https://github.com/CartBlanche/MacDockTileSample
- **Loading semantics** (security-research write-up, corroborates Apple's docs): the plugin "is
  loaded in a system process at login time or when the application tile is added to the Dock"
  (the `com.apple.dock.external.extra` XPC service); "We don't even need to start the app" — the
  host never has to run. One caveat: a **quarantined** app's plugin won't start until the app is
  first launched and approved — moot for locally-generated, never-quarantined helpers.
  `[OBSERVED — corroborates DOCUMENTED]` Source: https://theevilbit.github.io/beyond/beyond_0032/ ·
  https://developer.apple.com/documentation/appkit/nsdocktileplugin
- **Nobody ships runtime-generated `.icon` or runtime-generated `Assets.car`.** Searched
  specifically; every project distributing Tahoe icons for non-Xcode apps (emacs-plus,
  `jimeh/emacs-liquid-glass-icons`, tauri-liquid-icon) pre-compiles. The runtime-car niche is
  empty — either unexplored or quietly infeasible. `[OBSERVED — absence]`

---

## 3. The fallback comparison

### 3a. If runtime `.icon` is a NO (expected), the options ranked

**(0) Single static icon, system-generated variants — sanctioned, zero code, design cost.**
Delete `IconStyleManager` from helpers entirely; bake only the Default `.icns` (and, if the visual
result warrants it, a precompiled *generic* car is not even needed). macOS restyles it per
Icon & widget style, per the HIG's "generates variants you don't provide". Evaluate visually first
(§4, experiment 1). `[DOCUMENTED + OBSERVED]` — the only option with no undocumented surface at
all.

**(i) Patched `Assets.car` template — the declarative ceiling, on an undocumented floor.**
Per-tile car = template compiled once at *Dock Tile's* build time (this Mac has Xcode) + runtime
payload patch (tint gradient/color renditions + glyph layer bitmaps). If it works, helpers become
fully declarative on macOS 26: the system renders all six appearance combinations, no detection,
no swap, no in-place mutation ever. Risks: the layered rendition types are unreversed (§2c.5);
the format can change in any macOS/Xcode release with zero notice (it has version fields and an
"Authoring Tool" stamp — the same class of risk as the Dock plist, which this project already
carries, but with a binary format instead of a plist); a patch bug yields an invisible or corrupt
icon. Feasibility gate: §4 experiments 3, 6, 7.

**(ii) `NSDockTilePlugIn` — settles §C8's open question: YES to full tile icons, not just
badges.** The evidence stack: Apple documents the plugin as customising the tile "while the app
is not running", loaded "at login time or when the application tile is added to the Dock"
`[DOCUMENTED]`; bad-dock and DSFDockTile demonstrate full-image replacement surviving app quit
`[OBSERVED]`; theevilbit confirms the host never needs to launch `[OBSERVED]`. So a pinned,
never-running helper *can* have its icon drawn by our code running inside the Dock's own
(permanently active, never-idle) process — which dissolves the idle-helper delivery pathology
without deleting the appearance *logic*. Open Tahoe-specific unknowns: does plugin-drawn
`contentView` output receive the system's icon-style treatment (Dark/Clear/Tinted), or bypass it
entirely (bad-dock's "bypass squircle masking" framing suggests plugin content sits *outside* the
normal icon pipeline — which would make styles *our* job again, but with reliable in-process
signals: the Dock is active, so KVO/`effectiveAppearance` delivery caveats for idle processes
don't apply `[INFERENCE]`); does the Dock load plugins from ad-hoc-signed bundles on 26.x
(bad-dock's April 2026 activity says yes for its setup) — **[NEEDS LOCAL VERIFICATION]** (§4,
experiment 8). Note also: one plugin per helper bundle = the plugin code is copied into every
helper anyway, same as today's binary.

**(iii) Keep `.icns` swapping, detection already redesigned.** The status quo after the
2026-08-31 redesign ([icon-style-detection.md](../.claude/rules/icon-style-detection.md)):
event-driven KVO + one distributed notification + reconcile-on-wake/show, unknown-value no-op,
re-seal after swap. Zero new unknowns, but keeps: the unsupported-by-documentation bundle
mutation (appearance research §C8b), the seal-break window mid-swap, and the residual detection
reliability question that motivated this spike. This is the floor the other options must beat.

### 3b. What each option means for the invariants

| | (0) Single icon, system variants | (i) Patched car template | (ii) NSDockTilePlugIn | (iii) Keep swapping |
|---|---|---|---|---|
| **Ad-hoc signing of helpers** | Unchanged; icon sealed once at install | Car written at *generation* time, then sealed — sign after patch, same as today's install flow | Plugin bundle inside helper must be signed (ad-hoc suffices per bad-dock `[OBSERVED]`) | Re-sign after every swap (current design) |
| **The seal (in-place mutation)** | **Never broken** — no runtime writes | **Never broken** — per-tile car is written before signing; style changes need no writes at all | Never broken — drawing is in-memory in the Dock's process | Broken and re-sealed on every flip; broken window if killed mid-swap |
| **Sparkle-less helper updates** | Unchanged (regenerate on migration) | Unchanged — but template car must be regenerated per app version (bake at Dock Tile's build, ship inside the app, copy per-tile at install) | Plugin binary updates ride the existing regenerate pipeline; Dock caches loaded plugins — a Dock restart is likely needed to reload (undocumented) **[NEEDS LOCAL VERIFICATION]** | Unchanged |
| **macOS 15 degrade (target is 15.0+)** | Identical to today: 15 has no icon styles; a static icns is exactly current behaviour there `[INFERENCE — this repo: `AppleIconAppearanceTheme` absent on 15 resolves to Default]` | Ship car **and** `.icns` (`CFBundleIconName` + `CFBundleIconFile`), the standard dual-artifact layout (§2b); macOS 15 ignores stack renditions and uses the icns — the exact fallback actool itself emits `[OBSERVED]` | Plugin API exists since 10.6 `[DOCUMENTED]`; works on 15 | Current behaviour |
| **Detection deleted?** | **Yes, fully** | **Yes, fully** (on 26; and nothing to detect on 15) | No — logic moves into the Dock's active process (reliable signals, but still ours) | No |
| **Undocumented surface added** | None | `.car` binary internals (unreversed for icon stacks) | Plugin API is documented; Tahoe styling of plugin content is not | None new; keeps bundle-mutation violation |

---

## Unknowns / undocumented

1. Whether macOS 26 renders a raw `.icon` from a bundle under any Info.plist spelling. All
   evidence says no; nothing states it. **[NEEDS LOCAL VERIFICATION — experiment 2]** (§2a)
2. Whether any shipped Tahoe app bundles its `.icon` source (would hint at a runtime consumer).
   **[NEEDS LOCAL VERIFICATION — experiment 0b]** (§1a)
3. The `icon.json` schema, contractually — community-documented only; Apple publishes nothing.
   Any macOS/Icon Composer update can change it silently. (§1a)
4. The `Assets.car` layered-icon rendition internals (`IconImageStack`, `IconGroup`,
   `Named Gradient`, `Color`, `PackedImage`) — no public reverse engineering, no known writer.
   **[NEEDS LOCAL VERIFICATION — experiments 6–7]** (§2c.5)
5. Whether a macOS `.appiconset` (classic asset catalog) accepts explicit dark/clear/tinted image
   variants the way iOS 18's does, giving a bitmap-only patch surface.
   **[NEEDS LOCAL VERIFICATION — experiment 5]** (§2c.5)
6. What the system's auto-generated dark/clear/tinted treatment does, exactly, to a full-bleed
   squircle `.icns` in the Dock (vs the documented behaviour for irregular legacy icons).
   Rendering rules are undocumented; only outcomes are observable.
   **[NEEDS LOCAL VERIFICATION — experiment 1]** (§2c.4)
7. Whether the Dock re-renders a *pinned* entry's icon on an icon-style flip without the entry
   being re-seated, when the icon source is an `Assets.car` stack (the in-place-icns case is
   already known broken — architecture rule "Refresh the Dock icon cache"). Presumably yes (the
   whole OS restyles on flip), but our Dock-cache history says verify.
   **[NEEDS LOCAL VERIFICATION — experiment 4]**
8. Whether plugin-drawn (`NSDockTilePlugIn`) tile content participates in Tahoe icon styles or
   bypasses the pipeline entirely; whether the Dock's plugin loader accepts our ad-hoc helpers on
   26.6. **[NEEDS LOCAL VERIFICATION — experiment 8]** (§3a.ii)
9. `actool`'s licence posture beyond "ships only with Xcode" — no Apple statement found on
   redistributing *compiled* `.car` output; the community (Homebrew emacs-plus, electron-builder)
   redistributes compiled cars freely and no objection is on record. (§2b)
10. Whether Xcode 26.6's actool still carries the flattening/`IconImageStack`-omission bugs
    reported against 26.0–26.1. Validate every compile with `assetutil --info`.
    **[NEEDS LOCAL VERIFICATION — experiment 0a]** (§1b)

---

## 4. The local spike — ordered experiments

Environment: this Mac, macOS 26.6.2, Xcode 26 installed. Each item is one observable question with
an expected artifact. Use a scratch directory; **never** touch production helpers or the live Dock
plist beyond adding/removing scratch apps (memory: never mutate prod data uninvited). Screenshot
every appearance permutation (Style: Default/Dark/Clear/Tinted × Appearance: Light/Dark) — the
style switcher is System Settings → Appearance → Icon & widget style.

0. **Toolchain + ecosystem baseline** (10 min).
   a. `xcrun actool --version`; compile the repo's example:
      `xcrun actool docs/v2/icons/hanger-appicon.icon --compile <out> --app-icon hanger-appicon --output-partial-info-plist <out>/partial.plist --platform macosx --target-device mac --minimum-deployment-target 15.0`.
      *Artifacts*: `Assets.car`, a generated `.icns`(?), `partial.plist` contents (which keys —
      `CFBundleIconName`? anything else?). Run `xcrun assetutil --info <out>/Assets.car` and
      confirm `IconImageStack`/`IconGroup` renditions are present (Unknown 10 — the flattening
      bug).
   b. Inspect two shipped Tahoe apps (e.g. `/System/Applications/*.app`, a recent third-party
      one): does any bundle contain a `.icon`? Expect: `Assets.car` + `CFBundleIconName` only
      (Unknown 2).
1. **The deletion candidate: single static icon, system variants** (15 min). Build a scratch
   `.app` (minimal Info.plist, no binary needed for Finder rendering; add a stub executable if
   the Dock requires one to pin) containing ONE Dock-Tile-generated Default `.icns` +
   `CFBundleIconFile`. Pin it. Cycle all style × appearance permutations. *Observable*: what the
   system's auto-generated Dark/Clear/Tinted treatments look like on our full-bleed squircle —
   compare against `IconGenerator`'s designed Dark variant side by side. **If acceptable, stop
   here: the redesign is a deletion** (Unknown 6).
2. **The decisive NO/YES: raw `.icon` at runtime** (20 min). Scratch app permutations, one at a
   time, `killall Dock`+re-pin between (re-seat the entry so the Dock's icon cache can't mask a
   result — architecture rule):
   a. `Contents/Resources/hanger-appicon.icon` + `CFBundleIconName = hanger-appicon`;
   b. same + `CFBundleIconFile = hanger-appicon` (and `.icon` at Resources root);
   c. the `.icon` renamed/`AppIcon.icon`, no icns present at all;
   d. `.icon` at `Contents/` root.
   *Observable*: does Finder or the Dock render the hanger icon (vs generic-app placeholder)?
   Expected: placeholder in all cases (Unknown 1). Any YES here changes everything — re-verify
   across a reboot (Launch Services re-registration) before believing it.
3. **The declarative ceiling: compiled car in an ad-hoc helper** (30 min). Take experiment 0a's
   `Assets.car` + generated `.icns`; place both in a scratch app with `CFBundleIconName` +
   `CFBundleIconFile`; ad-hoc sign (`codesign --force --sign -`); pin; cycle all permutations
   with the app **never launched**. *Observable*: correct layered rendering in every mode, zero
   app-side code, `codesign --verify` stays clean throughout. This is the target end-state's
   proof of concept.
4. **Dock re-render on style flip for a pinned car-backed entry** (10 min, piggybacks on 3).
   With the scratch app pinned and *not* re-seated, flip Icon & widget style. *Observable*: does
   the pinned tile restyle in place? (Unknown 7.)
5. **The bitmap-only alternative: `.appiconset` with appearance variants for macOS** (30 min).
   In a throwaway Xcode project, build an asset-catalog `AppIcon.appiconset`; try attaching
   dark/tinted variants (as iOS 18 allows) with `--platform macosx`; `assetutil --info` the
   product. *Observable*: does actool emit per-appearance **classic image** renditions for
   macOS, and does the Dock honour them (repeat experiment 3's cycle)? A YES makes the template
   patch surface plain PNGs (Unknown 5).
6. **Template-patch feasibility, read-only half** (45 min). Compile the hanger `.icon` twice
   more: once changing only one gradient stop colour in `icon.json`, once swapping one layer PNG
   for a different same-size PNG. `assetutil --info` all three; binary-diff each variant against
   the original (expect UUID noise — diff structurally via assetutil JSON + `acextract`/Samra
   dumps, not bytes alone). *Observable*: are the tint and the glyph confined to identifiable
   `Named Gradient`/`Color` and `PackedImage` renditions, and are the payloads independently
   locatable? (Unknown 4.)
7. **Template-patch feasibility, write half** (only if 6 is encouraging; half a day). Attempt one
   payload swap in a copy of the template car (Appdome recipe: lzfse, BGRA, width padded to 16,
   rewrite the csi header + dependent offsets — or via Samra/ThemeEngine if they open the stack
   renditions). Install per experiment 3. *Observable*: does the patched car render, with the new
   tint/glyph, in all modes? A YES here is the green light for option (i); any corruption mode
   observed goes in the risk register.
8. **NSDockTilePlugIn probe (fallback path)** (half a day). Minimal `.docktileplugin`
   (NSPrincipalClass implementing `setDockTile:` → set `contentView`, draw a test pattern +
   current `effectiveAppearance` name, call `display`) inside an ad-hoc scratch app;
   `NSDockTilePlugIn` key in the host Info.plist; pin **without ever launching** the host.
   *Observables*: (a) does the Dock load it (Console: `com.apple.dock.external.extra`)? (b) does
   the drawn content replace the full tile icon? (c) flip appearance and icon style — does the
   plugin's view get appearance callbacks in the Dock's process, and is its output run through
   the Tahoe style pipeline or shown verbatim? (Unknown 8.)

**Decision tree after the spike**: experiment 1 acceptable → ship option (0), delete detection.
Else experiment 3 clean + (7 works or 5 works) → design option (i) around the proven patch
surface. Else experiment 8 clean → option (ii). Else → option (iii) stands (current
event-driven design), and this document's §2 is the recorded evidence for why.

---

## 5. Spike results — 2026-09-01

All experiments run on macOS 26.6.2, Xcode 26, scratch bundles only. `[OBSERVED]` throughout
unless noted; Dock observations are Karthik's, programmatic renders are via
`NSWorkspace.icon(forFile:)` which returns what IconServices serves.

### 5a. What was refuted

| Experiment | Result |
|---|---|
| **Raw `.icon` in a bundle** (4 wirings: `CFBundleIconName`, +`CFBundleIconFile`, renamed `AppIcon.icon`, at `Contents/` root) | **Refuted.** Generic placeholder in all four. macOS does not consume an uncompiled `.icon`. |
| **One static `.icns`, expecting Tahoe to auto-generate variants** (§2c option 0 — the "deletion" candidate) | **Refuted.** Pinned tile stayed full-colour in a Dark-mode Dock. The HIG's "the system automatically generates variants you don't provide" applies to apps that adopted the NEW icon format — it does not restyle legacy `.icns` apps. **This corrects the framing in `.claude/rules/icon-system.md` (App Icon Loading), which read Tahoe's treatment of `.icns`-only apps as automatic restyling.** |
| **`NSDockTilePlugIn`** (ad-hoc signed, host never launched) | **Not loaded.** `setDockTile:` never fired; no Dock log; `dock.extra` has no `disable-library-validation` entitlement and our plugin is `adhoc`/`TeamIdentifier=not set`. The plugin bundle itself loads fine under `Bundle.loadAndReturnError()` + principalClass resolution, so the code is valid — the Dock refuses it. Untested with a Developer ID signature, but **moot for Dock Tile: helpers are generated on user machines and can only ever be ad-hoc.** |

### 5b. What was proven

**A compiled `Assets.car` is the declarative end state, and it works.** A scratch ad-hoc-signed
bundle carrying only `Assets.car` + generated `.icns` + `CFBundleIconName`/`CFBundleIconFile`,
**never launched**, rendered the correct appearance variant and **restyled live in the Dock** across
Default/Dark/Clear/Tinted and Light/Dark. Zero app-side code, no process, no detection.

### 5c. The unlock — `actool` is not the barrier we thought

§2b concluded "actool cannot run on user machines, so runtime car generation is off the table."
**That conclusion was wrong**, and the error was in scope: the research established that *Apple's*
actool can't ship, then stopped, without asking whether anyone had reimplemented it. Karthik found
[viraptor/actool](https://github.com/viraptor/actool) — a cleanroom Rust reimplementation
(`license = "MIT"` in Cargo.toml; note **no LICENSE file in the repo**, worth an upstream issue),
v2.2.4, built on the same [Timac car-format research](https://blog.timac.org/2018/1018-reverse-engineering-the-car-file-format/)
this document already cited. It accepts Icon Composer `.icon` documents and emits `Assets.car`.

Parity, same input, same flags:

- **Rendition structure: identical.** Both emit 1 header, 5 Color, 7 Icon Image, 3 IconGroup,
  3 IconImageStack, 3 Image, 1 MultiSized Image, 2 Named Gradient, 1 PackedImage. The Tahoe layered
  types — the ones that make live restyling work — are all present.
- **On a Dock-Tile-shaped icon (one glyph layer on a tint gradient): pixel-identical.** Squircle
  206×206 at (25,25); glyph 39.3% × 34.0%; offset dx −62.5, dy −68.0 — same on both.
- **On the hanger reference icon: ~6% glyph-width difference** and a 6px horizontal offset. The
  hanger uses `blur-material`, `specular`, `translucency` and multi-layer groups — features Dock
  Tile does not generate. Upstream has an `icon-shading.md`, so this is known parity territory.
- A car produced by the OSS tool, in an ad-hoc bundle, **rendered and restyled correctly in the
  Dock** (Karthik, live).

### 5d. Consequence

The subsystem this whole investigation has been hardening **can be deleted**, not fixed:

| Today | With declarative icons |
|---|---|
| Detect appearance changes (KVO + notification + reconciles) | **Nothing to detect** |
| KVO stalls in idle helpers (unexplained, unfixed) | **Moot** |
| Swap `AppIcon.icns` in place | **Icon is static** |
| Swap breaks the code-signature seal → re-sign | **Seal never breaks** |
| Oscillation amplifier (guarded, never root-caused) | **Structurally impossible** |
| `LSRegisterURL` on every flip | **Not needed** |

### 5e. Cost of shipping the compiler

Measured: binary **4.0 MB raw / 3.1 MB stripped / ~1.3 MB compressed**. Current DMG 6.2 MB →
**~7.5 MB (+21%)**. Source is 11,154 LOC across 17 Rust files.

**Only the main app needs it.** Cars are generated when a tile is created or edited; helpers carry
a finished static car and compile nothing. Since helpers are copies of the main app,
`HelperBundleManager` strips the compiler exactly as it already strips `Assets.car` and Sparkle
keys — so per-helper disk cost is zero.

Embedding options, preference order: **(1)** vendor the Rust source, build as a static lib, thin C
shim to Swift — pinned and auditable, costs Rust in CI; **(2)** ship the prebuilt binary, invoke as
a subprocess — simplest, second executable to sign/notarise; **(3)** port the needed subset to
Swift — no dependency and no CI change, but we own format-tracking forever (the Timac article is
the map). Recommended: **start with (1), keep (3) as the exit** if upstream goes stale.

### 5f. Open before this becomes a design

1. **Generate a `.icon` from a real `DockTileConfiguration`** — actual tint, SF Symbol/emoji, icon
   scale and weight — and confirm the full matrix still holds. Everything above rests on one
   hand-made test icon.
2. **macOS 15 degradation — a shrinking, time-boxed problem (Karthik, 2026-09-01).** Dock Tile
   targets 15.0+; `.icon`/layered cars are Tahoe-only. Pre-Tahoe users need the existing `.icns`
   path, so **the current detection code is not deleted — it becomes the pre-Tahoe fallback**, and
   the version split is the central design question. **But the fallback has a known expiry:**
   macOS 27 ships within months, and Dock Tile expects to raise its floor and drop macOS 15
   support as that lands — *not now, but soon enough that the fallback should be built to be
   deleted.* Design implication: keep the legacy path **quarantined behind a single availability
   branch** rather than interleaved with the new one, so retiring it later is a deletion rather
   than an untangling. Under that split the legacy path also stops needing new investment — the
   KVO stall, for instance, is a pre-Tahoe-only defect the moment Tahoe users stop running
   detection at all.
3. **Emoji and the brand glyph** through the icon.json layer model.
4. **Migration**: every existing helper needs regenerating; what does an old helper do on first
   launch under the new scheme?
5. **Upstream risk**: 7 stars, one author, "unknown unknowns" per its own README. Vendoring pins
   it; a format change from Apple is the real exposure, shared with any approach.

### 5g. Appearance treatments are fully expressible — verified

The final objection was that a declarative icon might forfeit Dock Tile's *designed* Dark treatment
(near-black background + the tile's tint moved onto the glyph, per
[dark-mode-icon-rendering.md](dark-mode-icon-rendering.md)) in favour of the system's automatic
darkening. **It does not.** `[OBSERVED]`

The `.icon` format carries appearance-keyed overrides at both icon and layer level. The compiler
(both Apple's and the OSS one) understands: `fill-`, `hidden-`, `opacity-`, `blend-mode-`,
`glass-`, `lighting-`, `shadow-`, `specular-`, `blur-material-` and `translucency-specializations`.

**Schema gotcha that cost two failed attempts — the default belongs IN the list.** A specialization
entry with **no `appearance` key is the light/default value**; appearance-keyed entries override it.
A sibling property (`"hidden": true`) is *not* overridable by a specialization. Correct shape:

```json
"hidden-specializations": [ {"value": false}, {"appearance": "dark", "value": true} ]
```

Working reproduction of Dock Tile's Dark treatment (rendered correctly, confirmed in the Dock):
icon-level `fill` = the tint gradient with a `dark` specialization to near-black; two glyph layers
(white and tint-coloured) swapped by `hidden-specializations`.

**Per-appearance artwork is therefore a LAYER SWAP, which suits Dock Tile.** `IconGenerator` already
renders each variant with its shading, sheen and contact shadow — those become pre-rendered layer
PNGs rather than being re-expressed in JSON. The existing rendering investment carries over intact.

Also noted: for identical input Apple's car was **1.69 MB** vs the OSS tool's **400 KB**. Unexplained
(likely extra pre-rendered sizes); the smaller one renders correctly in every mode. Worth
understanding before shipping, not a blocker.

**Per-layer `fill` did not recolour the glyph** in either compiler — the layer PNG's own colours win.
Pre-colour the artwork; do not rely on layer fill for tinting.

---

## 6. Spike closed — verdict and handover

**Feasibility question: ANSWERED YES.** A user's Mac can produce a per-tile, fully declarative,
appearance-aware app icon with no Xcode, entirely inside Dock Tile's own code.

### What is proven

| Claim | Evidence |
|---|---|
| Compiled `Assets.car` gives live restyling, zero code, app never launched | Dock, all four styles |
| A cleanroom compiler can produce one on a user's machine | viraptor/actool, MIT, Rust |
| Output matches Apple's on Dock-Tile-shaped icons | pixel-identical geometry |
| A real tile config works | Dev Tile: green / `hammer.fill` / scale 14 / medium |
| Dock Tile's DESIGNED appearance treatments survive | near-black + tinted glyph reproduced exactly |
| Cost is acceptable | ~1.3 MB DMG, **zero** per helper (stripped like Sparkle keys) |

### The authoring model (hard-won; do not re-derive)

- **Three authorable appearances**: `light` (the default), `dark`, `tinted`. **`clear` is NOT
  authorable** — macOS derives it as a glass pass over what we supply.
- **The default value belongs IN the specializations list** as an entry with no `appearance` key.
  A sibling property (`"hidden": true`) is *not* overridable by a specialization. This cost two
  failed attempts.
- **Per-appearance artwork is a LAYER SWAP** via `hidden-specializations`, not a per-layer `fill`
  recolour — layer `fill` did **not** recolour the glyph in either compiler. Pre-colour the PNG.
  This suits Dock Tile: `IconGenerator` already renders each variant with its shading/sheen/shadow,
  so those become layer PNGs and the existing investment carries over.
- Icon-level `fill` + `fill-specializations` control the background per appearance.

### Known defect in the OSS compiler — reproduced, isolated

**Appearance selection is off by one when `fill-specializations` are present.** Same `icon.json`,
both compilers:

| Icon style | Apple | OSS |
|---|---|---|
| Default | green + white glyph ✅ | near-black + green ❌ (renders `dark`) |
| Dark | near-black + green ✅ | grey + green ❌ (renders `tinted`) |
| Tinted | blue + white ✅ | blue + white ✅ |

Apple's compiler is correct on all three from the identical input, so **the authoring is right and
the fault is isolated to the OSS tool.** Related symptom, possibly the same root cause: for the same
input OSS emitted **14 `Icon Image` renditions and 2 `PackedImage`s vs Apple's 7 and 1**.
Reproduction fixtures live in the scratch spike dir; the icon.json shape is recorded above.

**Implication for adoption:** vendor and pin a copy with our own fixture-based test rather than
tracking upstream, and fix this defect (MIT, ~11k LOC, has a `docs/` folder) before shipping.

### Design questions this hands over (NOT feasibility questions)

1. **macOS 15 split** — the legacy `.icns` + detection path becomes the pre-Tahoe fallback,
   **quarantined behind one availability branch so it can later be deleted, not untangled**
   (see §5f note: macOS 27 lands within months and the floor rises then).
2. **Geometry** — Dock Tile's icons are full-bleed (256×256 squircle); Apple's icon geometry has a
   margin (206×206 at 25,25). Adopting cars renders every tile at ~80% of its current size,
   consistent with other apps but **a visible change to every existing user's tiles**.
3. **`IconGenerator` depth work → layer PNGs** (glass stroke, surface sheen, glyph shading, contact
   shadow) and how much the system's own `specular`/`translucency`/`shadow` group effects should
   replace versus duplicate it.
4. **Emoji and the brand glyph** through the layer model.
5. **Migration** of every existing helper, and what an old helper does on first launch.
6. **Embedding**: vendor Rust source (preferred) vs ship binary vs port the subset to Swift.

---

## 7. OSS compiler defects — root-caused 2026-09-01

Investigated with `systematic-debugging`, using Apple's actool on identical input as the oracle.
Fixtures: `scratchpad/spike/devtile-full.icon` (repro) and `devtile-fix.icon` (workaround).

### Defect 1 — top-level `fill` is dropped when `fill-specializations` is present. **ROOT-CAUSED**

`fill_specializations_assets()` (`src/icon_bundle.rs`) iterates **only** `json.fill_specializations`
and never processes the top-level `json.fill`. `resolve_background_fills()` then assigns
positionally — `light = gradient_assets.first()`, `dark = gradient_assets.get(1)` — so every
appearance shifts down one slot.

Predicted and confirmed:

| icon.json | gradients emitted | Result |
|---|---|---|
| `fill` + dark spec | 1 (dark only) | light renders **dark** |
| `fill` + dark + tinted | 2 (dark, tinted) | light→dark, dark→tinted |
| default as a no-appearance ENTRY in the list + dark + tinted | **3** | **backgrounds correct in all modes** |

**Workaround, no code change:** emit the default fill as the first entry *inside*
`fill-specializations` (`{"value": …}`, no `appearance` key) — the same
default-belongs-in-the-list rule that `hidden-specializations` follows. Keep the top-level `fill`
too, for Apple's compiler. Verified: 3 gradients, correct background per appearance.

### Defect 2 — layer stack picks the wrong appearance. **CHARACTERISED, NOT ROOT-CAUSED**

With defect 1 worked around, the *background* is correct in every mode but the **glyph is not**:
in Default the OSS car shows the dark-appearance glyph (tint-coloured) where Apple's shows the
light one (white). Both compilers, same `icon.json`; Apple correct.

Suspected area (unproven): `icon_bundle.rs` builds only `light_stacks`/`dark_stacks` via
`collect_stack_layers(…, Appearance::Light|Dark)` and assigns "primary variant = light stack,
alternate = dark stack". Either `hidden-specializations` is not resolved into the stacks, or the
primary/alternate assignment is inverted. Related unexplained signal: for identical input OSS emits
**14 `Icon Image` + 2 `PackedImage`** vs Apple's **7 + 1**.

### Consequence for adoption

Neither defect is a blocker — both are in a small MIT Rust codebase we would vendor and pin anyway,
and Apple's compiler proves the authoring model is sound. But **shipping requires fixing defect 2**
(or driving appearance artwork some other way), and the plan should budget for it. The fixtures
above make both reproducible in minutes, and are worth contributing upstream regardless.
