# Troubleshooting Common Issues

Solutions to problems encountered during macOS app releases.

## Version Issues

### Version Not Updating After Rebuild

**Symptom:** After updating version and rebuilding, the app still shows the old version:
```bash
defaults read APP.app/Contents/Info.plist CFBundleShortVersionString
# Shows: 1.0.8 (expected: 1.0.9)
```

**Cause:** The version is defined in an `.xcconfig` file, not directly in `project.pbxproj` or `Info.plist`.

**Solution:**

1. **Find the version configuration file:**
   ```bash
   find . -name "*.xcconfig" -type f | grep -v DerivedData
   ```

2. **Update APP_VERSION in the .xcconfig file:**
   ```
   APP_VERSION = 1.0.9
   ```

3. **Verify the project uses this value:**
   ```bash
   grep -r "MARKETING_VERSION.*APP_VERSION" *.xcodeproj/project.pbxproj
   ```

4. **Rebuild from scratch:**
   ```bash
   rm -rf ~/Desktop/APP-VERSION.xcarchive
   xcodebuild -project PROJECT.xcodeproj -scheme SCHEME \
     -configuration Release -archivePath ~/Desktop/APP-VERSION.xcarchive archive
   ```

5. **Verify the version in the new archive:**
   ```bash
   defaults read ~/Desktop/APP-VERSION.xcarchive/Products/Applications/APP.app/Contents/Info.plist CFBundleShortVersionString
   ```

**Prevention:** Always update the version in the `.xcconfig` file, not just `Info.plist`.

### agvtool Not Working

**Symptom:** Running `agvtool new-marketing-version` appears to work but version doesn't change.

**Cause:** The project uses `.xcconfig` files for version management, which `agvtool` doesn't handle.

**Solution:** Manually edit the `.xcconfig` file instead of using `agvtool`.

## Code Signing Issues

### Sparkle Framework Not Signed

**Symptom:** Notarization fails with errors about unsigned Sparkle binaries:
```json
{
  "severity": "error",
  "path": "Claw.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app",
  "message": "The binary is not signed with a valid Developer ID certificate."
}
```

**Cause:** Copying the app directly from the `.xcarchive` without proper export doesn't sign embedded frameworks.

**Solution:** Use `xcodebuild -exportArchive` instead of copying:

```bash
# Wrong: Copying from archive
cp -R ~/Desktop/APP.xcarchive/Products/Applications/APP.app ~/Desktop/APP-Export/

# Correct: Export with signing
xcodebuild -exportArchive \
  -archivePath ~/Desktop/APP.xcarchive \
  -exportPath ~/Desktop/APP-Export \
  -exportOptionsPlist ExportOptions.plist
```

**Verification:**
```bash
codesign -dvvv ~/Desktop/APP-Export/APP.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
```

Should show "Developer ID Application" in Authority lines.

### Missing Secure Timestamp

**Symptom:** Notarization log shows:
```json
{
  "severity": "error",
  "message": "The signature does not include a secure timestamp."
}
```

**Cause:** Manual signing or copying files without proper export process.

**Solution:** Always use `xcodebuild -exportArchive` which automatically includes timestamps.

## DMG Issues

### DMG Missing Applications Folder

**Symptom:** DMG opens but there's no Applications folder for drag-and-drop installation.

**Cause:** Created DMG with simple `hdiutil create` without creating symlink.

**Solution:** Create temporary directory with symlink before creating DMG:

```bash
TEMP_DMG_DIR="/tmp/APP_dmg" && \
rm -rf "${TEMP_DMG_DIR}" && \
mkdir -p "${TEMP_DMG_DIR}" && \
cp -R ~/Desktop/APP-Export/APP.app "${TEMP_DMG_DIR}/" && \
ln -s /Applications "${TEMP_DMG_DIR}/Applications" && \
hdiutil create -volname "APP VERSION" \
  -srcfolder "${TEMP_DMG_DIR}" \
  -ov -format UDZO ~/Desktop/APP.dmg && \
rm -rf "${TEMP_DMG_DIR}"
```

**Verification:**
```bash
hdiutil attach ~/Desktop/APP.dmg -readonly -nobrowse -mountpoint /tmp/verify && \
ls -la /tmp/verify && \
hdiutil detach /tmp/verify
```

Should show both `APP.app` and `Applications -> /Applications` symlink.

### DMG Creation Fails "Operation Not Permitted"

**Symptom:**
```
hdiutil: create failed - Operation not permitted
```

