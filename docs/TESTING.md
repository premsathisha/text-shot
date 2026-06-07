# Manual Regression Checklist

Use this checklist for hands-on verification before a release or after changes that affect capture behavior. This file is intentionally manual-only.

## Screen Region Selection

- Verify actual screen region selection starts and completes on the intended area.
- Confirm the selected region matches what was highlighted on screen.
- Launch the app fresh and verify the first capture works from the hotkey.
- Re-run selection from both the hotkey and menu bar entry point.
- Verify a failed first capture does not leave the hotkey path stuck.

## Permissions

- Verify the first-time screen recording permission prompt appears when access is missing.
- Confirm the app recovers cleanly after permission is granted.
- Re-check the flow after toggling permission off and back on.

## Menu Bar

- Confirm the menu bar item appears correctly after launch.
- Verify the menu opens and closes normally.
- Check that Settings and Quit behave as expected from the menu.
- Open `Settings...`, close it, and reopen it multiple times without the app quitting.
- Confirm the settings window comes to the front when it is already open.

## Multi-Display

- Test selection across multiple displays.
- Confirm the capture overlay appears on the intended display.
- Verify OCR still works when captures originate from either display.

## OCR Samples

- Test printed text in screenshots, documents, and app windows.
- Test mixed formatting such as headings, paragraphs, and short lists.
- Test low-contrast or busy backgrounds to confirm the result is still usable.
