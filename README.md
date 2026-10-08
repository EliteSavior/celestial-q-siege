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
| `.github/workflows/build-apk.yml` | CI: exports the APK and uploads it as a workflow artifact. |

### Android export settings

- Package name: `me.elitesavior.celestialqsiege`
- App name: `Celestial Q Siege`, version `0.0.1` (versionCode `1`)
- Architectures: `arm64-v8a` + `armeabi-v7a`
- Standard (non-Gradle) export using Godot's prebuilt Android templates — no custom Android build template needed
- Min SDK 24 / target SDK 36 (Godot 4.7 defaults)

## Build pipeline (GitHub Actions)

The workflow `.github/workflows/build-apk.yml` runs on every push to `main`, on pull requests, and manually via
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
