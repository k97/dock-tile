# Sparkle Auto-Update System

Complete guide to Sparkle framework for automatic app updates.

## What is Sparkle?

Sparkle is an open-source framework that provides automatic updates for macOS applications. When you release a new version, users receive update notifications automatically.

**Key components:**
1. **Sparkle framework** - Embedded in your app
2. **appcast.xml** - Feed file listing available updates
3. **EdDSA key pair** - Cryptographic keys for signing updates

## EdDSA Signature System

### Public vs Private Keys

Sparkle uses EdDSA (Edwards-curve Digital Signature Algorithm) for secure updates:

**Private key:**
- Used to sign update files
- Keep secret - never commit to git
- Format: Base64 string (e.g., `mVCqrPX7Du+orVUEFiUSBT1wwEaORKsxWPLuORZpJio=`)
- Required for generating signatures

**Public key:**
- Embedded in app's Info.plist
- Safe to commit and distribute
- Format: Base64 string (e.g., `2jM5WXnwTjUxuIzdlnVIXdZtiA57cVL+gV3bef1a0mA=`)
- Used by Sparkle to verify updates

**Security model:**
- Private key signs updates → Public key verifies signatures
- Users can't install malicious updates without the private key
- Public key in Info.plist ensures only signed updates are accepted

### Generating Key Pairs

Generate a new EdDSA key pair (first time setup):

```bash
# Find Sparkle's generate_keys tool
find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f

# Generate keys
/path/to/generate_keys
```

**Output:**
```
A key has been generated and saved in your Keychain.
Please back it up securely.

Public key: 2jM5WXnwTjUxuIzdlnVIXdZtiA57cVL+gV3bef1a0mA=
Private key: mVCqrPX7Du+orVUEFiUSBT1wwEaORKsxWPLuORZpJio=
```

**Important:**
- Save the private key securely (password manager, encrypted file)
- Add public key to Info.plist under `SUPublicEDKey`
- Never commit private key to git

### Private Key Storage Options

**Option 1: File in project (gitignored)**
```bash
# Store in project root
echo "YOUR_PRIVATE_KEY" > .sparkle_private_key
echo ".sparkle_private_key" >> .gitignore

# Use with sign_update
cat .sparkle_private_key | sign_update APP.zip --ed-key-file -
```

**Option 2: macOS Keychain**
```bash
# Store in keychain
security add-generic-password \
  -a "$USER" \
  -s "com.yourapp.sparkle.private-key" \
  -w "YOUR_PRIVATE_KEY"

# Retrieve and use
security find-generic-password -s "com.yourapp.sparkle.private-key" -w | \
  sign_update APP.zip --ed-key-file -
```

**Option 3: Environment variable**
```bash
export SPARKLE_PRIVATE_KEY="YOUR_PRIVATE_KEY"
echo "$SPARKLE_PRIVATE_KEY" | sign_update APP.zip --ed-key-file -
```

## Signing Updates

### Finding sign_update Tool

Locate Sparkle's signing tool:

```bash
find ~/Library/Developer/Xcode/DerivedData -name sign_update -type f
```

Example path:
```
~/Library/Developer/Xcode/DerivedData/PROJECT-HASH/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
```

### Generating Signatures

Sign your zip file with the private key:

```bash
echo "YOUR_PRIVATE_KEY" | \
  /path/to/sign_update APP.app.zip --ed-key-file -
```

**Output:**
```
sparkle:edSignature="UKjPGogXtlsMybYCy7PGObvTihBs6CiZ6lWMdsZN67aWC138+VL9zdq2ZD0Pd3gxfXZIDW3pDVa9ZiiXGsKnCA==" length="9058964"
```

**Important notes:**
- `--ed-key-file -` reads private key from stdin (more secure than file)
- Each build produces a different signature (even same code)
- Signature is tied to the specific binary, not version number

## Why Signatures Change Between Builds

You'll notice the EdDSA signature changes even for identical versions. This is expected behavior:

