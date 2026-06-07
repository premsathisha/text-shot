# Repo Map
Last Updated: 2026-06-04

## Use This Map First
This file is the canonical repository map for coding agents. Read it before broad scanning or indexing, then freely inspect any files needed to understand the task, verify the map, or investigate missing context.

## Project Summary
- Text Shot is a native Swift macOS menu bar app for region OCR.
- It captures a selected screen area, runs on-device Vision OCR, copies text to the clipboard, and keeps the app lightweight and keyboard-driven.
- The repo also includes a static marketing site, GitHub Actions CI, and Sparkle-based release plumbing.

## Tech Stack
- Swift 5.9 and SwiftPM
- macOS 13+
- AppKit, SwiftUI, Vision, CoreGraphics, ServiceManagement, Carbon
- KeyboardShortcuts vendored package
- Sparkle for update checks
- Bash build and release scripts
- Static HTML/CSS/JS site with GitHub Pages deployment
- GitHub Actions CI

## Entry Points
| Entry point | What it starts |
|---|---|
| `native/settings-app/Sources/TextShotSettings/AppEntry.swift` | `@main` app entry, `AppDelegate`, status menu, and Settings scene. |
| `native/settings-app/Package.swift` | SwiftPM package entry for the native app and tests. |
| `package.json` | Command entry: `npm run build` -> `bash scripts/build-settings-app.sh`; `npm start` -> `open "./.generated/app/Text Shot.app"`; `npm test` -> `bash scripts/test-native.sh`; `npm run typecheck` -> `bash scripts/typecheck-native.sh`; `npm run clean` -> `bash scripts/clean-generated.sh`; `npm run release:native` and `npm run dist` -> `bash scripts/release-native.sh`; `npm run release:native:minor` -> `bash scripts/release-native.sh --bump-minor`. |
| `README.md` | Documented source workflow: `npm install`, `npm run build`, `npm start`, `npm test`, `bash scripts/release-native.sh --set-version <x.y.z>`. |
| `.github/workflows/ci.yml` | CI entry point on `macos-15` with `npm ci`, `npm run typecheck`, and `npm test`. |
| `.github/workflows/pages.yml` | GitHub Pages publish entry point for the site and Sparkle feed. |
| `site/index.html` | Static homepage entry. |

## Folder Map
### `.`
Purpose: repo-level docs, package metadata, licenses, and root ignore rules.
Edit here when:
- versioning changes
- release policy changes
- root docs change
- top-level ignore rules change
Important files:
- `AGENTS.md`
- `package.json`
- `README.md`
- `SECURITY.md`
- `LICENSE`
- `ThirdPartyNotices.txt`
- `.gitignore`

### `.github/workflows`
Purpose: macOS validation and GitHub Pages publishing.
Edit here when:
- CI steps change
- release gating changes
- publish inputs change
Important files:
- `ci.yml`
- `pages.yml`

### `assets`
Purpose: source artwork for the app, site, and screenshots.
Edit here when:
- branding changes
- screenshots change
- favicon art changes
- menu bar art changes
- app icon assets change
Important files:
- `screenshot.png`
- `macOS App Icon/`
- `macOS Menu Bar Icons/`
- `Website Favicon/`
- `Website Icon (logo on page : header)/`

### `build`
Purpose: signing and export configuration for native packaging.
Edit here when:
- entitlements change
- export settings change
Important files:
- `entitlements.mac.plist`
- `entitlements.mac.inherit.plist`
- `export-options.native.plist`

### `docs`
Purpose: human-run validation notes, release checks, and local change notes.
Edit here when:
- manual test steps change
- release checklists change
- rejected or declined changes are recorded
Important files:
- `TESTING.md`
- `REJECTED CHANGES.md`

### `native/settings-app`
Purpose: the Swift package for the menu bar app and tests.
Edit here when:
- app behavior changes
- package dependencies change
- test coverage changes
Important files:
- `Package.swift`
- `Sources/TextShotSettings/`
- `Tests/TextShotSettingsTests/`
- `Vendor/KeyboardShortcuts/`

