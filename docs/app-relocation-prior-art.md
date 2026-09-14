# App relocation — prior art (launching from a DMG / ~/Downloads)

Research date: 2026-09-14. Local machine: macOS 26.6.2 (25G83), Xcode SDK at
`xcrun --show-sdk-path`. Source snapshots examined: LetsMove `master` @ `70c5772` (last commit
2020-07-09), Sparkle `master` @ `5fddc92` (2026-09-13), Electron `main` (fetched 2026-09-14).
File:line references are to those snapshots.

## Answer

**What the field does.** Nobody moves the bundle. Every shipping implementation (LetsMove, and
Electron's `app.moveToApplicationsFolder()` which is a port of it) **copies** the running bundle
into `/Applications` with `NSFileManager copyItemAtPath:toPath:`, then treats deleting the source
as best-effort, and **skips the delete entirely when the source is on a disk image** — it detaches
the DMG after a 5 s delay instead. Neither checks for translocation before prompting; both run
from `[NSBundle mainBundle] bundlePath`, which is the reason LetsMove's open issues #60/#86 exist.
Sparkle does not relocate at all: it refuses to update when the bundle's volume is `MNT_RDONLY`
(covers DMG and translocation) and tells the user to copy the app to Applications. Apple's
official position (Quinn, DTS) is that there is *no supported way* to detect translocation or
recover the original path; the `SecTranslocate*` symbols are exported but not in any public SDK
header. Apple's packaging doc explicitly allows users to "run your app from the disk image."

**Patterns worth borrowing for Dock Tile.**

1. **Copy, never move; source removal is best-effort and skipped on a DMG.** Replace
   `FileManager.moveItem` (documented as copy-then-remove across volumes; the remove is what fails
   with 642 on a read-only DMG, leaving the copy in place and making the `copyItem` fallback hit
   516) with `copyItem` → best-effort `removeItem`/`trashItem` on the source only when
   `ContainingDiskImageDevice(...) == nil` → `hdiutil detach` the device after 5 s. This is exactly
   LetsMove `PFMoveApplication.m:190-215` / Electron `electron_bundle_mover.mm:411-439`.
2. **Resolve destination conflicts before copying.** If `/Applications/<name>.app` exists: if it is
   running (`NSRunningApplication.bundleURL` compare), `open` it and `exit(0)`; else trash it
   first. No version compare in either implementation (`PFMoveApplication.m:174-193`).
3. **Classify the source volume with `statfs`, not only the path.** Sparkle's
   `isRunningOnReadOnlyVolume` (`SUHost.m:196-205`, `MNT_RDONLY`) plus LetsMove's
   `ContainingDiskImageDevice` (`statfs` + `hdiutil info -plist` device match,
   `PFMoveApplication.m:335-389`) give a DMG/read-only signal independent of translocation.
   Dock Tile's `AppRelocation.classify` currently keys on translocation + `/Applications` prefix;
   a `.readOnlyVolume` input would let the copy path be chosen deliberately.
4. **Relaunch via a detached shell that waits for the old pid, strips quarantine, then `open`s**
   (`PFMoveApplication.m:539-563`). Note the 2016 radar comment quoted in LetsMove #56 warning
   that quarantine-stripping "could end up getting blocked in the future"; it still works on
   macOS 26 for Electron (same code, `electron_bundle_mover.mm:245-270`).
5. **Sparkle already produces the "move to Applications" message for DMG/translocated users;**
   `updater:didAbortWithError:` (`SPUUpdaterDelegate.h:455`) receives
   `SURunningFromDiskImageError` (1003) / `SURunningTranslocated` (1005) and could route into
   Dock Tile's relocation flow instead of Sparkle's plain alert. Background checks abort silently
   (`SPUScheduledUpdateDriver.m:104-107`, `showErrorToUser:_showedUpdate`).

## 1. LetsMove (`potionfactory/LetsMove`, `PFMoveApplication.m`)

Source: https://github.com/potionfactory/LetsMove/blob/master/PFMoveApplication.m (version 1.25 per
header line 2). Snapshot `70c5772`.

