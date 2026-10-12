# av-launcher

Reusable Tauri v2 tray-launcher shell (per-app-themed card UI) that wraps the fleet's web apps. Each of srt-router / flock / RFutils ships this as its OWN desktop app (server embedded; RFutils embeds a Node runtime). Released; v0.3.2 is the latest.

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
- This is a shared shell consumed by multiple apps — changes here ripple to every app carrying a copy under `launcher/` (srt-router/flock/RFutils and, by 2026-10-12, 26 more public repos). Keep the launcher API stable.
- Public repo. Multi-platform release CI; cross-compile macOS x86_64 on macos-14 (never macos-13). "Commit" = commit **and** push.

## Diagnostics

Log via `tracing` as usual; `crates/diag` adds a rotating file, an in-memory ring and a
panic hook that writes a JSON crash report. Wire it as the **first** thing in `main`, and
**hold the returned guard** — dropping it (`let _ = diag::init(..)`) silently stops the log
file being written. Console output goes to stderr; stdout is reserved for program output.
See [docs/diagnostics.md](docs/diagnostics.md).