### `native/settings-app/Sources/TextShotSettings`
Purpose: app runtime, settings UI, capture flow, OCR, hotkeys, login item handling, and updates.
Edit here when:
- app behavior changes
- app UI changes
Important files:
- `AppEntry.swift`
- `AppController.swift`
- `AppRelocator.swift`
- `CaptureService.swift`
- `CaptureTempStore.swift`
- `ClipboardService.swift`
- `ContentView.swift`
- `HotkeyBindingController.swift`
- `HotkeyManager.swift`
- `LaunchAtLoginService.swift`
- `OCRService.swift`
- `ScreenCapturePermissionService.swift`
- `SettingsModel.swift`
- `ShortcutRecorder.swift`
- `TextShotUpdateUserDriver.swift`
- `ToastPresenter.swift`
- `UpdateManager.swift`

### `native/settings-app/Sources/TextShotSettings/Resources`
Purpose: bundled menu bar artwork used by the app runtime.
Edit here when:
- the status item icon changes
- packaged resource art changes
Important files:
- `text-shot-menubar-template.pdf`
- `text-shot-menubar-template.png`
- `text-shot-menubar-template.svg`
- `text-shot-menubar-template-v2.pdf`
- `text-shot-menubar-template-v2.svg`

### `native/settings-app/Tests/TextShotSettingsTests`
Purpose: native unit tests for capture, hotkeys, settings, updates, migration, and permissions.
Edit here when:
- behavior changes need coverage
- a regression test is needed
Important files:
- `AppControllerCaptureFlowTests.swift`
- `AppRelocatorTests.swift`
- `CaptureServiceTests.swift`
- `HotkeyManagerTests.swift`
- `OCRServiceTests.swift`
- `ScreenCapturePermissionServiceTests.swift`
- `SettingsFileStoreTests.swift`
- `SettingsMigratorTests.swift`
- `SettingsViewModelTests.swift`
- `UpdateManagerTests.swift`

### `native/settings-app/Vendor/KeyboardShortcuts`
Purpose: vendored third-party dependency for global hotkey recording.
Edit here when:
- the upstream package is refreshed
- the dependency is patched locally
Important files:
- `Package.swift`
- `license`
- `Sources/KeyboardShortcuts/`

### `native/settings-app/Vendor/KeyboardShortcuts/Sources/KeyboardShortcuts`
Purpose: the vendored hotkey implementation used by the app.
Edit here when:
- the dependency itself changes
- the app behavior is not the target
Important files:
- `CarbonKeyboardShortcuts.swift`
- `Key.swift`
- `KeyboardShortcuts.swift`
- `NSMenuItem++.swift`
- `Name.swift`
- `Recorder.swift`
- `RecorderCocoa.swift`
- `Shortcut.swift`
- `Utilities.swift`
- `ViewModifiers.swift`

### `native/settings-app/Vendor/KeyboardShortcuts/Sources/KeyboardShortcuts/Localization`
Purpose: localized strings for the vendored KeyboardShortcuts UI.
Edit here when:
- upstream localization text changes
Important files:
- `*/Localizable.strings` in each locale folder

### `scripts`
Purpose: build, test, typecheck, clean, and release helpers for the native app.
Edit here when:
- automation changes
- packaging changes
- release flow changes
Important files:
- `clean-generated.sh`
- `build-settings-app.sh`
- `test-native.sh`
- `typecheck-native.sh`
- `release-native.sh`

### `site`
Purpose: the static marketing site and its page assets.
Edit here when:
- homepage copy changes
- styling changes
- runtime release wiring changes
- 404 behavior changes
Important files:
- `index.html`
- `styles.css`
- `script.js`
- `404.html`
- `assets/screenshot.png`

