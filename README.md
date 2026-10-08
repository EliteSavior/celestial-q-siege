# Celestial Q Siege

Touch-first, real-time **asymmetric strategy-RPG** for Android. One side is a party of five angels, moved as a single squad. The other side is a demon dungeon master — an AI budget-director in this build — that spends Dark Elixir on traps, summons, and curses, then becomes Lucifer.

Built with **Godot 4.7**. Distributed as a sideloadable APK.

> **Status: M5 (Lucifer Phase) on the M4 director.** The director spends Dark through the same `submit()` path a human demon will use. Priority is Survive, then Protect the stake, then Exploit the stance, then Spend what is over the line. On a march that is already over the line, that spend happens before the next punish, so a cooldown cannot refill the bank. Swarms are always available. Heavies unlock after 2 rooms cleared. The one elite (Teleporter and Molten) unlocks after 4, and committing it spends Dark immediately and shows a 3-second cast bar before the unit exists. Reinforcements go into the next room, not the one being fought. Spike, snare, and hellflame are laid ahead, two to a room, and stay hidden until Azrael's aura or Detect. A trap cluster is committed the same way as the elite. Silence, Rot, and Mark each show a cast bar before they land. Entering the throne — or an early descent in the sanctum — transforms the demon lord. The rise is a 3-second tell. Then Lucifer's four buttons (hell rain, cleave, judgment, grasp) are commands on that same path, each marked for 3 seconds. The echo is shaped by the siege's trap, summon, and curse counts: a trap-heavy run keeps a heavy and lays echo traps, a summon-heavy run sends a bigger wave, a curse-heavy run leans on Judgment, and an early transform spends less Dark for a weaker Lucifer and a thinner echo. On the current tune a scripted competent party reaches Lucifer at 499.4 seconds and wins at 617.1 seconds. The boss is 117.8 seconds. That run's echo was one heavy, trap style, with two echo traps — not the capped wave. Placeholder shapes, not final art. No networking yet.

---

## Play

Open the project in Godot 4.7.2 and run `Main.tscn` (landscape, 1280×720). A briefing covers the loop; **Begin the siege** starts the clock. Idle time in a cleared room feeds the demon, so the briefing does not tick the sim.

