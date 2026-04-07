# BonkBook — Build & Release Guide

## Prerequisites

- Xcode (with your Apple ID signed in)
- `xcodegen` — `brew install xcodegen`
- **Developer ID Application** certificate in your keychain
- Notarytool credentials stored in keychain (one-time setup)

### One-time notarytool setup
```bash
xcrun notarytool store-credentials "BonkBook" \
  --apple-id "reach.out.nauman@gmail.com" \
  --team-id "92X99MPMUT" \
  --password "ldjz-aryc-kqms-efpx"
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

**Step 1 — Make and test your changes in Xcode**
- Edit Swift files, press Cmd+R to run and test
- When happy, move to Step 2

**Step 2 — Bump the version in `BonkBook/Info.plist`**
- `CFBundleShortVersionString` → user-facing version e.g. `1.1`
- `CFBundleVersion` → build number e.g. `2`

**Step 3 — Build the DMG**
```bash
bash Scripts/build-dmg.sh
```

**Step 4 — Notarize**
```bash
xcrun notarytool submit build/BonkBook.dmg --keychain-profile "BonkBook" --wait
```
Wait for `status: Accepted`. If rejected, check what went wrong:
```bash
xcrun notarytool log <submission-id> --keychain-profile "BonkBook"
```

**Step 5 — Staple**
```bash
xcrun stapler staple build/BonkBook.dmg
```

**Step 6 — Upload `build/BonkBook.dmg` to Gumroad / your website**

That's it.

---

## Development vs Production

| | Xcode (Cmd+R) | DMG install (/Applications) |
|---|---|---|
| Use for | Testing changes | Shipping to users |
| spank path | DerivedData/... | /Applications/BonkBook.app/Contents/MacOS/spank |
| Sudoers rule | Must re-run Grant Permission each time you clean build | Set once on first launch, persists |
| Sound changes | Rebuild + Cmd+R | Rebuild DMG + reinstall |

**Important:** If you have the DMG version installed and switch to Xcode testing, delete the sudoers file first so Grant Permission rewrites it with the correct DerivedData path:
```bash
sudo rm /etc/sudoers.d/bonkbook
```
Then relaunch from Xcode and click Grant Permission. Reverse this when going back to the DMG version.

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
