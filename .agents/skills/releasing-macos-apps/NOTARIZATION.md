# Notarization Guide

Comprehensive guide to Apple notarization for macOS apps.

## What is Notarization?

Notarization is Apple's automated scanning process that checks your app for malicious content and code-signing issues. Once notarized, macOS Gatekeeper allows the app to run without showing security warnings.

**Without notarization:** Users see "malicious software" warnings
**With notarization:** App opens normally without warnings

## Prerequisites

### 1. Apple ID Credentials

You need three pieces of information:

1. **Apple ID email** - Your developer account email
2. **Team ID** - Found at https://developer.apple.com/account (Membership → Team ID)
3. **App-specific password** - Generate at appleid.apple.com

### 2. Generate App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Navigate to "Sign-In and Security"
4. Click "App-Specific Passwords"
5. Click "Generate an app-specific password"
6. Name it (e.g., "Notarization Tool")
7. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

**Important:** Save this password securely. You won't be able to see it again.

### 3. Store Credentials (Optional)

You can store credentials in your keychain for repeated use:

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Then use the profile for future submissions:
```bash
xcrun notarytool submit APP.dmg --keychain-profile "notarytool-profile" --wait
```

### Alternative: App Store Connect API Key

For CI/CD or when you prefer API keys over app-specific passwords:

1. **Generate API Key:**
   - Go to https://appstoreconnect.apple.com/access/api
   - Create a new key with "Developer" role
   - Download the `.p8` file (only available once)
   - Note the Key ID and Issuer ID

2. **Store the key:**
   ```bash
   mkdir -p ~/private_keys
   mv AuthKey_KEYID.p8 ~/private_keys/
   ```

3. **Submit using API key:**
   ```bash
   xcrun notarytool submit APP.dmg \
     --key ~/private_keys/AuthKey_KEYID.p8 \
     --key-id YOUR_KEY_ID \
     --issuer YOUR_ISSUER_ID \
     --wait
   ```

**Advantages of API keys:**
- No password expiration
- Better for automation/CI
- More granular access control

## Notarization Workflow

### Step 1: Submit for Notarization

Submit your DMG or app for notarization:

```bash
xcrun notarytool submit ~/Desktop/APP-VERSION.dmg \
  --apple-id your-email@example.com \
  --team-id YOUR_TEAM_ID \
  --password xxxx-xxxx-xxxx-xxxx \
  --wait
```

**Flags:**
- `--wait`: Wait for processing to complete (recommended)
- Without `--wait`: Returns immediately with submission ID

**Expected output:**
```
Conducting pre-submission checks for APP.dmg...
Submission ID received
  id: 12345678-1234-1234-1234-123456789abc
Successfully uploaded file
Waiting for processing to complete.
Current status: In Progress......
Processing complete
  id: 12345678-1234-1234-1234-123456789abc
  status: Accepted
```

**Processing time:** Usually 1-3 minutes

### Step 2: Check Submission Status

If you didn't use `--wait`, check status manually:

```bash
xcrun notarytool info SUBMISSION_ID \
  --apple-id your-email@example.com \
  --team-id YOUR_TEAM_ID \
  --password xxxx-xxxx-xxxx-xxxx
```

### Step 3: View Notarization Log

If notarization fails (status: "Invalid"), get detailed logs:

```bash
xcrun notarytool log SUBMISSION_ID \
  --apple-id your-email@example.com \
  --team-id YOUR_TEAM_ID \
  --password xxxx-xxxx-xxxx-xxxx
```

Logs are returned as JSON with specific error details.

### Step 4: Staple Notarization Ticket

Once accepted, staple the ticket to your DMG:

```bash
xcrun stapler staple ~/Desktop/APP-VERSION.dmg
```

**Output:**
```
Processing: /Users/you/Desktop/APP-VERSION.dmg
The staple and validate action worked!
```

**What stapling does:**
- Attaches the notarization ticket to the DMG
- Allows the app to be verified offline
- Required for distribution outside the App Store

## Verifying Notarization

### Check Notarization Status

```bash
spctl -a -vvv /path/to/APP.app
```

**Notarized app output:**
```
/path/to/APP.app: accepted
source=Notarized Developer ID
origin=Developer ID Application: Your Name (TEAM_ID)
```

