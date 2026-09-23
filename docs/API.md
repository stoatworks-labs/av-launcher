# av-launcher — Interfaces

Two surfaces: the **launcher config** that a consuming app writes, and the **Tauri command
API** the panel UI talks to.

> **The config schema, the three injection modes and host/interface resolution are documented in
> [adding-an-app.md](adding-an-app.md)** — that is the authority and is linked, not restated. This
> covers the runtime contract around it.

| § | Interface | Source |
|---|---|---|
| [1](#1-the-launcher-contract) | The launcher contract | `src-tauri/src/config.rs`, `launchers/*.toml` |
| [2](#2-tauri-command-api) | Tauri command API | `src-tauri/src/lib.rs`, `src/main.js` |
| [3](#3-persisted-settings) | Persisted settings | `src-tauri/src/lib.rs` |

---

## 1. The launcher contract

> **⚠ This is a shared shell consumed by multiple apps.** `srt-router`, `flock` and `RFutils`
> each ship it as their *own* desktop app, with the server embedded (and for RFutils, an embedded
> Node runtime too).
>
> **A change here is not a change to one product — it lands in three. Keep the launcher API
> stable.** Before altering anything in the config or launcher contract, check `launchers/*.toml`
> and consider what each consuming app expects.

**The launcher itself knows nothing about any particular server.** Each supervised app is
described by a small `launcher.toml` saying how to start the binary and — crucially — **how to
inject the chosen host:port.**

### Which config is loaded

`src-tauri/launcher.toml` is the **active** config for a build. To target another app without
editing it:

```bash
AV_LAUNCHER_CONFIG=launchers/flock.toml npm run tauri dev
```

Ready-made configs live in `launchers/`. Each is also a worked example of one injection mode:

| File | Mode | Illustrates |
|---|---|---|
| `srt-router.toml` | `configfile` | a **nested** key (`web.bind`) and `--config <path>` |
| `flock.toml` | `configfile` | a **top-level** key (`bind`) and a **positional** config arg |
| `rfutils.toml` | `env` | `RFUTILS_SERVER_PORT` / `RFUTILS_HOST`, no config file at all |

Those differences are the point: the same shell drives three servers whose command lines and
config shapes have nothing in common.

### Defaults worth knowing

| Field | Default |
|---|---|
| `app.url` | `http://{host}:{port}/` |
| `app.default_port` | `8080` |
| `app.cwd` | **the binary's directory** |
| `inject.configfile.value` | `{host}:{port}` |
| `app.theme` | anything omitted falls back to the shell's built-in defaults |

> **`cwd` matters more than it looks.** Both `srt-router` and `flock` set it to their repo root
> **so their own relative paths resolve** (`state/routes.json`, `data/registry.json`). A server
> that reads a relative path and is started from the wrong directory fails in a way that looks
> like a launcher bug.

Placeholders `{host}`, `{port}` and `{config}` are substituted in `args`; `{host}`/`{port}` in
`url`, in `env` values and in the `configfile` value.

`app.theme` is a plain map of CSS custom-property name → value (`bg`, `panel`, `panel-2`,
`border`, `text`, `muted`, `dim`, `accent`, `accent-soft`, `good`), applied to the panel so each
launcher matches its app's own web UI.

---

## 2. Tauri command API

The frontend (`src/main.js`) reaches the Rust shell through eleven commands. Everything returns
`Result<_, String>` unless noted — an `Err` is the launcher's own trouble (unreadable config,
poisoned lock) and surfaces as a flash message. A *start that fails* is not an `Err`: it is a
Stopped `Status` carrying a `failure`, which the panel shows until the next Start, Stop or
settings change (see below).

| Command | Returns | Notes |
|---|---|---|
| `get_app_info` | `{ name, default_port, url_template, theme }` | static, read from the config |
| `list_interfaces` | `Interface[]` | **infallible** — returns a list, never an error |
| `get_settings` | `{ port, interface }` | falls back to defaults if nothing persisted |
| `save_settings(port, interface)` | — | writes the JSON settings file |
| `get_status` | `Status` | |
| `start_server` | `Status` | |
| `stop_server` | `Status` | |
| `open_gui` | — | opens the resolved URL in the default browser |
| `fit_panel(height)` | — | resizes the panel window to `height` logical px, keeping its width and top-left; the panel grows to show a failure's output and shrinks back |
| `hide_window` | — | **infallible** |
| `quit_app` | — | **infallible**; kills the child first |

`Status` is `{ running, url, host, port, message, failure }` — the whole panel state in one
object, so the UI re-renders from a single value after every action. `failure` is `null` while
nothing is wrong, else `{ message, detail, port_busy }`: one or two sentences for the operator,
the server's last output lines (empty when it wrote none), and whether the chosen port is held
by something else — in which case the panel keeps **Open** enabled, since what is listening
there is often this app already running.

Behaviours a caller depends on:

- **`start_server` on an already-running server reports the current status instead of
  double-spawning.** It is safe to call twice; it does not restart.
- **`start_server` probes the port before spawning.** A bind refused by the OS comes back as
  a failure worded by `io::ErrorKind` (in use / reserved or needs administrator rights /
  address not on this machine) with nothing spawned. It then watches the server for up to
  1.5 s: an exit is reported with its status and the tail of its output; answering on
  loopback ends the wait early.
- **`get_status` reaps the child** — it calls `try_wait()`, so a server that exited on its own is
  detected the next time status is polled, not silently left showing as running — and is
  reported as a failure, with its exit status and last output, until Start, Stop or a settings
  change clears it. Every failure is also logged through `tracing`.
- **`stop_server` and `quit_app` stop the child gracefully on Unix**: SIGTERM, up to 3 s
  (`STOP_GRACE`) polling `try_wait`, then SIGKILL. Every exit path — Stop, the panel's Quit, the
  tray's Quit, ⌘Q and Dock quit (`RunEvent::ExitRequested`/`Exit`) — goes through
  `AppState::shutdown()`, so they all behave the same. Windows keeps `TerminateProcess`.
- **`open_gui` resolves the URL fresh** rather than using the last-rendered one.

`Interface` is `{ name, ip, label }`, where `name` is an interface (`en0`) **or the literal
`all`** for the `0.0.0.0` pseudo-entry, and `label` is a display string like `en0: 10.147.17.93`.

---

## 3. Persisted settings

`{ port, interface }` as JSON, in the **OS app-config directory** (`app_config_dir()`).

**Every failure path falls back to the default silently:**

- config dir can't be resolved → defaults;
- file missing → defaults;
- file present but **unparseable** → defaults.

Defaults are `port = app.default_port` and `interface = "all"`.

So a corrupted settings file presents as "my port reset itself", with no error. `save_settings`
*does* return an error if the write fails, but nothing re-reads to confirm.

---

## See also

- [adding-an-app.md](adding-an-app.md) — the config schema, injection modes, host resolution
- [USER-GUIDE.md](USER-GUIDE.md) — using a launcher-wrapped app
- [DEVELOPING.md](DEVELOPING.md) — the ripple rule and the Gatekeeper trap
