# Celestial Q Siege

Touch-first, real-time **asymmetric strategy-RPG** for Android. One side is a party of five angels, moved as a single squad. The other side is a demon dungeon master — an AI budget-director in this build — that spends Dark Elixir on traps, summons, and curses, then becomes Lucifer.

Built with **Godot 4.7**. Distributed as a sideloadable APK.

> **Status: v1.1.1 playtest fixes.** The board is a fixed 2:1 isometric view with on-screen zoom. Phones open in landscape. Every foe shows a screen-space HP bar, and hits flash with floating numbers (green for heals). Golden regen is slower so a heal is a spend. Team Heal is its own button beside the single-target heal. Touch targets are at least 64px and spread along the bottom. Zoom − and + sit under the portraits. The antechamber has no fight; a garrison pulls only from inside leash, so a doorway step cannot start and end a fight in one tick. The 20 Hz tick is unchanged. Michael holds aggro with a real threat table: his autos outpace the party, Taunt snaps a mob and then boosts his threat generation for 20 seconds, and a hard burst or overheal can still pull. A threat meter on the portraits shows who holds and who is about to pull. Elixir rites have no cooldown — the bar is the only gate. Scatter and Phalanx still lock out. Dark opens full. The antechamber is a short walk from the fork. Traps stay hidden until Azrael's Detect. A purifying shrine in each room channels for 2 seconds and disables that room's traps. Mobs pulse the whole team. The director casts Weaken. Tap a single-target rite to arm it, then tap the angel or foe. Golden Elixir is a 0–100 bar (opening 36: Taunt, Mend, Strike, and Shield). Active buffs and debuffs sit on each unit. The siege is a loop: a start screen holds the clock, a run plays, victory and defeat are different screens, and either one can start a new run or return to the title. A **Menu** button stays up during the run and can restart or return to the title without waiting for the outcome. Nothing dead-ends. Threats are labeled and color-coded (curses, traps, commitments, Lucifer's four blows, the echo wave). Hits, heals, and button presses are view-layer only — flashes, short particles, and generated tones — and they never call `submit()`. A gold arrow points at the next doorway or objective, and a one-line coach stays visible (move, clear the room, claim the stake, spend elixir, plus the tells) until **Hide hints**. The director is unchanged: Survive, then Protect the stake, then Exploit the stance, then Spend what is over the line. For 2 seconds, or until the first angel command, Dark regen and the idle clock are held; Golden still regens and the director still spends. A scripted competent party reaches Lucifer at 568.0 seconds and wins at 686.8 seconds. The boss is 118.8 seconds. A slower human-style policy, which still claims every stake and answers the blows, wins at 685.3 seconds (boss 116.9 seconds). Walking the short road with auto-attacks only, and skipping the kit and the stakes, dies in the second gallery at 335.9 seconds. That run's scripted echo was one heavy, trap style. Placeholder shapes and beeps, not final art. No networking yet.

---

## Play

Open the project in Godot 4.7.2 and run `Main.tscn`. Phones open in landscape. The base layout is 1280×720 and expands, and the bottom bar follows a taller window. The board is drawn as 2:1 diamonds. The title screen explains the loop. **Begin the siege** starts the clock. Idle time in a cleared room feeds the demon, so the title does not tick the sim. A gold arrow marks the next doorway, and a one-line coach sits above the command bar until **Hide hints**. **Menu** (top right, beside Pause and Speed) pauses and offers **Restart run**, **Title**, and **Resume**. Victory and defeat are separate screens. **Siege again** / **Try again** starts a new run. **Title** returns to the start screen. `R` restarts any time after the title.

| Input | Action |
| --- | --- |
| Tap the map | Move the squad. A tap on open ground snaps to the nearest walkable tile, or toward the next lit doorway when that tile is the one the party already occupies. |
| Tap a doorway | Commit to that branch for 3 seconds. |
| Tap an enemy | Focus fire. Attacks themselves are automatic. |
| Tap a hero | While a single-target rite is armed, cast it on that angel. Otherwise set the Mend target. |
| Portrait | That angel's HP and threat. DOWN counts 3 seconds, then the death is final. An armed ally rite casts on the portrait and leaves the skill bar where it is. |
| Tap the altar node | Channel the revive charge (the altar is in the demon's strongest room). |
| Shield / Heal / Cleanse / Detect / Burst | Contextual commands. Each routes to the angel who owns it. |
| Taunt / Heal / Team / Strike / Sunstrike | Always on the bar, named for the angel who owns them. Taunt, Strike, and Sunstrike arm, then a tap on a foe casts. Heal arms Raphael's single heal, then a tap on a teammate casts it. Team casts Raphael's party heal immediately. |
| Tap a portrait | With nothing armed, show that angel's kit and passive. Azrael and Uriel have four actives. Back returns to the shared bar. |
| Drag during Uriel's beam | Steer the beam. A tap on the ground steers it too, until the channel ends. |
| Tight / Spread / Column | Persistent stance. |
| Scatter Roll / Phalanx Push | Short-cooldown maneuvers. They spend no elixir and work while silenced. |
| 1–5, Z, X, Q/W/E | Same commands from a keyboard. |
| 1x button | Cycle lab speed 1x / 2x / 3x. |
| Menu | Pause, then restart the run or return to the title. Visible the whole siege, clear of the command bar. |
| Space | Pause. R restarts after the title, including mid-run. |

Combat is the sim, not the scene. Angels and demons auto-attack anything in range. Shield, Heal, Cleanse, Detect, Burst, Taunt, Mend, Team, Strike, and Sunstrike all go through `submit()` and spend Golden Elixir. Placed mobs hold their post until a party member enters aggro range, or shares their room and is inside leash. The antechamber garrisons nothing, so the first fight starts in the first real room. Once pulled, each mob attacks whoever holds the highest threat. There is no hand of cards. A lethal hit downs that angel for 3 seconds (the portrait and a ring on the board count it down). Emergency resurrection, Raphael's slow revive, or a banked altar charge can still reach them. When the window closes, the death is final and a full party of final deaths is a wipe. Golden comes from playing (a trap avoided, a cleanse, a kill), Dark from chipping angels, both capped per room. Neither bar drips extra to the side that is behind.

Fog shows the current room and the next doorway. Traps stay hidden until Azrael's Detect pulse. Stepping on one still springs it. Echo traps stay visible so the boss tell can be disarmed. A purifying shrine in each room channels for 2 seconds and disables that room's traps. Curses show a cast bar before they land. Summons are visible when they spawn, including the short spawn-in. An elite or a trap cluster spends its Dark when the commit is issued and shows a cast bar for 3 seconds before it arms. The angels can read that bar from the doorway. Movement is eight directions. Zoom − and + sit under the portrait column, labeled ZOOM, and a two-finger pinch scales the same way. Foes draw a wide HP bar with the current and max health. Damage numbers rise off the unit: yellow on a foe, red on an angel, green on a heal. A hit also flashes the body. Those pops and flashes are view-only.

The dungeon is three stages. Each fork reads the same way: **Still air** (traps), **Skittering** (a committed summon), **Whispers** (a committed curse). The east road is the short one; the other two are longer and reconverge. Between stages a held nave breaks the march.

Each stage has a stake, claimed by standing on the rear node for 10 seconds with the room clear:

| Stage | Stake | What it banks |
| --- | --- | --- |
| Descent | Gate Seal | Swarms can no longer be summoned |
| Wards | Cleansing Font | The next curse burns away on landing |
| Sanctum | Reviving Altar | One revive, spent automatically on the next death |

Idling in a cleared room, a fork, or a stake you are not channeling feeds the demon. Entering the throne transforms the demon lord. A wounded party in the sanctum, with the altar still unclaimed, can draw him early: less Dark spent, less Lucifer, a thinner echo. The rise is marked for 3 seconds. Then the four blows, each marked for 3 seconds: hell rain on the tiles you are standing on (move, or Scatter Roll), a cleave lane (leave it), Judgment on the lowest angel (body-block or shield), and a Grasp the Phalanx refuses. Planted traps still fire. One echo wave arrives on a timer, spawning in for 3 seconds. Echo traps arm on a tell and can be disarmed before they do. No new curses. No new elite affixes. The trap cap drops. Killing Lucifer wins; a full party of final deaths loses.

Elixir is an integer 0–100 bar (100 internal units per point, 20 ticks a second). Golden regen steps up each stage. Dark keeps its 1.0.3 income, shown on the same bar.

| Stage | Golden / sec | Dark / sec |
| --- | --- | --- |
| Descent | 2.0 | 1.0 |
| Wards | 4.4 | 1.8 |
| Sanctum | 9.6 | 3.2 |
| Approach | 22.0 | 6.0 |
| Lucifer | 52.0 | 10.8 |

v1.1.0 paid 4 points/sec at the descent, so a Mend (6) refunded in 1.5s and heals felt free. v1.0.3 paid 0.6 points/sec and a fight starved. v1.1.1 pays 2.0, so a Mend takes 3s to earn back and a Party Heal (15) takes 7.5s. Five seconds of descent regen cannot pay a party heal. Later stages still accelerate, and Lucifer stays near the old boss income. The internal curve is `[10, 22, 48, 110, 260]` per tick (100 internal = 1 point, 20 ticks a second).

Heavies unlock after 2 rooms cleared. The elite unlocks after 4. A fast party that clears rooms is what opens the tier, not the clock.

### Headless checks

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

`res://tests/smoke.gd` only validates the map and advances 100 ticks. The suite is 88 headless tests: determinism, fog, elixir, tier gates, stakes, stance vs traps, curse telegraph, per-angel HP and the 3-second downed window, auto-attack, single-target and AoE shapes, the touch scene (including `InputEventScreenTouch` through the real GUI picker, a tap on non-walkable ground, and focus-fire), the in-run Menu restart/title, the objective arrow and the persistent coach, the 2-second opening hold, the full five kits (cost, shape, effect, cleanse order, disarm, dash, disengage, both revives inside the downed window, Detect as the only trap reveal, Radiance), route lock, anti-turtle, echo budgeting, the Lucifer transformation, the four telegraphed boss buttons and the kit answers to them, the echo reflecting a trap siege versus a summon siege versus an early transform, the early-descent tradeoff, one echo wave with planted traps still firing, altar revive, the length of the road, director decisions (rooms-gated tiers, reinforcing the next room, commitment and curse telegraphs, Dark spent on a march, the early-descent gamble), a scripted angel policy that can win, the start → defeat → restart → victory → title loop, coach hints, distinct tell colors, juice staying out of the sim, a slower human policy that still wins, and a no-kit march that loses. The 1.0.3 cases cover threat ordering, taunt forcing the target and snapping threat, Strike and Sunstrike spending elixir and dealing damage, tougher-mob time-to-kill, Mend healing only the chosen hero, mobs holding until aggro, and the new bar buttons staying touchable. The 1.0.4 cases cover the 0–100 elixir bar, each ability's point cost being spent, Golden regen over a run of ticks, debuff rows the indicator layer can read, and several skill casts inside an imp, heavy, and elite fight. The 1.1.0 cases cover the tank holding under autos, Taunt storing threat and boosting generation, overheal pulling, the threat meter, mob pulses, the director's Weaken, hidden traps, the purifying shrine, diagonal pathing, and elixir rites with no cooldown. The 1.1.1 cases cover the Team Heal button, the doorway fight that used to last one tick, a calm antechamber until the first real room, and the slower Golden curve. On the current tune the scripted policy reaches Lucifer at 568.0 seconds and wins at 686.8 seconds (317 Golden casts). The boss lasts 118.8 seconds. The human-style policy wins at 685.3 seconds (boss 116.9 seconds, 230 casts). A focused party of autos kills an imp in 4.70 seconds, a heavy in 9.50 seconds, and an elite in 20.90 seconds. The empty road, stakes included and no demon, is 415.9 seconds.

---

## Project layout

| Path | Purpose |
| --- | --- |
| `sim/` | Authoritative tick sim. Integer positions (milli-tiles) and elixir (100 units per bar point). Commands only. |
| `sim/combat_sim.gd` | Map, units, abilities, traps, curses, Lucifer, snapshots. |
| `sim/director.gd` | Demon AI. Same `submit()` path a human demon will use. |
| `sim/dungeon_map.gd` | Three stages. Each is a fork, three different branches, a reconvergence, and a stake, plus a held nave on the march. |
| `game/` | Rendering and touch input. Reads snapshots; never decides combat. |
| `tests/` | Headless suite and the competent-angel policy. |
| `project.godot` | Godot 4.7, Mobile renderer, landscape, base 1280×720. |
| `export_presets.cfg` | Android preset named **`Android`**. |
| `scripts/build-apk.sh` | One-command debug APK. |
| `.github/workflows/build-apk.yml` | Builds and uploads an APK on push to `main` and on pull requests. |

### Android export settings

- Package name: `me.elitesavior.celestialqsiege`
- App name: `Celestial Q Siege`, version `1.1.1` (versionCode `14`)
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
- Pacing target is 8–12 minutes. The marches are the long part. The boss is the climax, about two minutes. Opening Golden is 36 points (Taunt, Mend, Strike, and Shield). Dark opens full, so the director can summon on the first decision. `OPENING_GRACE_TICKS` is 40 (2.0s at 20 Hz). Until the first angel command is drained, or tick 40 passes, Dark regen is 0 and the turtle/idle clock does not advance. Golden regen still applies. The director is not paused. The antechamber sits against the first fork, so the opening walk is short.
- The director spends Dark on the march (the next room, traps ahead, curses) down toward a per-stage line. The echo is that history, not the cap. Trap-heavy keeps a single heavy and lays echo traps (cap 3, still under the dungeon cap of 4). Summon-heavy adds bodies up to the mob cap. Curse-heavy swings the button pattern toward Judgment and does not cast new curses. Early descent spends 60% of the bank and brings the 2100-health Lucifer. On this tune, at the moment Lucifer rises, the healthy scripted run was traps (65 placed, 11 summons, 41 curses) and echoed one heavy.
- Lucifer's buttons are `submit("boss")` commands. The rise is `submit("descend")`. A future human demon issues those same commands. The director only chooses which button, from the pattern the history picked.
- Scatter Roll holds the shove for 3.5 seconds, long enough to stay out of a 3-second hell rain. Phalanx refuses Grasp. Body-block catches Judgment. None of the four blows kills a healthy angel by itself.
- Traps the party has already walked past do not keep occupying the global cap of 4. The live cap is the current room plus rooms not yet entered, and each room still holds at most 2.
- The Gate Seal locks swarm summons. The Cleansing Font stores one auto-cleanse. The altar is still the revive.
- Uriel's beam locks a target until you drag (or tap) to steer the line. An unsteered beam stays single-target.
- Taunt costs 8 Golden and lasts 4 seconds. It pulls one mob (the named foe, else the focus, else whoever is on the backline), forces that mob onto Michael, stores his threat one above the current highest, and doubles his threat generation for 20 seconds. It also cancels that elite's blink. Elixir rites have no cooldown. Scatter and Phalanx keep their lockouts because they cost nothing.
- Threat is deterministic. Damage dealt to a mob equals threat, and that hit also pulls the mob. Michael's damage threat is multiplied by 7.5, and by 2 again while the taunt boost is up, so his autos hold a pack. A large elixir hit can still pass him. A heal adds 100% of the amount cast, including overheal, split evenly across mobs already in the fight (the remainder goes to the lowest ids). Raphael's passive regen does not generate threat. Ties break to the nearer angel, then the lower id. An empty table falls back to the nearest angel. Mark and an elite blink still outrank the table. Taunt's force-target outranks both while it lasts. Lucifer does not use the table. The snapshot publishes a per-angel threat meter; the HUD only reads it. A room shares aggro only while an angel is also inside the 9.8-tile leash, so stepping onto a far doorway and back out does not flash a fight. A pulled mob drops combat and clears its table when no living angel is within 9.8 tiles and none share its room. Corridors do not pull by room, so a march does not drag the next pack. The antechamber is empty.
- Strike is Azrael's melee hit: 10 Golden, 108 raw damage on one foe in reach. Sunstrike is Uriel's ranged nuke: 14 Golden, 86 on the primary and 40 splash inside 1 tile. Both spend through the same ability path as Burst. On the touch bar they arm, then a tap on a foe casts.
- Mend is Raphael's single heal (6 Golden, 62 health). The Heal button and Mend arm it. A tap on a teammate or that angel's portrait then casts it and does not swap the skill bar. A named target in the command still wins. With no target, the lowest living hero is healed. Keyboard Heal still smart-routes. Team, beside Mend, submits `party_heal` directly (15 Golden, 32 health on every living angel) and does not arm.
- Mob bodies: imp 240 HP / atk 5 / every 18 ticks, heavy 480 / 10 / 20, elite 1080 / 11 / 20. Every fourth swing also pulses the party in the room, or within 5.2 tiles. Lucifer is 4000. A focused party of autos takes 4.70 seconds on an imp, 9.50 on a heavy, and 20.90 on an elite.
- Gabriel's cleanse order is Silence, Rot, Mark, then Weaken. Every fourth curse the director casts leads with Weaken on Azrael. Weaken on Uriel is the fallback when the others cannot be paid.
- Detect on the shared bar is Azrael's disarm when a revealed trap is in reach, and a paid wide pulse otherwise. The pulse is the only reveal. Traps do not render from proximity.
- The altar charge auto-spends on the next death (short delay, half health) and lands inside the 3-second downed window. It does not rewind a death that has already gone final.
- A slow revive already being cast holds the downed window open until the cast lands or is interrupted.
- Column eats spikes on the lead angel and suffers longer snares.
- Each non-corridor room has a purifying shrine. Channeling it for 2 seconds, in range, disables that room's armed traps. The view submits `channel_shrine` and only reads the snapshot.
- Feel and audio live in `game/feel.gd` and `game/sfx.gd`. They read snapshots and play generated tones. They do not submit commands. Headless runs build the clips and record the hook without opening an audio device.
- Victory and defeat are different panels. Restart and Title both call `CombatSim.reset()` through the view, then either begin the next run or show the title. The title does not tick. The in-run Menu uses the same two calls. Opening it sets the view pause; it does not submit a command.
- Gabriel's kit is cleanse, self-shield, emergency res, plus an always-on party damage aura. Azrael's kit is strike, burst, disarm, dash. Uriel's kit is sunstrike, beam, holy zone, disengage.