## File Map
### Root Files
| File | Purpose |
|---|---|
| `AGENTS.md` | Captures repo-specific operating rules, release policy, and workflow guidance for coding agents. It is the high-level behavioral policy layer that explains how this repo should be changed, not just how it is structured. |
| `package.json` | Defines the top-level command surface, package metadata, and canonical version field that the release flow expects to stay aligned with native packaging. It is the quickest index of how maintainers intend the repo to be built, checked, and released. |
| `README.md` | Explains the app’s purpose, source-build flow, release commands, and installation-oriented documentation for contributors and users. It is the public narrative and workflow contract for the repo. |
| `SECURITY.md` | Describes how security issues should be reported or disclosed for this project. It is part of the repo’s governance surface rather than the product runtime. |
| `ThirdPartyNotices.txt` | Contains bundled dependency notices that need to ship with the app for licensing and attribution reasons. It matters when the set of embedded dependencies changes. |
| `LICENSE` | Holds the project’s license terms and governs how the repository itself may be distributed or reused. It is legal metadata rather than runtime logic. |
| `.gitignore` | Defines the boundary between durable source and disposable local artifacts such as build output, caches, and project notes. It tells you what the repo considers generated or intentionally untracked. |

### `.github/workflows`
| File | Purpose |
|---|---|
| `ci.yml` | Defines the continuous-integration workflow that validates native build and test expectations on GitHub-hosted macOS runners. It is the remote enforcement layer for repo health. |
| `pages.yml` | Defines the GitHub Pages publishing workflow that packages the site and selected release-facing assets for the public web presence. It is the automation boundary between source files and the published website/update surface. |

### `assets`
| File | Purpose |
|---|---|
| `screenshot.png` | Stores the canonical product screenshot used by the README and homepage to visually explain the app. It is part of the repo’s communication surface, not the runtime. |
| `macOS App Icon/text-shot-source.svg` | Holds the vector master artwork for the app icon, making it the cleanest source for future exports or branding updates. It is the design origin for app icon derivatives. |
| `macOS App Icon/text-shot-source-1024.png` | Holds the high-resolution raster master that the packaging flow can use when generating the final `.icns` bundle asset. It is a production-ready icon source rather than a final packaged icon. |
| `macOS App Icon/icon_*.png` | Holds pre-exported icon size variants that support the macOS iconset and packaging pipeline. These files are prepared assets rather than the single design master. |
| `macOS Menu Bar Icons/text-shot-Template.pdf` | Provides a menu bar icon source asset used when packaging the app’s status-item visuals. It is one of the primary source formats for the app’s always-visible glyph. |
| `macOS Menu Bar Icons/text-shot-Template.png` | Provides a raster menu bar icon source for packaging or preview contexts that need bitmap assets. It complements the vector and PDF sources. |
| `macOS Menu Bar Icons/text-shot-Template.svg` | Provides a vector menu bar icon source that is easiest to edit without quality loss. It is the most flexible source for future status-item art changes. |
| `macOS Menu Bar Icons/text-shot-Template@2x.png` | Provides a high-resolution raster variant for sharper rendering or packaging steps that need a bitmap status-item asset. It is a prepared export, not the original design source. |
| `macOS Menu Bar Icons/text-shot-Template@3x.png` | Provides the largest raster variant of the menu bar icon source set for high-density display or export needs. It is another derived asset in the icon pipeline. |
| `macOS Menu Bar Icons/text-shot.iconset-README.md` | Documents packaging details or expectations around the iconset assets in this folder. It is process guidance for the branding pipeline. |
| `Website Favicon/favicon.svg` | Holds the primary vector favicon source for the site. It is the most authoritative favicon design file. |
| `Website Favicon/favicon.ico` | Provides the legacy favicon format expected by browsers and tools that do not prefer SVG. It is a compatibility export of the favicon set. |
| `Website Favicon/apple-touch-icon.png` | Provides the icon used when the site is saved to Apple-device home screens. It extends site branding beyond the browser tab. |
| `Website Icon (logo on page : header)/logo.svg` | Holds the vector logo source used by the public site header and related branded surfaces. It is the clean design master for site logo usage. |
| `Website Icon (logo on page : header)/logo-512.png` | Provides a medium-resolution raster export of the site logo for surfaces that cannot use the vector asset directly. It is a prepared display asset. |
| `Website Icon (logo on page : header)/logo-1024.png` | Provides a larger raster export of the site logo for sharper or larger web-facing uses. It is the high-resolution bitmap counterpart to the SVG source. |

