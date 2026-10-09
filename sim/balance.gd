class_name Balance
extends RefCounted
## Prototype 0 numbers. Tune here; the sim should not hardcode a second copy.

const TICK_HZ := 20
const MILLI := 1000
# One player-facing elixir point. The sim stays integer; the bar reads 0–100.
const POINT := 100
const ELIXIR_MAX := 10000 # 100 points
# 1.0.4 opening is 36 points: Taunt 8 + Mend 6 + Strike 10 + Shield 12.
# That is a real opener, not also a Sunstrike (14) or a Party Heal (15).
# 1.0.3 was 6500 internal, shown as 6.5 on a 0–10 meter (about two casts).
const GOLDEN_START := 3600
# Full Dread bar. The director can summon on the first decision.
const DARK_START := 10000
# 2 seconds. The pre-combat hold used to be 8s, which pushed the first
# fight back. Dark regen stays frozen until the first angel command, or
# until this window ends. Golden still regens. The director still spends.
const OPENING_GRACE_TICKS := 40

# Internal elixir per tick (100 internal = 1 point, 20 ticks/sec, so
# points/sec = internal / 5). Index is the stage reached (0 descent …
# 3 approach). Index 4 is the Lucifer phase.
# 1.0.3 was [3, 6, 12, 24, 48] internal/tick (0.6 points/sec at descent)
# and a fight starved. 1.1.0 was [20, 40, 80, 160, 320] (4 points/sec at
# descent) and a Mend refunded itself before the cast mattered.
# 1.1.1 is [10, 22, 48, 110, 260] = 2.0, 4.4, 9.6, 22.0, 52.0 points/sec.
# Descent refunds a Mend (6) in 3s and a Party Heal (15) in 7.5s, so a
# cast is a choice. Later stages still accelerate, and Lucifer stays near
# the old 64/s so the boss window does not collapse.
# Dark regen is unchanged from 1.0.3, so the director buys the same siege.
const GOLDEN_CURVE: Array[int] = [10, 22, 48, 110, 260]
const DARK_CURVE: Array[int] = [5, 9, 16, 30, 54]

# Summon tiers unlock by rooms cleared, not by the clock.
# A fought crawl clears fewer rooms than a stroll, because some spawns
# are still standing when the party moves on. These gates still fall
# stage by stage: heavies with the Wards, the elite with the Sanctum.
const HEAVY_ROOMS := 2
const ELITE_ROOMS := 4

const MOVE_SPEED := 165
const COLUMN_SPEED_BONUS := 25
const FORMATION_CATCH := 40

const ROOM_GOLDEN_CAP := 2500
const ROOM_DARK_DMG_CAP := 1500
const ROOM_TRAP_DARK_CAP := 1600

const CLEAR_BOUNTY := 400
const DISARM_BOUNTY := 450
const AVOID_BOUNTY := 300
const CLEANSE_BOUNTY := 500
const KILL_IMP := 140
const KILL_HEAVY := 320
const KILL_ELITE := 800

const TRAP_DARK := 650
const DARK_PER_HP := 2

# v1.1.3: camping a cleared fork used to corrupt in 12s and kill in ~25s
# with no fight on screen. Warn at 30s, bite at 50s, and tick for 1.
const TURTLE_WARN_TICKS := 600
const TURTLE_TICKS := 1000
const TURTLE_DMG_PERIOD := 10
const TURTLE_DMG := 1
const TURTLE_DARK_PER_TICK := 22

const ROUTE_LOCK_TICKS := 60
const FOCUS_TICKS := 160
const SPAWN_TELEGRAPH := 20
const ECHO_DELAY := 100
const CURSE_CAST_MARK := 60
const CURSE_CAST := 50
# Lucifer's arrival and each of his four buttons are a 3s tell.
# The gap is basic attacks only, so a tell is never stacked on a tell.
const TRANSFORM_CAST := 60
const BOSS_TELL := 60
const BOSS_GAP := 40

const DETECT_AURA := 2200
const DETECT_PULSE := 5600
const DISARM_RANGE := 1600
const HELLFLAME_RADIUS := 1800
const SPIKE_STEP := 450
const TIGHT_SPIKE := 950