**Cause:** Another DMG is already mounted at the same volume name.

**Solution:** Unmount any existing volumes:
```bash
hdiutil detach /Volumes/APP* 2>/dev/null || true
```

Then create DMG again.

## Notarization Issues

### "Malicious Software" Warning When Opening App

**Symptom:** macOS shows warning: "APP is damaged and can't be opened. You should move it to the Trash."

**Cause:** App is signed but not notarized.

**Check notarization status:**
```bash
spctl -a -vvv /Applications/APP.app
```

**If shows "Unnotarized Developer ID":**
1. Submit app for notarization
2. Wait for acceptance
3. Staple the ticket

**Full process:**
```bash
# Submit
xcrun notarytool submit APP.dmg \
  --apple-id EMAIL --team-id TEAM_ID --password PASSWORD --wait

# Staple
xcrun stapler staple APP.dmg

# Verify
spctl -a -vvv APP.app
# Should show: "Notarized Developer ID"
```

### Notarization Invalid - Multiple Errors

**Symptom:** Notarization fails with many errors about embedded frameworks.

**Cause:** App wasn't properly exported with code signing.

**Solution:**
1. **Delete existing export:**
   ```bash
   rm -rf ~/Desktop/APP-Export
   ```

2. **Create proper ExportOptions.plist:**
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

3. **Export properly:**
   ```bash
   xcodebuild -exportArchive \
     -archivePath ~/Desktop/APP.xcarchive \
     -exportPath ~/Desktop/APP-Export \
     -exportOptionsPlist /tmp/ExportOptions.plist
   ```

4. **Try notarization again**

### Notarization Credentials Rejected

**Symptom:**
```
Error: HTTP status code: 401. Invalid credentials.
```

**Common causes:**

1. **Wrong Apple ID email**
   - Verify at https://developer.apple.com/account
   - Must be the email associated with Developer ID certificate

2. **Expired app-specific password**
   - Generate new one at https://appleid.apple.com
   - Under "Sign-In and Security" → "App-Specific Passwords"

3. **Wrong team ID**
   - Find at https://developer.apple.com/account
   - Under "Membership" → "Team ID"

4. **Typo in credentials**
   - Double-check each value
   - App-specific password format: `xxxx-xxxx-xxxx-xxxx`

## Sparkle Update Issues

### Signature Doesn't Match

**Symptom:** Users report update downloads but fails to install with signature error.

**Cause:** The EdDSA signature in appcast.xml doesn't match the actual zip file.

**Common scenarios:**
1. Updated appcast.xml before rebuilding
2. Rebuilt app but didn't update signature
3. Modified zip after signing

**Solution:**
1. **Rebuild app**
2. **Create NEW zip:**
   ```bash
   cd ~/Desktop/APP-Export
   rm -f APP.app.zip
   ditto -c -k --keepParent APP.app APP.app.zip
   ```
3. **Generate NEW signature:**
   ```bash
   echo "PRIVATE_KEY" | sign_update APP.app.zip --ed-key-file -
   ```
4. **Update appcast.xml with NEW signature and size**
5. **Test locally before pushing**

### Updates Not Detected

**Symptom:** Sparkle doesn't show update notification for new version.

**Checklist:**

1. **Verify appcast.xml is accessible:**
   ```bash
   curl -I https://raw.githubusercontent.com/USER/REPO/main/appcast.xml
   # Should return 200 OK
   ```

2. **Check version comparison:**
   ```bash
   # Current version in app
   defaults read /Applications/APP.app/Contents/Info.plist CFBundleShortVersionString
   # Compare with <sparkle:version> in appcast.xml
   ```

3. **Verify XML syntax:**
   ```bash
   xmllint --noout appcast.xml
   # Should show no errors
   ```

4. **Check public key matches:**
   ```bash
   # Public key in app
   defaults read /Applications/APP.app/Contents/Info.plist SUPublicEDKey
   # Should match the key used to generate signature
   ```

### Signature Changes After Each Build

**Symptom:** Every rebuild produces a different EdDSA signature, even for the same version.

**Cause:** This is expected behavior. Signatures include build timestamps and UUIDs.

**Solution:** This is normal. Always:
1. Do final build
2. Generate signature from that build
3. Update appcast.xml with that signature
4. Don't rebuild after generating signature

If you must rebuild, regenerate the signature.

## GitHub Release Issues

### CI Fails on Release Commit

**Symptom:** GitHub Actions fails after pushing release commit.

**Cause:** CI environment doesn't have your Developer ID certificate (expected for local builds).

