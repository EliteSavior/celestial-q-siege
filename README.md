# Celestial Q Siege

Touch-first, real-time **asymmetric strategy-RPG** for Android. One side is a party of five angels, moved as a single squad. The other side is a demon dungeon master — an AI budget-director in this build — that spends Dark Elixir on traps, summons, and curses, then becomes Lucifer.

Built with **Godot 4.7**. Distributed as a sideloadable APK.

> **Status: M6 (Game feel & loop) — single-player MVP 1.0.3.** The board is a fixed 2:1 isometric view. The 20 Hz tick is unchanged. Combat now has a threat table, hold-until-aggro, Taunt, Strike, Sunstrike, and a chosen-hero Mend. The siege is a loop: a start screen holds the clock, a run plays, victory and defeat are different screens, and either one can start a new run or return to the title. A **Menu** button stays up during the run and can restart or return to the title without waiting for the outcome. Nothing dead-ends. Threats are labeled and color-coded (curses, traps, commitments, Lucifer's four blows, the echo wave). Hits, heals, and button presses are view-layer only — flashes, short particles, and generated tones — and they never call `submit()`. A gold arrow points at the next doorway or objective, and a one-line coach stays visible (move, clear the room, claim the stake, spend elixir, plus the tells) until **Hide hints**. The director is unchanged: Survive, then Protect the stake, then Exploit the stance, then Spend what is over the line. Opening Golden is 6.5, enough for Shield and a Heal with 2.0 left (a Cleanse or one 2.0 active, not a Burst). Was 5.0 in 1.0.0. For 8 seconds, or until the first angel command, Dark regen and the idle clock are held; Golden still regens and the director still spends. The regen curve, the road, and Lucifer's health are unchanged. A scripted competent party reaches Lucifer at 613.2 seconds and wins at 726.6 seconds. The boss is 113.4 seconds. A slower human-style policy, which still claims every stake and answers the blows, wins at 678.3 seconds (boss 103.0 seconds). Walking the short road with auto-attacks only, and skipping the kit and the stakes, dies in the gallery at 551.3 seconds. That run's scripted echo was one heavy, trap style. Placeholder shapes and beeps, not final art. No networking yet.

---

## Play

Open the project in Godot 4.7.2 and run `Main.tscn`. Phones open in portrait. The base layout is 1280×720 and expands on a tall screen, and the bottom bar follows a taller window. The board is drawn as 2:1 diamonds. The title screen explains the loop. **Begin the siege** starts the clock. Idle time in a cleared room feeds the demon, so the title does not tick the sim. A gold arrow marks the next doorway, and a one-line coach sits above the command bar until **Hide hints**. **Menu** (top right, under Pause) pauses and offers **Restart run**, **Title**, and **Resume**. Victory and defeat are separate screens. **Siege again** / **Try again** starts a new run. **Title** returns to the start screen. `R` restarts any time after the title.

| Input | Action |
| --- | --- |
| Tap the map | Move the squad. A tap on open ground snaps to the nearest walkable tile, or toward the next lit doorway when that tile is the one the party already occupies. |
| Tap a doorway | Commit to that branch for 3 seconds. |
| Tap an enemy | Focus fire. Attacks themselves are automatic. |
| Tap a hero | Mend target. Mend then heals that angel only. |
| Portrait | That angel's HP. DOWN counts 3 seconds, then the death is final. A `TGT` mark is the Mend target. |
| Tap the altar node | Channel the revive charge (the altar is in the demon's strongest room). |
| Shield / Heal / Cleanse / Detect / Burst | Contextual commands. Each routes to the angel who owns it. |
| Taunt / Mend / Strike / Sunstrike | Always on the bar. Taunt is Michael. Mend is Raphael's single heal. Strike is Azrael. Sunstrike is Uriel. |
| Tap a portrait | Show that angel's kit and passive. Azrael and Uriel have four actives. Back returns to the shared bar. |
| Drag during Uriel's beam | Steer the beam. A tap on the ground steers it too, until the channel ends. |
| Tight / Spread / Column | Persistent stance. |
| Scatter Roll / Phalanx Push | Short-cooldown maneuvers. They spend no elixir and work while silenced. |
| 1–5, Z, X, Q/W/E | Same commands from a keyboard. |
| 1x button | Cycle lab speed 1x / 2x / 3x. |
| Menu | Pause, then restart the run or return to the title. Visible the whole siege, clear of the command bar. |
| Space | Pause. R restarts after the title, including mid-run. |

Combat is the sim, not the scene. Angels and demons auto-attack anything in range. Shield, Heal, Cleanse, Detect, Burst, Taunt, Mend, Strike, and Sunstrike all go through `submit()` and spend Golden Elixir. Placed mobs hold their post until a party member enters aggro range or the same room. Once pulled, each mob attacks whoever holds the highest threat. There is no hand of cards. A lethal hit downs that angel for 3 seconds (the portrait and a ring on the board count it down). Emergency resurrection, Raphael's slow revive, or a banked altar charge can still reach them. When the window closes, the death is final and a full party of final deaths is a wipe. Golden comes from playing (a trap avoided, a cleanse, a kill), Dark from chipping angels, both capped per room. Neither bar drips extra to the side that is behind.

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

`res://tests/smoke.gd` only validates the map and advances 100 ticks. The suite is 71 headless tests: determinism, fog, elixir, tier gates, stakes, stance vs traps, curse telegraph, per-angel HP and the 3-second downed window, auto-attack, single-target and AoE shapes, the touch scene (including `InputEventScreenTouch` through the real GUI picker, a tap on non-walkable ground, and focus-fire), the in-run Menu restart/title, the objective arrow and the persistent coach, the 8-second opening hold, the full five kits (cost, cooldown, shape, effect, cleanse order, disarm, dash, disengage, both revives inside the downed window, detect aura, Radiance), route lock, anti-turtle, echo budgeting, the Lucifer transformation, the four telegraphed boss buttons and the kit answers to them, the echo reflecting a trap siege versus a summon siege versus an early transform, the early-descent tradeoff, one echo wave with planted traps still firing, altar revive, the length of the road, director decisions (rooms-gated tiers, reinforcing the next room, commitment and curse telegraphs, Dark spent on a march, the early-descent gamble), a scripted angel policy that can win, the start → defeat → restart → victory → title loop, coach hints, distinct tell colors, juice staying out of the sim, a slower human policy that still wins, and a no-kit march that loses. The 1.0.3 cases cover threat ordering, taunt forcing the target and snapping threat, Strike and Sunstrike spending elixir and dealing damage, tougher-mob time-to-kill, Mend healing only the chosen hero, mobs holding until aggro, and the new bar buttons staying touchable. On the current tune the scripted policy reaches Lucifer at 613.2 seconds and wins at 726.6 seconds. The boss lasts 113.4 seconds. The human-style policy wins at 678.3 seconds (boss 103.0 seconds). A focused party of autos kills an imp in 4.70 seconds, a heavy in 9.50 seconds, and an elite in 20.90 seconds. The empty road, stakes included and no demon, is 425.5 seconds and 1280 tiles.

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
| `project.godot` | Godot 4.7, Mobile renderer, portrait, base 1280×720. |
| `export_presets.cfg` | Android preset named **`Android`**. |
| `scripts/build-apk.sh` | One-command debug APK. |
| `.github/workflows/build-apk.yml` | Builds and uploads an APK on push to `main` and on pull requests. |

### Android export settings

- Package name: `me.elitesavior.celestialqsiege`
- App name: `Celestial Q Siege`, version `1.0.3` (versionCode `11`)
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
- **Networking, human demon, more heroes.** Later. This build is the single-player MVP.

## Notes for contributors / agents

- Keep the export preset name exactly `Android`.
- Commit `*.import` and `*.uid`. `.godot/` is cache and is ignored.
- If you bump Godot, update `GODOT_VERSION`, the workflow image tag, and `config/features` in `project.godot`.
- Do not put gameplay rules in `game/`. Both sides issue commands into `CombatSim.submit`.

### Calls made for this lab

- Portrait inspect is view state. It does not change the sim.
- Detect is a paid wide pulse, and the same button disarms a revealed trap in range.
- The Dark bar is visible here so the solo lab is readable. A real 1v1 would hide it.
- Pacing target is 8–12 minutes. The scripted party hits 726.6 seconds: 613.2 seconds of crawl, 113.4 seconds of Lucifer. A slower policy hits 678.3 seconds (boss 103.0) and still claims every stake. The marches are the long part. The boss is the climax, about two minutes. Opening Golden is 6.5 (6500 milli): Shield (3.0) and a Heal (1.5) leave 2.0, which pays a Cleanse (1.5) or one 2.0 active and does not pay a Burst (3.0). Was 5.0 (a 0.5 cushion) in 1.0.0. Dark still starts at 4.2. The regen curves were not raised; that would pull the crawl under 8 minutes. `OPENING_GRACE_TICKS` is 160 (8.0s at 20 Hz). Until the first angel command is drained, or tick 160 passes, Dark regen is 0 and the turtle/idle clock does not advance. Golden regen still applies. The director is not paused. A party that commands on the first tick never sees the hold; an idle party is not snowballed for those 8 seconds, then the demon and the turtle resume.
- The director spends Dark on the march (the next room, traps ahead, curses) down toward a per-stage line. The echo is that history, not the cap. Trap-heavy keeps a single heavy and lays echo traps (cap 3, still under the dungeon cap of 4). Summon-heavy adds bodies up to the mob cap. Curse-heavy swings the button pattern toward Judgment and does not cast new curses. Early descent spends 60% of the bank and brings the 2100-health Lucifer. On this tune the healthy scripted run was traps (73 placed, 11 summons, 31 curses) and echoed one heavy plus two echo traps.
- Lucifer's buttons are `submit("boss")` commands. The rise is `submit("descend")`. A future human demon issues those same commands. The director only chooses which button, from the pattern the history picked.
- Scatter Roll holds the shove for 3.5 seconds, long enough to stay out of a 3-second hell rain. Phalanx refuses Grasp. Body-block catches Judgment. None of the four blows kills a healthy angel by itself.
- Traps the party has already walked past do not keep occupying the global cap of 4. The live cap is the current room plus rooms not yet entered, and each room still holds at most 2.
- The Gate Seal locks swarm summons. The Cleansing Font stores one auto-cleanse. The altar is still the revive.
- Uriel's beam locks a target until you drag (or tap) to steer the line. An unsteered beam stays single-target.
- Taunt costs 2.0 Golden, cooldown 8 seconds, and lasts 4 seconds. It pulls one mob (the focus, else whoever is on the backline), not the whole room, forces that mob onto Michael, and sets his effective threat one above the current highest for the duration. The snap is not stored, so it ends with the taunt. It also cancels that elite's blink.
- Threat is deterministic. Damage dealt to a mob equals threat, and that hit also pulls the mob. Michael's damage threat is multiplied by 4, so his autos hold a pack and a DPS elixir hit can still pass him. A heal adds 50% of the health actually gained, split evenly across mobs already in the fight (the remainder goes to the lowest ids). Raphael's passive regen does not generate threat. Ties break to the nearer angel, then the lower id. An empty table falls back to the nearest angel. Mark and an elite blink still outrank the table. Taunt outranks both. Lucifer does not use the table. A pulled mob drops combat and clears its table when no living angel is within 9.8 tiles and none share its room. Corridors do not pull by room, so a march does not drag the next pack.
- Strike is Azrael's melee hit: 2.5 Golden, cooldown 5 seconds, 108 raw damage on one foe in reach. Sunstrike is Uriel's ranged nuke: 3.5 Golden, cooldown 7 seconds, 86 on the primary and 40 splash inside 1 tile. Both spend through the same ability path as Burst.
- Mend is Raphael's existing single heal (1.5 Golden, 62 health, cooldown 3 seconds). Tap a hero to store that ally; Mend and an untargeted `single_heal` heal that hero if they are alive. A named target in the command still wins. With no target, the lowest living hero is healed, which is what the shared Heal button already did.
- Mob bodies, 1.0.2 then 1.0.3: imp 34 HP / atk 6 / every 18 ticks, now 240 / 5 / 18. Heavy 260 / 13 / 18, now 480 / 10 / 20. Elite 420 / 12 / 20, now 1080 / 11 / 20. Lucifer is still 3700. A focused party of autos takes 4.70 seconds on an imp, 9.50 on a heavy, and 20.90 on an elite.
- Gabriel's cleanse order is Silence, Rot, Mark, then Weaken. Weaken is a debuff the cleanse understands. The director lands Silence, Rot, and Mark. Landing Weaken is deferred.
- Detect on the shared bar is Azrael's disarm when a revealed trap is in reach, and a paid wide pulse otherwise. The passive aura is the short reveal. The pulse is not a fourth active.
- The altar charge auto-spends on the next death (short delay, half health) and lands inside the 3-second downed window. It does not rewind a death that has already gone final.
- A slow revive already being cast holds the downed window open until the cast lands or is interrupted.
- Column eats spikes on the lead angel and suffers longer snares.
- Purifying shrines from the design's section 19 are not in this build.
- Feel and audio live in `game/feel.gd` and `game/sfx.gd`. They read snapshots and play generated tones. They do not submit commands. Headless runs build the clips and record the hook without opening an audio device.
- Victory and defeat are different panels. Restart and Title both call `CombatSim.reset()` through the view, then either begin the next run or show the title. The title does not tick. The in-run Menu uses the same two calls. Opening it sets the view pause; it does not submit a command.
- Gabriel's kit is cleanse, self-shield, emergency res, plus an always-on party damage aura. Azrael's kit is strike, burst, disarm, dash. Uriel's kit is sunstrike, beam, holy zone, disengage.
