# av-launcher

Reusable Tauri v2 tray-launcher shell (per-app-themed card UI) that wraps the fleet's web apps. Each of srt-router / flock / RFutils ships this as its OWN desktop app (server embedded; RFutils embeds a Node runtime). Released combined v0.1.0.

## Commands
- Dev: `npm run tauri dev`
- Build app: `npm run tauri build`
- Rust side lives in `src-tauri/` (`cargo` workspace); frontend in `src/`.

## Layout
- `src/` — launcher card UI (frontend)
- `src-tauri/` — Tauri/Rust shell (main binary, tray, window mgmt)
- `launchers/` — per-app launcher configs/themes
- `scripts/`, `docs/`

## Notes
- This is a shared shell consumed by multiple apps — changes here ripple to srt-router/flock/RFutils desktop builds. Keep the launcher API stable.
- Public repo. Multi-platform release CI; cross-compile macOS x86_64 on macos-14 (never macos-13). "Commit" = commit **and** push.
