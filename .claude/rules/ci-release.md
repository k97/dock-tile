# CI/CD & Release

## GitHub Actions

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push to main/develop, PRs | Build + unit tests |
| `release.yml` | Tag push (v*) | Build, sign, notarize, GitHub Release |

Both build on `macos-26` beta runners (ARM64 only); `ci.yml` additionally tests on `macos-15` (below). `paths-ignore` skips CI on website/docs-only changes. Vercel uses `ignoreCommand` in `vercel.json` to skip on Xcode-only changes. `ci.yml` also has `workflow_dispatch`, so any branch can be run on demand (`gh workflow run ci.yml --ref <branch>`).

**The project cannot be BUILT on a macOS 15 host (verified 2026-10-02).** The main app icon is
an Icon Composer `.icon` document, and Xcode 26's `actool` crashes compiling it on macOS 15
("IBPlatformToolFailureException … AssetCatalogAgent closed the connection"), even with Xcode 26.2
selected. So the macOS 15 leg — the only place the frozen legacy icon path
(`IconPipeline.isDeclarative == false`) ever runs under test — is a separate `test-macos-15` job:
`build-and-test` (macos-26) runs `xcodebuild build-for-testing`, tars `Build/Products` (tar, not
zip: `upload-artifact` drops the symlinks inside embedded frameworks), and the macos-15 job runs
`xcodebuild test-without-building -xctestrun …`. Keep that leg green before merging anything that
ships to macOS 15; a Tahoe-only test must `#available`-gate itself rather than drop the leg.
Its evidence is the "Prove the suite" step's `macOS 15: N passed, M failed` line (the job fails
below 600). `xcpretty` hides the per-test lines from the job log, so grepping it for test cases
finds ~2 and reads as a broken leg when it is not.