**Reasons signatures differ:**
1. **Build timestamps:** Xcode includes timestamps in binaries
2. **Code signing timestamps:** Each signing includes current time
3. **UUID changes:** Each build gets unique identifier
4. **Checksum differences:** Any binary difference changes signature

**What this means:**
- Always regenerate signature after rebuilding
- Old signatures won't work with new builds
- Update appcast.xml with new signature for each release

**Example:** Building version 1.0.9 three times produces three different signatures:
```
Build 1: UKjPGogXtlsMybYCy7PGObvTihBs6CiZ6lWMdsZN67aWC138+VL9zdq2ZD0Pd3gxfXZIDW3pDVa9ZiiXGsKnCA==
Build 2: OcojrC1GHEnJootmqla79vSzOtdOtR2LBxuYWn9fvXJb/t2JaVoevBS9WYxbBF12vjLGxB9Wd1ARz2yKvut0Dg==
Build 3: e1JkBsxJY+42z0M3Eo9XQ0ywzHCR6uqLL9oR2FtwT0L5KyBq5rvm9lDH2HSkCH2zPn5+bvBPgzfddrqtMVYNCg==
```

All are valid - just use the signature from the final build you're releasing.

## appcast.xml Format

The appcast.xml file tells Sparkle about available updates.

### Basic Structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Your App Name</title>
    <link>https://github.com/user/repo</link>
    <description>App update feed</description>
    <language>en</language>

    <item>
      <title>Version 1.0.9</title>
      <link>https://github.com/user/repo</link>
      <sparkle:version>1.0.9</sparkle:version>
      <sparkle:channel>stable</sparkle:channel>
      <description><![CDATA[
        Release version 1.0.9
      ]]></description>
      <pubDate>Sat, 26 Oct 2025 22:59:00 -0700</pubDate>
      <enclosure
        url="https://github.com/user/repo/releases/download/v1.0.9/App.app.zip"
        sparkle:version="1.0.9"
        sparkle:edSignature="UKjPGogXtlsMybYCy7PGObvTihBs6CiZ6lWMdsZN67aWC138+VL9zdq2ZD0Pd3gxfXZIDW3pDVa9ZiiXGsKnCA=="
        length="9058964"
        type="application/octet-stream" />
    </item>

  </channel>
</rss>
```

### Key Fields

**`<sparkle:version>`:**
- Version number (e.g., "1.0.9")
- Must match CFBundleShortVersionString in app
- Sparkle uses this for version comparison

**`<sparkle:edSignature>`:**
- EdDSA signature from sign_update
- Validates the update file
- Changes with each build

**`length`:**
- File size in bytes
- From sign_update output
- Used for download progress

**`url`:**
- Direct download URL for the zip file
- Must be publicly accessible
- Typically GitHub releases

**`<pubDate>`:**
- RFC 822 format: "Day, DD Mon YYYY HH:MM:SS TZ"
- Example: "Sat, 26 Oct 2025 22:59:00 -0700"

### Multiple Versions

Keep multiple versions in appcast.xml (newest first):

```xml
<channel>
  <title>Your App</title>

  <!-- Latest version -->
  <item>
    <title>Version 1.0.9</title>
    <sparkle:version>1.0.9</sparkle:version>
    <!-- ... -->
  </item>

  <!-- Previous version -->
  <item>
    <title>Version 1.0.8</title>
    <sparkle:version>1.0.8</sparkle:version>
    <!-- ... -->
  </item>

</channel>
```

Sparkle automatically finds the newest version based on `<sparkle:version>`.

## Update Channels

Use channels for different release tracks:

```xml
<sparkle:channel>stable</sparkle:channel>  <!-- Production users -->
<sparkle:channel>beta</sparkle:channel>    <!-- Beta testers -->
```

Users on beta channel receive beta updates; stable users only get stable releases.

## Info.plist Configuration

Your app's Info.plist needs Sparkle configuration:

```xml
<dict>
  <key>SUFeedURL</key>
  <string>https://raw.githubusercontent.com/user/repo/main/appcast.xml</string>

  <key>SUPublicEDKey</key>
  <string>2jM5WXnwTjUxuIzdlnVIXdZtiA57cVL+gV3bef1a0mA=</string>