### `build`
| File | Purpose |
|---|---|
| `entitlements.mac.plist` | Defines the code-signing entitlements granted to the main macOS binary, which directly controls what macOS capabilities the released app is allowed to use. It is part of the platform-permission contract for shipping builds. |
| `entitlements.mac.inherit.plist` | Defines the inherited entitlements used by child processes or nested signed components so they remain compatible with the main app’s signing model. It is part of the repo’s distribution-security plumbing. |
| `export-options.native.plist` | Holds the Xcode export configuration used for Developer ID packaging and distribution. It is the packaging-policy file that shapes how signed archives become releasable artifacts. |

### `docs`
| File | Purpose |
|---|---|
| `TESTING.md` | Documents the manual regression checklist that matters for this native utility, including capture, permissions, menu bar behavior, multi-display handling, and OCR expectations. It preserves validation knowledge that does not live naturally in package scripts alone. |
| `REJECTED CHANGES.md` | Records changes or ideas that were intentionally declined so the same proposals are not rediscovered without new evidence. It acts as a small decision-history file for the repo. |

### `native/settings-app`
| File | Purpose |
|---|---|
| `Package.swift` | Declares the Swift package, executable target, external dependencies, linked frameworks, and test configuration for the native app. It is the manifest that tells SwiftPM what this application is made of. |

### `native/settings-app/Sources/TextShotSettings`
| File | Purpose |
|---|---|
| `AppEntry.swift` | Defines the app bootstrap path, the `@main` entry type, and the initial status-menu/application-scene setup. It is the native runtime’s first composition layer. |
| `AppController.swift` | Coordinates the core runtime behavior across capture, OCR, clipboard, permissions, settings, login item state, and updates. It is the operational center of the app. |
| `AppRelocator.swift` | Handles the logic for moving the app into `/Applications` and relaunching from the proper install location. It supports the repo’s install-polish and packaging expectations. |
| `CaptureService.swift` | Wraps the underlying macOS screen-capture invocation and translates raw capture outcomes into app-understood success or failure states. It is the first step of the OCR workflow. |
| `CaptureTempStore.swift` | Manages temporary files created during screen capture and ensures stale capture artifacts are cleaned up safely. It is the file-lifecycle helper for capture output. |
| `ClipboardService.swift` | Writes recognized OCR text into the macOS pasteboard so the product delivers its core “capture text and copy it” value. It is the final handoff from OCR to user utility. |
| `ContentView.swift` | Defines the settings UI and the view-side state that lets users configure how the app behaves. It is the main user-facing configuration surface. |
| `HotkeyBindingController.swift` | Connects the KeyboardShortcuts dependency to the app’s runtime behavior so the chosen global shortcut triggers capture correctly. It is the wiring layer between shortcut state and action. |
| `HotkeyManager.swift` | Defines default shortcut behavior, validation rules, and display logic for hotkeys. It is the policy layer for shortcut semantics. |
| `LaunchAtLoginService.swift` | Manages login-item registration through `SMAppService` so the app can start automatically with the user session. It is the startup-behavior integration layer. |
| `OCRService.swift` | Performs the Vision OCR workflow, including retry logic, text assembly, and cleanup of recognition output into a more usable result. It is the heart of the text-extraction feature. |
| `ScreenCapturePermissionService.swift` | Manages the Screen Recording permission preflight and request path that the capture flow depends on. It is the permission gate for the core feature. |
| `SettingsModel.swift` | Defines the settings schema plus persistence and migration helpers that keep preferences stable across launches and versions. It is the data model behind the settings UI. |
| `ShortcutRecorder.swift` | Wraps the shortcut-recorder UI from the vendored dependency so it fits cleanly into the app’s SwiftUI settings surface. It is the presentation adapter for shortcut selection. |
| `TextShotUpdateUserDriver.swift` | Implements the update-related user-driver behavior, including the visible “already up to date” path. It shapes how Sparkle-driven update state is presented to the user. |
| `ToastPresenter.swift` | Presents the confirmation toast shown after capture completes, giving the user immediate feedback that OCR and clipboard handoff happened. It is a small but visible UX-feedback component. |
| `UpdateManager.swift` | Encapsulates both Sparkle-backed and disabled update-manager behavior so the app can switch update handling based on configuration. It is the main update integration layer. |