| Input | Action |
| --- | --- |
| Tap ground | Move the squad (deterministic path). |
| Tap a doorway | Commit to that branch for 3 seconds. |
| Tap an enemy | Focus fire. Attacks themselves are automatic. |
| Portrait | That angel's HP. DOWN counts 3 seconds, then the death is final. |
| Tap the altar node | Channel the revive charge (the altar is in the demon's strongest room). |
| Shield / Heal / Cleanse / Detect / Burst | Contextual commands. Each routes to the angel who owns it. |
| Tap a portrait | Show that angel's three actives and passive. Back returns to the shared bar. |
| Drag during Uriel's beam | Steer the beam. A tap on the ground steers it too, until the channel ends. |
| Tight / Spread / Column | Persistent stance. |
| Scatter Roll / Phalanx Push | Short-cooldown maneuvers. They spend no elixir and work while silenced. |
| 1–5, Z, X, Q/W/E | Same commands from a keyboard. |
| 1x button | Cycle lab speed 1x / 2x / 3x. |
| Space | Pause. R restarts after the outcome panel. |

Combat is the sim, not the scene. Angels and demons auto-attack anything in range. Shield, Heal, Cleanse, Detect, and Burst are the only angel buttons; each one routes to the owner and spends Golden Elixir. There is no hand of cards. A lethal hit downs that angel for 3 seconds (the portrait and a ring on the board count it down). Emergency resurrection, Raphael's slow revive, or a banked altar charge can still reach them. When the window closes, the death is final and a full party of final deaths is a wipe. Golden comes from playing (a trap avoided, a cleanse, a kill), Dark from chipping angels, both capped per room. Neither bar drips extra to the side that is behind.

Fog shows the current room and the next doorway. Traps stay hidden until Azrael's detect aura, a Detect pulse, or the lead angel steps on the tile. Curses show a cast bar before they land. Summons are visible when they spawn, including the short spawn-in. An elite or a trap cluster spends its Dark when the commit is issued and shows a cast bar for 3 seconds before it arms. The angels can read that bar from the doorway.

The dungeon is three stages. Each fork reads the same way: **Still air** (traps), **Skittering** (a committed summon), **Whispers** (a committed curse). The east road is the short one; the other two are longer and reconverge. Between stages a held nave breaks the march.

Each stage has a stake, claimed by standing on the rear node for 10 seconds with the room clear:

| Stage | Stake | What it banks |
| --- | --- | --- |
| Descent | Gate Seal | Swarms can no longer be summoned |
| Wards | Cleansing Font | The next curse burns away on landing |
| Sanctum | Reviving Altar | One revive, spent automatically on the next death |

Idling in a cleared room, a fork, or a stake you are not channeling feeds the demon. Entering the throne transforms the demon lord. A wounded party in the sanctum, with the altar still unclaimed, can draw him early: less Dark spent, less Lucifer, a thinner echo. The rise is marked for 3 seconds. Then the four blows, each marked for 3 seconds: hell rain on the tiles you are standing on (move, or Scatter Roll), a cleave lane (leave it), Judgment on the lowest angel (body-block or shield), and a Grasp the Phalanx refuses. Planted traps still fire. One echo wave arrives on a timer, spawning in for 3 seconds. Echo traps arm on a tell and can be disarmed before they do. No new curses. No new elite affixes. The trap cap drops. Killing Lucifer wins; a full party of final deaths loses.

Elixir is milli-units per tick (20 ticks a second), and the step up gets larger each stage:

| Stage | Golden / sec | Dark / sec |
| --- | --- | --- |
| Descent | 0.06 | 0.10 |
| Wards | 0.12 | 0.18 |
| Sanctum | 0.24 | 0.32 |
| Approach | 0.48 | 0.60 |
| Lucifer | 0.96 | 1.08 |

Heavies unlock after 2 rooms cleared. The elite unlocks after 4. A fast party that clears rooms is what opens the tier, not the clock.

### Headless checks

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

`res://tests/smoke.gd` only validates the map and advances 100 ticks. The suite is 52 headless tests: determinism, fog, elixir, tier gates, stakes, stance vs traps, curse telegraph, per-angel HP and the 3-second downed window, auto-attack, single-target and AoE shapes, the touch scene, the full five kits (cost, cooldown, shape, effect, cleanse order, disarm, dash, disengage, both revives inside the downed window, detect aura, Radiance), route lock, anti-turtle, echo budgeting, the Lucifer transformation, the four telegraphed boss buttons and the kit answers to them, the echo reflecting a trap siege versus a summon siege versus an early transform, the early-descent tradeoff, one echo wave with planted traps still firing, altar revive, the length of the road, director decisions (rooms-gated tiers, reinforcing the next room, commitment and curse telegraphs, Dark spent on a march, the early-descent gamble), and a scripted angel policy that can win. On the current tune that policy reaches Lucifer at 499.4 seconds and wins at 617.1 seconds. The boss lasts 117.8 seconds. The empty road, stakes included and no demon, is 425.5 seconds and 1280 tiles.

---

## Project layout

| Path | Purpose |
| --- | --- |
| `sim/` | Authoritative tick sim. Integer positions (milli-tiles) and elixir (milli). Commands only. |
| `sim/combat_sim.gd` | Map, units, abilities, traps, curses, Lucifer, snapshots. |
| `sim/director.gd` | Demon AI. Same `submit()` path a human demon will use. |
| `sim/dungeon_map.gd` | Three stages. Each is a fork, three different branches, a reconvergence, and a stake, plus a held nave on the march. |
| `game/` | Rendering and touch input. Reads snapshots; never decides combat. |
| `tests/` | Headless suite and the competent-angel policy. |
| `project.godot` | Godot 4.7, Mobile renderer, landscape 1280×720. |
| `export_presets.cfg` | Android preset named **`Android`**. |
| `scripts/build-apk.sh` | One-command debug APK. |
| `.github/workflows/build-apk.yml` | Builds and uploads an APK on push to `main` and on pull requests. |

### Android export settings

- Package name: `me.elitesavior.celestialqsiege`
- App name: `Celestial Q Siege`, version `0.6.0` (versionCode `7`)
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
- Pacing target is 8–12 minutes. The scripted party hits 617.1 seconds: 499.4 seconds of crawl, 117.8 seconds of Lucifer. The marches are the long part. The boss is the climax, about two minutes.
- The director spends Dark on the march (the next room, traps ahead, curses) down toward a per-stage line. The echo is that history, not the cap. Trap-heavy keeps a single heavy and lays echo traps (cap 3, still under the dungeon cap of 4). Summon-heavy adds bodies up to the mob cap. Curse-heavy swings the button pattern toward Judgment and does not cast new curses. Early descent spends 60% of the bank and brings the 2100-health Lucifer. On this tune the healthy scripted run was traps (65 placed, 10 summons, 27 curses) and echoed one heavy plus two echo traps.
- Lucifer's buttons are `submit("boss")` commands. The rise is `submit("descend")`. A future human demon issues those same commands. The director only chooses which button, from the pattern the history picked.
- Scatter Roll holds the shove for 3.5 seconds, long enough to stay out of a 3-second hell rain. Phalanx refuses Grasp. Body-block catches Judgment. None of the four blows kills a healthy angel by itself.
- Traps the party has already walked past do not keep occupying the global cap of 4. The live cap is the current room plus rooms not yet entered, and each room still holds at most 2.
- The Gate Seal locks swarm summons. The Cleansing Font stores one auto-cleanse. The altar is still the revive.
- Uriel's beam locks a target until you drag (or tap) to steer the line. An unsteered beam stays single-target.
- Taunt pulls one mob (the focus, else whoever is on the backline), not the whole room. It also cancels that elite's blink.
- Gabriel's cleanse order is Silence, Rot, Mark, then Weaken. Weaken is a debuff the cleanse understands. The director lands Silence, Rot, and Mark. Landing Weaken is deferred.
- Detect on the shared bar is Azrael's disarm when a revealed trap is in reach, and a paid wide pulse otherwise. The passive aura is the short reveal. The pulse is not a fourth active.
- The altar charge auto-spends on the next death (short delay, half health) and lands inside the 3-second downed window. It does not rewind a death that has already gone final.
- A slow revive already being cast holds the downed window open until the cast lands or is interrupted.
- Column eats spikes on the lead angel and suffers longer snares.
- Purifying shrines from the design's section 19 are not in this build.
- Gabriel's kit is cleanse, self-shield, emergency res, plus an always-on party damage aura. The active damage buff was dropped to keep three actives.