</dict>
```

**`SUFeedURL`:**
- URL to your appcast.xml
- Can be GitHub raw URL, your website, etc.
- Must be publicly accessible

**`SUPublicEDKey`:**
- Your EdDSA public key
- Used to verify update signatures
- Safe to commit

## Testing Updates

### Test Locally

1. **Lower app version:**
   - Edit .xcconfig to older version (e.g., 1.0.8)
   - Build and install locally

2. **Update appcast.xml:**
   - Point to newer version (e.g., 1.0.9)
   - Deploy appcast.xml

3. **Launch app:**
   - Sparkle checks for updates on launch
   - Should show update notification

### Force Update Check

Most apps have "Check for Updates..." in menu. Alternatively, trigger programmatically:

```swift
import Sparkle

// Force immediate check
SPUStandardUpdaterController.shared.updater.checkForUpdates()
```

### Common Test Issues

**Update not detected:**
- Verify appcast.xml is accessible at SUFeedURL
- Check version comparison (must be higher than current)
- Look for XML syntax errors

**Signature verification fails:**
- Wrong public key in Info.plist
- Signature doesn't match zip file
- Zip file modified after signing

## Security Best Practices

1. **Private key storage:**
   - Store in password manager
   - Use environment variables for automation
   - Never commit to git
   - Rotate if compromised

2. **Signature verification:**
   - Always sign releases before distribution
   - Test signature verification locally
   - Monitor for signature errors in logs

3. **HTTPS for appcast:**
   - Use HTTPS for SUFeedURL
   - Prevents man-in-the-middle attacks
   - GitHub raw URLs are HTTPS by default

4. **Backup keys:**
   - Keep secure backup of private key
   - If lost, must generate new keys and update all apps
   - Users on old versions can't verify updates with old public key

## Sparkle Version Compatibility

Different Sparkle versions have different signature formats:

**Sparkle 2.x (current):**
- Uses EdDSA signatures
- More secure than older formats
- Required for notarized apps

**Sparkle 1.x (legacy):**
- Uses DSA signatures
- Not recommended for new apps

This guide assumes Sparkle 2.x. Check your version:

```bash
grep -r "Sparkle" ~/Library/Developer/Xcode/DerivedData/*/SourcePackages/checkouts/*/Package.swift
```

## Troubleshooting

### "Update is available but cannot be installed"

**Cause:** Signature verification failed

**Solutions:**
1. Verify public key matches private key
2. Regenerate signature and update appcast.xml
3. Check zip file wasn't modified after signing

### "No update available" but newer version exists

**Cause:** Version comparison issue

**Solutions:**
1. Verify appcast.xml is accessible
2. Check `<sparkle:version>` is higher than current
3. Test version string format (avoid letters if using numeric comparison)

### Git pre-commit hooks flag signature

**Symptom:**
```
❌ COMMIT BLOCKED: Secrets detected!
```

**Cause:** Gitleaks detects EdDSA signature as base64-encoded secret

**Solution:** EdDSA signatures in appcast.xml are public and safe to commit. Use:
```bash
git commit --no-verify
```

Or add to `.gitleaks.toml`:
```toml
[[rules]]
id = "sparkle-signature"
description = "Sparkle EdDSA signatures are public"
path = "appcast.xml"
```

## Quick Reference

**Generate keys:**
```bash
/path/to/generate_keys
```

**Sign update:**
```bash
echo "PRIVATE_KEY" | /path/to/sign_update APP.zip --ed-key-file -
```

**Output format:**
```
sparkle:edSignature="SIGNATURE" length="SIZE"
```

**Info.plist keys:**
- `SUFeedURL` - appcast.xml URL
- `SUPublicEDKey` - Public key for verification

**appcast.xml location:**
- Must be publicly accessible
- Common: GitHub raw URL or project website
- Updated with each release
