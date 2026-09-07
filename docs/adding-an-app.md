# Adding an app to av-launcher

av-launcher is app-agnostic. Everything specific to a supervised server lives in
one `launcher.toml`. This doc explains the schema and the three injection modes,
and walks through the fleet configs shipped in [`../launchers/`](../launchers/).

## Where the config comes from

At startup the launcher resolves its config in this order:

1. `$AV_LAUNCHER_CONFIG` (a path)
2. `./launcher.toml` in the working directory (this is `src-tauri/` under `tauri dev`)
3. `launcher.toml` next to the built executable

So during development you can target any app without editing files:

```bash
AV_LAUNCHER_CONFIG=launchers/flock.toml npm run tauri dev
```

For a distributable build, copy the app's config to `src-tauri/launcher.toml`
(and swap `src-tauri/icons/`) before `npm run tauri build`.

## Schema

```toml
[app]
name = "flock"                     # shown in the panel + tray
command = "/abs/path/to/binary"    # or a command on PATH ("node")
args = ["{config}"]                # argv; supports {host} {port} {config}
url = "http://{host}:{port}/"      # what "Launch GUI" opens and the panel shows
default_port = 8080
cwd = "/abs/path/to/repo"          # working dir for the child (optional)

[inject]
mode = "configfile"                # configfile | env | args
```

`{host}` / `{port}` are substituted everywhere; `{config}` is replaced with the
path to the rendered config file (configfile mode only).

## The three injection modes

How does the *chosen* host:port actually reach the server? Different apps expect
it differently, so pick the matching mode.

### `configfile` — patch a key in the app's own TOML

The launcher reads the app's config as a template, overwrites one dotted key
with `host:port`, writes a rendered copy into its app-config dir, and exposes
that path as `{config}`. Comments and untouched keys are preserved
(via `toml_edit`).

```toml
[inject]
mode = "configfile"
[inject.configfile]
template = "/abs/path/config/example.toml"
set_key  = "web.bind"        # dotted path; "bind" for a top-level key
value    = "{host}:{port}"
```

* **srt-router** — `set_key = "web.bind"` (nested), arg `--config {config}`.
* **flock** — `set_key = "bind"` (top-level), positional arg `{config}`.

Both are covered by unit tests in `src-tauri/src/config.rs`.

### `env` — set environment variables

For servers configured by env (no file to patch).

```toml
[inject]
mode = "env"
[inject.env]
RFUTILS_SERVER_PORT = "{port}"
RFUTILS_HOST        = "{host}"
```

* **RFutils** (Node) uses this.

### `args` — placeholders already in argv

For a plain server that takes `--host` / `--port` flags directly.

```toml
[app]
args = ["--host", "{host}", "--port", "{port}"]
[inject]
mode = "args"
```

* **WebLinked** uses this, with one addition worth copying: the app has its own
  window (its control page, served by the process itself), so the config passes
  `--headless` alongside the injected host and port. An app that can show its
  own UI needs telling not to, or the tray ends up supervising a process that
  has already put a second, unmanaged copy of the UI on screen.

## A static site instead of a server: `[serve]`

The fleet's browser tools — Aspect Calc, Pixel Peeker, Negative Space and the
rest — are static pages with nothing to run. A tray app for one of them still
needs *something* to serve `dist/` on the chosen interface and port, and the
three modes above all supervise a child process. Bundling a static-server
binary beside the site would be exactly the shape the Gatekeeper note in
`AGENTS.md` §5 warns about: an unsigned helper inside a `.app` is quarantined
with it and killed silently on a clean Mac.

So the launcher serves the directory itself, in-process. No child, no
`[inject]`, no `command`:

```toml
[app]
name = "Aspect Calc"
default_port = 8520

[serve]
mode = "static"
dir = "{resource}/site"          # or an absolute path in development
# headers = "{resource}/site/_headers"   # default: _headers inside dir, if present
# index = "index.html"
not_found = "none"               # "spa" serves the index for any unknown path
```

What it does: GET and HEAD for files under `dir`, checked after percent
decoding and canonicalisation so `%2e%2e%2f` cannot walk out of it; a
directory serves its index; the site's Cloudflare `_headers` file is honoured
— same CSP, same cache policy as the hosted copy — and never served itself.
`not_found` takes the same two values as the fleet's `not_found_handling`.
There are no ranges, no compression and no keep-alive, on purpose: a browser
tool is a few hundred kilobytes on a LAN.

The panel is unchanged. Start binds, Stop releases the port, Open opens the
URL, and a serving thread that stops for any reason is reported as Stopped
rather than believed. See [`../launchers/static-site.toml`](../launchers/static-site.toml).

For a shipped build, bundle the built site as a resource (a `site/**` entry in
`tauri.conf.json`'s `bundle.resources`) and point `dir` at `{resource}/site`.
The site is data, not an executable, so nothing about it needs an execute bit
or a signature of its own.

## Host / interface resolution

The **GUI Interface** dropdown lists every bindable IPv4 interface plus an
"All interfaces (0.0.0.0)" entry:

* A **specific interface** → the server binds that IP and the URL shows that IP.
* **All interfaces** → the server binds `0.0.0.0` and the URL shows your primary
  non-loopback IP (so the link is still clickable).

## Checklist for a new app

1. Copy the closest example from `launchers/`.
2. Set `[app].name`, `command`, `args`, `default_port`, `cwd`.
3. Choose the `[inject]` mode and fill its block — or, for a static site,
   a `[serve]` block instead of both `command` and `[inject]`.
4. Confirm the server's URL scheme in `[app].url`.
5. (For a shipped build) replace `src-tauri/icons/` with the app's icon —
   `npm run tauri icon path/to/icon.png` regenerates every size.
6. If it's a `configfile` app with an unusual key path, add a test case in
   `config.rs` mirroring the `flock`/`srt-router` ones.
7. Rewrite the `NSLocalNetworkUsageDescription` string in
   `src-tauri/Info.plist` so it names this app. macOS shows it verbatim when
   asking the user, and without the key a double-clicked app is denied LAN
   traffic with no prompt and no error — which no test run from a terminal can
   reproduce, because a terminal-launched process inherits the terminal's own
   permission.