const TRAP_CAP := 4
const TRAP_CAP_PER_ROOM := 2
const ECHO_TRAP_CAP := 2
# A trap-heavy echo keeps one extra planted trap. Still under the dungeon cap.
const ECHO_TRAP_CAP_TRAPPY := 3
# Counts below this are noise. The echo starts reflecting the siege above it.
const HISTORY_FLOOR := 4
# A committed elite or trap cluster is readable for 3 seconds before it arms.
const COMMIT_CAST := 60
# First garrison of a room the party just entered. 2 seconds at 20 Hz.
const ROOM_SPAWN_DELAY := 40
# After Cleanse, curses (including Corruption) cannot land for 8 seconds.
const CURSE_GRACE := 160
# March ceilings by stage. Overflow above the line is spent, so a long
# corridor cannot sit on the cap and mint the same finale every time.
const MARCH_BANK: Array[int] = [8800, 7600, 6400, 4800]
const MOB_CAP := 6
const TRAP_MIN_DIST := 4000

const TAUNT_RADIUS := 3200
const TAUNT_TICKS := 80
# Taunt writes this much threat above the current top, so the snap stays
# after the force window. A later hit can still pass it.
const TAUNT_SNAP := 1
# After a taunt, Michael's damage threat is multiplied again for this long.
# The boost outlives the force window. 20 seconds at 20 Hz.
const TAUNT_BOOST_TICKS := 400
const TAUNT_BOOST_PCT := 100
# Mobs hold their spawn until a living angel walks into this radius, shares
# their room (corridors do not count — a march is not a pull), or damages them.
const AGGRO_RANGE := 4200
const LEASH_RANGE := 9800
# Damage dealt is threat. v1.1.2 raised this from 750% to 1600% so Michael's
# autos stay ahead of the other four angels with real headroom. A hard elixir
# burst, or a long run of heals that include overheal, can still pass him.
# Heals add this percent of the amount cast (not just the health gained),
# split across mobs already in the fight. v1.1.2 cut heal threat from 100%
# to 35%. v1.1.3 raised the party heal to 110 and cut the percent to 10 so
# the threat added by one party heal stays 11.
# Worked example, one mob, Gabriel's aura included (112%):
#   Michael auto: dealt 8 → threat 8 * 1600/100 = 128
#   Party heal: 110 * 10/100 = 11 threat. Twelve heals pass one auto.
#   Azrael strike: dealt 120 → threat 120, still under one tank auto.
#   Fresh pull also grants OPENER_THREAT (below) before anyone swings.
const TANK_THREAT_MULT := 1600
const HEAL_THREAT_PCT := 10
# Written onto Michael the moment a mob is pulled, before the first swing,
# so the pack opens on the tank even if a backliner is standing closer.
# 480 is about four Azrael strikes (120 each) or forty-three party heals
# (11 each) of pure excess with no tank damage on top.
const OPENER_THREAT := 480
# Bars are percent of Michael's threat on the current pack.
# Yellow at 70% (near the pull), red at 92% (about to pass him).
# The meter calls "about to pull" at 85%, unchanged.
const THREAT_WARN_PCT := 70
const THREAT_DANGER_PCT := 92
const THREAT_PULL_PCT := 85
const SHIELD_WALL_TICKS := 60
const BODY_BLOCK_TICKS := 80
# Michael keeps this percent of incoming damage. Highest HP is on the hero row.
# Armor is the reduction: 100 - MICHAEL_MITIGATION. Shield wall adds armor;
# Mark subtracts it. The cap is applied in CombatSim._armor_of.
const MICHAEL_MITIGATION := 75
const ARMOR_MICHAEL := 25
const ARMOR_CAP := 75
const SHIELD_WALL_ARMOR := 50
const MARK_ARMOR := 50
const POWER_BASE := 100
const CRIT_BASE := 0
const CRIT_MULT := 200
const DODGE_BASE := 0
# Dash is a dodge buff, not a hop. 55% for 4 seconds.
const DASH_DODGE := 55
const DASH_DODGE_TICKS := 80
const THREAT_MICHAEL := 1600
const THREAT_BASE := 100
# A curse lands only when a mob is this close, or a trap delivers it.
const CURSE_NEAR := 8000
# v1.1.3: elixir was never the limit. A party heal of 32 could not keep a
# cursed party up, and a single heal halved by Rot landed around 31.
const HEAL_SINGLE := 140
const HEAL_PARTY := 110
const REVIVE_CHANNEL := 60
const REVIVE_PCT := 40
const REVIVE_INTERRUPT := 14
# Half of Slow Revive (18 points). Was 3000 when that rite cost 6000.
const REVIVE_REFUND := 900
const BURST_DMG := 74
# Azrael's elixir strike. Melee, single target, heavier than Burst.
const STRIKE_DMG := 108
# Uriel's elixir nuke. Ranged primary hit plus a small splash around that foe.
const SUNSTRIKE_DMG := 86
const SUNSTRIKE_SPLASH := 40
const SUNSTRIKE_RADIUS := 1000
const DASH_TICKS := 30
const DASH_DISTANCE := 2400
const BEAM_TICKS := 24
const BEAM_PULSE := 8
const BEAM_PULSES := 3
const BEAM_DMG := 16
const BEAM_HALF_WIDTH := 500
const HOLY_ZONE_DMG := 9
const HOLY_ZONE_TICKS := 60
const RADIANCE_CAP := 5
const RADIANCE_PER_STACK := 20
const SELF_SHIELD := 55
const EMERGENCY_PCT := 25
const GABRIEL_AURA := 112
const RAPHAEL_REGEN := 1
const RAPHAEL_REGEN_PERIOD := 8
const DISENGAGE_DISTANCE := 2500
const DISENGAGE_TICKS := 30
# Weaken is the low cleanse tier (after Silence, Rot, and Mark). Outgoing damage kept.
const WEAKEN_DEALT := 80
const WEAKEN_TICKS := 120
const PHALANX_TICKS := 60
const PHALANX_ABSORB := 28
const SCATTER_TICKS := 70
const SCATTER_IFRAME := 12
const SCATTER_SHOVE := 1400
# Long enough that one cast still covers the healer when Cleanse is never
# pressed. Gabriel clears it on the next cast, so a party that cleanses
# only eats the telegraph.
const SILENCE_TICKS := 420
const ROT_TICKS := 100
const ROT_PERIOD := 10
# One stack is 6 dps (was 10). Reapply adds a stack, capped, instead of refreshing a flat 10.
const ROT_DMG := 3
const ROT_STACK_CAP := 3
const MARK_TICKS := 120
const MARK_AMP := 150