**When it prompts** (`PFMoveToApplicationsFolderIfNecessary`, lines 66-233):

- Skips if the user ticked the suppression checkbox (`moveToApplicationsFolderAlertSuppress`,
  lines 48, 78, 217-220).
- Skips if `IsInApplicationsFolder(bundlePath)` unless the app is nested inside another `.app`
  (line 88). `IsInApplicationsFolder` (lines 275-286) is true when the path has a prefix from
  `NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask)` **or** any path
  component equals `"Applications"` (line 283 — so `/Volumes/Data/Applications/X.app` counts).
- `bundlePath` is `[[NSBundle mainBundle] bundlePath]` (line 81). **No translocation check, no
  read-only-volume check.** Under translocation the path is
  `/private/var/folders/.../AppTranslocation/<UUID>/d/X.app`, which is not in Applications, so it
  prompts even if the real bundle already sits in `/Applications` (open issue #60, 2016-12-02,
  proposes using the original path; issue #86, 2023-08-06, iTerm2 unzipped as root into
  `/Applications` then "You are left with an empty folder" — the authorized `rm -rf` of the
  destination deleted the real source).
- Install target: `~/Applications` **only if it already exists and contains at least one `.app`**,
  else `/Applications` (`PreferredInstallLocation`, lines 242-273).
- `needAuthorization` when the target dir is not writable, or the existing destination bundle is
  not writable (lines 105-109). The alert text then adds "Note that this will require an
  administrator password." (lines 120-123); otherwise, if in `~/Downloads`, adds "This will keep
  your Downloads folder uncluttered." (lines 124-128, `IsInDownloadsFolder` lines 288-295).
- Alert: `NSAlert runModal`, buttons "Move to Applications Folder" / "Do Not Move" (Escape),
  suppression checkbox (lines 111-154). Activates the app first as a "work-around for focus
  issues related to 'scary file from internet' OS dialog" (lines 149-152).

**How it moves:**

- Non-admin path (lines 173-194): if the destination exists and **is running**
  (`IsApplicationAtPathRunning`, lines 297-320, compares `NSRunningApplication.bundleURL`), it
  runs `/usr/bin/open <destination>` and `exit(0)` — i.e. switches to the installed copy
  (lines 177-183). If it exists and is not running, it is **trashed** (`Trash`, line 185) — no
  version comparison. Then `CopyBundle` = `[fm copyItemAtPath:srcPath toPath:dstPath error:]`
  (lines 190, 522-533). **Copy, not move; never `copyfile(3)` directly.**
- Admin path (`AuthorizedInstall`, lines 448-520): `AuthorizationCreate` +
  `AuthorizationCopyRights(kAuthorizationRightExecute)`, then the **deprecated-since-10.7**
  `AuthorizationExecuteWithPrivileges` resolved via `dlsym(RTLD_DEFAULT, ...)` (lines 477-490)
  to run `/bin/rm -rf <dst>` (lines 492-501) then `/bin/cp -pR <src> <dst>` (lines 503-512).
  Not `authopen`, not AppleScript. The README states "Does NOT support sandboxed applications"
  (README.md:11).
- Source removal (lines 196-202): `DeleteOrTrash(bundlePath)` only when **not nested and
  `diskImageDevice == nil`**. Comment: "It's okay if this fails." `DeleteOrTrash` (lines 433-446)
  tries `removeItemAtPath:`, suppresses the warning if the path contains `/AppTranslocation/`
  (line 441), then falls back to `Trash` (lines 391-431): `trashItemAtURL:` → legacy
  `NSWorkspaceRecycleOperation` → **Finder AppleScript** `move theFile to trash` "even when the
  app is running inside an app translocation image" (lines 408-424; added in 1.22 per
  README.md:60-61 after issue #56). Open issue #81 (2020-08-08): on Big Sur+ the AppleScript
  fails with `-1743 Not authorized to send Apple events to Finder` unless the app carries
  `com.apple.security.automation.apple-events` + `NSAppleEventsUsageDescription` and the user
  grants Automation access. (Dock Tile's entitlements already include `automation.apple-events`
  per `.claude/rules/ci-release.md`; the TCC prompt would still appear.)
