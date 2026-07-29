# av-launcher — Developing

Tauri v2. Public repo, released as combined v0.1.0.

---

## 1. The thing that makes this repo different: changes ripple

> **This is a shared shell consumed by multiple apps.** `srt-router`, `flock` and `RFutils` each
> ship it as their **own** desktop app, with the server embedded (and for RFutils, an embedded
> Node runtime too).
>
> **So a change here is not a change to one product — it lands in three. Keep the launcher API
> stable.**

Before altering anything in the config or launcher contract, **check `launchers/*.toml` and
consider what each consuming app expects.** The three shipped configs are deliberately different
from each other, and between them they cover the whole contract:

| File | Mode | Exercises |
|---|---|---|
| `srt-router.toml` | `configfile` | a **nested** key (`web.bind`), `--config <path>` |
| `flock.toml` | `configfile` | a **top-level** key (`bind`), a **positional** config arg |
| `rfutils.toml` | `env` | env injection, no config file at all |

If a change doesn't work for all three, it isn't ready.

---

## 2. ⚠ The macOS Gatekeeper trap — this is the big one

> **For an unsigned `.app` that bundles helper binaries, approving the app does NOT unquarantine
> its payload. The helpers are SIGKILLed silently.**

**This is precisely av-launcher's shape**: a tray app wrapping an embedded server binary.

The failure mode is nasty — **the app launches and looks fine, the server never starts, and there
is no visible error.**

> **If a consuming app reports "the server won't start on a clean Mac", this is the first thing
> to check, not a bug in the server.**

---

## 3. Status — and why the gap matters

The Rust backend compiles and the panel UI has been exercised **via its mock backend**. **The
full tray app has not been run end-to-end against a live server on the target machine.**

> Given §2, that gap matters: **the untested path is exactly the one where the Gatekeeper problem
> shows up.**

Don't describe the launcher as verified end-to-end until that run has happened on a target
machine, from a real packaged build.

---

## 4. Layout and commands

```
src/            Launcher card UI (frontend). The original card design, themed
                per-app from [app.theme].
src-tauri/      Tauri/Rust shell — main binary, tray, window management
  config.rs       Launcher configuration + interface enumeration
  lib.rs          The ten #[tauri::command]s, child supervision, settings
  main.rs
  launcher.toml   The ACTIVE launcher config for this build
launchers/      Per-app launcher configs and themes
  srt-router.toml, flock.toml, rfutils.toml
scripts/, docs/
```

```bash
npm run tauri dev      # develop
npm run tauri build    # build the app

AV_LAUNCHER_CONFIG=launchers/flock.toml npm run tauri dev   # target another app
```

```bash
cd src-tauri && cargo test
```

The Rust tests cover **host:port injection for all three modes**, including the difference that
catches people out — `flock`'s top-level `bind` versus `srt-router`'s nested `web.bind`. **Add a
case there when you add an app with an unusual key path.**

> **Rust lives in `src-tauri/`, its own cargo workspace — there is no `Cargo.toml` at the repo
> root.** `cargo` commands need `--manifest-path src-tauri/Cargo.toml`, or a `cd` first. A bare
> `cargo test` in the repo root will not find anything.

---

## 5. The shell knows nothing about any server

**That is the design.** `config.rs`'s doc comment states it: the launcher is app-agnostic, and
each app is described by a small TOML that says how to start the binary and how to inject the
chosen host:port.

Three injection modes cover the whole fleet — `configfile`, `env`, `args` — and they are
documented in [adding-an-app.md](adding-an-app.md).

**Resist adding app-specific behaviour to the shell.** If a new app doesn't fit, the first
question is whether the config fields can express it; adding a fourth mode is a bigger change
than it looks, because it becomes part of the contract all three consumers depend on.

---

## 6. Behaviours to preserve

- **`start_server` is idempotent-ish**: called on an already-running server it reports current
  status rather than double-spawning. Keep that — the panel calls it on a toggle.
- **`get_status` reaps the child** via `try_wait()`, so a server that exited on its own is
  detected on the next poll. Removing that makes the panel lie.
- **`Status` carries the whole panel state** (`running`, `url`, `host`, `port`, `message`) so the
  UI re-renders from one value after every action. Don't split it.
- **Settings load falls back to defaults on every failure path** — unresolvable config dir,
  missing file, unparseable JSON. That's deliberate (a corrupt settings file shouldn't brick the
  launcher) and it means **a reset port is silent**. Documented in
  [USER-GUIDE.md](USER-GUIDE.md); if you add a warning, update it.
- **`stop_server` / `quit_app` kill the child outright.** There's no graceful shutdown. If a
  consuming app ever needs one, that's a contract change affecting all three.
- **`cwd` defaults to the binary's directory**, and both config-file apps override it to their
  repo root so their relative paths resolve. Don't change the default without checking those.

---

## 7. Conventions

- Public repo. "Commit" means commit **and** push.
- Consuming apps ship their own `launcher/SIGNING.md`; keep the Gatekeeper note accurate there
  too when it changes here.

---

## See also

- [API.md](API.md) — the launcher contract and the Tauri command surface
- [adding-an-app.md](adding-an-app.md) — wrapping another app
- [USER-GUIDE.md](USER-GUIDE.md) — the operator view
- [`AGENTS.md`](../AGENTS.md) — LLM onboarding
