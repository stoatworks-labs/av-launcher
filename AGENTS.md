# AGENTS.md — bringing an LLM up to speed on av-launcher

Orientation for an AI assistant (or a new human) picking this project up cold. `CLAUDE.md`
holds the short command reference; this file explains the model and the traps.

---

## 1. What this is

A reusable **menu-bar tray launcher shell** for the local web-server apps in this fleet. It
gives any of them a small panel to pick a **network interface** and **port**, **Start/Stop**
the server, **Open** the web UI, and live in the **system tray** — without each app building
that for itself.

Tauri v2. Public repo. Released as combined v0.1.0.

## 2. The thing that makes this repo different: changes ripple

**This is a shared shell consumed by multiple apps.** `srt-router`, `flock` and `RFutils`
each ship it as their *own* desktop app, with the server embedded (and for RFutils, an
embedded Node runtime too).

So a change here is not a change to one product — it lands in three. **Keep the launcher API
stable.** Before altering anything in the config or launcher contract, check
`launchers/*.toml` and consider what each consuming app expects.

## 3. Layout

```
src/            Launcher card UI (frontend). Original card design that themes
                itself to each app's own web UI.
src-tauri/      Tauri/Rust shell - main binary, tray, window management
  config.rs       Launcher configuration
  serve.rs        The in-process static server behind `[serve] mode = "static"`
  lib.rs / main.rs
  launcher.toml   Default/dev launcher config
launchers/      Per-app launcher configs and themes
  srt-router.toml, flock.toml, rfutils.toml
scripts/, docs/
```

## 4. Commands

```bash
npm run tauri dev      # develop
npm run tauri build    # build the app
```

Rust lives in `src-tauri/` (its own cargo workspace — note that there is **no `Cargo.toml` at
the repo root**, so `cargo` commands need `--manifest-path src-tauri/Cargo.toml`). Frontend is
in `src/`.

## 5. The macOS Gatekeeper trap — this is the big one

**For an unsigned `.app` that bundles helper binaries, approving the app does NOT unquarantine
its payload. The helpers are SIGKILLed silently.**

This is precisely av-launcher's shape: a tray app wrapping an embedded server binary. The
failure mode is nasty — the app launches and looks fine, the server never starts, and there is
no visible error. If a consuming app reports "the server won't start on a clean Mac", this is
the first thing to check, not a bug in the server.

## 5a. Static sites are served in-process, and that is because of §5

`[serve] mode = "static"` (2026-09-07) exists so the fleet's browser tools can
ship as tray apps. It serves a bundled directory from a thread inside the
launcher — `serve.rs`, `tiny_http`, GET/HEAD only, traversal checked after
percent decoding, the site's `_headers` applied so the offline copy is no more
permissive than the hosted one. **It must stay in-process.** The obvious
alternative, a bundled static-server helper, is precisely the unsigned-helper
shape §5 describes, multiplied by twenty tools. `AppState` holds either a
`Child` or a `StaticServer`; `shutdown()` stops whichever exists, and
`get_status` reaps both, so a serving thread that dies is reported as Stopped
rather than believed. `[app].command` and `[inject]` became optional for this
and every shipped child-process config still spells both out.

## 6. Status

The Rust backend compiles and the panel UI has been exercised **via its mock backend**. The
full tray app has **not** been run end-to-end against a live server on the target machine.

Given §5, that gap matters: the untested path is exactly the one where the Gatekeeper problem
shows up.

## 7. Conventions

- Multi-platform release CI; cross-compile macOS x86_64 on `macos-14` — never `macos-13`,
  those Intel runners are retired.
- Public repo. "Commit" means commit **and** push.

## Diagnostics

Log via `tracing` as usual; `crates/diag` adds a rotating file, an in-memory ring and a
panic hook that writes a JSON crash report. Wire it as the **first** thing in `main`, and
**hold the returned guard** — dropping it (`let _ = diag::init(..)`) silently stops the log
file being written. Console output goes to stderr; stdout is reserved for program output.
See [docs/diagnostics.md](docs/diagnostics.md).

## Notes

`docs/NOTES.md` carries this repo's working notes — current status, decisions
already made, and the traps that have actually bitten. Read it before changing
anything non-obvious. Cross-cutting fleet knowledge lives in
[fleet-notes](https://github.com/stoatworks-labs/fleet-notes).
