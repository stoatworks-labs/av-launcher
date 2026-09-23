# Notes

Working notes for this repo: status, decisions, and the traps that have actually bitten.
Migrated out of Claude Code's memory on 2026-08-24, so they are written in the first
person and dated by when each thing was learned — that date is usually the useful part.

Cross-cutting notes that are not specific to this repo live in
[fleet-notes](https://github.com/stoatworks-labs/fleet-notes).

*Reusable Companion-style Tauri tray launcher for the fleet's web-server apps*

**av-launcher** (~/Projects/av-launcher) — a Bitfocus Companion–style tray/splash launcher, built with **Tauri v2** (Rust backend + vanilla HTML/CSS/JS panel), that wraps the fleet's local web-server apps so users can pick a network interface + port, Start/Stop the server, Launch GUI in a browser, and run it from the system tray.

Key design: **app-agnostic**, driven by one `src-tauri/launcher.toml` per app. It supervises a child process and injects the chosen `host:port` three ways — `configfile` (patch a dotted TOML key, e.g. srt-router's `[web] bind`, via toml_edit), `env` (e.g. RFutils' `RFUTILS_SERVER_PORT`), or `args`. Interface enumeration via `if-addrs`. To retarget: edit `launcher.toml` + swap icon, no Rust changes.

Status as of 2026-07-16: Phase 1 built + **pushed public** at github.com/allansargeant/av-launcher (default branch `master`). Rust compiles clean; **injection logic unit-tested** (`cargo test` in src-tauri: 5 tests — configfile nested `web.bind`, configfile top-level `bind`, env, args, and bundled relative-path resolution). Panel UI + state machine verified via browser mock. The launcher is **bundle-portable**: relative `command`/`template` resolve against the .app resource dir, cwd defaults to a writable app-config dir, and a bundled binary's +x is restored — so a shipped `.app` carries its server binary + config and runs standalone. Still NOT run end-to-end as a real native tray window on the target machine (no GUI in the build env) — main open verification gap; but the bundled server chain WAS verified headlessly (ran each bundled binary with a host:port-patched config → HTTP 200).

**Per-repo apps shipped + redesigned (2026-07-17):** each fleet app carries a self-contained copy of the shell under `<repo>/launcher/` and ships as its OWN desktop app (product renamed from "X Launcher" to just "X"; identifier `com.allansargeant.<app>`), released as tag **`v0.1.0`** (the old `launcher-v0.1.0` tags were deleted). The tag push also triggers each repo's existing `release.yml`, which attaches cross-platform server builds alongside the desktop DMG (so one release = app + server):
- **srt-router** (main) — DMG bundles `srtrouter`; release also has standalone `srtrouter` CLI.
- **flock** (master) — DMG bundles `flock`; release CI added linux/win/mac tar/zip/deb/rpm server builds.
- **RFutils** (main) — **fully self-contained**: DMG embeds an official Node arm64 runtime (`src-tauri/node`, ~108MB, downloaded by prepare.sh) + the app tree (`src-tauri/rfutils-app/packages/{server,web}/dist`) — server esbuilt to one ESM file (`--format=esm` + require/__dirname banner so `import.meta.url` resolves), templates + built web UI mirrored in repo layout so paths resolve unchanged. launcher.toml: `command="{resource}/node"`, `args=["{resource}/rfutils-app/.../index.mjs"]`, env inject. Verified HTTP 200 + web UI served from inside the built .app. ~41MB DMG.

**Design (2026-07-17):** dropped the red Bitfocus-Companion look. New original card UI — status pill (not a giant "Running"), mono URL, app-initial mark, accent primary button — **themed per app** via `launcher.toml [app.theme]` (CSS vars applied in main.js): srt-router periwinkle `#9fb4ff`, flock emerald `#1fae63`, RFutils royal-blue `#6ea8fe`, each mirrored from that app's own web UI palette. Added `{resource}` placeholder (resolves to .app resource dir) for embedded-runtime configs. `cargo test` now 6 tests. Large embedded resources (server binaries, node, rfutils-app) are git-ignored per repo; `launcher/scripts/prepare.sh` regenerates them. Build gotchas: Tauri `bundle_dmg.sh` races if run concurrently (build DMGs sequentially); headless-Chrome screenshot needs width ≥500 (min-window quirk).

**Windows/Linux tray build fix (2026-07-18):** the shell now builds green on all of win/mac/linux (previously mac-only / broken). Two shared fixes, verified via CI on atem-fleet-admin + atem-overseer and landed in the canonical av-launcher template (`src-tauri/`): (1) **`config.rs` `with_windows_exe()`** — on Windows, resolve an extension-less bundled `command` (`node`, `bin/flock`) to its `.exe` sibling before spawning (no-op elsewhere); paired with a **`node*` resources glob** in `tauri.conf.json` so `node.exe` satisfies build-time resource validation. (2) **drop AppImage**: set `bundle.targets` to `["app","dmg","nsis","deb","rpm"]` — the AppImage bundler (linuxdeploy) needs FUSE on CI runners and fails there even with `APPIMAGE_EXTRACT_AND_RUN=1`; Linux ships `.deb`+`.rpm` (Electron builds still provide an `.AppImage` where an app has one). Propagated to atem-fleet-admin, atem-overseer, RFutils (node* glob). **srt-router/flock intentionally NOT touched** — older shell variant, native-binary, mac-only by their own `targets:["app","dmg"]`, already shipped; bringing them to win/linux is a per-app follow-up (needs their binary staged per platform).

The multi-MB server binary in `<repo>/launcher/src-tauri/bin/` is git-ignored (ships in the Release, not the repo); `launcher/scripts/prepare.sh` rebuilds+copies it. README panel screenshots are rendered by `scripts/screenshot.sh` (headless Chrome at 500px width — Chrome's ~500px min-window quirk clips narrower). DMG build gotcha: `bundle_dmg.sh` (Finder/AppleScript step) fails if two run concurrently — build DMGs sequentially. av-launcher's own `launchers/*.toml` configs remain as the canonical reference. Carries the standard AI-assisted disclaimer. See [srt router](https://github.com/stoatworks-labs/srt-router/blob/main/docs/NOTES.md) (`srt-router`), [rfutils](https://github.com/stoatworks-labs/RFutils/blob/main/docs/NOTES.md) (`RFutils`), **disclaimer scope** (working-practice note, kept in Claude memory).

**2026-08-22 — the Windows tray build was never actually RUN until now, and it did not work.** The 2026-07-18 note above calls the Windows build "green"; that meant CI *bundled* successfully. Launching the installed bundle on real Windows showed Start doing nothing at all, silently, in every `{resource}`-based launcher. Root cause and the fix across all 9 copies: [tauri resource dir verbatim path](https://github.com/stoatworks-labs/fleet-notes/blob/main/notes/reference_tauri_resource_dir_verbatim_path.md). `with_windows_exe()` was not wrong, it just could never fire. Three more Windows defects fixed in the same sweep (console window on spawn, macOS-only config path in the gear button, and two pre-existing tests that fail on Windows because the fixture interpolates a `C:\…` path into a TOML *basic* string where `\U` is an invalid escape — use a literal `'…'` string).

Test box: [win lab vm lilnasx](https://github.com/stoatworks-labs/fleet-notes/blob/main/notes/reference_win_lab_vm_lilnasx.md).

**2026-09-07 — a `[serve]` mode, so a browser tool can be a tray app.** Every one of the fleet's
browser tools now ships a container image and an Unraid template (stoatworks-unraid), and
Stoatworks Burrow wants to offer the same tools as standalone tray apps for the venue with no
internet. The shell had nothing for that: all three modes supervise a *child*, and a static site
has no process. Bundling a static-server binary beside the site was rejected before it was
written — it is the §5 Gatekeeper shape (unsigned helper inside a `.app`, SIGKILLed silently on
a clean Mac), and it would have shipped in twenty apps. So `serve.rs` serves the directory from a
thread inside the launcher: `tiny_http` (the crate Burrow's own demo server uses), GET/HEAD,
percent-decode-then-canonicalise traversal checks, the site's Cloudflare `_headers` parsed and
applied per request path (later rules override earlier, `!` removes, `*` and `:seg` patterns),
`not_found = "none" | "spa"` matching the fleet's `not_found_handling`, and the `_headers` file
itself never served. `[app].command` and `[inject]` became optional (`inject` defaults to
`args`); every shipped config still has both. `AppState` gained a `server` slot beside `child`,
`shutdown()` stops whichever exists, and `get_status` reaps the server thread the way it reaps
the child. 12 new tests; 24 total; clippy clean. **Not yet done:** no tool has been released
this way. The next steps are a `gen-launcher.mjs` in stoatworks-unraid emitting each tool's
`launcher/` from `fleet.json` (it already knows the served dir and the headers file), a bundle
with `site/**` in `bundle.resources`, and one tool opened from a *downloaded* build on a clean
Mac — the only test §5 accepts. Burrow's catalogue must not advertise the install until then.

**2026-09-17 — Start that fails now says why (port in use, server died).** Two silent
failures, found with openRCS at a show where a hand-run server held port 1432 and the tray
app's Start did nothing. (1) A child that could not bind exited within milliseconds, but
`start_server` reported Running the instant the spawn succeeded and the next poll quietly
said Stopped; its stderr was inherited, which for a Finder-launched app means /dev/null.
(2) The static mode *did* return a bind error, but the panel only flashed it and the
two-second poll wiped it. Fixed in the shell: a bind probe before spawning (mirrors the
server's own bind — verified on this Mac that std's `SO_REUSEADDR` lets a wildcard bind sit
beside a loopback listener, and that port 80 binds unprivileged, so wording follows
`io::ErrorKind` not the port number); the child's stdout/stderr piped into a 30-line tail
drained on its own threads; a 1.5 s watch after spawn (exit → quoted; loopback answers →
Running); the failure held in `AppState` and carried by `Status.failure` so the poll keeps
showing it; `Open` enabled when the port is busy; the window grows to show an output tail
(`fit_panel`, top-left pinned because `setContentSize` holds the bottom-left on macOS) and
shrinks back. Every `AppHandle`-taking function became generic over `tauri::Runtime` so the
commands run under `tauri::test::mock_builder()` with a stand-in `sh` server — 18 new tests,
42 total. **Traps:** two processes named `av-launcher` (openRCS.app + a dev build) make
System Events re-resolve `first process whose unix id is N` to the wrong twin by name; from
this session System Events saw zero windows for *every* app (Chrome included), so the
on-screen run of a real launcher was not done here — the fleet copies are proven by the
mock-runtime tests and the browser mock (`?fail=port`, `?fail=exit` in main.js). Readiness
is probed on loopback only: TN3179 makes a TCP connect to one of this machine's own LAN
addresses a local-network operation.

**2026-09-23 — Stop and Quit send SIGTERM first.** Every stop used std's `Child::kill()`, which is
SIGKILL on Unix: the server could not flush state, and whatever *it* had spawned was reparented
to launchd and kept running. packrat found it the hard way — its `rclone rcd` child and rclone
mounts outlived every Stop — and had to grow a self-re-exec guard process to survive the shell.
`stop_child` now sends SIGTERM via `libc::kill`, polls `try_wait` for up to `STOP_GRACE` (3 s),
then falls back to `kill()`; `shutdown()` takes the child out of its lock first so a status poll
during the grace is not queued behind it. All exit paths already funnelled into `shutdown()`
since 2c83ad7, so one function covers Stop, both Quits, ⌘Q and Dock quit. Windows unchanged:
`GenerateConsoleCtrlEvent` needs a console shared with the child, and a `CREATE_NO_WINDOW` child
has its own. Proven by `cargo test` (a fake server whose TERM trap stops its own child and writes
a marker, under the mock runtime; plus SIGTERM/SIGKILL-fallback unit tests, all failing when the
signal is swapped back to SIGKILL) and by the real debug binary against a Python trap server,
driven through System Events: Stop button, panel Quit, app-menu Quit (⌘Q's action) and tray Quit
each left the marker and no orphaned child.