- DMG detection (`ContainingDiskImageDevice`, lines 335-389): `statfs` on the parent dir; bail if
  `MNT_ROOTFS`; take `f_mntfromname`; run `/usr/bin/hdiutil info -plist` and return the device if
  it appears under any image's `system-entities[].dev-entry`.
- After a DMG launch (lines 207-212): `(/bin/sleep 5 && /usr/bin/hdiutil detach <dev>) &` —
  "unmount (if no files are open after 5 seconds, otherwise leave it mounted)". The DMG copy of
  the app is never deleted (read-only), only ejected.
- Relaunch (`Relaunch`, lines 539-563): `NSTask /bin/sh -c "(while /bin/kill -0 <pid>; do sleep
  0.1; done; /usr/bin/xattr -d -r com.apple.quarantine '<dst>'; /usr/bin/open '<dst>') &"`, then
  `exit(0)` (line 215; README.md:135 explains `exit(0)` over `[NSApp terminate:]` to avoid
  `applicationWillTerminate` side effects). Quarantine is stripped "to avoid duplicate 'scary
  file from the internet' dialog" (lines 549-551).
- Failure UI: a single alert "Could not move to Applications folder" (lines 225-232).

**License / maintenance:** header line 7 "dedicated to the public domain"; README.md:37-39
"Public domain". No LICENSE file in the repo root (GitHub API `license: null`). Last commit
2020-07-09 ("Update podspec"), 14 open issues, not archived
(https://api.github.com/repos/potionfactory/LetsMove). No Ventura/Sonoma/Sequoia/Tahoe-specific
issues exist; the newest are #87 (2023-12-07, "Link against Security.framework") and #86 (above).
Translocation-related: #56 (closed; the 2016 discussion — moving with `NSFileManager` did not
clear translocation until the quarantine xattr was stripped; a commenter reported Apple's
radar reply "Creating a script to strip quarantine off an app next to it is dangerous and could
end up getting blocked in the future"), #60 (open), #81 (open), #86 (open). Also #59 (open,
2016): replacing a running installed copy "fails silently" (code at HEAD switches to the running
copy instead, lines 177-183).

## 2. Sparkle

Source: https://github.com/sparkle-project/Sparkle, snapshot `5fddc92` (2026-09-13).

- `SUHost.m:196-205` `isRunningOnReadOnlyVolume`: `statfs(bundlePath)` and
  `(f_flags & MNT_RDONLY) != 0`. `SUHost.m:207-211` `isRunningTranslocated`: bundle path contains
  `"/AppTranslocation/"` (string match, no `SecTranslocate*` call).
- `SPUBasicUpdateDriver.m:69-85` `checkForUpdatesAtAppcastURL:...`: **before loading the appcast**,
  if `isRunningOnReadOnlyVolume` → abort. If additionally `isRunningTranslocated` → error
  `SURunningTranslocated` (1005, `SUErrors.h:45`): "%@ can’t be updated if it’s running from the
  location it was downloaded to." / recovery "Quit %@, move it into your Applications folder,
  relaunch it from there and try again." (line 78). Else `SURunningFromDiskImageError` (1003,
  `SUErrors.h:43`): "%@ can’t be updated because it was opened from a read-only or a temporary
  location." / "Use Finder to copy %@ to the Applications folder, relaunch it from there, and try
  again." (line 80). The read-only check is the gate; translocation only changes the wording.
