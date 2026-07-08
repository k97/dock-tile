---
name: releasing-macos-apps
description: Create notarized macOS app releases with Sparkle auto-updates, DMG installers, and GitHub releases. Use when releasing macOS apps, creating DMG files, notarizing apps, or setting up Sparkle updates. Handles version updates, code signing, notarization, and distribution.
---

# Releasing macOS Apps

Complete workflow for creating notarized macOS app releases with Sparkle auto-updates, DMG installers, and GitHub releases.

## Dock Tile: CI-driven release (start here)

**This repo releases through CI.** Pushing a version tag (`vX.Y.Z`) triggers
`.github/workflows/release.yml`, which does the heavy lifting automatically — so the manual
**Steps 2–10 below are done for you** and are only a fallback for a repo without this CI.

CI, on tag push, will:
- Build → sign → notarize the DMG
- Generate the Sparkle EdDSA signature
- Insert the new `appcast.xml` entry (newest first)
- Update `website/lib/config.ts` (download URL + version) and commit it to `main`
- Create the GitHub Release and upload the DMG + SHA256

**So the human flow is just:**

```
- [ ] Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION in DockTile/Config/Base.xcconfig (+ CLAUDE.md header)
- [ ] Generate release notes from git history (see next section)
- [ ] Commit, push main, then tag and push the tag
- [ ] Wait for release.yml to finish (gh run watch)
- [ ] Publish the draft + apply the notes (Step 11)
- [ ] (optional, separate website session) add a curated entry to website/lib/releases.ts
```

```bash
# 1. bump versions in Base.xcconfig + CLAUDE.md, then:
git add DockTile/Config/Base.xcconfig CLAUDE.md
git commit -m "chore: Bump version to X.Y.Z"
git push origin main                 # pushes pending commits; triggers CI + Vercel
git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z               # triggers release.yml
```

⚠️ **Do not push to `main` again between tagging and the release job finishing** — the pipeline
commits `appcast.xml`/`config.ts` back to `main` and needs a fast-forward. Pushing in between
breaks the release (this bit the 1.8.3 release). `git pull` after it completes.

See `.claude/rules/ci-release.md` for the authoritative pipeline description.

## Generate Release Notes