**The floor is one number, and four places must agree with it (`MacOSFloorGuardTests`).**
`MACOSX_DEPLOYMENT_TARGET` in `Base.xcconfig` is the source of truth; the guard fails on any
drift in: the appcast floor (`MIN_OS` in `generate-appcast-entry.sh`), the macOS 15 CI leg
(required while the target is below 26, and must be DELETED once it is 26+ — the named deletion
trigger for the frozen legacy icon path), and every requirement the website states ("Requires
macOS N", "For macOS N+", schema.org `operatingSystem`). The site said "macOS 26 or later" for
months while the binary and appcast said 15.0 — macOS 15 users ran a build the site disowned, on
a path nothing tested, and the 2.0.2 oversized-tile report came from there. Raising the floor is
therefore a single edit to `Base.xcconfig` plus whatever the guard then lists.
**A website-only push skips app CI (`paths-ignore`), so it can turn this guard red on `main` unseen**:
79f00bf removed the homepage banner holding "macOS 15+" and the guard failed only when the next
app branch ran tests (2026-10-31). After a website change to requirement copy, run
`-only-testing:DockTileTests/MacOSFloorGuardTests`; when a listed file stops stating the floor but
the site still does elsewhere, drop that file from the guard's list rather than re-adding copy.

**A CI check's negative control goes on a throwaway branch (2026-10-29).** Invert one expectation in
a commit on `<branch>-negative`, dispatch it, require it to FAIL with the expected count, then delete
the branch — no force push, and the inverted commit never reaches `main`. It earned its keep at once:
`dock-kill-check`'s inverted trial passed its capture on macOS 15, exposing a blind measurer (the
stub's generic icon was near-white on the bar) before either run was trusted.

**Run a feature branch through CI BEFORE merging it (2026-10-20).** The App Grid work sat as 25
local commits and first met CI on release day, where it surfaced two release blockers (a compile
deadlock, a renderer-dependent preview test). `gh workflow run ci.yml --ref <branch>` runs any branch.

**An outside contributor's PR: never approve its workflow run or its Vercel preview (2026-10-28, #32).**
Fork-PR runs wait for approval (policy: all external contributors), and Vercel's Git Fork Protection
holds a fork preview behind "Authorize" — both are the gate, leave them unapproved. Instead fetch with
`git fetch origin pull/<n>/head:<branch>`, read the whole diff before building it (a build runs its
script phases), fix on top of the contributor's commit, push the branch to origin and run CI there.
`main` then fast-forwards to the branch and GitHub marks the PR merged itself, authorship intact.

**Repo hardening (2026-10-28) — full reference: [docs/release-security.md](../../docs/release-security.md).**
- **`release` environment** (required reviewer k97, `v*` tags only): the build job waits for ONE
  approval when Run Tests passes (~15 min after the tag; Run Tests reads only the repo-level notary
  login and starts unapproved). Review `git log vPREV..HEAD` first. **The owner may say "approve" in
  chat**: the agent then approves via `gh api -X POST repos/k97/dock-tile/actions/runs/<run>/pending_deployments
  -F 'environment_ids[]=<id>' -f state=approved` (id: `gh api repos/k97/dock-tile/actions/runs/<run>/pending_deployments
  --jq '.[].environment.id'`) — never without that instruction for that release.
  The signing secrets (`SPARKLE_EDDSA_KEY`, `DEVELOPER_ID_APPLICATION_CERTIFICATE` + `_PASSWORD`) live
  ONLY in the environment (repo-level copies deleted 2026-10-28, after 2.6.1 shipped from them); the
  other five are repo-level. Never re-add a signing secret at repo level.
- **Rulesets**: "Release tags" — only an admin can create, move or delete `v*` tags; "Protect main" —
  no force push, no deletion (normal pushes, including the pipeline's own commit, still work).
- **Every action is pinned to a full commit SHA** with the version as a trailing comment; Dependabot
  (`.github/dependabot.yml`, 7-day cooldown, each major its own PR) proposes bumps. A new `uses:` must
  be pinned the same way — the repo's Actions policy requires it.
- **Sparkle signature guard**: `Scripts/ci/verify-sparkle-signature.swift` checks the build's
  `SUPublicEDKey` against a pinned copy, then the signature against it, before the appcast, website
  commit or GitHub Release — a wrong key fails the run and publishes nothing. The Sparkle tools
  tarball that receives the key is checked against a pinned SHA-256; bumping `SPARKLE_VERSION`
  needs the new release's digest (`gh api repos/sparkle-project/Sparkle/releases/tags/<v>`).

**Reading a failed run.** The macos-26 test step times out at 30 min; if xcodebuild is still running at
15 min it `sample`s the test host and keeps `diagnostics.log` (`hang/`). On failure it uploads
`build-logs` with `test.log` and `TestResults.xcresult`: `gh run download <run> -n build-logs`, then
`xcrun xcresulttool get test-results tests --path TestResults.xcresult | grep "Expectation failed"`.
Swift Testing's issue text is ONLY in the xcresult (xcpretty and the raw log carry just "failed on"),
and its per-test durations there are suite wall time, not the test's own.
Two false alarms from 2026-10-28: a `gh run watch` that exits 1 may be a LOCAL network error
("can't assign requested address") with the run still going — read `gh run view` first; and a
re-run of an older `main` run shows "cancelled" when a newer push lands, because `ci.yml` uses
`cancel-in-progress` per ref — only the newest commit's run counts.

**Dock render check (on demand):** `gh workflow run ci.yml --ref <branch> -f dock_check=true`
adds `dock-check-macos-15`, which bakes legacy tiles with the real generator on the macOS 15
runner (`LegacyIcnsDockFixtureTests`, enabled only by `TEST_RUNNER_DOCKTILE_ICNS_FIXTURE_DIR`),
pins them to that runner's Dock as stub bundles, screenshots the Dock and measures every icon's
width (`Scripts/ci/dock-check.sh` + `dock-measure.swift`; fails above 1.10× the median — a
full-bleed tile reads ~1.24×). Artifacts: `dock.png`, `dock-window.png`, `measure.txt`. The
measurer alone is safe locally (`swift Scripts/ci/dock-measure.swift out.png` captures the Dock
window by ID, never a screen rect); the shell script rewrites the Dock and refuses to run off CI.

**Dock SIGKILL check (on demand):** `gh workflow run ci.yml --ref <branch> -f dock_kill_check=true`
adds `dock-kill-check` on macos-15 AND macos-26 (no build products needed). It proves what the
2.6.2 Dock fix rests on: a persistent-apps write followed by `killall -KILL Dock` is kept, because
launchd relaunches the Dock and the killed Dock cannot flush its stale list over ours (SIGTERM lost
14/14 such writes in the 2026-10-29 experiment, docs/dock-modification-prior-art.md §6). Six
trials (0.5 / 2.5 / 10 s after a prior restart, add then remove) each require a new Dock PID, the
stub entry in the plist by `bundle-identifier`, and the running Dock's icon count via
`dock-measure.swift --count-only` (the stub carries a saturated red icon: the generic app icon is
near-white on macOS 15 and the measurer could not see it). Three uncounted SIGTERM controls,
§6's arm A exactly, report `lost N/3`: lost means the runner reproduces the race; 0/3 means it
does not, so the passes prove only the relaunch. Verdict =
the `dock-kill-check: N/6 OK` line in `log.txt`; a capture that can't be made reads
`capture: unavailable` and fails the job. `Scripts/ci/dock-kill-check.swift` rewrites the
runner's Dock and refuses to run off CI. Re-run it on each new runner image or macOS release.

**SwiftPM caching + resolve-retry (flaky-build fix)**: every build/test job caches `./build/SourcePackages` + `~/Library/Caches/org.swift.swiftpm` (keyed on `Package.resolved`) and runs a `-resolvePackageDependencies` step with retries **before** building. Firebase ships large binary xcframeworks (e.g. `grpc`) as binary targets downloaded during resolution; without this, every run re-downloaded them and a transient "network connection was lost" failed the build. A cache hit skips the download entirely; a cache miss retries (4×). A Firebase/dependency bump changes `Package.resolved` → first run is a cache miss (slower) that repopulates.

## Release Pipeline

```bash
./Scripts/build-release.sh --sign --notarize  # Full release
./Scripts/create-dmg.sh --app-path /path/to/DockTile.app  # DMG only
./Scripts/notarize.sh --dmg-path ./build/DockTile-1.0.dmg  # Notarize only
```

| Script | Purpose |
|--------|---------|
| `build-release.sh` | Build → sign → DMG → notarize |
| `create-dmg.sh` | DMG installer with Applications symlink |
| `notarize.sh` | Apple notarization submission |
| `generate-appcast-entry.sh` | Sparkle appcast XML for CI |

## Code Signing

Entitlements in `DockTile/DockTile.entitlements`:
- `cs.allow-unsigned-executable-memory` — ad-hoc signed helper bundles
- `cs.disable-library-validation` — loading helper bundles
- `automation.apple-events` — Dock restart via osascript

**`--deep` does NOT reach a loose executable in `Contents/Resources` (verified 2026-09-01).**
It neither signs nor verifies `docktile-actool` there, so the outer sign passes local
verification and **notarization rejects the DMG** — after a full sign → DMG → notarize cycle.
Sign nested executables explicitly (`--options runtime`) and verify them **before** the
enclosing bundle is sealed; an inner signature applied after the outer seal is worthless.
`release.yml` and `Scripts/build-release.sh` both do this — keep them in step.

**An Xcode script phase silently no-ops under `ENABLE_USER_SCRIPT_SANDBOXING`** unless it
declares `inputPaths`/`outputPaths`: the sandbox denies the copy and the build still succeeds.
A stale artifact from an earlier build masks this perfectly — delete it before trusting a phase.

## Sparkle Auto-Updates

- Sparkle 2.9.0 via SPM, EdDSA (Ed25519) signing
- Appcast at `https://docktile.app/appcast.xml`
- **`docktile.rkarthik.co` must stay attached in Vercel, permanently.** `SUFeedURL` is baked into
  each build at ship time: copies **≤ 1.8.8** poll the old host and always will, builds from
  2026-08-30 poll `docktile.app`. Detaching either host silently strands those users on their last
  version — no error they would ever see. (Full reasoning: website/.claude/rules/seo-geo.md.)
- **The update prompt shows no release notes.** Appcast items carry no `<description>` or
  `sparkle:releaseNotesLink` (`generate-appcast-entry.sh`; the only `<description>` is the
  channel's), so text written into GitHub release notes reaches the website's changelog, never an
  existing user's update dialog. A plan once assumed otherwise; reach existing users in the app.
- **Updates install silently** (`SUAutomaticallyUpdate` true since 2.3.1): Sparkle downloads in the
  background and installs when the main app quits. Added because most actives sat on 1.8.x/2.0.x
  with every check enabled (GA4, 2026-10-18). Sparkle still runs only in the MAIN app, so a user
  who never reopens Dock Tile is still never checked. `update_check` (`result`: found/none/declined/error),
  `update_choice` (`choice`) and `update_installing` measure this; Sparkle also reports "no update"
  as abort error 1001, which `UpdateAnalytics.abortResult` excludes (`UpdateAnalyticsTests`).
- Helper bundles have Sparkle keys stripped to prevent update conflicts
- `UpdateController.swift` wraps SPUUpdater with error-handling delegate; publishes `canCheckForUpdates`
  (KVO via Combine) so the Settings → General **Check for Updates…** button disables mid-session
- Daily checks (`SUScheduledCheckInterval = 86400`)

## New development machine

Everything the release needs lives in GitHub secrets, so a new Mac only needs `gh auth` + git
identity to tag a release. To **build locally** it also needs a Rust toolchain
(https://rustup.rs) plus one `./Scripts/build-compiler.sh` run — the Xcode build phase fails
until `Vendor/actool/target/release/docktile-actool` exists (CI builds it in the workflow). The
**one machine-local secret is the Sparkle EdDSA private key**:
`generate_keys` stores it as a non-synchronizable login-keychain item (iCloud Keychain never carries
it), and the GitHub secret cannot be read back. Move it with `generate_keys -x file` (old Mac) →
`generate_keys -i file` (new Mac); `generate_keys -p` must print the `SUPublicEDKey` in
`Resources/Info.plist`. Never regenerate it — a new key orphans every installed copy. Local
`sign_update --verify` also needs this key; OpenSSL can verify an appcast signature without it.

## GitHub Secrets

`DEVELOPER_ID_APPLICATION_CERTIFICATE`, `DEVELOPER_ID_APPLICATION_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_DEVELOPER_NAME`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `SPARKLE_EDDSA_KEY`

## Creating a Release (3 steps only)

```bash
# 1. Bump BOTH versions in DockTile/Config/Base.xcconfig
#    MARKETING_VERSION = 1.x.x
#    CURRENT_PROJECT_VERSION = N  (increment by 1)

# 2. Commit and push
git add DockTile/Config/Base.xcconfig && git commit -m "chore: Bump version to 1.x.x" && git push

# 3. Tag and push — triggers full CI pipeline (admin only: the "Release tags" ruleset)
git tag -a v1.x.x -m "Release 1.x.x" && git push origin v1.x.x

# 4. When Run Tests passes, approve the `release` environment (Review deployments, or say "approve"
#    in chat) — nothing is signed or published until you do
```

**CI handles everything else automatically:**
- Build, sign, notarize DMG
- Generate Sparkle EdDSA signature (uses `SPARKLE_EDDSA_KEY` secret)
- Update `appcast.xml` (inserts entry after `<language>`, newest first)
- Update `website/lib/config.ts` (download URL, version)
- Commit website changes to main
- Create GitHub Release with auto-generated notes from commits
- Upload DMG + SHA256 as release assets

**`sparkle:version`** (build number) is read from `CURRENT_PROJECT_VERSION` in `Base.xcconfig` — not derived from the marketing version.

**Notary preflight (first step of `release.yml`, since 2026-10-03).** Apple's notary service
answers every request with HTTP 403 "A required agreement is missing or has expired" while a
developer agreement is unsigned or the membership has lapsed. 2.0.3 failed twice at "Notarize
DMG" for this, 15 minutes into the first run, with nothing published. The workflow now runs
`xcrun notarytool history` with the release credentials before the tests, so that state stops the
run in seconds (the probe returned the same 403 from this Mac during the outage; it has not yet
been observed to trip inside the workflow itself). The same probe works locally and is the thing to run BEFORE tagging and before
re-running a failed release: `xcrun notarytool history --keychain-profile "DockTile-Notarization"`.
Only the Account Holder can accept the agreement (developer.apple.com/account, then App Store
Connect > Business); it took a few minutes to reach the notary service.

**No manual steps needed** for Sparkle signing, appcast editing, or release note writing. Edit the GitHub Release notes after creation if you want to polish them.

## Release Checklist (quick reference)

- [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Base.xcconfig`
- [ ] Update version in `CLAUDE.md` header
- [ ] Commit, push, tag, push tag
- [ ] Approve the `release` deployment once, when Run Tests passes (after reviewing `git log vPREV..HEAD`)
- [ ] Verify CI completes: `gh run list --limit 3`
- [ ] Optionally edit release notes: `gh release edit v1.x.x --notes "..."`
