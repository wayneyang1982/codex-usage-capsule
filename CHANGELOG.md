# Changelog

## 0.2.0 - 2026-09-22

- Close the details panel on outside clicks without taking focus from Codex. The mouse watcher runs only while details are open, does not block clicks, and does not retain coordinates.
- Open details immediately by moving the slow Task Scheduler check to capsule startup. Keep the sign-in checkbox current when changed in the panel.
- Ignore delayed close messages from an earlier popup session, so a quick reopen stays open.

## 0.1.1 - 2026-09-22

- Keep the capsule anchored during roomy window resizes; revalidate near narrow layouts and DPI transitions.

## 0.1.0 - 2026-09-22

- Initial Windows MVP.
- Single- and multi-window quota capsules with elapsed-time baselines.
- Expandable details, adaptive narrow-window layout, appearance selection, and sign-in startup control.
- Current-user installer, status check, uninstaller, and automated tests.
- Smoother title-bar tracking during window moves, with resize/DPI revalidation to prevent misplaced overlays.