### `native/settings-app/Sources/TextShotSettings/Resources`
| File | Purpose |
|---|---|
| `text-shot-menubar-template.pdf` | Bundles a menu bar icon source asset in PDF form for use in the shipped app resources. It is one of the packaged representations of the status-item glyph. |
| `text-shot-menubar-template.png` | Bundles a raster form of the menu bar icon for runtime or packaging contexts that rely on bitmap assets. It is a packaged display asset rather than the design master. |
| `text-shot-menubar-template.svg` | Bundles a vector form of the menu bar icon, preserving editability and export flexibility. It is the most adaptable packaged source for the status-item art. |
| `text-shot-menubar-template-v2.pdf` | Bundles the alternate or newer PDF variant of the menu bar icon resource. It represents a second-generation version of the packaged glyph. |
| `text-shot-menubar-template-v2.svg` | Bundles the alternate or newer SVG variant of the menu bar icon resource. It is the flexible vector counterpart to the second-generation packaged glyph. |

### `native/settings-app/Tests/TextShotSettingsTests`
| File | Purpose |
|---|---|
| `AppControllerCaptureFlowTests.swift` | Verifies the orchestration logic that ties together capture, OCR, and follow-on behavior inside the main controller. It protects the highest-value end-to-end native workflow. |
| `AppRelocatorTests.swift` | Verifies the install-location and move-to-Applications behavior that supports a polished macOS distribution flow. It protects a packaging-adjacent but user-visible path. |
| `CaptureServiceTests.swift` | Verifies how the app interprets `screencapture` success and failure outcomes. It protects the reliability of the first step in the product’s core feature. |
| `HotkeyManagerTests.swift` | Verifies shortcut defaults, validation, and rules so the global hotkey system behaves consistently. It protects a core interaction path. |
| `OCRServiceTests.swift` | Verifies OCR assembly, cleanup, and retry behavior so recognized text stays usable and stable across code changes. It protects the core text-extraction feature. |
| `ScreenCapturePermissionServiceTests.swift` | Verifies the permission-handling path for screen capture authorization. It protects the gating condition of the app’s primary capability. |
| `SettingsFileStoreTests.swift` | Verifies how settings are persisted on disk and restored. It protects the long-lived preference layer. |
| `SettingsMigratorTests.swift` | Verifies migration behavior for old settings formats so upgrades do not silently break stored preferences. It protects continuity across versions. |
| `SettingsViewModelTests.swift` | Verifies settings-view logic and update-toggle behavior from the UI side. It protects the correctness of the configuration surface. |
| `UpdateManagerTests.swift` | Verifies update-manager behavior across Sparkle-enabled and disabled paths. It protects the repo’s update integration contract. |

### `native/settings-app/Vendor/KeyboardShortcuts`
| File | Purpose |
|---|---|
| `Package.swift` | Declares the local Swift package wrapper for the vendored KeyboardShortcuts dependency so SwiftPM can consume it as part of the app build. It is the manifest layer for the embedded dependency. |
| `license` | Preserves the upstream dependency’s license text inside the vendored tree. It is part of the legal and provenance record for embedded third-party code. |

