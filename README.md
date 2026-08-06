# av-launcher

> **AI-assisted project.** This codebase was created with [Claude](https://claude.com/claude-code)
> (Anthropic), directed and reviewed by a human author. The Rust backend
> compiles and the panel UI has been exercised via its mock backend; the
> full tray app has **not yet** been run end-to-end against a live server on
> the target machine.

A menu-bar **tray launcher** shell for the local web-server apps in this fleet
(srt-router, flock, RFutils, …). It gives any of them a small panel to pick a
**network interface** and **port**, **Start/Stop** the server, **Open** the web
UI, and live in the **system tray** — without each app building its own.

The panel is an original card design that **themes itself to each app's own web
UI** (palette carried in `launcher.toml`), built with
[Tauri v2](https://tauri.app) (Rust + a tiny HTML/CSS/JS panel) — a small native
app, not a bundled browser.

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/panel-srt-router.png" width="260" alt="Launcher panel themed for SRT Router (running)"><br><sub>srt-router · running</sub></td>
    <td align="center"><img src="docs/screenshots/panel-flock.png" width="260" alt="Launcher panel themed for flock (running)"><br><sub>flock · running</sub></td>
    <td align="center"><img src="docs/screenshots/panel-rfutils.png" width="260" alt="Launcher panel themed for RFutils (stopped)"><br><sub>RFutils · stopped</sub></td>
  </tr>
</table>

*The same shell, themed per app from `launcher.toml`. Rendered from the exact
panel HTML/CSS via [`scripts/screenshot.sh`](scripts/screenshot.sh) (headless Chrome).*

<!-- downloads:start -->

## Download

**[v0.1.1](https://github.com/stoatworks-labs/av-launcher/releases/tag/v0.1.1)** — prebuilt for macOS, Windows and Linux. Pick your platform:

<details>
<summary><b>macOS</b> — Apple Silicon, Intel</summary>

| Build | Download | Size |
| --- | --- | --- |
| Apple Silicon · .dmg disk image | [`av-launcher-0.1.1-macos-aarch64.dmg`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/av-launcher-0.1.1-macos-aarch64.dmg) | 3.7 MB |
| Intel · .dmg disk image | [`av-launcher-0.1.1-macos-x86_64.dmg`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/av-launcher-0.1.1-macos-x86_64.dmg) | 4.0 MB |
| Apple Silicon · .pkg installer | [`av-launcher-0.1.1-macos-aarch64.pkg`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/av-launcher-0.1.1-macos-aarch64.pkg) | 3.7 MB |
| Intel · .pkg installer | [`av-launcher-0.1.1-macos-x86_64.pkg`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/av-launcher-0.1.1-macos-x86_64.pkg) | 4.0 MB |

</details>

<details>
<summary><b>Windows</b> — x64</summary>

| Build | Download | Size |
| --- | --- | --- |
| x64 · .exe installer | [`AV.Launcher_0.1.1_x64-setup.exe`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/AV.Launcher_0.1.1_x64-setup.exe) | 2.5 MB |
| x64 · .msi installer | [`AV.Launcher_0.1.1_x64_en-US.msi`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/AV.Launcher_0.1.1_x64_en-US.msi) | 3.8 MB |

</details>

<details>
<summary><b>Linux</b> — x64</summary>

| Build | Download | Size |
| --- | --- | --- |
| x64 · .deb package (Debian/Ubuntu) | [`AV.Launcher_0.1.1_amd64.deb`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/AV.Launcher_0.1.1_amd64.deb) | 5.0 MB |
| x64 · AppImage | [`AV.Launcher_0.1.1_amd64.AppImage`](https://github.com/stoatworks-labs/av-launcher/releases/download/v0.1.1/AV.Launcher_0.1.1_amd64.AppImage) | 82 MB |

</details>

All builds, checksums and release notes: [github.com/stoatworks-labs/av-launcher/releases](https://github.com/stoatworks-labs/av-launcher/releases).

macOS builds are signed and notarised and open normally. The Windows builds are unsigned, so SmartScreen warns once — see [Unsigned builds — Gatekeeper, SmartScreen & Defender Firewall](#unsigned-builds--gatekeeper-smartscreen--defender-firewall) for the one-time click-through.

<!-- downloads:end -->

## Shipped apps

Each fleet app ships this shell as its **own desktop app**, with the server
embedded so the download is one self-contained thing (no linking, nothing to
install). Built and released from each repo:

| app | source | download | server embedding |
| --- | --- | --- | --- |
| srt-router | [`launcher/`](https://github.com/stoatworks-labs/srt-router/tree/main/launcher) | [v0.1.0](https://github.com/stoatworks-labs/srt-router/releases/tag/v0.1.0) | native binary bundled |
| flock | [`launcher/`](https://github.com/stoatworks-labs/flock/tree/main/launcher) | [v0.1.0](https://github.com/stoatworks-labs/flock/releases/tag/v0.1.0) | native binary bundled |
| RFutils | [`launcher/`](https://github.com/stoatworks-labs/RFutils/tree/main/launcher) | [v0.1.0](https://github.com/stoatworks-labs/RFutils/releases/tag/v0.1.0) | Node runtime + app embedded |

This repo remains the canonical template/shell. A shipped `.app` finds its
baked-in config, theme, and server (a native binary, or an embedded Node runtime
+ ESM bundle) via bundled resources — the `{resource}` placeholder in
`launcher.toml` points at them. See [`scripts/screenshot.sh`](scripts/screenshot.sh)
for how the README panel images are rendered.

## How it works

The launcher itself is **app-agnostic**. It supervises a child process and
knows nothing about any particular server. Each app it can launch is described
by a single [`src-tauri/launcher.toml`](src-tauri/launcher.toml), which says how
to start the binary and — the important part — **how to inject the chosen
`host:port`**. Three modes cover the whole fleet:

| mode | what it does | fleet example |
| --- | --- | --- |
| `configfile` | patches a dotted key in the app's own TOML, then passes the rendered copy as the config arg | **srt-router** (nested `web.bind`, `--config`), **flock** (top-level `bind`, positional arg) |
| `env` | sets environment variables | **RFutils** (`RFUTILS_SERVER_PORT` / `RFUTILS_HOST`) |
| `args` | `{host}`/`{port}` placeholders already in `[app].args` | **WebLinked** (`--bind` / `--port`, plus `--headless`) |

Ready-made configs for each app live in [`launchers/`](launchers/). To point the
launcher at one you only pick a config and swap the icon — no Rust changes.
(A future version can ship one bundled app per fleet member, each with its own
baked-in `launcher.toml` + icon.)

See [docs/adding-an-app.md](docs/adding-an-app.md) for the full schema and a
new-app checklist.

### What the panel does

- **GUI Interface** dropdown — every bindable IPv4 interface, plus an
  "All interfaces (0.0.0.0)" entry. Choosing a specific interface binds to that
  IP and shows it in the URL; "All" binds `0.0.0.0` and shows your primary LAN IP.
- **Port** — persisted per app.
- **Start / Stop** — spawns/kills the server child process and supervises it
  (detects if it exits on its own).
- **Launch GUI** — opens the resolved URL in your default browser.
- **Hide** — hides to the tray; **Quit** — stops the server and exits.
- Interface/port are locked while the server is running.

Settings persist to the OS app-config dir
(`~/Library/Application Support/com.allansargeant.av-launcher/` on macOS), along
with the rendered config the launcher hands to the server.

## Running (dev)

```bash
cd ~/Projects/av-launcher
npm install                 # first time only (fetches @tauri-apps/cli)
npm run tauri dev           # launches the panel + tray
```

`launcher.toml` is read from the working directory (`src-tauri/` under
`tauri dev`), or from `$AV_LAUNCHER_CONFIG`, or next to the built executable.

The bundled `launcher.toml` targets srt-router and expects its debug binary at
`~/Projects/srt-router/target/debug/srtrouter` — build it once with
`cargo build` in that repo (or edit `command`/`cwd` to taste).

To target another fleet app, point at its config in [`launchers/`](launchers/):

```bash
AV_LAUNCHER_CONFIG=launchers/flock.toml   npm run tauri dev   # flock
AV_LAUNCHER_CONFIG=launchers/rfutils.toml npm run tauri dev   # RFutils
```

## Building a distributable app

```bash
npm run tauri build         # produces a .app / .dmg (macOS), etc.
```

By default the `.app`/`.dmg`/`.exe` this produces is **not code-signed or
notarized**, so macOS and Windows will each warn once — see
[Unsigned builds](#unsigned-builds--gatekeeper-smartscreen--defender-firewall)
below, and [docs/UNSIGNED.md](docs/UNSIGNED.md) for the full walkthrough.

**Signing it yourself:** Tauri signs + notarizes automatically when you set the
Apple credentials as env vars / GitHub Actions secrets — `APPLE_CERTIFICATE`,
`APPLE_CERTIFICATE_PASSWORD`, `APPLE_SIGNING_IDENTITY`, `APPLE_ID`,
`APPLE_PASSWORD`, `APPLE_TEAM_ID`. RFutils' desktop app (which is built on this
shell) documents the full flow in
[its `launcher/SIGNING.md`](https://github.com/stoatworks-labs/RFutils/blob/main/launcher/SIGNING.md).
For an *ad-hoc* local-only signature: `codesign --force --deep --sign - "<App>.app"`.
On Windows, clearing SmartScreen needs an Authenticode code-signing certificate.

## Tests

```bash
cd src-tauri && cargo test  # covers host:port injection for all three modes,
                            # incl. flock (top-level bind) vs srt-router (web.bind)
```

## Documentation

| Doc | Contents |
|---|---|
| [docs/USER-GUIDE.md](docs/USER-GUIDE.md) | Using the panel, interface/port choices, and the Gatekeeper trap |
| [docs/API.md](docs/API.md) | The launcher contract and the Tauri command surface |
| [docs/DEVELOPING.md](docs/DEVELOPING.md) | Why changes ripple across three apps, and the behaviours to preserve |
| [docs/adding-an-app.md](docs/adding-an-app.md) | The config schema, the three injection modes, host resolution |

## Adopting it for another app

1. Copy the closest config from [`launchers/`](launchers/) (or the active
   [`src-tauri/launcher.toml`](src-tauri/launcher.toml)).
2. Set `[app].name`, `command`, `args`, `default_port`, `cwd`, and the
   `[inject]` block. Full guide: [docs/adding-an-app.md](docs/adding-an-app.md).
3. Replace `src-tauri/icons/` with the app's icon
   (`npm run tauri icon path/to/icon.png` regenerates all sizes).

## Layout

```
src/                 panel UI (index.html, styles.css, main.js)
launchers/           ready-made per-app configs (srt-router, flock, rfutils)
docs/adding-an-app.md   schema + injection modes + new-app checklist
src-tauri/
  launcher.toml      the ACTIVE per-app config (this build → srt-router)
  src/config.rs      config parsing, interface enumeration, host:port injection (+ tests)
  src/lib.rs         Tauri commands, process supervision, system tray
```

## Unsigned builds — Gatekeeper, SmartScreen & Defender Firewall

The release binaries are **not code-signed or notarized** — that needs paid Apple
and Microsoft developer certificates this project doesn't carry. The downloads are
fine; the OS just can't identify the publisher, so it warns you the first time.

- **macOS** — *"cannot be opened because the developer cannot be verified"*.
  Right-click the app → **Open** → **Open**, or clear the flag:
  `xattr -dr com.apple.quarantine "/Applications/AV Launcher.app"`
- **Windows** — SmartScreen shows *"Windows protected your PC"* →
  **More info** → **Run anyway**.
- **Windows Defender Firewall** — first launch pops *"Allow AV Launcher to communicate
  on these networks"*. Tick **Private** (and **Domain** on a managed network) — AV
  Launcher needs it to bind the wrapped app's web server to the interface you chose in
  the panel. Deny it and the app will start but be reachable only from the machine it
  runs on.
- **Linux** — no signing gate.

Per-artifact steps, self-signing, checksum verification and the Defender Firewall reset
procedure: **[docs/UNSIGNED.md](docs/UNSIGNED.md)**.

<!-- attributions:start -->
This project is built on other people's work — see [ATTRIBUTIONS.md](ATTRIBUTIONS.md).
<!-- attributions:end -->