const MOLTEN_RADIUS := 1300
const MOLTEN_DMG := 4
const BLINK_PERIOD := 200
const BLINK_TELEGRAPH := 36
const BLINK_DMG := 12

const ALTAR_RANGE := 1600
const ALTAR_PER_TICK := 2
# 400 / 2 ticks = 10s to claim a stake. Long enough to be a hold, short of the turtle.
const ALTAR_NEED := 400
# Purifying shrine. Standing on the room's shrine and channeling clears its traps.
const SHRINE_CHANNEL := 40
const SHRINE_RANGE := 1600
const ALTAR_REVIVE_DELAY := 20
# Lethal damage downs an angel for 10 seconds. Revive rites can still reach
# them; when the window closes the death is final. A revive already queued
# holds the window open until that command resolves.
const DOWNED_TICKS := 200

# Mob bodies. 1.0.2 values, for the balance note:
#   imp 34 HP / atk 6 / period 18, heavy 260 / 13 / 18, elite 420 / 12 / 20.
# A focused party killed an imp in under a second. These HP totals are a
# sustained exchange: several seconds on an imp, longer on a heavy and an elite.
# Attacks came down slightly so the extra time stays survivable.
const IMP_HP := 240
const IMP_ATK := 5
const IMP_PERIOD := 18
const IMP_RANGE := 1100
const IMP_SPEED := 140
const HEAVY_HP := 480
const HEAVY_ATK := 10
const HEAVY_PERIOD := 20
const HEAVY_RANGE := 1200
const HEAVY_SPEED := 78
const ELITE_HP := 1080
const ELITE_ATK := 11
const ELITE_PERIOD := 20
const ELITE_RANGE := 1300
const ELITE_SPEED := 88
# Every Nth swing is also a pulse that reaches the whole fighting team.
const MOB_AOE_EVERY := 4
const MOB_AOE_RADIUS := 5200
const IMP_AOE := 4
const HEAVY_AOE := 7
const ELITE_AOE := 9

# The crawl is the siege. Lucifer is the climax, not most of the clock:
# about two minutes of telegraphs. 1.0.4 was 4600. Party-wide mob pulses
# and a full opening Dark bar lengthened that fight past the window;
# 4000 puts a casting party back in the 1.5–2 minute climax without
# touching mob HP.
const LUCIFER_HP := 4000
const LUCIFER_HP_EARLY := 2100
const JUDGMENT_DMG := 48
const CLEAVE_DMG := 34
const HELL_RAIN_DMG := 26
const HELL_RAIN_RADIUS := 1000
const GRASP_DMG := 16
const GRASP_PULL := 1400
const CLEAVE_HALF_WIDTH := 700
const CLEAVE_LENGTH := 5600