- User-facing behaviour: `SPUUIBasedUpdateDriver.m:452-494` shows `showUpdaterError:` only when
  `showErrorToUser` is true; `SPUScheduledUpdateDriver.m:104-107` passes
  `showErrorToUser:_showedUpdate`, so a **scheduled/background check on a DMG aborts silently**;
  a user-initiated "Check for Updates…" shows the alert. Sparkle docs confirm: "Note by default
  Sparkle will not notify your user if an update cannot be performed, like if the app is running
  from a read-only mount or being impacted by app translocation"
  (https://sparkle-project.org/documentation/, "Distributing your App"). Same section: "If you
  distribute your app on your website as a zip or a tar archive, avoid placing anything but your
  app inside the archive so you can minimize app translocation issues."
- Delegate hooks that receive the error: `updater:didAbortWithError:` (`SPUUpdaterDelegate.h:455`)
  and `updater:didFinishUpdateCycleForUpdateCheck:error:` (`:475`). `SPUUpdater.m:798` logs every
  abort except no-update/cancel/authorize-later.
- History (`CHANGELOG`): line 541 "Improved error when running from translocated location";
  line 281 (#2233) the installer agent also matches **translocated** running instances of the
  app so it can quit them (`InstallerProgressAppController.m:201-254`); line 136 (#2689) "Fix
  recovery error suggestion not shown when app is translocated or on read-only mount".
- Sparkle ships **no** move-to-Applications feature (no such code in the tree; `grep -ri
  "Applications folder"` hits only the two strings above).

## 3. Electron / electron-builder / Tauri / popular apps

**Electron (first-party, built in).** `app.isInApplicationsFolder()` and
`app.moveToApplicationsFolder([options])` (macOS) —
https://github.com/electron/electron/blob/main/docs/api/app.md (lines 1784-1829 of the fetched
file). "No confirmation dialog will be presented by default." "if the move is successful, your
application will quit and relaunch." Conflict handling: "if an app of the same name … exists in
the Applications directory and is *not* running, the existing app will be trashed and the active
app moved into its place. If it *is* running, the preexisting running app will assume focus and
the previously active app will quit itself." A `conflictHandler` receives `exists` /
`existsAndRunning` and returns a boolean. "if the user cancels the authorization dialog, this
method returns false. If we fail to perform the copy, then this method will throw an error."

Implementation `shell/browser/ui/cocoa/electron_bundle_mover.mm` (MIT, "Copyright (c) 2017
GitHub, Inc.", lines 1-3) is a straight port of LetsMove: `ContainingDiskImageDevice` (42-100),
`IsInApplicationsFolder` with `realpath` (102-126), `AuthorizedInstall` via `dlsym`'d
`AuthorizationExecuteWithPrivileges` + `rm -rf` + `cp -pR` (128-229), `CopyBundle` =
`copyItemAtPath:toPath:` (231-236), `Relaunch` with `xattr -d -r com.apple.quarantine` + `open`
(245-270), `Trash` = `trashItemAtURL:` only — **no AppleScript fallback** (272-277),
`DeleteOrTrash` (279-287). `Move` (330-444): always targets `NSLocalDomainMask` `/Applications`
(343-345; no `~/Applications` preference), skips source deletion when `diskImageDevice != nil`
(423), detaches the DMG after 5 s (430-439), no translocation check (333-337).

**electron-builder.** No move prompt (the DMG builder only lays out the image). Default layout is
"the app icon on the left and a `/Applications` shortcut on the right" with `type: link, path:
/Applications` (`website/docs/dmg.md:57-79`). `DmgOptions.internetEnabled` (default false):
"Whether to create internet-enabled disk image (when it is downloaded using a browser it will
automatically decompress the image, put the application on the desktop, unmount and remove the
disk image file)" (`packages/app-builder-lib/src/options/macOptions.ts:317-321`). It is a no-op
on Darwin ≥ 19 (Catalina): `if (this.options.internetEnabled && parseInt(getOsRelease()…) < 19)`
(`packages/dmg-builder/src/dmg.ts:86-88`), added by PR #4531 (merged 2020-01-16, "remove
internet-enable from macOS 10.15") fixing issue #4405 (`hdiutil: internet-enable: verb not
recognized`). Docs: "Internet-enabled DMGs … This is an older pattern and is no longer
recommended for modern apps." (`website/docs/dmg.md:163-170`).

**Tauri.** No built-in prompt. Open feature request tauri-apps/plugins-workspace#2148
(2023-02-15): the updater fails with "Tauri API error: read-only filesystem error (os error 30)"
when the `.app` is not in Applications, "with no feedback to the end-user"; asks Tauri to detect
it and prompt the user to move the app. No maintainer resolution visible as of fetch. Tauri's DMG
doc describes the standard drag-to-Applications layout (https://v2.tauri.app/distribute/dmg/).

**Popular apps.** First-party statements found:

- **VS Code** — docs say it ships as a `.dmg`; "Drag `Visual Studio Code.app` to the
  **Applications** folder." No mention of a move prompt
  (https://code.visualstudio.com/docs/setup/mac).
- **1Password 8** — "1Password must be installed in the `/Applications` folder to work properly.
  Don't install the app in the user `~/Applications` folder." Offers a `1Password.app` download
  (auto-updates) or `1Password.pkg` (IT-managed) (https://support.1password.com/deploy-1password/).
  Community thread reports a startup message about not being in Applications; exact wording and
  whether it self-moves are **not verified** (https://www.1password.community/discussions/1password/at-startup-message-from-1password-is-that-it-isnt-installed-in-the-applications-/92742).
- **Notion** — help page only says "Open the downloaded file and follow the installation prompts"
  (https://www.notion.com/help/notion-for-desktop); format and prompt behaviour **not verified**.
- **Spotify** — LetsMove's README credits "Rasmus Andersson / Spotify (French and Spanish)" as
  translators (README.md:192), which is evidence Spotify used LetsMove historically; current
  behaviour **not verified**.
- **Slack, Discord, Arc, Raycast, Figma** — first-party install pages could not be fetched (403 /
  redirected / JS-only) during this research. Any "these apps prompt to move" claim is
  **unverified/observed** and is not asserted here.

## 4. Apple's guidance

- **App Translocation Notes**, Quinn "The Eskimo!", Apple DTS, Apple Developer Forums thread
  724969 (Feb 2023): "The exact circumstances where the system translocates an app is not
  documented and has changed over time." "There is no supported way to detect if your app is
  being run translocated." "There is no supported way to determine the original (untranslocated)
  path of your app. Again, you'll find lots of unsupported techniques for this out there on the
  'net. Use them at your peril!" "It's best to structure your app so that it works regardless of
  whether it's translocated or not." Demonstrates that Finder-moving the app "cleared the state
  that triggered app translocation." (https://developer.apple.com/forums/thread/724969)
- **`SecTranslocate*` API status.** Verified locally on the macOS 26 SDK: zero matches for
  `SecTranslocate` in `Security.framework/Headers/`, while `Security.tbd` exports
  `_SecTranslocateCreateOriginalPathForURL`, `_SecTranslocateIsTranslocatedURL`,
  `_SecTranslocateURLShouldRunTranslocated`, `_SecTranslocateCreateSecureDirectoryForURL`,
  `_SecTranslocateDeleteSecureDirectory`, `_SecTranslocateAppLaunchCheckin`,
  `_SecTranslocateStartListening[WithOptions]`, `_SecTranslocateCreateGeneric`. The header exists
  only in Apple's open-source drop
  (`Security/OSX/libsecurity_translocate/lib/SecTranslocate.h`, APSL 2.0), declaring e.g.
  `CFURLRef __nullable SecTranslocateCreateOriginalPathForURL(CFURLRef translocatedPath,
  CFErrorRef* __nullable error) __OSX_AVAILABLE(10.12);` (lines ~151-173)
  (https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_translocate/lib/SecTranslocate.h).
  Conclusion: exported, `10.12`-available, **not in the public SDK** — SPI, consistent with Quinn's
  "no supported way". Dock Tile's `dlsym` approach (per `.claude/rules/app-relocation.md`) is the
  same unsupported route LetsMove #60 proposed.
- **WWDC 2016 Session 706 "What's New in Security"** (Lucia Ballard, Simon Cooper;
  https://developer.apple.com/videos/play/wwdc2016/706/; transcript
  https://asciiwwdc.com/2016/sessions/706; slides
  https://devstreaming-cdn.apple.com/videos/wwdc/2016/706sgjvzkvg6rrg9icw/706/706_whats_new_in_security.pdf).
  Transcript: the threat is an app "inside a container … through a zip or a disk image or using
  an ISO image" loading external resources; "We can now sign disk images … macOS 10.11.5 … and
  that will basically bind the external resources and the app together."; "If the user moves the
  single app by itself, maybe to Slash Applications, then this mechanism will be turned off.";
  "For a container with apps and resources, with a disk image, please use, and switch to using a
  signed disk image."; "please stop shipping ISO images." (Session 706 is "What's New in Security";
  "How iOS Security Really Works" is a different session — the caller's title was mistaken.)
- **Packaging Mac software for distribution** (Xcode docs): lists zip, Installer package and disk
  image. On DMG: "The person receiving your disk image opens it in Finder to access its contents,
  and they may choose to run your app from the disk image or move it to their preferred location.
  This experience is easiest if your product is a single file or bundle." Apple's own steps are
  `hdiutil create -srcFolder … -o …` then `codesign`; the Applications symlink is explicitly
  delegated: "You can use a third-party tool to configure a disk image for distribution. For
  example, the tool might arrange the icons, set a background image, and add a symlink to the
  Applications folder." On pkg: "An installer package is the best choice if your product contains
  multiple components, must be copied to specific locations, or if you need to run custom code
  during installation." `productbuild --sign <Identity> --component <PathToApp> /Applications
  <PathToPackage>` (https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).
- **HIG.** The HIG "Onboarding" page has no mention of installation, the Applications folder or
  move prompts (headings: Best practices, Additional content, Additional requests, Platform
  considerations, Resources) (https://developer.apple.com/design/human-interface-guidelines/onboarding).
  No HIG page on install prompts was found.
- **Translocation trigger rules (secondary).** Howard Oakley (2023-05-09) summarising Jeff
  Johnson's 2016 findings: translocation when the app "has a com.apple.quarantine extended
  attribute", "must be opened by Launch Services (normally the Finder) rather than a command
  shell", and "hasn't been moved by the Finder from the folder it was unarchived or downloaded
  to"; Oakley's macOS 13.3.1 tests found the third rule no longer reliable and "The only way to
  prevent App Translocation from occurring is to strip the com.apple.quarantine extended
  attribute" (https://eclecticlight.co/2023/05/09/what-causes-app-translocation/). Rogue Amoeba
  (2016-06-29): "disabled once the user moves the application out of the Downloads folder"; asked
  Apple for an Info.plist opt-out key (never shipped)
  (https://weblog.rogueamoeba.com/2016/06/29/sierra-and-gatekeeper-path-randomization/).
  These are not Apple sources; Apple says the rules are undocumented (above).

## 5. Alternative distribution mechanics

- **zip.** Apple: "You can't sign a zip archive … The person receiving your zip archive opens it
  with Finder to unarchive the contents, which they optionally move into their preferred location."
  Sparkle: keep only the app in the archive to "minimize app translocation issues" (sources in §2,
  §4). A zip lands the app in `~/Downloads` — the same "elsewhere" case, but on a writable volume,
  so a move (not copy) is possible there.
- **pkg (`productbuild`).** Apple's recommended choice when the product "must be copied to specific
  locations"; `--component <app> /Applications` installs straight into `/Applications` (§4). 1Password
  offers a `.pkg` for IT-managed installs (§3). Trade-off for Dock Tile: Sparkle's default installer
  updates an app bundle, and a pkg install path changes the first-run story; not evaluated here.
- **Internet-enabled DMGs.** `hdiutil internet-enable` was **removed** in macOS 10.15 per the local
  `hdiutil(1)` man page history: "macOS 10.15: … Removed the deprecated 'hdiutil internet-enable'
  command and the IDME attach flags." electron-builder guards it to Darwin < 19 (§3). The feature
  historically caused Safari (not Finder) to copy the contents out and eject the image
  (secondary: Wikipedia "Apple Disk Image" / create-dmg issue #76,
  https://github.com/andreyvit/create-dmg/issues/76). Dead end for macOS 15+.
- **Finder / Safari auto-copy.** Safari's "Open 'safe' files after downloading" mounts a downloaded
  disk image; it does not copy the app out (Apple Support, "Download items from the web using
  Safari on Mac", https://support.apple.com/guide/safari/sfri40598/mac). Finder has no auto-copy.
- **Applications-symlink DMG convention.** No official Apple requirement; Apple's packaging doc
  mentions the symlink only as something "a third-party tool" might add (§4). electron-builder and
  Tauri both default to it (§3). Apple's own doc states users may "run your app from the disk
  image", i.e. the DMG-launch case is an Apple-sanctioned path, not user error.
- **Signed DMG.** WWDC 2016 706 recommends a signed disk image so the app and companion files are
  bound together; it does not exempt the app from translocation when launched from the image —
  the image is itself read-only, which is why Sparkle's `MNT_RDONLY` check fires there.

## 6. Copy vs move from a read-only volume

- **`FileManager.moveItem(at:to:)` / `moveItem(atPath:toPath:)` (Apple docs):** "If the source and
  destination of the move operation are not on the same volume, this method copies the item first
  and then removes it from its current location. This behavior may trigger additional delegate
  notifications related to copying and removing individual items." and "If an item with the same
  name already exists at `dstURL`, this method stops the move attempt and returns an appropriate
  error." Also "the current process must have permission to read the item at `srcURL` and write
  the parent directory of `dstURL`" — write permission on the *source* parent (needed for the
  remove) is not listed, which matches the observed behaviour: the copy succeeds, the remove fails
  (642, `NSFileWriteVolumeReadOnlyError`), and the docs make no promise about rolling back the
  copy. (https://developer.apple.com/documentation/foundation/filemanager/moveitem(at:to:),
  https://developer.apple.com/documentation/foundation/filemanager/moveitem(atpath:topath:)).
  The SDK header `NSFileManager.h:204-209` adds nothing beyond availability.
- **What LetsMove/Electron do about it:** never call move. `copyItemAtPath:toPath:`, then
  `removeItemAtPath:` / trash as best-effort, skipped outright when `ContainingDiskImageDevice`
  is non-nil; the DMG is detached instead (§1, §3). Neither pre-checks source writability with
  `statfs`; Sparkle does (§2).
- **`copyfile(3)` flags** (local man page, macOS 26): `COPYFILE_MOVE` — "Unlink (using remove(3))
  the from file. (This is only applicable for the copyfile() function.) No error is returned if
  remove(3) fails." — i.e. a `copyfile(src, dst, NULL, COPYFILE_ALL|COPYFILE_RECURSIVE|
  COPYFILE_MOVE)` from a read-only source would report success with the source left behind, which
  is the semantics LetsMove hand-rolls. `COPYFILE_CLONE` "Try to clone the file instead … if
  cloning fails, fallback to copying" (irrelevant across volumes; clones need the same APFS
  volume). `COPYFILE_UNLINK` "Unlink the to file before starting" (would replace an existing
  destination — but does not check whether it is running). `COPYFILE_EXCL` (implied by CLONE)
  fails if the destination exists. Not used by any of the surveyed implementations.

## Sources

Primary (code / docs read directly):

- LetsMove `PFMoveApplication.m` @ `70c5772` — https://github.com/potionfactory/LetsMove/blob/master/PFMoveApplication.m
- LetsMove `README.md` — https://github.com/potionfactory/LetsMove/blob/master/README.md
- LetsMove repo metadata (GitHub API: `license: null`, `pushed_at` 2022-06-26, last commit 2020-07-09, 14 open issues) — https://api.github.com/repos/potionfactory/LetsMove
- LetsMove issues #56, #59, #60, #81, #86, #87 — https://github.com/potionfactory/LetsMove/issues/56 , /59 , /60 , /81 , /86 , /87
- Sparkle @ `5fddc92`: `Sparkle/SUHost.m`, `Sparkle/SPUBasicUpdateDriver.m`, `Sparkle/SUErrors.h`, `Sparkle/SPUUIBasedUpdateDriver.m`, `Sparkle/SPUScheduledUpdateDriver.m`, `Sparkle/SPUUpdaterDelegate.h`, `Sparkle/InstallerProgress/InstallerProgressAppController.m`, `CHANGELOG` — https://github.com/sparkle-project/Sparkle
- Sparkle documentation, "Distributing your App" — https://sparkle-project.org/documentation/
- Electron `docs/api/app.md` (`isInApplicationsFolder`, `moveToApplicationsFolder`) — https://github.com/electron/electron/blob/main/docs/api/app.md
- Electron `shell/browser/ui/cocoa/electron_bundle_mover.mm` — https://github.com/electron/electron/blob/main/shell/browser/ui/cocoa/electron_bundle_mover.mm
- electron-builder `packages/app-builder-lib/src/options/macOptions.ts`, `packages/dmg-builder/src/dmg.ts`, `website/docs/dmg.md` — https://github.com/electron-userland/electron-builder
- electron-builder issue #4405 / PR #4531 — https://github.com/electron-userland/electron-builder/issues/4405 , https://github.com/electron-userland/electron-builder/pull/4531
- Tauri plugins-workspace issue #2148 — https://github.com/tauri-apps/plugins-workspace/issues/2148 ; Tauri DMG doc — https://v2.tauri.app/distribute/dmg/
- Apple, "App Translocation Notes" (Quinn, DTS) — https://developer.apple.com/forums/thread/724969
- Apple open source `SecTranslocate.h` — https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_translocate/lib/SecTranslocate.h
- Local macOS 26 SDK: `Security.framework/Headers` (no `SecTranslocate`), `Security.tbd` exports; `NSFileManager.h`; `man copyfile`; `man hdiutil` (history section)
- Apple, WWDC 2016 Session 706 — https://developer.apple.com/videos/play/wwdc2016/706/ ; transcript https://asciiwwdc.com/2016/sessions/706 ; slides https://devstreaming-cdn.apple.com/videos/wwdc/2016/706sgjvzkvg6rrg9icw/706/706_whats_new_in_security.pdf
- Apple, "Packaging Mac software for distribution" — https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution
- Apple, `FileManager.moveItem(at:to:)` / `moveItem(atPath:toPath:)` — https://developer.apple.com/documentation/foundation/filemanager/moveitem(at:to:) , https://developer.apple.com/documentation/foundation/filemanager/moveitem(atpath:topath:)
- Apple HIG, Onboarding — https://developer.apple.com/design/human-interface-guidelines/onboarding
- Apple Support, "Download items from the web using Safari on Mac" — https://support.apple.com/guide/safari/sfri40598/mac
- VS Code, "Visual Studio Code on macOS" — https://code.visualstudio.com/docs/setup/mac
- 1Password, "Deploy 1Password for Mac and Windows" — https://support.1password.com/deploy-1password/
- Notion, "Notion for desktop" — https://www.notion.com/help/notion-for-desktop

Secondary (not authoritative; used only where marked):

- Howard Oakley, "What causes App Translocation?" (2023-05-09) — https://eclecticlight.co/2023/05/09/what-causes-app-translocation/
- Rogue Amoeba, "Sierra and Gatekeeper Path Randomization" (2016-06-29) — https://weblog.rogueamoeba.com/2016/06/29/sierra-and-gatekeeper-path-randomization/
- 1Password community thread on the Applications-folder startup message — https://www.1password.community/discussions/1password/at-startup-message-from-1password-is-that-it-isnt-installed-in-the-applications-/92742
- create-dmg issue #76 (`hdiutil internet-enable`) — https://github.com/andreyvit/create-dmg/issues/76