### `native/settings-app/Vendor/KeyboardShortcuts/Sources/KeyboardShortcuts`
| File | Purpose |
|---|---|
| `CarbonKeyboardShortcuts.swift` | Implements Carbon-based low-level shortcut plumbing inside the vendored dependency. It is part of the dependency’s platform-integration core. |
| `Key.swift` | Defines key-code and shortcut helper behavior inside the vendored dependency. It is part of the dependency’s internal keyboard model. |
| `KeyboardShortcuts.swift` | Exposes the dependency’s public API surface that the app consumes for shortcut behavior. It is the main integration point between app code and vendored library code. |
| `NSMenuItem++.swift` | Provides dependency-local menu-item helper extensions used by the shortcut package. It supports the package’s AppKit-facing behavior. |
| `Name.swift` | Handles shortcut naming and identity inside the dependency. It is part of how the package tracks and refers to configured shortcuts. |
| `Recorder.swift` | Implements the core recorder behavior for capturing shortcut input in the dependency. It is central to the shortcut-selection UX provided upstream. |
| `RecorderCocoa.swift` | Implements the Cocoa-backed portions of the shortcut recorder. It is part of the dependency’s platform-specific UI behavior. |
| `Shortcut.swift` | Defines the shortcut model type used throughout the dependency. It is the dependency’s core data structure for represented key combinations. |
| `Utilities.swift` | Provides shared helper behavior used across the vendored shortcut package. It is support code that keeps the dependency implementation DRY. |
| `ViewModifiers.swift` | Provides SwiftUI view modifiers used by the vendored shortcut package. It is the integration layer that makes the dependency ergonomic in SwiftUI code. |

### `native/settings-app/Vendor/KeyboardShortcuts/Sources/KeyboardShortcuts/Localization`
| File | Purpose |
|---|---|
| `*/Localizable.strings` | Holds the localized UI strings used by the vendored shortcut recorder across supported languages. It is the translation surface for the embedded dependency’s user-facing text. |

### `scripts`
| File | Purpose |
|---|---|
| `clean-generated.sh` | Removes generated outputs, caches, and packaging artifacts so local state can be reset cleanly between builds or release attempts. It is the repo’s cleanup/reset script. |
| `build-settings-app.sh` | Builds the universal native app bundle into the `.generated/app` location using the repo’s expected asset and package layout. It is the primary local assembly step for the product binary. |
| `test-native.sh` | Runs the canonical Swift test workflow with the repo’s chosen scratch-path and keychain constraints so validation is reproducible. It is the main native test gate. |
| `typecheck-native.sh` | Runs the canonical Swift build/typecheck workflow used to prove the app still compiles under the repo’s expected build assumptions. It is the compile-safety gate. |
| `release-native.sh` | Orchestrates version bumping, packaging, notarization, and Sparkle appcast generation for releases. It is the source of truth for the shipping pipeline. |

### `site`
| File | Purpose |
|---|---|
| `index.html` | Defines the homepage structure, metadata, and content shell for the site that presents the product publicly. It is the main content-bearing file of the web presence. |
| `styles.css` | Defines the visual system and responsive layout behavior of the homepage. It is the styling source of truth for the static site. |
| `script.js` | Implements the small client-side runtime behavior that keeps the site’s release badge and download link aligned with GitHub release data. It is the dynamic glue on an otherwise static page. |
| `404.html` | Defines the fallback/redirect page shown when the GitHub Pages site receives an unknown route. It is the public error-path shell for the site. |
| `assets/screenshot.png` | Stores the site-local screenshot used directly by the homepage. It is a web-facing display asset distinct from the native runtime. |

## Architecture Notes
- The runtime is native Swift; there is no Electron layer.
- `AppEntry.swift` builds the menu bar app and keeps the app headless unless the Settings window is opened.
- `AppController.swift` is the main orchestration layer for capture, OCR, clipboard, hotkeys, permissions, login-item state, and updates.
- `CaptureService.swift` shells out to `/usr/sbin/screencapture`; `OCRService.swift` uses Vision and custom line assembly to make the text readable.
- `UpdateManager.swift` chooses between disabled and Sparkle-backed update handling based on the bundle info keys.
- `scripts/build-settings-app.sh` assembles the app bundle, and `scripts/release-native.sh` is the release source of truth for version bumps, appcast generation, and `release/` output.
- `site/script.js` is runtime wiring only; it does not own release data, it reads the latest GitHub release at page load.

