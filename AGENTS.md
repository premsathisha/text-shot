# AGENTS.md

This file is the repo-specific operating guide for agents working in Text Shot. Use it for product rules, runtime seams, and validation expectations. Use `docs/REPO MAP.md` for structure and file discovery.

## Start Here
- Read `docs/REPO MAP.md` before broad scanning or indexing.
- Use the repo map as the navigation layer and this file as the policy layer.
- Update only the affected parts of `docs/REPO MAP.md` when architecture, meaningful files, or folder responsibilities change.
- Use repo scripts before ad hoc command substitutes whenever practical.
- Before claiming a behavior change is verified, check the relevant runtime file and at least one test or manual checklist item.

## Product Priorities
- Keep Text Shot lightweight, keyboard-first, and low-friction.
- Favor good defaults over extra knobs. Users should be able to install, grant permission, set a shortcut, and get value immediately.
- Preserve convenience, but not at the cost of safety or brittle runtime behavior.
- Be especially careful around permissions, launch flow, hotkey behavior, packaging, and updates. Those are core product seams here.

## Core Runtime Invariants
- Preserve the menu bar -> capture -> OCR -> clipboard flow unless the task explicitly changes product behavior.
- Startup order matters. Launch cleanup and move-to-Applications prompting happen before the normal controller-driven runtime and should not be rearranged casually.
- Wake-from-sleep hotkey re-registration is intentional. Do not remove or bypass it without proving the replacement handles the same failure mode.
- Settings-window reopen behavior, first-launch behavior, and permission recovery are regression-prone seams. Validate them when touched.
- Toasts and user feedback for copied text, no text found, or error cases are part of the product experience, not incidental UI.

## Settings, Migration, And Persistence
- Treat settings persistence as a real compatibility contract.
- Use the existing migrator/store flow when changing settings behavior. Do not introduce parallel settings files or sidecar persistence paths casually.
- Do not rename, reinterpret, or delete stored keys unless the task explicitly includes a migration plan.
- Launch-at-login, update preferences, and runtime settings belong to the same product surface and should be reviewed together when changed.

## Capture, OCR, And UX Rules
- The app should stay fast to trigger and fast to recover from failure.
- Be careful with permission handling, retry paths, duplicate-copy suppression, and clipboard confirmation behavior.
- Multi-display behavior is important. Do not assume single-screen validation is enough for capture changes.
- For OCR changes, preserve the product goal of usable pasted text rather than raw OCR output alone.
- Avoid adding extra friction such as unnecessary dialogs, blockers, or slow intermediate states.

## Build, Test, And Validate
- Default code checks:
  - `npm run typecheck`
  - `npm test`
- Use `npm run build` when the change may affect the app bundle, resources, icons, signing, Sparkle integration, or packaging.
- For AppKit/menu bar/capture/runtime UX changes, bundle-level validation matters more than source-only confidence.
- Use `docs/TESTING.md` for manual validation of capture, permissions, menu bar behavior, multi-display behavior, and OCR quality.
- Prefer focused automated tests for logic changes, but do not treat them as sufficient proof for bundle/runtime behavior.

## Verification Expectations
- Report exactly which of `npm run typecheck`, `npm test`, `npm run build`, and manual checklist items were run.
- For capture-flow changes, manually verify the first capture path, repeat capture path, and permission-recovery path.
- For menu bar or settings changes, verify opening, closing, and reopening the settings window without app shutdown or focus glitches.
- For runtime or packaging changes, validate the built app bundle rather than relying only on source inspection.
- If permission-sensitive, UI-sensitive, or release-sensitive checks were not run, say that clearly in the handoff.

## Release And Packaging Guardrails
- `package.json` version is the canonical version source for the build and release scripts.
- Do not leave stale DMGs or checksums in `release/`.
- Treat `release/` as the DMG/checksum surface and `dist-appcast/` as the updater publish surface. They are related but not interchangeable.
- Local release runs may skip some updater publishing behavior when Apple or Sparkle prerequisites are unavailable. Official releases have stricter requirements.
- Do not change entitlements, export options, signing flow, notarization assumptions, or Sparkle wiring casually.
- Site publishing and updater publishing are coupled. Changes to release surfacing may require checking both `site/` and `dist-appcast/`.

## Safety And Dependency Boundaries
- Avoid editing vendored `KeyboardShortcuts` unless the task is specifically about that dependency.
- Keep tests and validation paths free from accidental keychain-prompt regressions where the repo already avoids them.
- Never commit private signing keys, tokens, certificates, provisioning profiles, or `.env` files.
- Prefer non-destructive changes. Do not remove user data, generated release assets, or migration paths unless the task explicitly calls for it.

## Boundaries
- Do not turn this file into a second repo map. Folder inventories and file tables belong in `docs/REPO MAP.md`.
- Prefer small, direct changes over broad abstraction unless the task clearly needs a larger refactor.
- Preserve the native macOS feel of the app. Do not add complexity that makes the product heavier or more fragile.

## Handoff Expectations
- Summaries should explain what changed, what was verified, and what still needs bundle/manual/release validation.
- If a change touched settings compatibility, permissions, packaging, or updates, call that out explicitly.
- If a follow-up installed-app or release-path check is still needed, say so clearly.
