# Celestial Q Siege

Touch-first, real-time **asymmetric strategy-RPG** for Android. One side is a party of five angels, moved as a single squad. The other side is a demon dungeon master — an AI budget-director in this build — that spends Dark Elixir on traps, summons, and curses, then becomes Lucifer.

Built with **Godot 4.7**. Distributed as a sideloadable APK.

> **Status: Prototype 0 (Combat Lab).** One branching dungeon, the angel command loop, twin elixir, an AI director, one push objective, and the Lucifer echo. Placeholder shapes, not final art. No networking yet: the sim already takes commands from either side, so a human demon can be a transport layer later.

---

## Play

Open the project in Godot 4.7.2 and run `Main.tscn` (landscape, 1280×720). A briefing covers the loop; **Begin the siege** starts the clock. Idle time in a cleared room feeds the demon, so the briefing does not tick the sim.

| Input | Action |
| --- | --- |
| Tap ground | Move the squad (deterministic path). |
| Tap a doorway | Commit to that branch for 3 seconds. |
| Tap an enemy | Focus fire. There is no target-priority toggle. |
| Tap the altar node | Channel the revive charge (the altar is in the demon's strongest room). |
| Shield / Heal / Cleanse / Detect / Burst | Contextual commands. Each routes to the angel who owns it. |
| Tap a portrait | Show that angel's three actives. Back returns to the shared bar. |
| Tight / Spread / Column | Persistent stance. |
| Scatter Roll / Phalanx Push | Short-cooldown maneuvers. They spend no elixir and work while silenced. |
| 1–5, Z, X, Q/W/E | Same commands from a keyboard. |
| 1x button | Cycle lab speed 1x / 2x / 3x. |
| Space | Pause. R restarts after the outcome panel. |

Fog shows the current room and the next doorway. Traps stay hidden until Azrael's detect aura, a Detect pulse, or the lead angel steps on the tile. Curses show a cast bar before they land. Summons are visible when they spawn.

Fork branches: **Still air** (traps), **Skittering** (a committed summon), **Whispers** (a committed curse). They reconverge. The altar banks one revive, spent automatically on the next death. Entering the throne makes the director descend. Lucifer's pattern and the one echo wave follow what the demon spent during the crawl. New curses stop. The trap cap drops. Killing Lucifer wins; a full wipe loses.

### Headless checks

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

`res://tests/smoke.gd` only validates the map and advances 100 ticks. The suite covers determinism, fog, elixir (cap, no rubber-band), stance vs traps, curse telegraph, cleanse order, route lock, anti-turtle, echo budgeting, altar revive, and a scripted angel policy that can win.

---

## Project layout

| Path | Purpose |
| --- | --- |
| `sim/` | Authoritative tick sim. Integer positions (milli-tiles) and elixir (milli). Commands only. |
| `sim/combat_sim.gd` | Map, units, abilities, traps, curses, Lucifer, snapshots. |
| `sim/director.gd` | Demon AI. Same `submit()` path a human demon will use. |
| `sim/dungeon_map.gd` | The one dungeon: start, fork, three branches, altar, throne. |
| `game/` | Rendering and touch input. Reads snapshots; never decides combat. |
| `tests/` | Headless suite and the competent-angel policy. |
| `project.godot` | Godot 4.7, Mobile renderer, landscape 1280×720. |
| `export_presets.cfg` | Android preset named **`Android`**. |
| `scripts/build-apk.sh` | One-command debug APK. |
| `.github/workflows/build-apk.yml` | Builds and uploads an APK on push to `main` and on pull requests. |

### Android export settings

- Package name: `me.elitesavior.celestialqsiege`
- App name: `Celestial Q Siege`, version `0.1.0` (versionCode `2`)
- Architectures: `arm64-v8a` + `armeabi-v7a`
- Standard (non-Gradle) export. Min SDK 24 / target SDK 36.

## Building the APK

```bash
scripts/build-apk.sh          # -> build/CelestialQSiege-debug.apk
scripts/build-apk.sh release  # needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
```

No root needed. First run downloads ~1.6 GB of tools into `~/.cache/cqs-godot-tools`. The script finishes with `apksigner verify`.

CI uses [`barichello/godot-ci:4.7.2`](https://github.com/abarichello/godot-ci). It imports the project, exports the **Android** preset, and uploads `celestial-q-siege-apk-<sha>`.

### Not done yet (planned)

- **Release signing.** Builds are debug-signed. Repo secrets, when added: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`.
- **GitHub Release publishing.** Not wired. Planned: keep two recent versions, label tested vs untested, publish untested builds as pre-releases.
- **Networking, human demon, remaining milestones.** Out of Prototype 0. See the design notes below.

## Notes for contributors / agents

- Keep the export preset name exactly `Android`.
- Commit `*.import` and `*.uid`. `.godot/` is cache and is ignored.
- If you bump Godot, update `GODOT_VERSION`, the workflow image tag, and `config/features` in `project.godot`.
- Do not put gameplay rules in `game/`. Both sides issue commands into `CombatSim.submit`.

### Calls made for this lab

- Portrait inspect is view state. It does not change the sim.
- Detect is a paid wide pulse, and the same button disarms a revealed trap in range.
- The Dark bar is visible here so the solo lab is readable. A real 1v1 would hide it.
- Pacing is compressed versus the 8–12 minute target. The throne is about a minute away for a direct policy.
- Uriel's beam tracks the focus target. Finger-steering is deferred.
- The altar charge auto-spends on the next death (short delay, half health). It does not rewind a death.
- Column eats spikes on the lead angel and suffers longer snares.
- Purifying shrines from the design's section 19 are not in this build.
- Gabriel's kit is cleanse, self-shield, emergency res, plus an always-on party damage aura. The active damage buff was dropped to keep three actives.
