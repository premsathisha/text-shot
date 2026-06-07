# Text Shot

Text Shot is a lightweight macOS screenshot-to-text utility that lets you capture any screen region and instantly extract text using on-device OCR. It runs entirely on-device for OCR and is built for speed, simplicity, and keyboard-driven workflows. It requires macOS Screen Recording permission to capture selected regions, collects no data, and needs no account.

## Screenshot

![Text Shot screenshot](assets/screenshot.png)

## Who This Is For

- Keyboard-first macOS users
- People who extract text from videos, images, or on-screen content
- Users who prefer local-first utilities

## Key Features

- Fully local OCR processing
- Smart line formatting
- Lightweight native macOS experience
- No login or account required
- Optional native app updates in signed release builds
- Fast capture-to-text workflow

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`swift`, `codesign`, `hdiutil`, `install_name_tool`, `otool`)
- Node.js and npm

## Install / Quick Start

Download the DMG from Releases, open it, and move Text Shot into your Applications folder. Launch the app, grant Screen Recording permission, set your preferred shortcut, and start capturing text.

## Usage

1. Use your keyboard shortcut to start a quick screen selection.
2. Select the area that contains the text you want.
3. Text Shot extracts the text and copies it to your clipboard.
4. Paste the result anywhere immediately.

Default shortcut:

```text
Cmd + Shift + 2
```

## How It Works

1. Text Shot captures the selected screen region.
2. It runs on-device Vision OCR and reconstructs the layout with line grouping.
3. It places the result on your clipboard without uploading screenshot content to an external OCR service.

## FAQ

### Why does Text Shot need Screen Recording permission?

Text Shot needs Screen Recording permission so it can capture the selected region on your Mac.

### Does Text Shot upload screenshots anywhere?

No. OCR runs on the Mac itself, and screenshot content is not uploaded for recognition.

## Privacy

Text Shot is designed to stay local.

- OCR runs on the Mac itself
- Screenshot content is not uploaded for recognition
- The app does not require an account or login
- Screen Recording permission is needed only so the app can capture the selected region

## Development

For developers who want to build Text Shot locally:

```bash
npm install
npm run build
npm start
npm test
```

To create a distributable DMG:

```bash
bash scripts/release-native.sh --set-version <x.y.z>
```

Make sure the Sparkle signing key is available either in the login Keychain or via `SPARKLE_PRIVATE_ED_KEY` before publishing `dist-appcast/`.

Typecheck:

```bash
npm run typecheck
```

Clean:

```bash
npm run clean
```

See [docs/TESTING.md](docs/TESTING.md) for the full manual regression checklist.

Generated build and release outputs live under `.generated/`, `dist-appcast/`, and `release/`.

## Troubleshooting

- If Screen Recording permission is missing, open `System Settings > Privacy & Security > Screen Recording`, enable Text Shot, and fully quit and relaunch the app.
- If capture still fails after permission is granted, remove the permission entry and grant it again when macOS prompts.
- If the hotkey does not open the capture overlay, confirm the shortcut shown in `Settings...`, re-record it if needed, then relaunch the app.
- If the settings window does not appear, open `Settings...` from the menu bar item and relaunch from `/Applications` or the freshly built app bundle.

## Architecture

Text Shot is a native Swift menu bar app.

- `native/settings-app` - main app runtime, including menu bar item, hotkey handling, capture flow, OCR, permissions, settings UI, confirmation toast, and Sparkle update integration
- `scripts` - build, test, typecheck, clean, and release helper scripts for the SwiftPM native app bundle
- `build` - entitlements and export configuration for packaging and signing
- `assets` - app icon and tray assets

## Contributing

Contributions are welcome.

1. Keep commits focused and descriptive.
2. Run `npm run typecheck` and `npm test` before opening a pull request.
3. If the change affects packaging or user-facing behavior, also run the relevant manual checks in `docs/TESTING.md`.
4. Every DMG release must bump the version, keep `package.json` aligned, and leave only the latest DMG and checksum in `release/`.

## Credits

- Uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for global hotkey recording
- Uses [Sparkle](https://sparkle-project.org/) for native macOS updates
- See [ThirdPartyNotices.txt](ThirdPartyNotices.txt) for bundled third-party notices

## License

MIT License. See [LICENSE](LICENSE) for full text.
