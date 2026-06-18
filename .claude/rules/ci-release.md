# CI/CD & Release

## GitHub Actions

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push to main/develop, PRs | Build + unit tests |
| `release.yml` | Tag push (v*) | Build, sign, notarize, GitHub Release |

Both use `macos-26` beta runners (ARM64 only). `paths-ignore` skips CI on website/docs-only changes. Vercel uses `ignoreCommand` in `vercel.json` to skip on Xcode-only changes.

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

## Sparkle Auto-Updates

- Sparkle 2.9.0 via SPM, EdDSA (Ed25519) signing
- Appcast at `https://docktile.rkarthik.co/appcast.xml`
- Helper bundles have Sparkle keys stripped to prevent update conflicts
- `UpdateController.swift` wraps SPUUpdater with error-handling delegate
- Daily checks (`SUScheduledCheckInterval = 86400`)

## GitHub Secrets

`DEVELOPER_ID_APPLICATION_CERTIFICATE`, `DEVELOPER_ID_APPLICATION_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_DEVELOPER_NAME`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `SPARKLE_EDDSA_KEY`

## Creating a Release (3 steps only)

```bash
# 1. Bump BOTH versions in DockTile/Config/Base.xcconfig
#    MARKETING_VERSION = 1.x.x
#    CURRENT_PROJECT_VERSION = N  (increment by 1)

# 2. Commit and push
git add DockTile/Config/Base.xcconfig && git commit -m "chore: Bump version to 1.x.x" && git push

# 3. Tag and push — triggers full CI pipeline
git tag -a v1.x.x -m "Release 1.x.x" && git push origin v1.x.x
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

**No manual steps needed** for Sparkle signing, appcast editing, or release note writing. Edit the GitHub Release notes after creation if you want to polish them.

## Release Checklist (quick reference)

- [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Base.xcconfig`
- [ ] Update version in `CLAUDE.md` header
- [ ] Commit, push, tag, push tag
- [ ] Verify CI completes: `gh run list --limit 3`
- [ ] Optionally edit release notes: `gh release edit v1.x.x --notes "..."`
