# Text Shot

Text Shot is a lightweight macOS screenshot-to-text utility that lets you capture any screen region and instantly extract text using on-device OCR. It runs entirely on-device for OCR and is built for speed, simplicity, and keyboard-driven workflows. It requires macOS Screen Recording permission to capture selected regions, collects no data, and needs no account.

## Screenshot

![Text Shot screenshot](assets/screenshot.png)

## Key Features

- Fully local OCR processing
- Smart Line Formatting
- Lightweight (~2 MB)
- Native macOS experience
- No login or accounts
- Optional native app updates in signed release builds
- Fast capture-to-text workflow
  
## Who It Is For

- Keyboard-first macOS users
- Users who extract text from videos, images, or on-screen content
- Users who prefer local-first utilities

## How It Works

Use your keyboard shortcut to start a quick screen selection. Text Shot reads the text inside that selected area, reconstructs the layout with OCR line grouping, and places the result on your clipboard. You can then paste it anywhere immediately, without uploading screenshot content to an external OCR service.

## Installation

Download the DMG from the Releases section, open it, and move Text Shot into your Applications folder. Launch the app, grant the required permissions, set your preferred shortcut (default: Cmd + Shift + 2), and start capturing text.

## Updates

Text Shot 3.0.0 is the first Sparkle-enabled release line. Builds embed the production Sparkle feed URL and public EdDSA key so the in-app update controls stay wired to the live feed, while local release packaging can stay unsigned.

To cut a local Sparkle release:

1. Keep the Sparkle private EdDSA key available to `generate_appcast` via Keychain or `SPARKLE_PRIVATE_ED_KEY`.
2. Point `SPARKLE_BIN_DIR` at the official Sparkle `bin/` directory.
3. Run `bash scripts/release-native.sh --set-version <x.y.z>`.

By default, Sparkle publish artifacts land in `dist-appcast/` for publishing. `release/` remains reserved for the latest DMG and checksum.

## Built from Source

For developers who want to build Text Shot locally.

### Prerequisites

- macOS 13 or later
- Xcode Command Line Tools (`swift`, `codesign`, `hdiutil`, `install_name_tool`, `otool`)
- Node.js and npm

### Steps

1. Clone the repository.
2. Install dependencies with `npm install`.
3. Build the app with `npm run build`.
4. Launch the built app with `npm start`.
5. Run tests with `npm test`.
6. Create a distributable DMG with `bash scripts/release-native.sh --set-version <x.y.z>`.

### Release Outputs

- `.generated/app/`: hidden local app bundle output for `npm run build`
- `dist-appcast/`: Sparkle `appcast.xml` and update archive output for publishing
- `release/`: latest DMG and `.sha256` only
- `TESTING.md`: manual regression checklist for capture, permissions, menu bar behavior, multi-display, and OCR samples

## Architecture

Text Shot is a native Swift menu bar app.

- `native/settings-app`: Main app runtime (menu bar item, hotkey handling, capture flow, OCR, permissions, settings UI, confirmation toast, and Sparkle update integration)
- `scripts`: Build, test, typecheck, clean, and release helper scripts for the SwiftPM native app bundle
- `build`: Entitlements and export configuration for packaging/signing
- `assets`: App icon and tray assets

## Agent-Assisted Development

Text Shot was built while exploring agent-assisted software development, with a GPT-5.3-Codex model. The application logic and implementation were generated through iterative prompting and system-level direction by the author, then tested in real-world usage and reviewed at a system level before release. The author assumes full responsibility for the distributed software.

This project bundles KeyboardShortcuts:
https://github.com/sindresorhus/KeyboardShortcuts
Licensed under the MIT License.

This project also integrates Sparkle for native macOS updates:
https://sparkle-project.org/
Licensed under the MIT License.

## Why I Built This

Text Shot began as a tool to eliminate repeated manual text extraction in my daily workflow while evaluating modern coding agents and frontier development tooling. The project reflects a practical exploration of agent-assisted software development alongside an understanding that strong engineering judgment and validation remain essential.

## License

MIT