## Player-facing cost on the 0–100 bar. Cheap utility sits low; nukes and
## the two revives sit at the top of the 5–20 band. Scatter and Phalanx are free.
static func point_cost(ability: String) -> int:
	match ability:
		"detect_pulse":
			return 5
		"single_heal", "cleanse":
			return 6
		"taunt", "body_block", "disarm", "escape_dash", "disengage", "self_shield":
			return 8
		"strike":
			return 10
		"shield_wall", "burst", "beam":
			return 12
		"sunstrike":
			return 14
		"party_heal", "aoe_zone":
			return 15
		"slow_revive":
			return 18
		"emergency_res":
			return 20
		"scatter", "phalanx":
			return 0
		_:
			return 0


static func cost(ability: String) -> int:
	return point_cost(ability) * POINT


static func points_of(internal: int) -> int:
	return internal / POINT


## Elixir abilities have no cooldown. The bar is the only gate.
## Scatter and Phalanx spend nothing, so they keep a short lockout.
static func cooldown(ability: String) -> int:
	match ability:
		"phalanx":
			return 200
		"scatter":
			return 140
		_:
			return 0


static func summon_cost(unit: String) -> int:
	match unit:
		"swarm":
			return 1600
		"heavy":
			return 3000
		"elite":
			return 5500
		_:
			return 99999


static func trap_cost(kind: String) -> int:
	match kind:
		"spike":
			return 900
		"snare":
			return 1200
		"hellflame":
			return 1800
		_:
			return 99999


static func curse_cost(kind: String) -> int:
	match kind:
		"silence":
			return 1600
		"rot":
			return 1800
		"mark":
			return 2000
		"weaken":
			return 1400
		_:
			return 99999


static func owner_of(ability: String) -> String:
	match ability:
		"taunt", "shield_wall", "body_block":
			return "michael"
		"single_heal", "party_heal", "slow_revive":
			return "raphael"
		"burst", "disarm", "escape_dash", "detect_pulse", "strike":
			return "azrael"
		"beam", "aoe_zone", "disengage", "sunstrike":
			return "uriel"
		"cleanse", "self_shield", "emergency_res":
			return "gabriel"
		_:
			return ""


static func ability_label(ability: String) -> String:
	match ability:
		"taunt":
			return "Taunt"
		"shield_wall":
			return "Shield"
		"body_block":
			return "Body Block"
		"single_heal":
			return "Heal"
		"party_heal":
			return "Party Heal"
		"slow_revive":
			return "Revive"
		"burst":
			return "Burst"
		"strike":
			return "Strike"
		"sunstrike":
			return "Sunstrike"
		"disarm":
			return "Disarm"
		"escape_dash":
			return "Dash"
		"detect_pulse":
			return "Detect"
		"beam":
			return "Beam"
		"aoe_zone":
			return "Holy Zone"
		"disengage":
			return "Disengage"
		"cleanse":
			return "Cleanse"
		"self_shield":
			return "Self Shield"
		"emergency_res":
			return "Emergency"
		"scatter":
			return "Scatter"
		"phalanx":
			return "Phalanx"
		_:
			return ability


static func golden_regen(stage: int) -> int:
	var i := clampi(stage, 0, GOLDEN_CURVE.size() - 1)
	return int(GOLDEN_CURVE[i])


static func dark_regen(stage: int) -> int:
	var i := clampi(stage, 0, DARK_CURVE.size() - 1)
	return int(DARK_CURVE[i])


static func tier_ok(unit: String, rooms_cleared: int) -> bool:
	match unit:
		"swarm":
			return true
		"heavy":
			return rooms_cleared >= HEAVY_ROOMS
		"elite":
			return rooms_cleared >= ELITE_ROOMS
		_:
			return false


## Dynamic Threat Budgeting. hp_pct is 0-100 collective remaining HP.
static func mob_aoe(subtype: String) -> int:
	match subtype:
		"heavy":
			return HEAVY_AOE
		"elite":
			return ELITE_AOE
		_:
			return IMP_AOE


static func echo_budget(bank: int, hp_pct: int, early: bool) -> int:
	var b := bank
	if hp_pct < 40:
		b = mini(b, 3000)
	elif hp_pct < 80:
		b = b * (40 + hp_pct) / 140
	if early:
		b = b * 60 / 100
	if b < 0:
		return 0
	return b
