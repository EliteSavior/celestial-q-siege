# Celestial Q Siege

Touch-friendly, real-time **1v1 asymmetric strategy-RPG** for Android — **Angels vs Demons**.
One player leads a party of five celestial heroes into a dungeon; the other player *is* the dungeon:
a live demon-lord dungeon master who fights back in real time and finally becomes the boss.

Built with **Godot 4** and developed incrementally by Cursor cloud agents. Distributed as a sideloadable APK.

> **Status: build-pipeline scaffolding only.** There is no game logic yet. The app just shows a
> "Celestial Q Siege" title screen, to prove the Cursor → Godot → APK pipeline works end to end.

Design doc: see `docs/DESIGN.md` (rough draft v0.1; to be committed separately).

---

## Project layout

| Path | Purpose |
| --- | --- |
| `project.godot` | Godot 4.7 project config — **Mobile** renderer, **landscape** (sensor/user landscape on Android), 1280×720 base viewport, `canvas_items` stretch. |
| `Main.tscn` / `Main.gd` | Placeholder main scene: one full-screen label reading "Celestial Q Siege". |
| `icon.svg` | Placeholder app/launcher icon. |
| `export_presets.cfg` | One Android export preset named **`Android`** (used for both debug and release exports). |
| `scripts/build-apk.sh` | One-command APK build for a plain Linux box / Cursor cloud agent (downloads Godot, templates, JDK, Android SDK into a cache, then exports). |
| `ci/github-actions/build-apk.yml` | GitHub Actions workflow (exports the APK, uploads it as an artifact). **Staged, not active yet** — see below. |

### Android export settings

- Package name: `me.elitesavior.celestialqsiege`
- App name: `Celestial Q Siege`, version `0.0.1` (versionCode `1`)
- Architectures: `arm64-v8a` + `armeabi-v7a`
- Standard (non-Gradle) export using Godot's prebuilt Android templates — no custom Android build template needed
- Min SDK 24 / target SDK 36 (Godot 4.7 defaults)

## Building the APK (Cursor cloud agent / any Linux x86_64 box)

```bash
scripts/build-apk.sh          # -> build/CelestialQSiege-debug.apk (debug-signed, sideload-installable)
scripts/build-apk.sh release  # needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
```

No root needed. First run downloads ~1.6 GB of tools into `~/.cache/cqs-godot-tools` (Godot 4.7.2, its Android
export templates, Temurin JDK 17, Android cmdline-tools + build-tools 35.0.0) and writes Godot editor settings to
`~/.config/godot/`. Later runs reuse the cache. The script finishes with `apksigner verify`.

## Build pipeline (GitHub Actions)

> **Activation pending:** the workflow lives at `ci/github-actions/build-apk.yml` because the credentials used to
> scaffold this repo lacked GitHub's `workflow` scope (GitHub rejects pushes to `.github/workflows/` without it).
> To activate: move it to `.github/workflows/build-apk.yml` using credentials that have workflow permission
> (GitHub web UI, `gh auth refresh -s workflow`, or a Cursor cloud agent).

Once activated, the workflow runs on every push to `main`, on pull requests, and manually via
**Actions → Build Android APK → Run workflow**.

It runs inside the maintained [`barichello/godot-ci`](https://github.com/abarichello/godot-ci) Docker image
(pinned to `4.7.2`), which ships Godot headless, the matching export templates, the Android SDK/NDK, JDK 17 and a
debug keystore. Steps:

1. Checkout.
2. Copy the image's Godot editor settings and export templates into the runner's `$HOME`.
3. `godot --headless --import` to build the `.godot/` import cache.
4. Export:
   - **default:** `godot --headless --export-debug "Android" build/CelestialQSiege-debug.apk` (debug-signed, sideload-installable)
   - **if release-signing secrets are set:** `godot --headless --export-release "Android" build/CelestialQSiege-release.apk`
5. Upload the APK as a workflow artifact named `celestial-q-siege-apk-<commit sha>` (kept 30 days).

To get the APK: open the workflow run on the **Actions** tab → **Artifacts** → download → unzip → sideload the `.apk`
(enable "Install unknown apps" on the device).

### Not done yet (planned)

- **Release signing.** Builds are debug-signed for now. To switch CI to release-signed APKs, add these repo secrets:
  `ANDROID_KEYSTORE_BASE64` (`base64 -w0 release.keystore`), `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`.
  The workflow passes them to Godot via `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars. Never commit a keystore.
- **GitHub Release publishing.** Not wired up yet. Planned policy: keep the two most recent versions, label each
  release *tested* or *untested*, always keep at least one tested working version, and publish untested builds as
  GitHub **pre-releases**.

## Building an APK locally

Requirements: Godot **4.7.2** (standard, not .NET), the 4.7.2 export templates, JDK 17, and an Android SDK with
`platform-tools` + `build-tools` (e.g. 35.0.0).

1. In Godot: **Editor → Editor Settings → Export → Android**, set *Java SDK Path*, *Android SDK Path*, and a debug
   keystore (Godot can generate one).
2. Export from the editor (**Project → Export → Android**) or headless:

   ```bash
   godot --headless --import
   godot --headless --export-debug "Android" build/CelestialQSiege-debug.apk
   ```

3. Install: `adb install -r build/CelestialQSiege-debug.apk`

## Notes for contributors / agents

- Keep `export_presets.cfg` committed and the preset name exactly `Android` (CI depends on it).
- Commit `*.import` and `*.uid` files (they hold import settings / resource IDs); `.godot/` is cache and is ignored.
- If you bump the Godot version, update `GODOT_VERSION` **and** the container image tag in the workflow, plus
  `config/features` in `project.godot`.
