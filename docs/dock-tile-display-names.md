# Dock Tile — Display Names (Finder, Dock `file-label`, Cmd-Tab)

Two tiles may share a name, so the second helper is stored as `<name>-<shortId>.app` (e.g.
`Utils-B4EF96A2.app`) while its Info.plist says `CFBundleName = CFBundleDisplayName = "Utils"`.
The Dock tooltip read "Utils-B4EF96A2" because `addToDock` wrote `file-label` from the folder stem.
This note records what Apple documents about bundle display names, what the Dock plist format is
(and isn't), and the compliant fix. Verified on macOS 26 (2026-08): the Dock renders `file-label`
verbatim and keeps it across `killall Dock`; Launch Services / `mdls kMDItemDisplayName` report
`Utils-B4EF96A2.app` for the disambiguated bundle despite its `CFBundleDisplayName`. Every claim
below cites a primary source; gaps are marked **unverified**.

## 1. `CFBundleDisplayName` vs `CFBundleName`

- Archived key reference (Apple's fullest text): `CFBundleDisplayName` "specifies the display name of
  the bundle, visible to users and used by Siri. If you support localized names for your bundle,
  include this key in your app's `Info.plist` file and in the `InfoPlist.strings` files of your app's
  language subdirectories. If you localize this key, include a localized version of the
  `CFBundleName` key as well. … **In macOS, before displaying a localized name for your bundle, the
  Finder compares the value of this key against the actual name of your bundle in the file system.
  If the two names match, the Finder proceeds to display the localized name from the appropriate
  `InfoPlist.strings` file of your bundle. If the names do not match, the Finder displays the
  file-system name.**" `CFBundleName` "specifies the short name of the bundle, which may be displayed
  to users in situations such as the absence of a value for `CFBundleDisplayName`. This name should
  be less than 16 characters long."
  Source: https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
- "Don't include it when not localized" — yes, in the pre-Siri revision (2010 capture): "If you do
  not intend to localize your bundle, do not include this key in your `Info.plist` file. Inclusion of
  this key does not affect the display of the bundle name but does incur a performance penalty to
  search for localized versions of this key." The current archive replaced this with "Because Siri
  uses the value of this key, always provide a value, whether or not you localize your app."
  Source: https://web.archive.org/web/20100831135551/http://developer.apple.com/mac/library/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
- Current reference is terser and omits the Finder rule: `CFBundleDisplayName` = "The user-visible
  name for the bundle, used by Siri and visible on the iOS Home screen. … Use this key if you want a
  product name that's longer than `CFBundleName`." `CFBundleName` = "A user-visible short name for the
  bundle. This name can contain up to 15 characters. The system may display it to users if
  `CFBundleDisplayName` isn't set." Bundle Programming Guide: `CFBundleName` "is usually the name of
  your application"; `CFBundleDisplayName` is "The localized version of your application name …
  typically … in an `InfoPlist.strings` files in each of your language-specific resource directories."
  Source: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledisplayname ·
  https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundlename ·
  https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html
- File System Programming Guide: display names "are used only by the Finder and specific system
  components (such as the Open and Save panels)… Display names do not affect the actual name of the
  file in the file system… You can get the display name for any file or directory using the
  `displayNameAtPath:` method of `NSFileManager`."
  Source: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html

## 2. Launch Services / FileManager, and the `InfoPlist.strings` override

- `LSCopyDisplayNameForURL` (deprecated 10.10): "The item's display name is returned in the form in
  which it will appear on the user's screen; it may be localized (for applications and folders), and
  it excludes the filename extension if the extension is set to be hidden…". The SDK header
  (`LSInfoDeprecated.h`) says to "Use the URL resource property `kCFURLLocalizedNameKey` or
  `NSURLLocalizedNameKey` instead" — "The resource's localized or extension-hidden name".
  Source: https://developer.apple.com/documentation/coreservices/1446850-lscopydisplaynameforurl ·
  https://developer.apple.com/documentation/foundation/urlresourcekey/localizednamekey
- `FileManager.displayName(atPath:)` returns "The name of the file or directory at `path` in a
  localized form appropriate for presentation to the user". QA1544: it "will return the localized
  display name if it exists, fall back on the bundle name if it does not, and will even reflect a
  renaming of the application by the user" — Apple's recommended way to get a Mac app's name.
  Source: https://developer.apple.com/documentation/foundation/filemanager/displayname(atpath:) ·
  https://developer.apple.com/library/archive/qa/qa1544/_index.html
- The sanctioned override: "Localized values are not stored in the `Info.plist` file itself. Instead,
  you store the values for a particular localization in a strings file with the name
  `InfoPlist.strings`… in the same language-specific project directory". Example: Info.plist
  `CFBundleDisplayName = TextEdit` + `French.lproj/InfoPlist.strings` `CFBundleDisplayName = "TextEdit";`.
  Source: https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html ·
  https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LocalizingYourApp/LocalizingYourApp.html
- **Must the Info.plist value equal the filename stem?** Yes — that is the Finder rule in §1: the
  `.lproj` override is honoured only when `Info.plist`'s `CFBundleDisplayName` equals the on-disk
  name minus `.app`. `Utils-B4EF96A2.app` with `CFBundleDisplayName = "Utils"` fails the comparison,
  so the file-system name wins. A DTS engineer additionally recommends `LSHasLocalizedDisplayName =
  YES` plus localizing both keys; that key is only *listed*, never described, in Apple's archived Mac
  App Programming Guide, so its semantics are **unverified**.
  Source: https://developer.apple.com/forums/thread/756303 ·
  https://developer.apple.com/library/archive/documentation/General/Conceptual/MOSXAppProgrammingGuide/BuildTimeConfiguration/BuildTimeConfiguration.html

## 3. Names for a *running* app (Cmd-Tab, Force Quit, Activity Monitor)

- `NSRunningApplication.localizedName`: "Indicates the localized name of the application… dependent
  on the current localization of the application and is suitable for presentation to the user."
  QA1544 gives the derivation: "returns the localized value of `CFBundleDisplayName` if it exists,
  falls back on the value of `CFBundleName` otherwise." Neither mentions the file name.
  Source: https://developer.apple.com/documentation/appkit/nsrunningapplication/localizedname ·
  https://developer.apple.com/library/archive/qa/qa1544/_index.html
- Apple staff on per-surface keys: "The localized `CFBundleDisplayName` should then be used in the
  Dock, and the localized `CFBundleName` should be used in the Apple menu and menu items." QA1544:
  `CFBundleName` "is used by the About window and main menu"; `CFBundleDisplayName` "is used by the
  Finder to display the bundle."
  Source: https://developer.apple.com/forums/thread/756303 (DTS Engineer reply)
- Which name Cmd-Tab, Force Quit and Activity Monitor read is **not documented** (the Activity Monitor
  user guide never defines "Process Name"). Only related text: `LSUIElement` agent apps "do not appear
  in the Dock or in the Force Quit window" (Ghost-mode helpers). **Unverified** beyond that.
  Source: https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html

## 4. The Dock's `persistent-apps` / `file-label`

- Apple documents the Dock item shape only as an **MDM configuration-profile payload**, not as a
  contract for writing `com.apple.dock`: `persistent-apps` — "An array of items located on the
  Applications side of the Dock that users can remove from the Dock." A `Dock.StaticItem` requires
  `tile-data` + `tile-type` (`file-tile`, `directory-tile`, `url-tile`); `Tile-data` documents `label`
  (required, "The label of the Dock item."), `file-type` (`0` URL / `1` File / `3` Directory), `url`,
  and `file-data` — "For Apple use only." **`file-label`, `bundle-identifier`, `dock-extra`,
  `file-type 41` and `_CFURLStringType 15` appear in no Apple document** — the Dock's private on-disk
  form, learned by reading the plist.
  Source: https://developer.apple.com/documentation/devicemanagement/dock ·
  https://developer.apple.com/documentation/devicemanagement/dock/staticitem/tile-data-data.dictionary ·
  https://developer.apple.com/business/documentation/Configuration-Profile-Reference.pdf (Dock Payload, pp. 27–29)
- dockutil 3.1.3 (Swift; `Dock.swift` byte-identical at `main` 7238012, 2025-03-17) computes the label
  with **no** Launch Services / `displayName(atPath:)` call: with no `--label`, an `.app` path gets
  `URL(fileURLWithPath: opts.path).deletingPathExtension().lastPathComponent` (the path stem), then
  `"file-label": opts.label` is written into `tile-data` beside `file-data._CFURLString` and
  `file-type 41`. It reads back `tile-data.file-label ?? tile-data.label`; `--remove/--find/--move`
  match label **or** bundle id, and `add` refuses a duplicate label in the same section — dockutil
  treats the label as identity; Dock Tile keys on `bundle-identifier`.
  Source: https://github.com/kcrawford/dockutil/blob/3.1.3/Sources/DockUtil/Dock.swift#L243-L253 (label) ·
  https://github.com/kcrawford/dockutil/blob/3.1.3/Sources/DockUtil/Dock.swift#L276-L289 (write) ·
  https://github.com/kcrawford/dockutil/blob/3.1.3/Sources/DockUtil/DockTile.swift#L40-L44 (read) ·
  https://github.com/kcrawford/dockutil/blob/3.1.3/Sources/DockUtil/DockUtil.swift#L252-L253 (`--label`)
- Public Dock-tile APIs control appearance, never the name: `NSDockTile` has `contentView`,
  `display()`, `showsApplicationBadge`, `badgeLabel` ("Badge the dock icon with a localized string"),
  `size`, `owner`; `NSDockTilePlugIn` (loaded "in a system process at login time or when the
  application tile is added to the Dock") has only `setDockTile(_:)` and `dockMenu()`. Nothing sets a
  pinned, non-running tile's label/tooltip. The archived *Dock Tile Programming Guide* is no longer
  hosted (404); the Mac App Programming Guide's "Take Advantage of the Dock" survives.
  Source: https://developer.apple.com/documentation/appkit/nsdocktile ·
  https://developer.apple.com/documentation/appkit/nsdocktileplugin ·
  https://developer.apple.com/library/archive/documentation/General/Conceptual/MOSXAppProgrammingGuide/CommonAppBehaviors/CommonAppBehaviors.html

## 5. HIG / naming guidance

- HIG "Dock menus" covers menu items only ("label Dock menu items succinctly and organize them
  logically"). No HIG page (Dock menus, App icons, Branding, Launching, Writing) mentions the name
  shown for a Dock icon; the old OS X HIG "The Dock" page now redirects to "Designing for macOS". A
  rule that "the Dock name must match the display name" is **not stated anywhere**.
  Source: https://developer.apple.com/design/human-interface-guidelines/dock-menus
- HIG "App icons": "Apple trademarks must not appear in your app name or images." / "In some contexts,
  your app name already appears nearby, making it redundant to display the name within the icon."
  Source: https://developer.apple.com/design/human-interface-guidelines/app-icons
- App Review 2.3.7: "Choose a unique app name… App names must be limited to 30 characters. Metadata
  such as app names… should not include prices, terms, or descriptions that are not specific to the
  metadata type." 2.3.8: "ensure your metadata, including app name and icons… are similar to avoid
  creating confusion." Product page: "Choose a simple, memorable name that is easy to spell… Be
  distinctive. Avoid names that use generic terms". Plus `CFBundleName` ≤ 15 characters (§1).
  Source: https://developer.apple.com/app-store/review/guidelines/ · https://developer.apple.com/app-store/product-page/

## Conclusions for Dock Tile

**(a) Documented vs undocumented.** Documented: the helper `Info.plist` keys (`CFBundleName`,
`CFBundleDisplayName`, `CFBundleIdentifier`, `CFBundleIconFile` — "you must specify the
`CFBundleIconFile` property" without an asset-catalog icon —, `LSUIElement` for Ghost mode),
`InfoPlist.strings` localisation, `NSDockTile`/`NSDockTilePlugIn`. Undocumented (private, observed):
writing `persistent-apps` via CFPreferences, every `tile-data` key we emit except `label`
(`file-label`, `file-data` "For Apple use only", `bundle-identifier`, `dock-extra`, `file-type 41`),
the Dock rendering `file-label` verbatim, and `killall Dock` as the reload. Our entry shape matches
dockutil's, so we share its risk profile, not a worse one.

**(b) The Apple-sanctioned way** to make `Utils-B4EF96A2.app` present as "Utils" everywhere is the
Finder rule in §1: set `Info.plist` `CFBundleDisplayName` to the folder stem (`Utils-B4EF96A2`) and
add `<lang>.lproj/InfoPlist.strings` with `CFBundleDisplayName = "Utils"; CFBundleName = "Utils";`
(DTS also suggests `LSHasLocalizedDisplayName = YES`, unverified). Finder, Spotlight,
`displayName(atPath:)` and the running-app name would then all say "Utils". Trade-offs: `.lproj`
folders in every helper (a strings file per language the user may run, or reliance on the
development-region fallback — **unverified** for Finder), an extra rename-time regenerate, and
Apple's older text warning the lookup "does incur a performance penalty". It also does **nothing**
for the tooltip by itself: the Dock keeps whatever `file-label` was written (verified).

**(c) Recommended minimal fix.** In `HelperBundleManager.addToDock(at:atIndex:)`
([HelperBundleManager+Dock.swift](../DockTile/Managers/HelperBundleManager+Dock.swift), `file-label` in the new entry) write
`file-label` from the helper's own `Info.plist` — `CFBundleDisplayName`, else `CFBundleName`, else
the folder stem — instead of `appPath.deletingPathExtension().lastPathComponent`; the plist is
already read there for `CFBundleIdentifier`. For every bundle whose folder matches its name this is
byte-identical to dockutil's output and to what Finder shows, so existing tiles are unaffected; for a
disambiguated folder it yields "Utils", the name Apple's APIs would return once the bundle were
localised. Do **not** use `displayName(atPath:)` here — it returns the folder name for the
disambiguated bundle (verified), because the Finder comparison fails. Lookups stay safe:
`findDockIndex`/`findInDock`/`removeFromDockPlist` compare `bundle-identifier`, never the label, so two
"Utils" tiles remain distinct (unlike dockutil's label-keyed `--remove`). Wrong labels already in the
Dock self-correct on the next re-seat (`refreshDockEntry` → `addToDock`, i.e. Update or migration).
