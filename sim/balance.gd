class_name Balance
extends RefCounted
## Prototype 0 numbers. Tune here; the sim should not hardcode a second copy.

const TICK_HZ := 20
const MILLI := 1000
const ELIXIR_MAX := 10000
const GOLDEN_START := 4500
const DARK_START := 4200

# Milli-elixir per tick. Index is the stage reached (0 descent … 3 approach).
# Index 4 is the Lucifer phase. Each step's gain is larger than the last,
# so the finale is the explosive peak and the opening is deliberately poor.
const GOLDEN_CURVE: Array[int] = [3, 6, 12, 24, 48]
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

const TURTLE_WARN_TICKS := 240
const TURTLE_TICKS := 360
const TURTLE_DMG_PERIOD := 10
const TURTLE_DMG := 2
const TURTLE_DARK_PER_TICK := 22

const ROUTE_LOCK_TICKS := 60
const FOCUS_TICKS := 160
const SPAWN_TELEGRAPH := 20
const ECHO_DELAY := 100
const CURSE_CAST_MARK := 60
const CURSE_CAST := 50

const DETECT_AURA := 2200
const DETECT_PULSE := 5600
const DISARM_RANGE := 1600
const HELLFLAME_RADIUS := 1800
const SPIKE_STEP := 450
const TIGHT_SPIKE := 950

const TRAP_CAP := 4
const ECHO_TRAP_CAP := 2
const MOB_CAP := 6
const TRAP_MIN_DIST := 4000

const TAUNT_RADIUS := 3200
const TAUNT_TICKS := 80
const SHIELD_WALL_TICKS := 60
const BODY_BLOCK_TICKS := 80
const PHALANX_TICKS := 60
const PHALANX_ABSORB := 28
const SCATTER_TICKS := 50
const SCATTER_IFRAME := 12
const SCATTER_SHOVE := 1400
const SILENCE_TICKS := 80
const ROT_TICKS := 100
const ROT_PERIOD := 10
const ROT_DMG := 5
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
const ALTAR_REVIVE_DELAY := 20
# Lethal damage downs an angel for 3 seconds. Revive rites can still reach
# them; when the window closes the death is final.
const DOWNED_TICKS := 60

# The crawl is the siege. Lucifer is the climax, not most of the clock:
# a healthy party burns this down in a couple of minutes of telegraphs.
const LUCIFER_HP := 3200
const LUCIFER_HP_EARLY := 2100
const JUDGMENT_DMG := 48
const CLEAVE_DMG := 34
const HELL_RAIN_DMG := 26
const HELL_RAIN_RADIUS := 1000
const GRASP_DMG := 16
const GRASP_PULL := 1400
const CLEAVE_HALF_WIDTH := 700
const CLEAVE_LENGTH := 5600


static func cost(ability: String) -> int:
	match ability:
		"taunt", "body_block", "disarm", "escape_dash", "disengage", "self_shield":
			return 2000
		"single_heal", "cleanse":
			return 1500
		"shield_wall", "burst", "beam":
			return 3000
		"party_heal", "aoe_zone":
			return 4000
		"slow_revive":
			return 6000
		"emergency_res":
			return 8000
		"detect_pulse":
			return 1000
		"scatter", "phalanx":
			return 0
		_:
			return 0


static func cooldown(ability: String) -> int:
	match ability:
		"taunt", "escape_dash", "detect_pulse":
			return 160
		"shield_wall", "aoe_zone":
			return 240
		"body_block", "self_shield", "phalanx":
			return 200
		"single_heal":
			return 60
		"party_heal":
			return 260
		"slow_revive":
			return 400
		"burst", "cleanse":
			return 100
		"disarm":
			return 70
		"beam":
			return 50
		"disengage":
			return 160
		"emergency_res":
			return 600
		"scatter":
			return 140
		_:
			return 40


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
		_:
			return 99999


static func owner_of(ability: String) -> String:
	match ability:
		"taunt", "shield_wall", "body_block":
			return "michael"
		"single_heal", "party_heal", "slow_revive":
			return "raphael"
		"burst", "disarm", "escape_dash", "detect_pulse":
			return "azrael"
		"beam", "aoe_zone", "disengage":
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