**Non-notarized app output:**
```
/path/to/APP.app: rejected
source=Unnotarized Developer ID
```

### Check Code Signing

```bash
codesign -dvvv /path/to/APP.app
```

Look for:
- `Authority=Developer ID Application: Your Name (TEAM_ID)`
- `Signature size=` (should be present)
- `TeamIdentifier=YOUR_TEAM_ID`

### Check Stapled Ticket

```bash
stapler validate /path/to/APP.dmg
```

**Output if stapled:**
```
Processing: /path/to/APP.dmg
The validate action worked!
```

## Common Notarization Errors

### Error: Invalid Credentials (HTTP 401)

**Symptom:**
```
Error: HTTP status code: 401. Invalid credentials.
```

**Causes:**
1. Wrong Apple ID email
2. Expired or incorrect app-specific password
3. Wrong team ID

**Solution:**
- Verify Apple ID email is correct
- Generate a new app-specific password
- Confirm team ID at https://developer.apple.com/account

### Error: Archive Contains Critical Validation Errors

**Symptom:**
```
status: Invalid
statusSummary: Archive contains critical validation errors
```

**Common causes:**
1. **Unsigned frameworks**: Embedded frameworks not properly signed
2. **Missing timestamps**: Signatures don't include secure timestamps
3. **Wrong certificate**: Not signed with "Developer ID Application"

**Solution:**
Use proper export with `xcodebuild -exportArchive` instead of copying from archive:

```bash
xcodebuild -exportArchive \
  -archivePath ~/Desktop/APP.xcarchive \
  -exportPath ~/Desktop/APP-Export \
  -exportOptionsPlist ExportOptions.plist
```

This ensures all embedded frameworks (like Sparkle) are properly signed.

### Error: Binary Not Signed with Valid Developer ID

**Symptom in logs:**
```json
{
  "severity": "error",
  "message": "The binary is not signed with a valid Developer ID certificate."
}
```

**Solution:**
1. Verify certificate is installed:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

2. Re-export the app with proper signing options

### Error: Signature Does Not Include Secure Timestamp

**Symptom in logs:**
```json
{
  "severity": "error",
  "message": "The signature does not include a secure timestamp."
}
```

**Solution:**
Xcode automatically includes timestamps when using `xcodebuild -exportArchive`. If you see this error, you likely manually copied files from the archive. Use the proper export process.

## Notarization History

View all your notarization submissions:

```bash
xcrun notarytool history \
  --apple-id your-email@example.com \
  --team-id YOUR_TEAM_ID \
  --password xxxx-xxxx-xxxx-xxxx
```

## Notarizing Without Internet (Offline Verification)

Stapling the ticket allows Gatekeeper to verify your app offline:

1. **With stapled ticket:** App runs immediately, no internet needed
2. **Without stapled ticket:** Gatekeeper checks online (slower, requires internet)

Always staple before distribution.

## Best Practices

1. **Automate credential storage:** Use `notarytool store-credentials` to avoid typing credentials repeatedly
2. **Always use `--wait`:** Easier to track progress than checking status manually
3. **Keep logs:** Save notarization logs for debugging future issues
4. **Test before distributing:** Download from GitHub and test on a clean machine
5. **Staple immediately:** Don't forget to staple after successful notarization

## Security Notes

**App-specific password:**
- Use a unique password for notarization
- Don't share or commit passwords to git
- Rotate periodically for security
- This Skill prompts for it - never hardcode

**Notarization is public:**
- Notarization tickets are publicly verifiable
- EdDSA signatures in appcast.xml are public (safe to commit)
- Only the private key must be kept secret

## Quick Reference

**Submit:**
```bash
xcrun notarytool submit FILE --apple-id EMAIL --team-id TEAM --password PASS --wait
```

**Check status:**
```bash
xcrun notarytool info SUBMISSION_ID --apple-id EMAIL --team-id TEAM --password PASS
```

**Get logs:**
```bash
xcrun notarytool log SUBMISSION_ID --apple-id EMAIL --team-id TEAM --password PASS
```

**Staple:**
```bash
xcrun stapler staple FILE
```

**Verify:**
```bash
spctl -a -vvv APP.app
```
