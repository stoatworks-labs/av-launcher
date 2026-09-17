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

## 5b. A start that fails says so — the failure lives in the backend

`AppState` holds a `failure: Option<Failure>` beside the child/server slot, and `Status`
carries it to the panel. It exists because the panel polls `get_status` every two seconds
and re-renders from scratch: anything it merely *flashed* was gone on the next poll, which
is how "port already in use" used to look like Start doing nothing. The rules:

- `start_server` returns a **Stopped status carrying the failure**, not an `Err`. `Err` is
  for the launcher's own trouble (unreadable config, poisoned lock).
- Before spawning anything, `probe_bind` binds the exact host:port the server will bind and
  drops it. It mirrors the server's own bind (std sets `SO_REUSEADDR` on Unix, as Node/Go/
  Python/every Rust server do), so it predicts the server's outcome rather than asserting
  its own. Wording comes from `io::ErrorKind`, never from the port number: macOS binds port
  80 unprivileged since 10.14, and Windows answers `EACCES` for ports another program holds
  exclusively.
- After spawning, `watch_startup` watches for up to 1.5 s: exit → quoted with exit status
  and output tail; answering on loopback → Running; neither → Running (the poll keeps
  watching). Readiness is checked through **loopback only** — connecting to one of this
  machine's LAN addresses is a local-network operation under macOS local network privacy
  (TN3179) and would prompt.
- The child's stdout/stderr are piped into `OutputTail` and **drained continuously** on
  their own threads. Never pipe a child's output without reading it: at 64 KiB the child
  blocks on write.
- `get_status` reaping a dead child records the same kind of failure, so a server that dies
  later is reported too. `fail()` also logs through `tracing`, so the diag file has it.
- Cleared by the next Start, by Stop, and by `save_settings` (the failure was about the old
  choice).
- The panel enables **Open** when `failure.port_busy`, since the thing on the port may well
  be this app; it grows the window (`fit_panel`) to show an output tail and shrinks back.

The commands are tested against `tauri::test::mock_builder()` with a real config and a
stand-in `sh` server (`tests::commands` in lib.rs), which is why every function taking an
`AppHandle` is generic over `tauri::Runtime`. Keep it that way.

## 6. Status

The Rust backend compiles, the command layer runs under Tauri's mock runtime in `cargo
test`, and the panel UI has been exercised **via its mock backend**. The full tray app has
**not** been run end-to-end against a live server on the target machine from this repo
(the fleet copies have — see the fleet notes).

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