**Expected behavior:** CI failures are normal for local release builds. The release workflow is:
1. Build locally (with your certificate)
2. Export and sign locally
3. Upload to GitHub releases
4. CI may fail - ignore it for release commits

**Solution:** This is expected. Either:
- Add `[skip ci]` to commit message
- Configure CI to skip release commits
- Accept that CI fails for release commits

### Tag Naming Inconsistency

**Symptom:** appcast.xml URL doesn't match actual release tag, causing 404 errors.

**Cause:** Some releases use `v` prefix (`v1.2.4`) and some don't (`1.3.3`).

**Solution:** Check your existing releases and use consistent naming:
```bash
# Check existing tags
gh release list --limit 5

# Match URL format in appcast.xml to your tag format
# If tags are v1.2.4: url=".../download/v1.2.4/APP.app.zip"
# If tags are 1.2.4:  url=".../download/1.2.4/APP.app.zip"
```

**Best practice:** Pick one format and stick with it for all releases.

### Assets Not Uploading

**Symptom:** `gh release upload` fails or times out.

**Common causes:**

1. **File doesn't exist:**
   ```bash
   ls -lh ~/Desktop/APP.dmg
   ls -lh ~/Desktop/APP-Export/APP.app.zip
   ```

2. **GitHub CLI not authenticated:**
   ```bash
   gh auth status
   ```

3. **Release tag doesn't exist:**
   ```bash
   gh release view vVERSION
   ```

4. **Network timeout:**
   - Retry the upload
   - Check file size (very large files may timeout)

**Solution:**
```bash
# Ensure files exist
ls -lh ~/Desktop/APP-1.0.9.dmg ~/Desktop/APP-1.0.9-Export/APP.app.zip

# Re-authenticate if needed
gh auth login

# Upload with explicit paths
gh release upload v1.0.9 \
  ~/Desktop/APP-1.0.9.dmg \
  ~/Desktop/APP-1.0.9-Export/APP.app.zip \
  --clobber
```

## Testing Issues

### Downloaded App Shows Wrong Version

**Symptom:** After downloading DMG from GitHub, installed app shows wrong version.

**Cause:** Cached app or DMG wasn't updated.

**Solution:**

1. **Remove all existing installations:**
   ```bash
   rm -rf /Applications/APP.app
   rm -rf ~/Library/Preferences/BUNDLE_ID.plist
   rm -rf ~/Library/Caches/BUNDLE_ID
   ```

2. **Download fresh DMG from GitHub**

3. **Verify DMG version before installing:**
   ```bash
   hdiutil attach APP.dmg -readonly -nobrowse -mountpoint /tmp/test
   defaults read /tmp/test/APP.app/Contents/Info.plist CFBundleShortVersionString
   hdiutil detach /tmp/test
   ```

4. **Install and verify:**
   ```bash
   cp -R /tmp/test/APP.app /Applications/
   defaults read /Applications/APP.app/Contents/Info.plist CFBundleShortVersionString
   ```

## Quick Diagnostic Commands

**Check version in built app:**
```bash
defaults read ~/Desktop/APP-Export/APP.app/Contents/Info.plist CFBundleShortVersionString
```

**Check code signing:**
```bash
codesign -dvvv ~/Desktop/APP-Export/APP.app 2>&1 | grep -E "Authority|TeamIdentifier"
```

**Check notarization:**
```bash
spctl -a -vvv ~/Desktop/APP-Export/APP.app
```

**Verify DMG contents:**
```bash
hdiutil attach APP.dmg -readonly -nobrowse -mountpoint /tmp/check && \
ls -la /tmp/check && \
hdiutil detach /tmp/check
```

**Check Sparkle framework signing:**
```bash
codesign -dvvv ~/Desktop/APP-Export/APP.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
```

**Verify appcast.xml accessible:**
```bash
curl -I https://raw.githubusercontent.com/USER/REPO/main/appcast.xml
```

**Test XML syntax:**
```bash
xmllint --noout appcast.xml
```

## Getting Help

If you're still stuck:

1. **Collect diagnostic information:**
   - Version of Xcode
   - macOS version
   - Output of diagnostic commands above
   - Notarization logs (if applicable)

2. **Check Sparkle documentation:**
   - https://sparkle-project.org/documentation/

3. **Review Apple notarization docs:**
   - https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

4. **Common issue trackers:**
   - Sparkle issues: https://github.com/sparkle-project/Sparkle/issues
   - Xcode signing issues: https://developer.apple.com/forums/