## Common Tasks → Files To Edit
| Task Type | Start Here | Usually Also Check |
|---|---|---|
| Capture flow | `native/settings-app/Sources/TextShotSettings/AppController.swift` | `CaptureService.swift`, `CaptureTempStore.swift`, `OCRService.swift`, `ClipboardService.swift` |
| Settings UI or persistence | `ContentView.swift` | `SettingsModel.swift`, `ShortcutRecorder.swift`, `AppController.swift` |
| Hotkey behavior | `HotkeyManager.swift` | `HotkeyBindingController.swift`, `ShortcutRecorder.swift` |
| Screen Recording or login-item behavior | `ScreenCapturePermissionService.swift` | `LaunchAtLoginService.swift` |
| Update behavior | `UpdateManager.swift` | `TextShotUpdateUserDriver.swift` |
| Packaging or release flow | `scripts/build-settings-app.sh` | `scripts/release-native.sh`, `build/*.plist`, `package.json`, `native/settings-app/Package.swift` |
| Tests or validation | `native/settings-app/Tests/TextShotSettingsTests/*` | `scripts/test-native.sh`, `scripts/typecheck-native.sh`, `docs/TESTING.md`, `.github/workflows/ci.yml` |
| Website behavior or copy | `site/index.html` | `site/styles.css`, `site/script.js`, `site/404.html`, `.github/workflows/pages.yml` |
| Branding or artwork | `assets/*` | `native/settings-app/Sources/TextShotSettings/Resources/*` |
| Repo rules or docs | `AGENTS.md` | `README.md`, `SECURITY.md`, `ThirdPartyNotices.txt`, `.gitignore` |

## Testing And Validation
- `npm run typecheck` -> `bash scripts/typecheck-native.sh` -> `swift build --package-path native/settings-app --scratch-path <tmp> --disable-keychain`
- `npm test` -> `bash scripts/test-native.sh` -> `swift test --package-path native/settings-app --scratch-path <tmp> --disable-keychain --no-parallel`
- `npm run build` -> `bash scripts/build-settings-app.sh`
- `npm start` -> `open "./.generated/app/Text Shot.app"`
- Release validation: `bash scripts/release-native.sh --set-version <x.y.z>`; use `--bump-minor` only for an intentional minor bump and `--skip-notarize` only when notarization is intentionally being skipped.
- Manual regression checklist: `docs/TESTING.md`
- CI mirrors the native checks on `macos-15` with `npm ci`, `npm run typecheck`, and `npm test`.

## Known Generated Or External Files
- `.generated/` - local app bundle output from `npm run build`.
- `release/` - shipping DMG and `.sha256`; should contain only the latest pair.
- `dist-appcast/` - Sparkle feed and archive output for publishing.
- `native/settings-app/.build/` - SwiftPM build output.
- `.swiftpm-module-cache/` and `.clang-module-cache/` - local caches used by the helper scripts.
- `node_modules/` - npm dependency tree.
- `native/settings-app/Package.resolved` - generated SwiftPM resolution file and intentionally ignored here.
- `native/settings-app/Vendor/KeyboardShortcuts/` - vendored third-party source tree.
- `dist-appcast/appcast.xml` and `dist-appcast/Text Shot-3.0.5.zip` - generated publish artifacts from the last release snapshot.

## Stale Or Unclear Areas
- `site/index.html` hardcodes the badge `v3.0.5`, while `site/script.js` replaces it at runtime from GitHub Releases; that HTML value can go stale between releases.
- `site/script.js` depends on the GitHub API and on the latest release having a downloadable `.dmg`.
- `assets/screenshot.png` and `site/assets/screenshot.png` should stay in sync if the homepage image changes.
- `native/settings-app/Vendor/KeyboardShortcuts` is vendored upstream code, so local edits there should be treated as external dependency changes.

## How To Update This Map
1. Update only the affected section.
2. Keep descriptions short and factual.
3. Do not paste large code snippets.
4. Prefer navigation value over exhaustive implementation detail.
