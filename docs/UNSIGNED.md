# Running AV Launcher — Gatekeeper, SmartScreen and firewalls

macOS builds are signed and notarised, so they just open. The Windows builds are
unsigned and SmartScreen will object once. This page covers that, the firewall prompts,
and what to do with a copy you built yourself.

## Why the Windows builds are unsigned

macOS signing is covered: this project carries an Apple Developer Program membership and
a *Developer ID Application* certificate, and every macOS artefact is notarised by Apple.

Windows is not. An Authenticode certificate (OV, or EV to skip building SmartScreen
reputation) runs ~$200–500/year, and the certificate authorities will only issue one to a
registered legal entity — which this project is not. Nothing is wrong with the Windows
downloads; Windows simply has no publisher identity to check them against, so it assumes
the worst once and then remembers your answer.

> If you'd rather not trust a stranger's binary at all, every release is reproducible
> from source — see the build instructions in the README.

## macOS — Gatekeeper

**A released `.dmg` or `.pkg` needs none of this.** What follows applies to a build you
made yourself, or to a download from before the releases were signed — and it matters
more for this app than most, because **approving an unsigned `.app` does not unquarantine
the helper binaries inside it**. The app then launches, looks fine, and its server never
starts, with no error anywhere.

macOS quarantines anything downloaded from a browser, then refuses to launch it because
**"the developer cannot be verified"**. Any one of these clears it:

**1. Right-click → Open** (simplest, per-app, once)

Right-click (or Control-click) the app → **Open** → **Open** in the dialog. The plain
double-click won't offer this — it has to be the context menu.

**2. Clear the quarantine flag** (scriptable, good for deployment)

```sh
xattr -dr com.apple.quarantine "/Applications/AV Launcher.app"
```

**3. Approve it after the fact**

Launch it once, let macOS block it, then go to **System Settings → Privacy & Security**
and click **Open Anyway** next to the message about the blocked app.

### `.pkg` installers

A `.pkg` from an unidentified developer is blocked the same way. Right-click → **Open**,
or clear the flag on the installer itself before running it:

```sh
xattr -dr com.apple.quarantine ~/Downloads/<file>.pkg
```

### Apple Silicon and the `.zip` trap

If you copy an app out of a `.zip` with Finder the quarantine flag comes with it. Prefer the
`.dmg` or `.pkg`, or run the `xattr` command above after copying.

## Windows — SmartScreen

**"Windows protected your PC — Microsoft Defender SmartScreen prevented an
unrecognised app from starting."** Click **More info**, confirm the publisher line reads
*Unknown publisher*, then **Run anyway**.

To clear the mark-of-the-web before running instead — useful when the block is silent
rather than a prompt:

```powershell
Unblock-File .\<file>.exe
```

Or right-click the file → **Properties** → tick **Unblock** → **OK**. If you downloaded a
`.zip`, **unblock the `.zip` first, then extract** — otherwise every extracted file
inherits the flag and you'll be unblocking them one at a time.

### Defender antivirus false positives

Unsigned binaries that bundle a runtime occasionally get quarantined outright by
Defender's heuristics rather than merely warned about. If the download vanishes from
your Downloads folder, check **Windows Security → Virus & threat protection →
Protection history** and choose **Restore**. Add an exclusion for the install folder if
it keeps happening.

## Windows — Defender Firewall

AV Launcher listens on the network, so the first time it starts Windows shows:

> **Windows Defender Firewall has blocked some features of AV Launcher**
> Allow it to communicate on these networks: ☐ Private ☐ Public

Tick **Private networks** — and **Domain networks** too if the machine is on a managed
domain. AV Launcher needs this to bind the wrapped app's web server to the interface you chose in the panel.

If you deny it (or the prompt appears behind another window and times out), the app will start but be reachable only from the machine it runs on

**Leave Public unticked** unless you know you need it — that profile covers untrusted
networks like conference or hotel Wi-Fi.

### If you already clicked Cancel

The prompt does not come back. Fix it in **Windows Security → Firewall & network
protection → Allow an app through firewall → Change settings**, find the entry, tick
**Private**. If AV Launcher isn't listed, **Allow another app…** → **Browse** to the `.exe`.

Or from an elevated PowerShell:

```powershell
New-NetFirewallRule -DisplayName "AV Launcher" -Direction Inbound -Program "C:\Path\To\AV Launcher.exe" -Action Allow -Profile Private,Domain
```

To remove a bad rule and get the prompt back on next launch:

```powershell
Get-NetFirewallRule -DisplayName "*AV Launcher*" | Remove-NetFirewallRule
```

### macOS and Linux firewalls

macOS shows an equivalent one-off prompt — *"Do you want the application to accept
incoming network connections?"* — click **Allow**. It's under **System Settings →
Network → Firewall → Options** if you need to change it later. On Linux nothing prompts;
if you run a firewall, open the ports yourself (`ufw allow <port>/tcp`).

## Linux

No signing gate. Make the binary executable if you took the tarball:

```sh
chmod +x ./av-launcher
```

The `.deb` and `.rpm` packages are unsigned too, so your package manager may object:
`sudo dpkg -i <file>.deb` or `sudo rpm -i --nosignature <file>.rpm`.

## Signing it yourself

### macOS — ad-hoc (local machine only)

An ad-hoc signature stops the OS re-prompting on **your own machine**. It is **not**
notarization and will do nothing for anyone else:

```sh
codesign --force --deep --sign - "/Applications/AV Launcher.app"
```

Verify it took:

```sh
codesign -dv --verbose=4 "/Applications/AV Launcher.app"
spctl -a -vv "/Applications/AV Launcher.app"   # still reports "rejected" — ad-hoc is not notarization
```

### macOS — real signing and notarization

With an Apple Developer Program membership and a *Developer ID Application* certificate:

```sh
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" "<artifact>"
xcrun notarytool submit "<artifact>.zip" --apple-id you@example.com \
  --team-id TEAMID --password "app-specific-password" --wait
xcrun stapler staple "<artifact>"
```

Note the **hardened runtime** (`--options runtime`) — notarization rejects builds without
it, and a hardened build with an ad-hoc signature won't launch at all.

### Windows — Authenticode

```powershell
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
  /f mycert.pfx /p <password> .\<file>.exe
```

An OV certificate still needs to build SmartScreen reputation over time; an EV
certificate is trusted immediately. Neither is free.

## Verifying a download

Signing proves *who* built it; a checksum proves you got *what they built* — worth doing
even unsigned. Compare against the release notes:

```sh
shasum -a 256 <file>        # macOS / Linux
certutil -hashfile <file> SHA256   # Windows
```

You can also confirm the artifact came from this repo's CI by checking the release page it
was downloaded from — GitHub shows the workflow run that produced each asset.
