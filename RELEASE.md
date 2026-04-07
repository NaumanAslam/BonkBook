# BonkBook — Build & Release Guide

## Prerequisites

- Xcode (with your Apple ID signed in)
- `xcodegen` — `brew install xcodegen`
- **Developer ID Application** certificate in your keychain
- Notarytool credentials stored in keychain (one-time setup)

### One-time notarytool setup
```bash
xcrun notarytool store-credentials "BonkBook" \
  --apple-id "your@email.com" \
  --team-id "92X99MPMUT" \
  --password "xxxx-xxxx-xxxx-xxxx"
```
Use an app-specific password from appleid.apple.com (not your Apple ID password).

---

## Project Structure

```
BonkBook/
├── BonkBook/               ← SwiftUI menu bar app source
│   ├── spank               ← Go binary (bundled, DO NOT compile — copy from spank project)
│   ├── BonkBook.entitlements
│   ├── Sounds/
│   │   ├── Custom/         ← pain / sexy / halo sound packs (m4a)
│   │   └── Lid/            ← lid-open.m4a, lid-close.m4a (optional, falls back to system sounds)
│   └── ...
├── Scripts/
│   └── build-dmg.sh        ← Full build + sign + DMG script
├── project.yml             ← XcodeGen project definition
└── build/                  ← Output folder (gitignore this)
    └── BonkBook.dmg
```

---

## Architecture

Two-component model:

| Component | Runs as | Responsibility |
|-----------|---------|----------------|
| `BonkBook.app` | Normal user | Menu bar UI, sound playback, lid sound detection |
| `spank` (bundled binary) | root (via sudo) | Accelerometer reading, slap detection, JSON output over stdio |

The app spawns `sudo spank --stdio` as a child process and reads JSON slap events from its stdout. The sudoers rule at `/etc/sudoers.d/bonkbook` allows passwordless sudo for the bundled spank binary.

---

## Shipping a New Version

### 1. Make code changes

Edit Swift source files in `BonkBook/`. If you change the UI or logic, test with Cmd+R in Xcode first.

### 2. Update the spank binary (if needed)

If the Go `spank` project was updated:
```bash
# Build spank (must use original binary — rebuilding breaks macOS signing)
# Only update if the original binary from the spank project works
cp /Users/naumanaslam/Downloads/XcodeProjects/spank/spank BonkBook/spank
```

### 3. Bump the version

In `BonkBook/Info.plist`, update:
- `CFBundleShortVersionString` — user-facing version (e.g. `1.1`)
- `CFBundleVersion` — build number (e.g. `2`)

### 4. Regenerate Xcode project (if project.yml changed)

```bash
xcodegen generate
```

### 5. Build, sign, and package

```bash
bash Scripts/build-dmg.sh
```

This will:
- Build Release with Developer ID Application signing
- Inject and sign the spank binary
- Re-sign the app bundle with timestamp
- Create `build/BonkBook.dmg`

### 6. Notarize

```bash
xcrun notarytool submit build/BonkBook.dmg --keychain-profile "BonkBook" --wait
```

Takes 1–5 minutes. Look for `status: Accepted`.

If rejected, check the log:
```bash
xcrun notarytool log <submission-id> --keychain-profile "BonkBook"
```

### 7. Staple

```bash
xcrun stapler staple build/BonkBook.dmg
```

### 8. Verify

```bash
xcrun stapler validate build/BonkBook.dmg
# Should print: The validate action worked!
```

### 9. Upload to Gumroad / website

Upload `build/BonkBook.dmg`. Done.

---

## Development Setup (fresh machine)

```bash
# Clone repo
git clone <repo-url>
cd BonkBook

# Install xcodegen
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open BonkBook.xcodeproj

# For local testing — set up sudoers for bundled spank
# Launch the app, click "Grant Permission" when prompted
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| Click Start → immediately goes back to Start | Sudoers rule path mismatch. Delete `/etc/sudoers.d/bonkbook`, relaunch app, click Grant Permission |
| `zsh: killed` when running spank | macOS blocked the binary. Run `sudo xattr -cr /usr/local/bin/spank` or use the original binary from the spank project |
| Notarization rejected — invalid signature | Run `build-dmg.sh` again — do not manually codesign separately |
| Notarization rejected — no Developer ID | Create Developer ID Application cert in Xcode → Settings → Accounts → Manage Certificates |
| spank plays double audio | The `--no-audio` flag doesn't exist in the bundled binary version. Spank handles audio only |

---

## Future Features (Backlog)

- [ ] Lid angle sounds (requires IOKit SMC reading — needs root, extend spank)
- [ ] Custom sound pack support (convert m4a → mp3 for spank, or re-enable Swift audio with `--no-audio` flag in a rebuilt spank)
- [ ] Auto-update mechanism (Sparkle framework)
- [ ] Launch at login toggle in UI
- [ ] Monetization — Paddle/Gumroad paywall for extra sound packs
