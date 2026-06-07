# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Repository Map

- Read `docs/REPO_MAP.md` before broad scanning or indexing.
- Use the map as the first navigation aid, not as a restriction. Inspect any files needed to understand the task, verify the map, or investigate missing context.
- When architecture, meaningful files, or folder responsibilities change, update only the affected sections of `docs/REPO_MAP.md`.

## High-level Architecture

This project is a native Swift menu bar macOS utility for fast region OCR. There is no Electron runtime.

- `native/settings-app`: Main Swift app runtime (status item, hotkey, capture flow, OCR, settings, permissions, toast)
- `scripts`: Build/test/release helpers
- `build`: Release configuration files (export options, entitlements)
- `assets`: App icon and tray assets

## Common Commands

- `npm run build`: Build universal native binary and app bundle (`.generated/app/Text Shot.app`)
- `npm start`: Launch the native app bundle
- `npm test`: Native unit tests (`swift test`)
- `npm run typecheck`: Compile-check native Swift package
- `npm run clean`: Remove generated files (`.generated`, `release`, Swift caches)

## Release Requirements (Mandatory Every Edit Cycle)

- Keep semantic version in `package.json` aligned with native release policy.
- Choose the release version using the semver policy below before packaging.
- Prefer explicit version selection with:
  - `bash scripts/release-native.sh --set-version <x.y.z>`
- Treat `npm run release:native:minor` / `--bump-minor` as a legacy shortcut that should only be used when an intentional minor bump is desired.
- Build native app bundle:
  - `npm run build`
- Build DMG and copy artifacts to `release/`:
  - `bash scripts/release-native.sh --set-version <x.y.z>`
- Ensure `release/` contains only the latest DMG and matching `.sha256`.
- `dist-native/` is transient/internal and must not be used as a distribution location.

## Version Policy

- Every new DMG must bump the version.
- Use standard semantic versioning: `major.minor.patch`
- Patch bump (`0.0.1`):
  - Use for small updates, minor changes, tiny polish, or a narrow low-risk fix
  - Example: `3.1.0` -> `3.1.1`
- Minor bump (`0.1.0`):
  - Use for a good fix, multiple fixes together, or a meaningful non-breaking improvement
  - Example: `3.1.0` -> `3.2.0`
- Major bump (`1.0.0`):
  - Use for major changes, major feature shifts, or breaking behavior changes
  - Example: `3.1.0` -> `4.0.0`
- Do not use the old patchless progression policy anymore.
- Keep only the latest DMG and checksum in `release/`; delete older release artifacts.