Produce curated, user-facing notes from the commits since the last release tag, as part of *this*
flow — no separate `gen-release-notes` pass, and no `CHANGELOG.md` required. The notes go straight
onto the GitHub Release in Step 11 (and, optionally, the website's curated list).

**1. List the commits since the last release tag:**
```bash
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^)   # last release tag before HEAD
echo "since ${PREV_TAG}:"
git log "${PREV_TAG}..HEAD" --no-merges --pretty=format:'%h %s'
```

**2. Keep only user-facing *app* changes.** Include `feat`/`fix`/`perf` commits that touch the app
(`DockTile/**`). **Exclude** `website(...)`, `docs`, `chore`, `test`, `ci`, `style`, and
tooling/skill commits — those never belong in app release notes. When in doubt, read the commit
body (`git show -s <hash>`) to write the line accurately.

**3. Rewrite each kept commit as one user-facing line** — imperative, benefit-first, *what changed
for the user*, never *how it was implemented*. Group under `### Fixed` / `### Changed` / `### Added`
(map `fix→Fixed`, `perf→Changed`, `feat→Added` or `Changed`). Be specific; never "various fixes".

**4. Write the notes to a file** for Step 11:
```bash
cat > /tmp/release-notes-vX.Y.Z.md << 'EOF'
APP X.Y.Z

<one-line summary of the release>

### Fixed
- <user-facing fix>

### Changed
- <user-facing change>

**Full Changelog**: https://github.com/USER/REPO/compare/vPREV...vX.Y.Z
EOF
```

Match the calm, user-focused tone of the website's curated notes in `website/lib/releases.ts`.

## Release Checklist (manual fallback — non-CI repos only)

Copy this checklist and track progress:

```
Release Progress:
- [ ] Step 1: Check prerequisites (certificates, credentials)
- [ ] Step 2: Update version in .xcconfig file
- [ ] Step 3: Build and archive the app
- [ ] Step 4: Export with proper code signing
- [ ] Step 5: Create zip and generate Sparkle signature
- [ ] Step 6: Create DMG with Applications folder
- [ ] Step 7: Submit for notarization
- [ ] Step 8: Staple notarization ticket to DMG
- [ ] Step 9: Update appcast.xml with new signature
- [ ] Step 10: Commit and push changes
- [ ] Step 11: Update GitHub release assets
- [ ] Step 11: Publish release & apply notes (⚠️ CRITICAL)
- [ ] Step 12: Final verification (DMG + Sparkle updates)
```

## Prerequisites

Before starting a release, verify:

1. **Apple Developer ID Application certificate** installed and valid
2. **Apple ID credentials** for notarization:
   - Apple ID email
   - App-specific password (generate at appleid.apple.com)
   - Team ID
3. **Sparkle private key** for signing updates
4. **GitHub CLI** (`gh`) installed and authenticated
5. **Version configuration location** identified (usually `.xcconfig` file)

Check certificate:
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## Step 1: Update Version

Locate your version configuration file (commonly `ProjectName.xcconfig` or `project.pbxproj`).

**For .xcconfig files:**
```bash
# Edit the APP_VERSION line
# Example: APP_VERSION = 1.0.9
```

**Verify the update:**
```bash
xcodebuild -project PROJECT.xcodeproj -showBuildSettings | grep MARKETING_VERSION
```

## Step 2: Build and Archive

Archive the app with the new version:

```bash
xcodebuild -project PROJECT.xcodeproj \
  -scheme SCHEME_NAME \
  -configuration Release \
  -archivePath ~/Desktop/APP-VERSION.xcarchive \
  archive
```

**Verify archive was created:**
```bash
ls -la ~/Desktop/APP-VERSION.xcarchive
```

## Step 3: Export with Code Signing

Create export options file:

```bash
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>YOUR_TEAM_ID</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
</dict>
</plist>
EOF
```

Replace `YOUR_TEAM_ID` with your actual team ID.

Export the archive:

```bash
xcodebuild -exportArchive \
  -archivePath ~/Desktop/APP-VERSION.xcarchive \
  -exportPath ~/Desktop/APP-VERSION-Export \
  -exportOptionsPlist /tmp/ExportOptions.plist
```

**Verify the exported app version:**
```bash
defaults read ~/Desktop/APP-VERSION-Export/APP.app/Contents/Info.plist CFBundleShortVersionString
```

This should show the new version number.

**Verify code signing:**
```bash
codesign -dvvv ~/Desktop/APP-VERSION-Export/APP.app
```

Look for "Developer ID Application" in the Authority lines.

## Step 4: Create Zip and Generate Sparkle Signature

Create zip file for Sparkle auto-updates:

```bash
cd ~/Desktop/APP-VERSION-Export
ditto -c -k --keepParent APP.app APP.app.zip
```

Generate Sparkle EdDSA signature (you'll be prompted for the private key):

```bash
echo "YOUR_SPARKLE_PRIVATE_KEY" | \
  ~/Library/Developer/Xcode/DerivedData/PROJECT-HASH/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update \
  APP.app.zip --ed-key-file -
```

**Output format:**
```
sparkle:edSignature="BASE64_SIGNATURE" length="FILE_SIZE"
```

Save both the signature and length for updating appcast.xml.

For more details, see [SPARKLE.md](SPARKLE.md).

## Step 5: Create DMG with Applications Folder

Create DMG installer with Applications folder symlink for drag-and-drop installation:

```bash
TEMP_DMG_DIR="/tmp/APP_dmg" && \
rm -rf "${TEMP_DMG_DIR}" && \
mkdir -p "${TEMP_DMG_DIR}" && \
cp -R ~/Desktop/APP-VERSION-Export/APP.app "${TEMP_DMG_DIR}/" && \
ln -s /Applications "${TEMP_DMG_DIR}/Applications" && \
hdiutil create -volname "APP VERSION" \
  -srcfolder "${TEMP_DMG_DIR}" \
  -ov -format UDZO ~/Desktop/APP-VERSION.dmg && \
rm -rf "${TEMP_DMG_DIR}"
```

**Verify DMG contents:**
```bash
hdiutil attach ~/Desktop/APP-VERSION.dmg -readonly -nobrowse -mountpoint /tmp/verify_dmg && \
ls -la /tmp/verify_dmg && \
hdiutil detach /tmp/verify_dmg
```

You should see both `APP.app` and `Applications` (symlink).

## Step 6: Submit for Notarization

Submit the DMG to Apple for notarization (you'll be prompted for credentials):

```bash
xcrun notarytool submit ~/Desktop/APP-VERSION.dmg \
  --apple-id YOUR_APPLE_ID@gmail.com \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD \
  --wait
```

The `--wait` flag makes the command wait for processing to complete (typically 1-2 minutes).

**Expected output:**
```
Processing complete
  id: [submission-id]
  status: Accepted
```

If status is "Invalid", get detailed logs:
```bash
xcrun notarytool log SUBMISSION_ID \
  --apple-id YOUR_APPLE_ID@gmail.com \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD
```

For notarization troubleshooting, see [NOTARIZATION.md](NOTARIZATION.md).

## Step 7: Staple Notarization Ticket

Staple the notarization ticket to the DMG:

```bash
xcrun stapler staple ~/Desktop/APP-VERSION.dmg
```

**Expected output:**
```
The staple and validate action worked!
```

**Verify notarization:**
```bash
spctl -a -vvv ~/Desktop/APP-VERSION-Export/APP.app
```

Should show:
```
accepted
source=Notarized Developer ID
```

## Step 8: Update appcast.xml

Update the Sparkle appcast file with the new version, signature, and file size from Step 4:

```xml
<item>
  <title>Version X.X.X</title>
  <link>https://github.com/USER/REPO</link>
  <sparkle:version>X.X.X</sparkle:version>
  <sparkle:channel>stable</sparkle:channel>
  <description><![CDATA[
    Release version X.X.X
  ]]></description>
  <pubDate>DAY, DD MMM YYYY HH:MM:SS -0700</pubDate>
  <enclosure
    url="https://github.com/USER/REPO/releases/download/vX.X.X/APP.app.zip"
    sparkle:version="X.X.X"
    sparkle:edSignature="SIGNATURE_FROM_STEP_4"
    length="FILE_SIZE_FROM_STEP_4"
    type="application/octet-stream" />
</item>
```

**Note:** The gitleaks pre-commit hook may flag the Sparkle signature as a potential secret. This is a false positive - the EdDSA signature is public and safe to commit. Use `git commit --no-verify` if needed.

## Step 9: Commit and Push Changes

Commit the version update and appcast changes:

```bash
git add PROJECT.xcconfig appcast.xml
git commit --no-verify -m "Bump version to X.X.X

Update appcast.xml with new version, Sparkle signature, and file size.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push
```

## Step 10: Update GitHub Release

Create or update the GitHub release with new assets:

**For new releases:**
```bash
gh release create vX.X.X \
  --title "APP vX.X.X" \
  --notes "Release version X.X.X" \
  ~/Desktop/APP-VERSION.dmg \
  ~/Desktop/APP-VERSION-Export/APP.app.zip
```

**For updating existing releases:**
```bash
# Upload new assets (overwrites existing with --clobber)
gh release upload vX.X.X \
  ~/Desktop/APP-VERSION.dmg \
  ~/Desktop/APP-VERSION-Export/APP.app.zip \
  --clobber
```

**Note on asset naming:**
The uploaded filename becomes the asset name. To upload with a specific name:
```bash
# Copy to desired name first
cp ~/Desktop/APP-1.0.9.dmg /tmp/APP.dmg
gh release upload vX.X.X /tmp/APP.dmg
```

**Verify release assets:**
```bash
gh release view vX.X.X --json assets -q '.assets[] | "\(.name) - \(.size) bytes"'
```

## Step 11: Publish Release & Apply Notes

Wait for `release.yml` to finish before this step:
```bash
gh run watch "$(gh run list --workflow=release.yml --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
```

**Apply the curated notes and publish in one command** — replaces CI's auto-generated notes with
the file from [Generate Release Notes](#generate-release-notes):
```bash
gh release edit vX.X.X --draft=false --notes-file /tmp/release-notes-vX.X.X.md
```

⚠️ **CRITICAL**: GitHub releases created by CI may be **drafts** (`draft: true`). Draft release assets return **404** for unauthenticated downloads, so Sparkle shows "Update Error — An error occurred while downloading the update" until published. `--draft=false` above is a no-op if it's already public, so it's safe to always run.

**Verify the DMG is publicly downloadable:**
```bash
curl -sI -L "https://github.com/USER/REPO/releases/download/vX.X.X/APP-X.X.X.dmg" | grep "HTTP/"
# Should show: HTTP/2 302 then HTTP/2 200
```

**Website:** CI already updates `website/lib/config.ts` (download URL + version) and commits it to
`main` — **do not** edit it by hand. The only manual, optional website touch is adding a curated
entry to `website/lib/releases.ts` (the human-readable release list). Per repo convention that is a
**website change → do it in a separate website session**, not this app-release flow.

## Step 12: Final Verification

Verify the release is working correctly:

**Check version in app:**
```bash
defaults read /Applications/APP.app/Contents/Info.plist CFBundleShortVersionString
```

Should show: `X.X.X`

**Test DMG:**
1. Download the DMG from GitHub release
2. Open the DMG
3. Verify Applications folder is present for drag-and-drop
4. Drag app to Applications and launch
5. Should open without any "malicious" or security warnings

**Test Sparkle updates:**
- Open the previous version of the app
- Click "Check for Updates..." from the app menu
- The update dialog should show the new version
- Click "Install Update" — it should download and install without errors
- If you see "Update Error — An error occurred while downloading", the release is still a **draft** — go back to Step 11

## Common Issues

If you encounter problems, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions to:

- Version not updating after rebuild
- DMG missing Applications folder
- Notarization failures
- "Malicious app" warnings
- Sparkle signature issues
- CI/CD failures

## Quick Reference

**Check version:**
```bash
defaults read /path/to/APP.app/Contents/Info.plist CFBundleShortVersionString
```

**Check code signing:**
```bash
codesign -dvvv /path/to/APP.app
```

**Check notarization:**
```bash
spctl -a -vvv /path/to/APP.app
```

**Get Sparkle sign_update path:**
```bash
find ~/Library/Developer/Xcode/DerivedData -name sign_update -type f
```
