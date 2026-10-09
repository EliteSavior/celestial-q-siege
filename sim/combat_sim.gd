class_name CombatSim
extends RefCounted
## Authoritative combat simulation.
##
## Angels and the demon (the director now, a human later) submit the same
## commands. tick_once() is an integer step: no frame delta. Dodge, crit,
## and the director draw a seeded xorshift, so one seed replays bit-for-bit.
## The renderer may only trust build_snapshot(). Fair play is assumed.

const STANCE_TIGHT := 0
const STANCE_SPREAD := 1
const STANCE_COLUMN := 2

const _STANCE_NAME := ["Tight", "Spread", "Column"]

const _KIT := {
	"michael": ["taunt", "shield_wall", "body_block"],
	"raphael": ["single_heal", "party_heal", "slow_revive"],
	"azrael": ["strike", "burst", "disarm", "escape_dash"],
	"uriel": ["sunstrike", "beam", "aoe_zone", "disengage"],
	"gabriel": ["cleanse", "self_shield", "emergency_res"],
}

const _HERO := [
	{"subtype": "michael", "name": "Michael", "hp": 320, "atk": 8, "period": 20, "range": 1400},
	{"subtype": "raphael", "name": "Raphael", "hp": 175, "atk": 4, "period": 22, "range": 1300},
	{"subtype": "azrael", "name": "Azrael", "hp": 175, "atk": 15, "period": 16, "range": 1250},
	{"subtype": "uriel", "name": "Uriel", "hp": 165, "atk": 12, "period": 18, "range": 5400},
	{"subtype": "gabriel", "name": "Gabriel", "hp": 150, "atk": 6, "period": 20, "range": 4200},
]

const _TIGHT := [
	Vector2i(280, 0), Vector2i(0, -260), Vector2i(0, 260), Vector2i(-260, -140), Vector2i(-300, 160),
]
const _SPREAD := [
	Vector2i(200, 0), Vector2i(0, -1900), Vector2i(0, 1900), Vector2i(-1700, -800), Vector2i(-1900, 700),
]
const _COLUMN := [
	Vector2i(0, 0), Vector2i(-850, 0), Vector2i(-1700, 0), Vector2i(-2550, 0), Vector2i(-3400, 0),
]

var tick := 0
var map: DungeonMap
var director: DemonDirector
var director_enabled := true
var entities := {}
var order: Array = []
var next_id := 1
var queue: Array = []
var seq := 0

var golden := Balance.GOLDEN_START
var dark := Balance.DARK_START
# Successful Golden spends. View and tests read it; it never changes a tick.
var ability_casts := 0
var angel_acted := false
var stance := STANCE_TIGHT
var facing := Vector2i(1, 0)
var anchor := Vector2i.ZERO
var path: Array = []
var move_goal_room := ""
var move_goal_tile := Vector2i(-1, -1)
var ignore_traps := false
var last_move_key := ""
var last_move_tick := -999
var route_lock_room := ""
var route_lock_until := 0

var focus_id := 0
var focus_until := 0
# Living hero chosen by a tap. Single heal spends on this angel when set.
var ally_target := ""
var phase := "dungeon"
var outcome := ""
var max_depth := 0
var stage_reached := 0
var rooms_cleared := 0
var cleared := {}
var visited := {}
var shield_wall_until := 0
var shield_wall_facing := Vector2i(1, 0)
var taunt_until := 0
var taunt_id := 0
# Lasts after the force window. Multiplies Michael's later threat gains.
var threat_boost_until := 0
var shrine_progress := 0
var shrines_done := {}
var channeling_shrine := false
var root_until := 0
var root_total := 0
var scatter_until := 0
var iframe_until := 0
var phalanx_until := 0
var disengage_until := 0
var altar_progress := 0
var altar_done := false
var seal_progress := 0
var seal_done := false
var font_progress := 0
var font_done := false
var cleanse_charges := 0
var revive_charges := 0
var pending_revives: Array = []
var channeling_altar := false
var idle_ticks := 0
var corruption := false
var corruption_warned := false
var turtle_clock := 0
var curse_grace_until := 0
var run_seed := 1
var rng_state := 1
var god_mode := false
var infinite_elixir := false
var curses_enabled := true
var traps_enabled := true
var hero_report := {}
var debug_log: Array = []

var traps_placed := 0
var spawns_placed := 0
var curses_cast := 0
var echo_style := ""
var echo_units: Array = []
var echo_traps := 0
var echo_spent := 0
var echo_spawned := false
var early_descend := false
var banner := ""
var banner_until := 0
var lucifer_pattern: Array = []
var lucifer_step := 0
var lucifer_next := 0
var transform_until := 0
var telegraph := {}
var hell_rain_marks: Array = []

var golden_income_room := {}
var dark_income_room := {}
var trap_dark_room := {}
var feed: Array = []
var popups: Array = []
var last_fail := ""
var last_fail_tick := -999
var stats := {
	"damage_dealt": 0,
	"damage_taken": 0,
	"traps_triggered": 0,
	"traps_disarmed": 0,
	"curses_cleansed": 0,
	"revives": 0,
}
var maneuver_cd := {"scatter": 0, "phalanx": 0}
var trap_cap := Balance.TRAP_CAP
var party_room_id := "start"
var _prev_room := "start"


func _init() -> void:
	reset()


func reset() -> void:
	tick = 0
	map = DungeonMap.new()
	director = DemonDirector.new()
	director.setup(self)
	entities = {}
	order = []
	next_id = 1
	queue = []
	seq = 0
	golden = Balance.GOLDEN_START
	dark = Balance.DARK_START
	ability_casts = 0
	angel_acted = false
	stance = STANCE_TIGHT
	facing = Vector2i(1, 0)
	anchor = Fixed.tile_center(map.center_tile("start"))
	path = []
	move_goal_room = ""
	move_goal_tile = Vector2i(-1, -1)
	ignore_traps = false
	last_move_key = ""
	last_move_tick = -999
	route_lock_room = ""
	route_lock_until = 0
	focus_id = 0
	focus_until = 0
	ally_target = ""
	phase = "dungeon"
	outcome = ""
	max_depth = 0
	stage_reached = 0
	rooms_cleared = 0
	cleared = {"start": true}
	visited = {"start": true}
	shield_wall_until = 0
	shield_wall_facing = Vector2i(1, 0)
	taunt_until = 0
	taunt_id = 0
	threat_boost_until = 0
	shrine_progress = 0
	shrines_done = {}
	channeling_shrine = false
	root_until = 0
	root_total = 0
	scatter_until = 0
	iframe_until = 0
	phalanx_until = 0
	disengage_until = 0
	altar_progress = 0
	altar_done = false
	seal_progress = 0
	seal_done = false
	font_progress = 0
	font_done = false
	cleanse_charges = 0
	revive_charges = 0
	pending_revives = []
	channeling_altar = false
	idle_ticks = 0
	corruption = false
	corruption_warned = false
	turtle_clock = 0
	curse_grace_until = 0
	_reseed()
	god_mode = false
	infinite_elixir = false
	curses_enabled = true
	traps_enabled = true
	hero_report = {}
	debug_log = []
	traps_placed = 0
	spawns_placed = 0
	curses_cast = 0
	echo_style = ""
	echo_units = []
	echo_traps = 0
	echo_spent = 0
	echo_spawned = false
	early_descend = false
	banner = ""
	banner_until = 0
	lucifer_pattern = ["hell_rain", "cleave", "judgment", "grasp"]
	lucifer_step = 0
	lucifer_next = 0
	transform_until = 0
	telegraph = {}
	hell_rain_marks = []
	golden_income_room = {}
	dark_income_room = {}
	trap_dark_room = {}
	feed = []
	popups = []
	last_fail = ""
	last_fail_tick = -999
	stats = {"damage_dealt": 0, "damage_taken": 0, "traps_triggered": 0, "traps_disarmed": 0, "curses_cleansed": 0, "revives": 0}
	maneuver_cd = {"scatter": 0, "phalanx": 0}
	trap_cap = Balance.TRAP_CAP
	party_room_id = "start"
	_prev_room = "start"
	_spawn_heroes()
	for spec in _HERO:
		hero_report[str(spec.subtype)] = {"damage": 0, "healing": 0, "threat": 0, "taken": 0}
	_log("The siege begins. Three forks, three stakes, then the throne.", "info")
	debug_line("seed %d" % run_seed)


func submit(type: String, args: Dictionary = {}, who: String = "angel", delay: int = 1) -> void:
	seq += 1
	queue.append({
		"type": type,
		"args": args.duplicate(true),
		"who": who,
		"seq": seq,
		"due": tick + maxi(delay, 1),
	})


func tick_once() -> void:
	if outcome != "":
		return
	tick += 1
	_drain_commands()
	_regen()
	if director_enabled and director != null:
		director.on_tick()
	_movement()
	_formation()
	_sync_room()
	_passives()
	_maybe_repath()
	_arm_echo_traps()
	_trigger_traps()
	_mob_ai()
	_angel_autos()
	_channels()
	_zones_and_auras()
	_curses_land()
	_commitments_land()
	_lucifer()
	_stakes()
	_shrines()
	_turtle()
	_resolve_revives()
	_tick_downed()
	_clears()
	_win_lose()
	_prune_popups()


# --- commands ---------------------------------------------------------------

func _drain_commands() -> void:
	var due: Array = []
	var keep: Array = []
	for c in queue:
		if int(c.due) <= tick:
			due.append(c)
		else:
			keep.append(c)
	queue = keep
	due.sort_custom(func(a, b): return int(a.seq) < int(b.seq))
	for c in due:
		_exec(c)


func opening_grace() -> bool:
	return not angel_acted and tick <= Balance.OPENING_GRACE_TICKS


func grace_left() -> int:
	if not opening_grace():
		return 0
	return maxi(0, Balance.OPENING_GRACE_TICKS - tick)


func _exec(c: Dictionary) -> void:
	if str(c.get("who", "")) == "angel":
		angel_acted = true
	var type := str(c.type)
	var args: Dictionary = c.args
	match type:
		"move_room":
			_cmd_move_room(str(args.get("room", "")))
		"move_tile":
			_cmd_move_tile(_vec(args.get("tile", Vector2i.ZERO)))
		"stance":
			_cmd_stance(int(args.get("stance", stance)))
		"focus":
			_cmd_focus(int(args.get("id", 0)))
		"ally":
			_cmd_ally(str(args.get("target", "")))
		"shield", "heal", "cleanse", "detect", "burst":
			_cast(_route(type), args)
		"ability":
			_cast(str(args.get("name", "")), args)
		"steer":
			_cmd_steer(_vec(args.get("pos", Vector2i.ZERO)))
		"scatter":
			_cast_scatter()
		"phalanx":
			_cast_phalanx()
		"channel_altar":
			channeling_altar = true
		"channel_shrine":
			channeling_shrine = true
		"stop_channel":
			channeling_altar = false
			channeling_shrine = false
		"spawn":
			_cmd_spawn(args)
		"trap":
			_cmd_trap(args)
		"curse":
			_cmd_curse(args)
		"descend":
			_cmd_descend(bool(args.get("early", false)))
		"boss":
			_cmd_boss(str(args.get("button", "")))
		"commit":
			_cmd_commit(args)
		"debug_spawn":
			_cmd_debug_spawn(args)
		"debug_god":
			_cmd_debug_flag("god")
		"debug_infinite":
			_cmd_debug_flag("infinite")
		"debug_heal":
			_cmd_debug_heal()
		"debug_dread":
			_cmd_debug_dread(bool(args.get("fill", true)))
		"debug_summon":
			_cmd_debug_spawn({"unit": "swarm"})
		"debug_teleport":
			_cmd_debug_teleport(str(args.get("room", "")))
		"debug_curses":
			_cmd_debug_toggle("curses", bool(args.get("on", true)))
		"debug_traps":
			_cmd_debug_toggle("traps", bool(args.get("on", true)))
		"debug_seed":
			_cmd_debug_seed(int(args.get("seed", run_seed)))
		_:
			_fail("Unknown command.")


func _cmd_move_room(room: String) -> void:
	if not map.by_id.has(room):
		_fail("Nowhere to go.")
		return
	if _route_blocked(room):
		_fail("Route committed — hold the line.")
		return
	var tile := map.center_tile(room)
	if map.by_id[room].corridor:
		tile = _corridor_goal(room)
	_begin_move(tile, room)


func _cmd_move_tile(tile: Vector2i) -> void:
	if map.at(tile) < 0:
		_fail("Blocked.")
		return
	var key := "%s,%s" % [tile.x, tile.y]
	if key == last_move_key and tick - last_move_tick < 40:
		ignore_traps = true
	else:
		ignore_traps = false
	last_move_key = key
	last_move_tick = tick
	_begin_move(tile, "")


func _begin_move(tile: Vector2i, room: String) -> void:
	if room != "" and room == move_goal_room and not path.is_empty():
		return
	if tile == move_goal_tile and room == "" and not path.is_empty():
		return
	if _route_blocked(room):
		_fail("Route committed — hold the line.")
		return
	var start := Fixed.tile_of(anchor)
	var extra := _trap_costs()
	var found: Array = Pathing.find(map.walk, map.width, map.height, start, tile, extra)
	if found.is_empty():
		_fail("No path.")
		return
	path = found
	if path.size() > 0 and path[0] == start:
		path.pop_front()
	move_goal_room = room
	move_goal_tile = tile
	channeling_altar = false
	if _is_branch_choice(room):
		route_lock_room = room
		route_lock_until = tick + Balance.ROUTE_LOCK_TICKS
		var hint: String = str(map.by_id[room].hint)
		_log("Committed: %s (%s)." % [map.by_id[room].name, hint], "info")


func _is_branch_choice(room: String) -> bool:
	var info = map.by_id.get(room, {})
	if info.is_empty():
		return false
	return str(info.get("kind", "")) in ["trapped", "summoned", "cursed"]


func _route_blocked(room: String) -> bool:
	if room == "" or route_lock_until <= tick:
		return false
	if not _is_branch_choice(room):
		return false
	return room != route_lock_room


func _cmd_stance(next: int) -> void:
	if next < 0 or next > 2 or next == stance:
		return
	stance = next
	_log("Stance: %s." % _STANCE_NAME[stance], "info")


func _cmd_ally(name: String) -> void:
	var hero := _hero(name)
	if hero.is_empty() or not hero.alive:
		return
	if ally_target == name:
		ally_target = ""
		_log("Mend target cleared.", "info")
		return
	ally_target = name
	_log("Mend target: %s." % hero.name, "info")


func _cmd_focus(id: int) -> void:
	if id == focus_id:
		focus_id = 0
		focus_until = 0
		_log("Focus cleared.", "info")
		return
	var e := _ent(id)
	if e.is_empty() or not e.alive or str(e.team) != "demon":
		return
	focus_id = id
	focus_until = tick + Balance.FOCUS_TICKS
	_log("Focus: %s." % e.name, "info")


func _route(cmd: String) -> String:
	match cmd:
		"shield":
			if _any_mark() and _hero("michael").alive:
				return "body_block"
			return "shield_wall"
		"heal":
			if _downed_count() > 0 and _lowest_living_pct() >= 70:
				return "slow_revive"
			if _below_pct(70) >= 2:
				return "party_heal"
			return "single_heal"
		"cleanse":
			return "cleanse"
		"detect":
			if not _disarm_target().is_empty():
				return "disarm"
			return "detect_pulse"
		"burst":
			if _cluster_count() >= 3 and int(_hero("uriel").get("radiance", 0)) >= 2 and _hero("uriel").alive:
				return "aoe_zone"
			var az := _hero("azrael")
			var foe := _focus_or_nearest(az)
			if az.alive and not foe.is_empty() and Fixed.dist(az.pos, foe.pos) <= int(az.range):
				return "burst"
			return "beam"
		_:
			return ""


func _cast(ability: String, args: Dictionary = {}) -> void:
	if ability == "":
		return
	var owner_name := Balance.owner_of(ability)
	var owner := _hero(owner_name)
	if owner.is_empty() or not owner.alive:
		_fail("%s is down." % owner_name.capitalize())
		return
	if int(owner.silence_until) > tick and ability != "escape_dash":
		_fail("%s is silenced." % owner.name)
		return
	var ready := int(owner.cooldowns.get(ability, 0))
	if tick < ready:
		_fail("%s is not ready." % Balance.ability_label(ability))
		return
	var price := Balance.cost(ability)
	if golden < price:
		_fail("Not enough Golden Elixir.")
		return
	if not _apply_ability(ability, owner, args):
		return
	golden -= price
	ability_casts += 1
	owner.cooldowns[ability] = tick + Balance.cooldown(ability)


func _apply_ability(ability: String, owner: Dictionary, args: Dictionary = {}) -> bool:
	match ability:
		"taunt":
			var pulled := _taunt_target(args)
			if pulled.is_empty():
				_fail("No one to taunt.")
				return false
			taunt_id = int(pulled.id)
			taunt_until = tick + Balance.TAUNT_TICKS
			_snap_taunt_threat(pulled)
			pulled.pulled = true
			if pulled.get("blink", {}) is Dictionary and not pulled.blink.is_empty():
				pulled.blink = {}
				pulled.teleport_at = tick + Balance.BLINK_PERIOD
			_log("Michael taunts %s." % pulled.name, "good")
			return true
		"shield_wall":
			shield_wall_until = tick + Balance.SHIELD_WALL_TICKS
			shield_wall_facing = facing
			_log("Shield wall.", "good")
			return true
		"body_block":
			owner.body_block_until = tick + Balance.BODY_BLOCK_TICKS
			_log("Michael will intercept the next strike.", "good")
			return true
		"single_heal":
			var tgt := _heal_target(args)
			if tgt.is_empty():
				_fail("No one to heal.")
				return false
			_heal(tgt, Balance.HEAL_SINGLE, int(owner.id))
			_log("Raphael heals %s." % tgt.name, "good")
			return true
		"party_heal":
			var healed := 0
			for a in _angels():
				if a.alive:
					_heal(a, Balance.HEAL_PARTY, int(owner.id))
					healed += 1
			if healed == 0:
				_fail("No one to heal.")
				return false
			_log("Raphael mends the party.", "good")
			return true
		"slow_revive":
			var dead := _named_angel(args, false)
			if dead.is_empty():
				dead = _revive_target()
			elif bool(dead.get("final_death", false)):
				_fail("Death is final.")
				return false
			if dead.is_empty():
				_fail("Death is final." if _has_final_corpse() else "No one is down.")
				return false
			owner.casting = {"ability": "slow_revive", "until": tick + Balance.REVIVE_CHANNEL, "target": dead.id}
			_log("Raphael begins a resurrection.", "good")
			return true
		"burst":
			var foe := _picked_foe(owner, args, int(owner.range) + 150)
			if foe.is_empty() or Fixed.dist(owner.pos, foe.pos) > int(owner.range) + 150:
				_fail("Burst has no target in reach.")
				return false
			_hurt(foe, _out_damage(Balance.BURST_DMG, owner.id), "single", owner.id, false)
			_log("Azrael bursts %s." % foe.name, "good")
			return true
		"strike":
			var strike_foe := _picked_foe(owner, args, int(owner.range) + 150)
			if strike_foe.is_empty() or Fixed.dist(owner.pos, strike_foe.pos) > int(owner.range) + 150:
				_fail("Strike has no target in reach.")
				return false
			_hurt(strike_foe, _out_damage(Balance.STRIKE_DMG, owner.id), "single", owner.id, false)
			_log("Azrael strikes %s." % strike_foe.name, "good")
			return true
		"disarm":
			var trap := _disarm_target()
			if trap.is_empty():
				_fail("No revealed trap in reach.")
				return false
			_remove_trap(trap, true)
			_log("Azrael disarms a trap.", "good")
			return true
		"escape_dash":
			owner.dodge_until = tick + Balance.DASH_DODGE_TICKS
			owner.dodge_bonus = Balance.DASH_DODGE
			_log("Azrael's Dodge surges.", "good")
			debug_line("dash dodge %d for %d" % [Balance.DASH_DODGE, Balance.DASH_DODGE_TICKS])
			return true
		"detect_pulse":
			var n := _reveal_radius(owner.pos, Balance.DETECT_PULSE)
			_log("Detect pulse reveals %d trap%s." % [n, "" if n == 1 else "s"], "info")
			return true
		"sunstrike":
			var nuke := _picked_foe(owner, args, int(owner.range))
			if nuke.is_empty() or Fixed.dist(owner.pos, nuke.pos) > int(owner.range):
				_fail("Sunstrike has no target.")
				return false
			var nuke_at: Vector2i = nuke.pos
			var nuke_id := int(nuke.id)
			_hurt(nuke, _out_damage(Balance.SUNSTRIKE_DMG, owner.id), "single", owner.id, false)
			for splash in _living_mobs():
				if int(splash.id) == nuke_id:
					continue
				if Fixed.dist(splash.pos, nuke_at) > Balance.SUNSTRIKE_RADIUS:
					continue
				_hurt(splash, _out_damage(Balance.SUNSTRIKE_SPLASH, owner.id), "aoe", owner.id, true)
			_log("Uriel's sunstrike hits %s." % nuke.name, "good")
			return true
		"beam":
			var aim := _vec(args.get("pos", Vector2i.ZERO))
			var foe2 := _focus_or_nearest(owner)
			if aim == Vector2i.ZERO:
				if foe2.is_empty():
					_fail("Beam has no target.")
					return false
				aim = foe2.pos
			owner.casting = {
				"ability": "beam",
				"until": tick + Balance.BEAM_TICKS,
				"next": tick + Balance.BEAM_PULSE,
				"pulses": Balance.BEAM_PULSES,
				"target": foe2.id if not foe2.is_empty() else 0,
				"aim": aim,
				"steered": _vec(args.get("pos", Vector2i.ZERO)) != Vector2i.ZERO,
			}
			_log("Uriel's beam locks on.", "good")
			return true
		"aoe_zone":
			var spot := _vec(args.get("pos", Vector2i.ZERO))
			if spot == Vector2i.ZERO:
				spot = _cluster_point(owner)
			if spot == Vector2i.ZERO:
				_fail("No one to burn.")
				return false
			var stacks := int(owner.radiance)
			owner.radiance = 0
			_add_zone(spot, Balance.HELLFLAME_RADIUS, Balance.HOLY_ZONE_TICKS, Balance.HOLY_ZONE_DMG, "holy", stacks)
			_log("Holy zone (Radiance %d)." % stacks, "good")
			return true
		"disengage":
			var delta := _retreat_delta()
			if delta == Vector2i.ZERO:
				_fail("Nowhere to disengage.")
				return false
			anchor = _clamp_pos(anchor + delta)
			for ally in _angels():
				if ally.alive:
					var landed: Vector2i = ally.pos + delta
					ally.pos = landed if _walkable_pos(landed) else _clamp_pos(landed)
			path = []
			move_goal_room = ""
			move_goal_tile = Vector2i(-1, -1)
			disengage_until = tick + Balance.DISENGAGE_TICKS
			channeling_altar = false
			_log("The squad disengages.", "good")
			return true
		"cleanse":
			return _do_cleanse()
		"self_shield":
			owner.shield += Balance.SELF_SHIELD
			_log("Gabriel shields himself.", "good")
			return true
		"emergency_res":
			var dead2 := _named_angel(args, false)
			if dead2.is_empty():
				dead2 = _revive_target()
			elif bool(dead2.get("final_death", false)):
				_fail("Death is final.")
				return false
			if dead2.is_empty():
				_fail("Death is final." if _has_final_corpse() else "No one is down.")
				return false
			if not _revive(dead2, Balance.EMERGENCY_PCT):
				_fail("Death is final.")
				return false
			_log("Gabriel forces %s back." % dead2.name, "good")
			return true
		_:
			_fail("No such rite.")
			return false


func _cmd_steer(pos: Vector2i) -> void:
	if pos == Vector2i.ZERO:
		return
	var uriel := _hero("uriel")
	if uriel.is_empty() or uriel.casting.is_empty():
		return
	if str(uriel.casting.get("ability", "")) != "beam":
		return
	uriel.casting.aim = pos
	uriel.casting.steered = true
	uriel.casting.target = 0


func _do_cleanse() -> bool:
	# One cast clears every curse on the party, including every Rot stack.
	# A snare is a trap root, not a curse, and is left in place.
	var any := corruption
	for a in _angels():
		if _hero_cursed(a):
			any = true
			break
	if not any:
		_fail("Nothing to cleanse.")
		return false
	corruption = false
	corruption_warned = false
	idle_ticks = 0
	turtle_clock = 0
	curse_grace_until = tick + Balance.CURSE_GRACE
	for a in _angels():
		a.silence_until = 0
		a.rot_until = 0
		a.rot_stacks = 0
		a.mark_until = 0
		a.weaken_until = 0
	_log("Gabriel cleanses the party.", "good")
	debug_line("cleanse party, grace %d" % Balance.CURSE_GRACE)
	stats.curses_cleansed += 1
	_grant_golden(Balance.CLEANSE_BOUNTY, party_room_id)
	return true


func _hero_cursed(a: Dictionary) -> bool:
	if a.is_empty():
		return false
	if int(a.get("silence_until", 0)) > tick:
		return true
	if int(a.get("rot_until", 0)) > tick or int(a.get("rot_stacks", 0)) > 0:
		return true
	if int(a.get("mark_until", 0)) > tick:
		return true
	if int(a.get("weaken_until", 0)) > tick:
		return true
	return false


func _named_angel(args: Dictionary, must_live: bool) -> Dictionary:
	var name := str(args.get("target", ""))
	if name == "":
		return {}
	var hero := _hero(name)
	if hero.is_empty():
		return {}
	if must_live and not hero.alive:
		return {}
	if not must_live and hero.alive:
		return {}
	return hero


func _snap_taunt_threat(mob: Dictionary) -> void:
	var michael := _hero("michael")
	if michael.is_empty():
		return
	if typeof(mob.get("threat", null)) != TYPE_DICTIONARY:
		mob.threat = {}
	var top := 0
	for a in _angels():
		if int(a.id) == int(michael.id):
			continue
		top = maxi(top, int(mob.threat.get(str(a.id), 0)))
	var mine := int(mob.threat.get(str(michael.id), 0))
	mob.threat[str(michael.id)] = maxi(mine, top) + Balance.TAUNT_SNAP
	threat_boost_until = tick + Balance.TAUNT_BOOST_TICKS


func _picked_foe(owner: Dictionary, args: Dictionary, max_range: int) -> Dictionary:
	var picked := _ent(int(args.get("id", 0)))
	if not picked.is_empty() and bool(picked.get("alive", false)) and str(picked.get("team", "")) == "demon":
		if Fixed.dist(owner.pos, picked.pos) <= max_range:
			return picked
	return _focus_or_nearest(owner)


func _taunt_target(args: Dictionary = {}) -> Dictionary:
	var michael := _hero("michael")
	if michael.is_empty() or not michael.alive:
		return {}
	var picked := _ent(int(args.get("id", 0)))
	if _tauntable(picked) and Fixed.dist(michael.pos, picked.pos) <= Balance.TAUNT_RADIUS:
		return picked
	if focus_id != 0 and focus_until > tick:
		var focused := _ent(focus_id)
		if _tauntable(focused) and Fixed.dist(michael.pos, focused.pos) <= Balance.TAUNT_RADIUS:
			return focused
	var back := _lowest_backline()
	var best: Dictionary = {}
	var best_d := 1 << 30
	for m in _living_mobs():
		if not _tauntable(m):
			continue
		if Fixed.dist(michael.pos, m.pos) > Balance.TAUNT_RADIUS:
			continue
		var d := Fixed.dist(m.pos, back.pos) if not back.is_empty() else Fixed.dist(m.pos, michael.pos)
		if d < best_d or (d == best_d and not best.is_empty() and int(m.id) < int(best.id)):
			best = m
			best_d = d
	return best


func _tauntable(m: Dictionary) -> bool:
	if m.is_empty() or not bool(m.get("alive", false)):
		return false
	if str(m.get("team", "")) != "demon":
		return false
	return str(m.get("kind", "")) == "mob"


func _dash_landing(from: Vector2i) -> Vector2i:
	var step := Fixed.rotate_facing(Vector2i(-400, 0), facing)
	var hops := Balance.DASH_DISTANCE / 400
	var cursor := from
	for _i in hops:
		var nxt := cursor + step
		if not _walkable_pos(nxt):
			break
		cursor = nxt
	return cursor


func _retreat_delta() -> Vector2i:
	var step := Fixed.rotate_facing(Vector2i(-500, 0), facing)
	var hops := Balance.DISENGAGE_DISTANCE / 500
	var cursor := anchor
	var moved := Vector2i.ZERO
	for _i in hops:
		var nxt := cursor + step
		if not _walkable_pos(nxt):
			break
		cursor = nxt
		moved += step
	return moved


func _cast_scatter() -> void:
	if tick < int(maneuver_cd.scatter):
		_fail("Scatter is not ready.")
		return
	maneuver_cd.scatter = tick + Balance.cooldown("scatter")
	scatter_until = tick + Balance.SCATTER_TICKS
	iframe_until = tick + Balance.SCATTER_IFRAME
	var c := anchor
	for a in _angels():
		if not a.alive:
			continue
		var dir: Vector2i = a.pos - c
		if dir == Vector2i.ZERO:
			dir = Vector2i(a.id * 100 - 300, 200)
		var len := Fixed.isqrt(dir.x * dir.x + dir.y * dir.y)
		if len == 0:
			len = 1
		a.pos = _clamp_pos(a.pos + Vector2i(dir.x * Balance.SCATTER_SHOVE / len, dir.y * Balance.SCATTER_SHOVE / len))
	_log("Scatter Roll.", "good")


func _cast_phalanx() -> void:
	if tick < int(maneuver_cd.phalanx):
		_fail("Phalanx is not ready.")
		return
	maneuver_cd.phalanx = tick + Balance.cooldown("phalanx")
	phalanx_until = tick + Balance.PHALANX_TICKS
	stance = STANCE_TIGHT
	for a in _angels():
		if a.alive:
			a.phalanx = Balance.PHALANX_ABSORB
	var step := Fixed.rotate_facing(Vector2i(1000, 0), facing)
	anchor = _clamp_pos(anchor + step)
	_log("Phalanx Push.", "good")


func _cmd_spawn(args: Dictionary) -> void:
	if phase != "dungeon" and not bool(args.get("echo", false)):
		_fail("The dungeon is only an echo.")
		return
	var unit := str(args.get("unit", ""))
	var node := str(args.get("node", ""))
	var echo := bool(args.get("echo", false))
	var paid := bool(args.get("paid", false))
	var garrison := bool(args.get("garrison", false))
	var reason := "" if echo or paid else legal_spawn(unit, node, garrison)
	if reason != "":
		return
	if paid and map.node_tile(node).x < 0:
		return
	if not echo and not paid:
		var cost := Balance.summon_cost(unit)
		if dark >= cost:
			dark -= cost
			spawns_placed += 1
		elif not garrison:
			return
	var pos := Fixed.tile_center(map.node_tile(node))
	var tell := Balance.BOSS_TELL if echo else -1
	var where := _room_title(node)
	if unit == "swarm":
		for i in 3:
			var off := Vector2i((i - 1) * 450, (i - 1) * 280)
			_make_mob("imp", "Imp", pos + off, Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, Balance.IMP_SPEED, [], node, tell)
		_log("Imps claw their way into %s." % where, "bad")
		debug_line("spawn swarm in %s" % where)
	elif unit == "heavy":
		_make_mob("heavy", "Heavy Demon", pos, Balance.HEAVY_HP, Balance.HEAVY_ATK, Balance.HEAVY_PERIOD, Balance.HEAVY_RANGE, Balance.HEAVY_SPEED, [], node, tell)
		_log("A heavy demon rises in %s." % where, "bad")
		debug_line("spawn heavy in %s" % where)
	elif unit == "elite":
		var affixes: Array = [] if echo else ["teleporter", "molten"]
		_make_mob("elite", "Elite", pos, Balance.ELITE_HP, Balance.ELITE_ATK, Balance.ELITE_PERIOD, Balance.ELITE_RANGE, Balance.ELITE_SPEED, affixes, node, tell)
		_log("An elite takes the node in %s — Teleporter, Molten." % where, "bad")
		debug_line("spawn elite in %s" % where)
	elif unit == "imp":
		_make_mob("imp", "Imp", pos, Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, Balance.IMP_SPEED, [], node, tell)
		_log("An imp crawls out in %s." % where, "bad")
		debug_line("spawn imp in %s" % where)


func _cmd_trap(args: Dictionary) -> void:
	if bool(args.get("echo", false)):
		_cmd_echo_trap(args)
		return
	if phase != "dungeon":
		return
	var kind := str(args.get("kind", ""))
	var node := str(args.get("node", ""))
	var paid := bool(args.get("paid", false))
	if paid:
		if map.node_tile(node).x < 0 or node_occupied_by_trap(node):
			return
	elif legal_trap(kind, node) != "":
		return
	if not paid:
		dark -= Balance.trap_cost(kind)
		traps_placed += 1
	var pos := Fixed.tile_center(map.node_tile(node))
	var id := _alloc()
	entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "trap",
		"subtype": kind,
		"name": kind,
		"pos": pos,
		"hp": 1,
		"hp_max": 1,
		"alive": true,
		"armed": true,
		"revealed": false,
		"node": node,
		"room": node.split(":")[0],
		"avoided": false,
		"radius": Balance.HELLFLAME_RADIUS if kind == "hellflame" else 0,
		"curse": str(args.get("curse", "")),
	}
	order.append(id)
	order.sort()


func _cmd_echo_trap(args: Dictionary) -> void:
	if phase != "lucifer":
		return
	var kind := str(args.get("kind", ""))
	var node := str(args.get("node", ""))
	if Balance.trap_cost(kind) >= 99999:
		return
	if map.node_tile(node).x < 0 or node_occupied_by_trap(node):
		return
	var pos := Fixed.tile_center(map.node_tile(node))
	var id := _alloc()
	entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "trap",
		"subtype": kind,
		"name": kind,
		"pos": pos,
		"hp": 1,
		"hp_max": 1,
		"alive": true,
		"armed": false,
		"revealed": true,
		"echo": true,
		"arm_at": tick + Balance.BOSS_TELL,
		"node": node,
		"room": node.split(":")[0],
		"avoided": false,
		"radius": Balance.HELLFLAME_RADIUS if kind == "hellflame" else 0,
	}
	order.append(id)
	order.sort()
	_log("An echo %s is being laid." % kind, "bad")


func _cmd_curse(args: Dictionary) -> void:
	if phase != "dungeon":
		_fail("No new curses in the echo.")
		return
	var kind := str(args.get("kind", ""))
	var target_name := str(args.get("target", ""))
	if legal_curse(kind, target_name) != "":
		return
	var tgt := _hero(target_name)
	dark -= Balance.curse_cost(kind)
	curses_cast += 1
	var cast := Balance.CURSE_CAST_MARK if kind == "mark" else Balance.CURSE_CAST
	var id := _alloc()
	entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "curse",
		"subtype": kind,
		"name": kind,
		"pos": tgt.pos,
		"hp": 1,
		"hp_max": 1,
		"alive": true,
		"target": tgt.id,
		"land": tick + cast,
		"landed": false,
	}
	order.append(id)
	order.sort()
	_log("%s gathers on %s." % [kind.capitalize(), tgt.name], "bad")
	debug_line("curse %s on %s, lands %d" % [kind, tgt.name, tick + cast])


func _cmd_commit(args: Dictionary) -> void:
	if phase != "dungeon":
		return
	var why := legal_commit(args)
	if why != "":
		return
	var plan := str(args.get("plan", ""))
	var pieces: Array = []
	var node := str(args.get("node", ""))
	var cost := 0
	if plan == "elite":
		cost = Balance.summon_cost("elite")
		dark -= cost
		spawns_placed += 1
		pieces = []
	else:
		pieces = args.get("pieces", [])
		for p in pieces:
			var piece_cost := Balance.trap_cost(str(p.get("kind", "")))
			cost += piece_cost
			traps_placed += 1
			if node == "":
				node = str(p.get("node", ""))
		dark -= cost
	if dark < 0:
		dark = 0
	var room := node.split(":")[0]
	var pos := Fixed.tile_center(map.node_tile(node))
	var id := _alloc()
	var stored: Array = []
	for p2 in pieces:
		stored.append({"kind": str(p2.get("kind", "")), "node": str(p2.get("node", "")), "curse": str(p2.get("curse", ""))})
	entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "commitment",
		"subtype": plan,
		"name": plan,
		"pos": pos,
		"hp": 1,
		"hp_max": 1,
		"alive": true,
		"plan": plan,
		"node": node,
		"room": room,
		"pieces": stored,
		"land": tick + Balance.COMMIT_CAST,
		"landed": false,
	}
	order.append(id)
	order.sort()
	if tick >= banner_until:
		banner = "Elite committing" if plan == "elite" else "Trap cluster"
		banner_until = tick + Balance.COMMIT_CAST
	if plan == "elite":
		_log("The demon commits an elite — Teleporter, Molten.", "bad")
	else:
		_log("A trap cluster is being laid.", "bad")


func _cmd_descend(early: bool) -> void:
	if phase == "lucifer":
		return
	phase = "lucifer"
	early_descend = early
	var hp_pct := party_hp_pct()
	var budget := Balance.echo_budget(dark, hp_pct, early)
	echo_spent = budget
	dark -= budget
	if dark < 0:
		dark = 0
	echo_style = _history_style()
	_shape_echo(budget, hp_pct)
	_cut_traps()
	if echo_style == "traps" and traps_placed >= Balance.HISTORY_FLOOR:
		_reignite_traps()
	lucifer_pattern = _pattern_for(echo_style)
	lucifer_step = 0
	transform_until = tick + Balance.TRANSFORM_CAST
	lucifer_next = transform_until
	telegraph = {}
	hell_rain_marks = []
	var hp := Balance.LUCIFER_HP_EARLY if early else Balance.LUCIFER_HP
	var pos := _lucifer_spawn_pos()
	var id := _alloc()
	entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "boss",
		"subtype": "lucifer",
		"name": "Lucifer",
		"pos": pos,
		"hp": hp,
		"hp_max": hp,
		"alive": true,
		"atk": 14,
		"period": 22,
		"atk_cd": 22,
		"range": 2100,
		"speed": 70,
		"shield": 0,
		"room": party_room_id,
	}
	order.append(id)
	order.sort()
	banner = "THE DEMON LORD TRANSFORMS"
	banner_until = transform_until
	var when := "early" if early else "at the throne"
	_log("The demon lord transforms %s. Echo of %s." % [when, echo_style], "bad")
	# One committed wave, paid for by the descent. It arrives after the rise.
	var delay := Balance.TRANSFORM_CAST + Balance.ECHO_DELAY
	for u in echo_units:
		var node := _echo_node()
		var unit := "heavy" if str(u) == "heavy" else "imp"
		submit("spawn", {"unit": unit, "node": node, "echo": true}, "demon", delay)
		delay += 8
	_schedule_echo_traps()
	echo_spawned = true


func legal_boss(button: String) -> String:
	if phase != "lucifer":
		return "phase"
	if outcome != "":
		return "over"
	var boss := _boss()
	if boss.is_empty() or not bool(boss.get("alive", false)):
		return "dead"
	if not _boss_button_ok(button):
		return "button"
	if tick < transform_until:
		return "transform"
	if not telegraph.is_empty():
		return "busy"
	if tick < lucifer_next:
		return "cooling"
	if _command_pending("boss"):
		return "busy"
	return ""


func _boss_button_ok(button: String) -> bool:
	return button == "hell_rain" or button == "cleave" or button == "judgment" or button == "grasp"


func _cmd_boss(button: String) -> void:
	var why := legal_boss(button)
	if why != "":
		return
	var boss := _boss()
	_open_telegraph(boss, button)
	lucifer_step += 1
	lucifer_next = int(telegraph.until) + Balance.BOSS_GAP


# --- legality ---------------------------------------------------------------

func legal_trap(kind: String, node: String) -> String:
	if not traps_enabled:
		return "off"
	if phase != "dungeon":
		return "echo"
	if Balance.trap_cost(kind) > dark:
		return "dark"
	var room := node.split(":")[0]
	if traps_in_room(room) >= Balance.TRAP_CAP_PER_ROOM:
		return "room"
	if _armed_trap_count() >= trap_cap:
		return "cap"
	var tile := map.node_tile(node)
	if tile.x < 0:
		return "node"
	if node_occupied_by_trap(node):
		return "occupied"
	if room == party_room_id:
		return "too close"
	var pos := Fixed.tile_center(tile)
	for a in _angels():
		if a.alive and Fixed.dist(a.pos, pos) < Balance.TRAP_MIN_DIST:
			return "too close"
	return ""


func legal_spawn(unit: String, node: String, garrison: bool = false) -> String:
	if phase != "dungeon":
		return "echo"
	if unit == "swarm" and seal_done:
		return "sealed"
	if not Balance.tier_ok(unit, rooms_cleared):
		return "tier"
	if map.node_tile(node).x < 0:
		return "node"
	# A room the party is standing in still gets its opening pack when the
	# cap is full of mobs homed somewhere else, or the bank is short.
	if garrison:
		return ""
	if Balance.summon_cost(unit) > dark:
		return "dark"
	if mob_count() >= Balance.MOB_CAP:
		return "cap"
	return ""


func legal_curse(kind: String, target_name: String) -> String:
	if not curses_enabled:
		return "off"
	if tick < curse_grace_until:
		return "grace"
	if phase != "dungeon":
		return "echo"
	if Balance.curse_cost(kind) > dark:
		return "dark"
	if _curse_casting() or _command_pending("curse"):
		return "busy"
	var hero := _hero(target_name)
	if hero.is_empty() or not hero.alive:
		return "target"
	return ""


func legal_commit(args: Dictionary) -> String:
	if phase != "dungeon":
		return "echo"
	if commitment_open() or _command_pending("commit"):
		return "busy"
	var plan := str(args.get("plan", ""))
	if plan == "elite":
		return legal_spawn("elite", str(args.get("node", "")))
	if plan != "trap_cluster":
		return "plan"
	var pieces: Array = args.get("pieces", [])
	if pieces.size() < 2:
		return "plan"
	var cost := 0
	var room := ""
	var seen := {}
	for p in pieces:
		var kind := str(p.get("kind", ""))
		var node := str(p.get("node", ""))
		if seen.has(node):
			return "occupied"
		seen[node] = true
		var why := legal_trap(kind, node)
		if why == "dark":
			pass
		elif why != "":
			return why
		var piece_room := node.split(":")[0]
		if room == "":
			room = piece_room
		elif room != piece_room:
			return "room"
		cost += Balance.trap_cost(kind)
	if traps_in_room(room) + pieces.size() > Balance.TRAP_CAP_PER_ROOM:
		return "room"
	if _armed_trap_count() + pieces.size() > trap_cap:
		return "cap"
	if cost > dark:
		return "dark"
	return ""


func can_read(room: String) -> bool:
	if room == "" or room == party_room_id:
		return room != ""
	var info = map.by_id.get(party_room_id, {})
	if info.is_empty():
		return false
	if info.neighbors.has(room):
		return true
	for n in info.neighbors:
		var other = map.by_id.get(str(n), {})
		if not other.is_empty() and other.neighbors.has(room):
			return true
	return false


func traps_in_room(room: String) -> int:
	var n := 0
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)) and str(e.get("room", "")) == room:
			n += 1
		if _commitment_pending(e) and str(e.get("plan", "")) == "trap_cluster":
			for p in e.get("pieces", []):
				if str(p.get("node", "")).begins_with(room + ":"):
					n += 1
	return n


func commitment_open(plan: String = "") -> bool:
	for id in order:
		var e: Dictionary = entities[id]
		if not _commitment_pending(e):
			continue
		if plan == "" or str(e.get("plan", "")) == plan:
			return true
	if plan == "":
		return _command_pending("commit")
	for c in queue:
		if str(c.type) != "commit":
			continue
		if str(c.args.get("plan", "")) == plan:
			return true
	return false


func node_occupied_by_trap(node: String) -> bool:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or str(e.get("node", "")) != node:
			continue
		if bool(e.get("armed", false)):
			return true
		if bool(e.get("echo", false)) and bool(e.get("alive", false)):
			return true
	return false


# --- simulation steps -------------------------------------------------------

func _regen_index() -> int:
	if phase == "lucifer":
		return 4
	return mini(stage_reached, 3)


func _regen() -> void:
	var idx := _regen_index()
	var g := Balance.golden_regen(idx)
	var d := Balance.dark_regen(idx)
	if opening_grace():
		d = 0
	elif corruption:
		d += Balance.TURTLE_DARK_PER_TICK
	golden = mini(Balance.ELIXIR_MAX, golden + g)
	dark = mini(Balance.ELIXIR_MAX, dark + d)
	if infinite_elixir:
		golden = Balance.ELIXIR_MAX


func _movement() -> void:
	if tick < root_until:
		idle_ticks = 0
		return
	if path.is_empty():
		_idle_tick()
		return
	idle_ticks = 0
	if corruption:
		corruption = false
		_log("You step out of the corruption.", "good")
	var speed := Balance.MOVE_SPEED
	if _effective_stance() == STANCE_COLUMN and _room_is_corridor():
		speed += Balance.COLUMN_SPEED_BONUS
	if tick < disengage_until:
		speed = speed * 140 / 100
	var before := anchor
	var guard := 0
	while guard < 3 and not path.is_empty():
		var center: Vector2i = Fixed.tile_center(path[0])
		anchor = Fixed.step_toward(anchor, center, speed)
		if anchor == center:
			path.pop_front()
			speed = 0
		else:
			break
		guard += 1
	var delta := anchor - before
	var ax := absi(delta.x)
	var ay := absi(delta.y)
	if ax == 0 and ay == 0:
		pass
	elif ay * 2 < ax:
		facing = Vector2i(Fixed.sign_i(delta.x), 0)
	elif ax * 2 < ay:
		facing = Vector2i(0, Fixed.sign_i(delta.y))
	else:
		facing = Vector2i(Fixed.sign_i(delta.x), Fixed.sign_i(delta.y))


func _idle_tick() -> void:
	if opening_grace():
		return
	if phase == "lucifer" or channeling_altar:
		idle_ticks = 0
		return
	if _hostiles_in_room(party_room_id) > 0:
		idle_ticks = 0
		return
	var room = map.by_id.get(party_room_id, {})
	if room.is_empty():
		return
	var kind := str(room.kind)
	# The antechamber is a lobby. Camping a cleared fork still corrupts;
	# standing on the title's first tile must not.
	if kind == "start":
		idle_ticks = 0
		return
	var is_cleared := bool(cleared.get(party_room_id, false)) or kind in ["corridor", "fork", "seal", "font", "altar"]
	if not is_cleared:
		idle_ticks = 0
		return
	idle_ticks += 1


func _formation() -> void:
	# Scatter Roll holds the shove until the tell resolves. Pulling back
	# into the marked tiles would make the dodge a lie.
	if tick < scatter_until:
		return
	var offsets := _offsets(_effective_stance())
	var i := 0
	for a in _angels():
		if not a.alive:
			i += 1
			continue
		if not a.casting.is_empty() and str(a.casting.get("ability", "")) == "slow_revive":
			i += 1
			continue
		if int(a.get("untargetable_until", 0)) > tick:
			i += 1
			continue
		var dest := _clamp_pos(anchor + Fixed.rotate_facing(offsets[i], facing))
		var speed := Balance.MOVE_SPEED + Balance.FORMATION_CATCH
		if tick < root_until:
			speed = 0
		if speed > 0:
			a.pos = Fixed.step_toward(a.pos, dest, speed)
		i += 1


func _sync_room() -> void:
	var id := map.id_at_tile(Fixed.tile_of(anchor))
	if id == "":
		return
	_prev_room = party_room_id
	party_room_id = id
	visited[id] = true
	var room: Dictionary = map.by_id[id]
	if int(room.depth) > max_depth:
		max_depth = int(room.depth)
	if int(room.get("stage", 0)) > stage_reached:
		stage_reached = int(room.stage)


func _passives() -> void:
	var raphael := _hero("raphael")
	if raphael.alive and raphael.casting.is_empty() and raphael.hp < raphael.hp_max:
		if Balance.RAPHAEL_REGEN_PERIOD > 0 and tick % Balance.RAPHAEL_REGEN_PERIOD == 0:
			raphael.hp = mini(raphael.hp_max, int(raphael.hp) + Balance.RAPHAEL_REGEN)


func _maybe_repath() -> void:
	if path.is_empty() or ignore_traps:
		return
	var crossed := false
	for tile in path:
		if _trap_at_tile(tile) != null:
			crossed = true
			break
	if not crossed:
		return
	var goal := move_goal_tile
	if goal.x < 0:
		return
	var extra := _trap_costs()
	var found: Array = Pathing.find(map.walk, map.width, map.height, Fixed.tile_of(anchor), goal, extra)
	if found.is_empty():
		return
	path = found
	if path.size() > 0 and path[0] == Fixed.tile_of(anchor):
		path.pop_front()


func _trigger_traps() -> void:
	if not traps_enabled:
		return
	for id in order.duplicate():
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("armed", false)):
			continue
		var tripped := false
		for a in _angels():
			if a.alive and Fixed.dist(a.pos, e.pos) <= Balance.SPIKE_STEP:
				tripped = true
				break
		if not tripped:
			if bool(e.revealed) and not bool(e.avoided):
				var near := false
				for a2 in _angels():
					if a2.alive and Fixed.dist(a2.pos, e.pos) < 2200:
						near = true
				if near and not _standing_on(e.pos):
					e.avoided = true
					_grant_golden(Balance.AVOID_BOUNTY, str(e.room))
					_log("The squad steps around a trap.", "good")
			continue
		_spring_trap(e)


func _spring_trap(e: Dictionary) -> void:
	e.armed = false
	e.alive = false
	stats.traps_triggered += 1
	var room := str(e.room)
	var grant := mini(Balance.TRAP_DARK, Balance.ROOM_TRAP_DARK_CAP - int(trap_dark_room.get(room, 0)))
	if grant > 0:
		dark = mini(Balance.ELIXIR_MAX, dark + grant)
		trap_dark_room[room] = int(trap_dark_room.get(room, 0)) + grant
	var kind := str(e.subtype)
	if kind == "spike":
		if tick < iframe_until:
			_log("Scatter slips the spike.", "good")
			return
		if _effective_stance() == STANCE_COLUMN:
			var lead := _lead_angel()
			if not lead.is_empty():
				_hurt(lead, 38, "trap", e.id, false)
		elif _effective_stance() == STANCE_TIGHT:
			for a in _angels():
				if a.alive and Fixed.dist(a.pos, e.pos) <= Balance.TIGHT_SPIKE:
					_hurt(a, 32, "trap", e.id, true)
		else:
			for a2 in _angels():
				if a2.alive and Fixed.dist(a2.pos, e.pos) <= Balance.SPIKE_STEP:
					_hurt(a2, 38, "trap", e.id, false)
		_log("Spike!", "bad")
	elif kind == "snare":
		if tick < iframe_until:
			_log("Scatter slips the snare.", "good")
			return
		var dur := 40
		if _effective_stance() == STANCE_COLUMN:
			dur = 70
		elif _effective_stance() == STANCE_SPREAD:
			dur = 22
		root_until = tick + dur
		root_total = dur
		path = []
		_log("Snared. Cleanse will not break a trap.", "bad")
	elif kind == "hellflame":
		_add_zone(e.pos, Balance.HELLFLAME_RADIUS, 60, 8, "hell", 0)
		_log("Hellflame erupts.", "bad")
	_trap_curse(e)


func _mob_ai() -> void:
	for m in _living_mobs():
		if str(m.kind) == "boss":
			continue
		if int(m.get("active_at", 0)) > tick:
			continue
		_update_aggro(m)
		if str(m.subtype) == "elite" and bool(m.get("pulled", false)):
			_elite_affixes(m)
		if not bool(m.get("pulled", false)):
			_hold_post(m)
			continue
		var tgt := _mob_target(m)
		if tgt.is_empty():
			continue
		var dist := Fixed.dist(m.pos, tgt.pos)
		if dist > int(m.range):
			var step := Fixed.step_toward(m.pos, tgt.pos, int(m.speed))
			m.pos = _slide(m.pos, step)
		else:
			m.atk_cd = int(m.atk_cd) - 1
			if int(m.atk_cd) <= 0:
				m.atk_cd = int(m.period)
				m.swing = int(m.get("swing", 0)) + 1
				if int(tgt.get("untargetable_until", 0)) > tick:
					if int(m.swing) % Balance.MOB_AOE_EVERY == 0:
						_mob_pulse(m)
					continue
				_hurt(tgt, int(m.atk), "single", m.id, false)
				if int(m.swing) % Balance.MOB_AOE_EVERY == 0:
					_mob_pulse(m)
	_separate_mobs()


func _mob_pulse(m: Dictionary) -> void:
	var dmg := Balance.mob_aoe(str(m.get("subtype", "")))
	if dmg <= 0:
		return
	var room := map.id_at_tile(Fixed.tile_of(m.pos))
	var hit := 0
	for a in _angels():
		if not a.alive:
			continue
		var same := room != "" and map.id_at_tile(Fixed.tile_of(a.pos)) == room
		var near := Fixed.dist(a.pos, m.pos) <= Balance.MOB_AOE_RADIUS
		if not same and not near:
			continue
		_hurt(a, dmg, "aoe", int(m.id), true)
		hit += 1
	if hit > 0:
		_log("%s lashes the party." % m.name, "bad")


func _separate_mobs() -> void:
	var mobs := _living_mobs()
	for i in mobs.size():
		for j in range(i + 1, mobs.size()):
			var a: Dictionary = mobs[i]
			var b: Dictionary = mobs[j]
			var d := Fixed.dist(a.pos, b.pos)
			if d >= 520 or d == 0:
				if d == 0:
					b.pos = _slide(b.pos, b.pos + Vector2i(200 + int(b.id), 0))
				continue
			var push := (520 - d) / 2
			var delta: Vector2i = b.pos - a.pos
			var len := d
			var step := Vector2i(delta.x * push / len, delta.y * push / len)
			if int(a.id) < int(b.id):
				b.pos = _slide(b.pos, b.pos + step)
			else:
				a.pos = _slide(a.pos, a.pos - step)


func _elite_affixes(m: Dictionary) -> void:
	var taunted := int(m.id) == taunt_id and tick < taunt_until
	if m.affixes.has("molten") and tick % 20 == 0:
		for a in _angels():
			if a.alive and Fixed.dist(a.pos, m.pos) <= Balance.MOLTEN_RADIUS:
				_hurt(a, Balance.MOLTEN_DMG, "aoe", m.id, true)
	if taunted:
		m.blink = {}
	if not m.affixes.has("teleporter") or taunted:
		return
	if m.blink.is_empty():
		if tick >= int(m.teleport_at):
			var tgt := _lowest_living()
			if tgt.is_empty():
				return
			m.blink = {"target": tgt.id, "until": tick + Balance.BLINK_TELEGRAPH, "pos": tgt.pos}
			_log("The elite blinks toward %s." % tgt.name, "bad")
	elif tick >= int(m.blink.until):
		var tgt2 := _ent(int(m.blink.target))
		var spot: Vector2i = m.blink.pos
		if not tgt2.is_empty():
			spot = tgt2.pos
		m.pos = _clamp_pos(spot + Vector2i(550, 0))
		if not tgt2.is_empty() and tgt2.alive:
			_hurt(tgt2, Balance.BLINK_DMG, "single", m.id, false)
		m.teleport_at = tick + Balance.BLINK_PERIOD
		m.blink = {}


func _angel_autos() -> void:
	for a in _angels():
		if not a.alive:
			continue
		if int(a.get("active_at", 0)) > tick:
			continue
		a.atk_cd = int(a.atk_cd) - 1
		if int(a.atk_cd) > 0:
			continue
		var tgt := _attack_target(a)
		if tgt.is_empty():
			a.atk_cd = 4
			continue
		a.atk_cd = int(a.period)
		_hurt(tgt, _out_damage(int(a.atk), a.id), "single", a.id, false)
		if str(a.subtype) == "uriel":
			a.radiance = mini(Balance.RADIANCE_CAP, int(a.radiance) + 1)
		stats.damage_dealt += int(a.atk)


func _channels() -> void:
	for a in _angels():
		if a.casting.is_empty():
			continue
		var ability := str(a.casting.ability)
		if ability == "beam":
			if tick >= int(a.casting.next) and int(a.casting.pulses) > 0:
				_beam_pulse(a)
				a.casting.pulses = int(a.casting.pulses) - 1
				a.casting.next = tick + Balance.BEAM_PULSE
			if int(a.casting.pulses) <= 0 or tick >= int(a.casting.until):
				a.casting = {}
		elif ability == "slow_revive":
			if not a.alive or tick < root_until:
				_interrupt_revive(a)
			elif tick >= int(a.casting.until):
				var dead := _ent(int(a.casting.target))
				a.casting = {}
				if not dead.is_empty() and not dead.alive:
					if _revive(dead, Balance.REVIVE_PCT):
						_log("%s stands again." % dead.name, "good")
					else:
						_log("The resurrection comes too late.", "bad")


func _zones_and_auras() -> void:
	for id in order.duplicate():
		var e: Dictionary = entities[id]
		if str(e.kind) != "zone":
			continue
		if tick >= int(e.until):
			_erase(id)
			continue
		if tick < int(e.get("start", e.born)):
			continue
		if (tick - int(e.born)) % 10 != 0:
			continue
		var holy := str(e.subtype) == "holy"
		var mult := 100 + Balance.RADIANCE_PER_STACK * int(e.get("stacks", 0))
		if holy:
			var uriel := _hero("uriel")
			var src := int(uriel.id) if not uriel.is_empty() else 0
			for m in _living_mobs():
				if Fixed.dist(m.pos, e.pos) <= int(e.radius):
					_hurt(m, _out_damage(int(e.dmg) * mult / 100, src), "aoe", src, true)
		else:
			for a in _angels():
				if a.alive and Fixed.dist(a.pos, e.pos) <= int(e.radius):
					_hurt(a, int(e.dmg), "aoe", e.id, true)
	for a in _angels():
		if not a.alive:
			continue
		if int(a.rot_until) > tick and tick % Balance.ROT_PERIOD == 0:
			var stacks := maxi(1, int(a.get("rot_stacks", 1)))
			_hurt(a, Balance.ROT_DMG * stacks, "dot", 0, true, "Rot")


func _curses_land() -> void:
	for id in order.duplicate():
		var e: Dictionary = entities[id]
		if str(e.kind) != "curse" or bool(e.get("landed", false)):
			continue
		var tgt := _ent(int(e.target))
		e.pos = tgt.pos if not tgt.is_empty() else e.pos
		if tick < int(e.land):
			continue
		e.landed = true
		e.alive = false
		if tgt.is_empty() or not tgt.alive:
			continue
		var kind := str(e.subtype)
		if tick < curse_grace_until or not curses_enabled:
			_log("The %s fails to take hold." % kind, "good")
			debug_line("curse %s fizzled on %s" % [kind, tgt.name])
			continue
		if cleanse_charges > 0:
			cleanse_charges -= 1
			_log("The font burns the %s off %s." % [kind, tgt.name], "good")
			continue
		var via_trap := bool(e.get("via_trap", false))
		if not via_trap and not mob_near(str(tgt.subtype)):
			_log("The %s finds no one close enough to cast it." % kind, "good")
			debug_line("curse %s fizzled, no vehicle on %s" % [kind, tgt.name])
			continue
		_apply_curse_now(tgt, kind)


func _lucifer() -> void:
	var boss := _boss()
	if boss.is_empty() or not boss.alive:
		return
	# The rise is a tell. No steps, no swings, no buttons landing.
	if tick < transform_until:
		return
	if not telegraph.is_empty():
		if tick < int(telegraph.until):
			return
		_resolve_telegraph(boss)
		telegraph = {}
		hell_rain_marks = []
		return
	var tgt := _nearest_angel(boss.pos)
	if tgt.is_empty():
		return
	var dist := Fixed.dist(boss.pos, tgt.pos)
	if dist > 1800:
		boss.pos = _slide(boss.pos, Fixed.step_toward(boss.pos, tgt.pos, int(boss.speed)))
	elif dist <= int(boss.range):
		boss.atk_cd = int(boss.atk_cd) - 1
		if int(boss.atk_cd) <= 0:
			boss.atk_cd = int(boss.period)
			_hurt(tgt, int(boss.atk), "single", boss.id, false)


func _open_telegraph(boss: Dictionary, name: String) -> void:
	telegraph = {"name": name, "until": tick + Balance.BOSS_TELL, "from": boss.pos}
	if name == "hell_rain":
		hell_rain_marks = []
		for a in _angels():
			if a.alive:
				hell_rain_marks.append({"id": a.id, "pos": a.pos})
		_log("Hell rain marks the ground. Move.", "bad")
	elif name == "cleave":
		var aim := anchor
		telegraph.aim = aim
		telegraph.end = Fixed.approach(boss.pos, aim, Balance.CLEAVE_LENGTH)
		_log("Cleave lane. Leave the line.", "bad")
	elif name == "judgment":
		var victim := _lowest_living()
		telegraph.target = victim.id if not victim.is_empty() else 0
		_log("Judgment on %s." % (victim.name if not victim.is_empty() else "the party"), "bad")
	elif name == "grasp":
		_log("Grasp. Phalanx, or be pulled in.", "bad")


func _resolve_telegraph(boss: Dictionary) -> void:
	var name := str(telegraph.name)
	if name == "hell_rain":
		for mark in hell_rain_marks:
			var a := _ent(int(mark.id))
			if a.is_empty() or not a.alive:
				continue
			if Fixed.dist(a.pos, mark.pos) <= Balance.HELL_RAIN_RADIUS:
				_hurt(a, Balance.HELL_RAIN_DMG, "boss", boss.id, true)
	elif name == "cleave":
		var origin: Vector2i = telegraph.get("from", boss.pos)
		var end: Vector2i = telegraph.get("end", origin)
		for a in _angels():
			if not a.alive:
				continue
			if _dist_to_segment(a.pos, origin, end) <= Balance.CLEAVE_HALF_WIDTH:
				_hurt(a, Balance.CLEAVE_DMG, "boss", boss.id, true)
	elif name == "judgment":
		var a2 := _ent(int(telegraph.get("target", 0)))
		if not a2.is_empty() and a2.alive:
			_hurt(a2, Balance.JUDGMENT_DMG, "single", boss.id, false)
	elif name == "grasp":
		for a3 in _angels():
			if not a3.alive:
				continue
			var pulled := tick >= phalanx_until
			if pulled:
				a3.pos = _clamp_pos(Fixed.step_toward(a3.pos, boss.pos, Balance.GRASP_PULL))
			_hurt(a3, Balance.GRASP_DMG if pulled else Balance.GRASP_DMG / 2, "boss", boss.id, true)


func _stakes() -> void:
	if phase == "lucifer":
		channeling_altar = false
		return
	var here := _stake_id()
	for sid in ["seal", "font", "altar"]:
		if sid == here or _stake_done_id(sid):
			continue
		if _stake_get(sid) > 0:
			_stake_set(sid, maxi(0, _stake_get(sid) - 2))
	if here == "" or _stake_done_id(here):
		if here == "":
			channeling_altar = false
		return
	if not channeling_altar:
		return
	if _hostiles_in_room(here) > 0:
		_stake_set(here, maxi(0, _stake_get(here) - 4))
		return
	var node := map.node_tile("%s:rear" % here)
	var spot := Fixed.tile_center(node)
	var close := false
	for a in _angels():
		if a.alive and Fixed.dist(a.pos, spot) <= Balance.ALTAR_RANGE:
			close = true
			break
	if not close:
		_stake_set(here, maxi(0, _stake_get(here) - 2))
		return
	var prog := _stake_get(here) + Balance.ALTAR_PER_TICK
	_stake_set(here, prog)
	if prog >= Balance.ALTAR_NEED:
		_complete_stake(here)


func _stake_id() -> String:
	var info = map.by_id.get(party_room_id, {})
	if info.is_empty():
		return ""
	if str(info.get("kind", "")) in ["seal", "font", "altar"]:
		return party_room_id
	return ""


func _stake_done_id(id: String) -> bool:
	match id:
		"seal":
			return seal_done
		"font":
			return font_done
		"altar":
			return altar_done
		_:
			return false


func _stake_get(id: String) -> int:
	match id:
		"seal":
			return seal_progress
		"font":
			return font_progress
		"altar":
			return altar_progress
		_:
			return 0


func _stake_set(id: String, value: int) -> void:
	match id:
		"seal":
			seal_progress = value
		"font":
			font_progress = value
		"altar":
			altar_progress = value


func _complete_stake(id: String) -> void:
	_stake_set(id, Balance.ALTAR_NEED)
	channeling_altar = false
	match id:
		"seal":
			seal_done = true
			_log("The gate seal locks. Swarms can no longer be called.", "good")
		"font":
			font_done = true
			cleanse_charges += 1
			_log("The font banks a cleanse. The next curse burns away.", "good")
		"altar":
			altar_done = true
			revive_charges += 1
			_log("The altar banks a revive charge.", "good")
	if not bool(cleared.get(id, false)):
		_mark_cleared(id)


func _stake_percent() -> int:
	var id := _stake_id()
	if id == "":
		return 0
	if _stake_done_id(id):
		return 100
	return mini(100, _stake_get(id) * 100 / maxi(Balance.ALTAR_NEED, 1))


func _stake_label() -> String:
	var id := _stake_id()
	if id == "":
		return ""
	return str(map.by_id[id].name)


func _shrines() -> void:
	if phase == "lucifer":
		channeling_shrine = false
		shrine_progress = 0
		return
	var tile := _shrine_tile(party_room_id)
	if tile.x < 0 or bool(shrines_done.get(party_room_id, false)):
		shrine_progress = 0
		return
	var on := Fixed.dist(anchor, Fixed.tile_center(tile)) <= Balance.SHRINE_RANGE
	if not channeling_shrine or not on:
		if not on:
			shrine_progress = 0
		return
	shrine_progress += 1
	if shrine_progress < Balance.SHRINE_CHANNEL:
		return
	shrine_progress = 0
	channeling_shrine = false
	shrines_done[party_room_id] = true
	_disable_room_traps(party_room_id)
	_log("The shrine stills the traps.", "good")


func _shrine_tile(room: String) -> Vector2i:
	if room == "":
		return Vector2i(-1, -1)
	return map.node_tile("%s:shrine" % room)


func _disable_room_traps(room: String) -> void:
	for id in order.duplicate():
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or str(e.get("room", "")) != room:
			continue
		if not bool(e.get("armed", false)) and not bool(e.get("alive", false)):
			continue
		e.armed = false
		e.alive = false
		e.disabled = true


func _turtle() -> void:
	if not curses_enabled or tick < curse_grace_until:
		if tick < curse_grace_until:
			idle_ticks = 0
			corruption = false
			corruption_warned = false
		return
	if idle_ticks == Balance.TURTLE_WARN_TICKS and not corruption_warned:
		corruption_warned = true
		_log("Corruption creeps. Move.", "bad")
	if idle_ticks < Balance.TURTLE_TICKS:
		return
	if not corruption:
		corruption = true
		_log("The cleared room turns on you. Dark swells.", "bad")
	# Idle Corruption is a warning, not a hit. The dungeon never damages
	# the party by itself — only mobs and traps do.
	turtle_clock += 1


func _resolve_revives() -> void:
	var keep: Array = []
	for p in pending_revives:
		if tick < int(p.at):
			keep.append(p)
			continue
		var a := _ent(int(p.id))
		if not a.is_empty() and not a.alive:
			if _revive(a, 50):
				_log("The altar restores %s." % a.name, "good")
			else:
				_log("The altar is too late for %s." % a.name, "bad")
	pending_revives = keep


func _clears() -> void:
	if _prev_room != party_room_id:
		_try_clear_room(_prev_room)


func _try_clear_room(id: String) -> void:
	if id == "" or bool(cleared.get(id, false)):
		return
	var room = map.by_id.get(id, {})
	if room.is_empty() or bool(room.corridor):
		return
	var kind := str(room.kind)
	# Stakes clear when claimed. Forks are decisions, not pushes.
	if kind in ["start", "fork", "throne", "seal", "font", "altar"]:
		return
	if not bool(visited.get(id, false)):
		return
	if _hostiles_in_room(id) > 0:
		return
	_mark_cleared(id)


func _mark_cleared(id: String) -> void:
	cleared[id] = true
	rooms_cleared += 1
	_grant_golden(Balance.CLEAR_BOUNTY, id)
	_log("%s is clear." % map.by_id[id].name, "good")


func _win_lose() -> void:
	var boss := _boss()
	if not boss.is_empty() and not boss.alive and outcome == "":
		outcome = "angels"
		banner = "VICTORY"
		_log("Lucifer falls. The siege breaks.", "good")
		return
	# A downed angel is not a wipe yet. The 3s window is the decision.
	if _any_angel_coming_back() or _downed_count() > 0:
		return
	var any := false
	for a in _angels():
		if a.alive:
			any = true
	if not any and outcome == "":
		outcome = "demon"
		banner = "DEFEAT"
		_log("The party is extinguished.", "bad")


# --- damage / healing -------------------------------------------------------

func _hurt(target: Dictionary, amount: int, kind: String, source_id: int, area: bool, source_name: String = "") -> int:
	if target.is_empty() or not bool(target.get("alive", false)):
		return 0
	if amount <= 0:
		return 0
	if god_mode and str(target.get("team", "")) == "angel":
		return 0
	if area and tick < iframe_until and str(target.team) == "angel":
		_popup(target.pos, "Dodge", "good", int(target.id), "Dodge")
		return 0
	if str(target.team) == "angel" and _try_dodge(target):
		return 0
	if str(target.team) == "angel" and kind == "single" and not area:
		var michael := _hero("michael")
		if not michael.is_empty() and michael.alive and int(michael.body_block_until) > tick and str(target.subtype) != "michael":
			michael.body_block_until = 0
			_log("Michael body-blocks for %s." % target.name, "good")
			target = michael
	if str(target.team) == "angel":
		if _effective_stance() == STANCE_TIGHT and kind == "single":
			amount = amount * 75 / 100
		if _effective_stance() == STANCE_TIGHT and (area or kind == "aoe" or kind == "boss"):
			amount = amount * 125 / 100
		if _effective_stance() == STANCE_SPREAD and kind == "single" and _is_backline(target):
			var michael2 := _hero("michael")
			if michael2.alive and Fixed.dist(target.pos, michael2.pos) > 1400:
				amount = amount * 120 / 100
		var kept := 100 - _armor_of(target)
		amount = amount * kept / 100
		if amount < 1:
			amount = 1
		if tick < phalanx_until and int(target.phalanx) > 0:
			var absorb: int = mini(amount, int(target.phalanx))
			target.phalanx = int(target.phalanx) - absorb
			amount -= absorb
		if int(target.shield) > 0 and amount > 0:
			var absorb2: int = mini(amount, int(target.shield))
			target.shield = int(target.shield) - absorb2
			amount -= absorb2
	if amount <= 0:
		return 0
	var before := int(target.hp)
	target.hp = before - amount
	var dealt := before - maxi(int(target.hp), 0)
	_note_damage_threat(target, source_id, dealt)
	if str(target.team) == "angel":
		stats.damage_taken += dealt
		_add_report(str(target.get("subtype", "")), "taken", dealt)
		_dark_from_damage(str(target.get("room", party_room_id)), dealt)
		debug_line("hurt %s %d %s from %s" % [target.name, dealt, kind, source_name if source_name != "" else str(source_id)])
		target.room = party_room_id
		if not target.casting.is_empty() and str(target.casting.get("ability", "")) == "slow_revive" and dealt >= Balance.REVIVE_INTERRUPT:
			_interrupt_revive(target)
	else:
		stats.damage_dealt += dealt
		var src := _ent(source_id)
		if not src.is_empty():
			_add_report(str(src.get("subtype", "")), "damage", dealt)
		debug_line("hit %s %d from %s" % [target.name, dealt, src.get("name", source_id) if not src.is_empty() else source_id])
	# Angel damage is "bad" (red). Foe damage is "dmg" (yellow), not "good",
	# so a hit does not read as a heal. Heals stay "good" (green).
	var pop := str(dealt) if source_name == "" else "%s %d" % [source_name, dealt]
	_popup(target.pos, pop, "bad" if str(target.team) == "angel" else "dmg", int(target.id), source_name)
	if int(target.hp) <= 0:
		_die(target)
	return dealt


func _die(target: Dictionary) -> void:
	target.alive = false
	target.hp = 0
	target.casting = {}
	target.shield = 0
	if focus_id == int(target.id):
		focus_id = 0
	if str(target.team) == "angel":
		target.final_death = false
		target.downed_until = tick + Balance.DOWNED_TICKS
		_log("%s is down. %0.0fs to reach them." % [target.name, float(Balance.DOWNED_TICKS) / float(Balance.TICK_HZ)], "bad")
		if revive_charges > 0:
			revive_charges -= 1
			pending_revives.append({"id": target.id, "at": tick + Balance.ALTAR_REVIVE_DELAY})
			_log("Altar revive reaches for %s." % target.name, "good")
	elif str(target.kind) == "boss":
		_log("Lucifer breaks.", "good")
	else:
		var bounty := Balance.KILL_IMP
		if str(target.subtype) == "heavy":
			bounty = Balance.KILL_HEAVY
		elif str(target.subtype) == "elite":
			bounty = Balance.KILL_ELITE
		_grant_golden(bounty, party_room_id)
		_log("%s falls." % target.name, "good")
		_erase_later(target)


func _heal(target: Dictionary, amount: int, source_id: int = 0) -> void:
	if not target.alive:
		return
	if source_id != 0:
		var caster := _ent(source_id)
		if not caster.is_empty() and str(caster.get("team", "")) == "angel":
			amount = amount * _power_of(caster) / 100
	if int(target.rot_until) > tick:
		amount = amount * 50 / 100
	if amount < 1:
		return
	var before := int(target.hp)
	target.hp = mini(int(target.hp_max), int(target.hp) + amount)
	var gained := int(target.hp) - before
	if gained > 0:
		_popup(target.pos, "+%s" % gained, "good")
		var src := _ent(source_id)
		if not src.is_empty():
			_add_report(str(src.get("subtype", "")), "healing", gained)
			debug_line("heal %s +%d from %s" % [target.name, gained, src.get("name", "")])
	# Overheal still generates threat. Passive regen never reaches this path.
	if source_id != 0:
		_threat_from_heal(source_id, amount)


func _revive(target: Dictionary, pct: int) -> bool:
	if target.is_empty() or bool(target.get("final_death", false)):
		return false
	target.alive = true
	target.hp = maxi(1, int(target.hp_max) * pct / 100)
	target.pos = _clamp_pos(anchor)
	target.silence_until = 0
	target.rot_until = 0
	target.rot_stacks = 0
	target.mark_until = 0
	target.weaken_until = 0
	target.shield = 0
	target.casting = {}
	target.downed_until = 0
	target.final_death = false
	stats.revives += 1
	return true


func _tick_downed() -> void:
	var held := {}
	for a in _angels():
		if a.casting.is_empty():
			continue
		if str(a.casting.get("ability", "")) != "slow_revive":
			continue
		held[int(a.casting.get("target", -1))] = true
	for c in queue:
		var ctype := str(c.get("type", ""))
		var cname := str(c.get("args", {}).get("name", ""))
		if ctype == "ability" and cname in ["slow_revive", "emergency_res"]:
			var named := str(c.get("args", {}).get("target", ""))
			if named == "":
				var pending := _revive_target()
				if not pending.is_empty():
					held[int(pending.id)] = true
			else:
				var hero := _hero(named)
				if not hero.is_empty():
					held[int(hero.id)] = true
	for a in _angels():
		if a.alive or bool(a.get("final_death", false)):
			continue
		# A slow revive already in the cast holds the window open until it lands or breaks.
		if held.has(int(a.id)):
			if tick >= int(a.get("downed_until", 0)):
				a.downed_until = tick + 1
			continue
		if tick >= int(a.get("downed_until", 0)):
			a.final_death = true
			_log("%s's death is final." % a.name, "bad")


func _interrupt_revive(owner: Dictionary) -> void:
	if owner.casting.is_empty():
		return
	owner.casting = {}
	golden = mini(Balance.ELIXIR_MAX, golden + Balance.REVIVE_REFUND)
	_log("Resurrection interrupted.", "bad")


func _dark_from_damage(room: String, dealt: int) -> void:
	if dealt <= 0 or phase == "lucifer":
		return
	var used := int(dark_income_room.get(room, 0))
	var grant := mini(dealt * Balance.DARK_PER_HP, Balance.ROOM_DARK_DMG_CAP - used)
	if grant <= 0:
		return
	dark = mini(Balance.ELIXIR_MAX, dark + grant)
	dark_income_room[room] = used + grant


func _grant_golden(amount: int, room: String) -> void:
	if amount <= 0:
		return
	var used := int(golden_income_room.get(room, 0))
	var grant := mini(amount, Balance.ROOM_GOLDEN_CAP - used)
	if grant <= 0:
		return
	golden = mini(Balance.ELIXIR_MAX, golden + grant)
	golden_income_room[room] = used + grant


# --- queries ----------------------------------------------------------------

func party_room() -> String:
	return party_room_id


func party_hp_pct() -> int:
	var hp := 0
	var mx := 0
	for a in _angels():
		mx += int(a.hp_max)
		if a.alive:
			hp += maxi(int(a.hp), 0)
	if mx <= 0:
		return 0
	return hp * 100 / mx


func angel_hp_pct(subtype: String) -> int:
	var a := _hero(subtype)
	if a.is_empty() or not a.alive or int(a.hp_max) <= 0:
		return 0
	return int(a.hp) * 100 / int(a.hp_max)


func lowest_angel_subtype() -> String:
	var a := _lowest_living()
	if a.is_empty():
		return "raphael"
	return str(a.subtype)


func lowest_angel_hp_pct() -> int:
	var a := _lowest_living()
	if a.is_empty():
		return 100
	return int(a.hp) * 100 / int(a.hp_max)


func mob_count() -> int:
	var n := 0
	for m in _living_mobs():
		if str(m.kind) == "mob":
			n += 1
	return n


func count_subtype(subtype: String) -> int:
	var n := 0
	for m in _living_mobs():
		if str(m.subtype) == subtype:
			n += 1
	return n


func elite_alive() -> bool:
	return count_subtype("elite") > 0


func elite_hp_pct() -> int:
	for m in _living_mobs():
		if str(m.subtype) == "elite":
			return int(m.hp) * 100 / int(m.hp_max)
	return 0


func _commitment_pending(e: Dictionary) -> bool:
	return str(e.get("kind", "")) == "commitment" and bool(e.get("alive", false)) and not bool(e.get("landed", false))


func _curse_casting() -> bool:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "curse" and not bool(e.get("landed", false)):
			return true
	return false


func _command_pending(type: String) -> bool:
	for c in queue:
		if str(c.type) == type:
			return true
	return false


func _commitments_land() -> void:
	for id in order.duplicate():
		var e: Dictionary = entities[id]
		if not _commitment_pending(e):
			continue
		if tick < int(e.land):
			continue
		e.landed = true
		e.alive = false
		if phase != "dungeon":
			continue
		var plan := str(e.plan)
		if plan == "elite":
			_cmd_spawn({"unit": "elite", "node": str(e.node), "paid": true})
		elif plan == "trap_cluster":
			for p in e.pieces:
				_cmd_trap({
					"kind": str(p.get("kind", "")),
					"node": str(p.get("node", "")),
					"paid": true,
					"curse": str(p.get("curse", "")),
				})


func curse_pending_or_active() -> bool:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "curse" and not bool(e.get("landed", false)):
			return true
		if str(e.team) == "angel" and e.alive:
			if int(e.silence_until) > tick or int(e.rot_until) > tick or int(e.mark_until) > tick or int(e.get("weaken_until", 0)) > tick:
				return true
	return false


func preview(cmd: String) -> Dictionary:
	var ability := _route(cmd) if cmd in ["shield", "heal", "cleanse", "detect", "burst"] else cmd
	return ability_status(ability)


func ability_status(ability: String) -> Dictionary:
	var owner_name := Balance.owner_of(ability)
	var owner := _hero(owner_name) if owner_name != "" else {}
	var reason := ""
	var ready := true
	if owner.is_empty() and ability not in ["scatter", "phalanx"]:
		ready = false
		reason = "Unknown"
	elif ability in ["scatter", "phalanx"]:
		ready = tick >= int(maneuver_cd.get(ability, 0))
		if not ready:
			reason = "Cooling"
	else:
		if not owner.alive:
			ready = false
			reason = "Down"
		elif int(owner.silence_until) > tick and ability != "escape_dash":
			ready = false
			reason = "Silenced"
		elif tick < int(owner.cooldowns.get(ability, 0)):
			ready = false
			reason = "Cooling"
		elif golden < Balance.cost(ability):
			ready = false
			reason = "Elixir"
	var cd_left := 0
	if ability in ["scatter", "phalanx"]:
		cd_left = maxi(0, int(maneuver_cd.get(ability, 0)) - tick)
	elif not owner.is_empty():
		cd_left = maxi(0, int(owner.cooldowns.get(ability, 0)) - tick)
	return {
		"ability": ability,
		"label": Balance.ability_label(ability),
		"cost": Balance.cost(ability),
		"ready": ready,
		"reason": reason,
		"owner": owner_name,
		"cd_left": cd_left,
	}


func build_snapshot() -> Dictionary:
	var vis := _visible_rooms()
	var angels: Array = []
	for a in _angels():
		angels.append(_copy_unit(a))
	var foes: Array = []
	var traps: Array = []
	var zones: Array = []
	var curses: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		var kind := str(e.kind)
		if kind == "mob" or kind == "boss":
			var room_now := map.id_at_tile(Fixed.tile_of(e.pos))
			if bool(e.alive) and (vis.has(room_now) or kind == "boss"):
				var foe_copy := _copy_unit(e)
				if kind == "mob":
					var tgt_now := _mob_target(e)
					foe_copy["pulled"] = bool(e.get("pulled", false))
					foe_copy["target"] = str(tgt_now.get("subtype", "")) if not tgt_now.is_empty() else ""
				foes.append(foe_copy)
		elif kind == "trap":
			if bool(e.get("revealed", false)) and (vis.has(str(e.room)) or not bool(e.get("armed", false))):
				traps.append({
					"id": e.id,
					"subtype": e.subtype,
					"pos": e.pos,
					"armed": e.armed,
					"node": e.node,
					"echo": bool(e.get("echo", false)),
					"arm_at": int(e.get("arm_at", 0)),
				})
		elif kind == "zone":
			if vis.has(map.id_at_tile(Fixed.tile_of(e.pos))):
				zones.append({"pos": e.pos, "radius": e.radius, "subtype": e.subtype, "until": e.until})
		elif kind == "curse":
			if not bool(e.landed):
				var tgt := _ent(int(e.target))
				curses.append({
					"subtype": e.subtype,
					"target": e.target,
					"name": tgt.name if not tgt.is_empty() else "",
					"land": e.land,
					"pos": tgt.pos if not tgt.is_empty() else e.pos,
				})
	var exits: Array = []
	var here = map.by_id.get(party_room_id, {})
	if not here.is_empty() and not here.corridor:
		for e in here.exits:
			exits.append(e.duplicate(true))
	elif not here.is_empty() and here.corridor:
		for n in here.neighbors:
			var other = map.by_id.get(n, {})
			if other.is_empty() or other.corridor:
				continue
			exits.append({
				"dest": other.id,
				"tile": map.center_tile(party_room_id) if map.center_tile(party_room_id) != Vector2i.ZERO else Fixed.tile_of(anchor),
				"label": other.name,
				"hint": other.hint,
				"kind": other.kind,
			})
	var hero_state := {}
	for subtype in _KIT.keys():
		var a := _hero(str(subtype))
		var downed: bool = not a.alive and not bool(a.get("final_death", false))
		hero_state[subtype] = {
			"id": a.id,
			"alive": a.alive,
			"hp": a.hp,
			"hp_max": a.hp_max,
			"shield": a.shield,
			"silence": int(a.silence_until) > tick,
			"rot": int(a.rot_until) > tick,
			"mark": int(a.mark_until) > tick,
			"weaken": int(a.get("weaken_until", 0)) > tick,
			"radiance": int(a.get("radiance", 0)),
			"casting": str(a.casting.get("ability", "")),
			"untargetable": int(a.get("untargetable_until", 0)) > tick,
			"downed": downed,
			"downed_left": maxi(0, int(a.get("downed_until", 0)) - tick) if downed else 0,
			"final_death": bool(a.get("final_death", false)),
		}
	var abilities := {}
	for subtype in _KIT.keys():
		for ability in _KIT[subtype]:
			abilities[ability] = ability_status(ability)
	for extra in ["detect_pulse", "scatter", "phalanx"]:
		abilities[extra] = ability_status(extra)
	var bar := {}
	for cmd in ["shield", "heal", "cleanse", "detect", "burst"]:
		bar[cmd] = preview(cmd)
	return {
		"tick": tick,
		"golden": golden,
		"dark": dark,
		"elixir_max": Balance.ELIXIR_MAX,
		"stance": stance,
		"stance_name": _STANCE_NAME[_effective_stance()],
		"chosen_stance": _STANCE_NAME[stance],
		"facing": facing,
		"anchor": anchor,
		"path": path.duplicate(),
		"focus_id": focus_id if focus_until > tick else 0,
		"ally_target": ally_target,
		"phase": phase,
		"outcome": outcome,
		"party_room": party_room_id,
		"max_depth": max_depth,
		"rooms_cleared": rooms_cleared,
		"visible": vis.keys(),
		"angels": angels,
		"foes": foes,
		"traps": traps,
		"zones": zones,
		"curses": curses,
		"commitments": _visible_commitments(),
		"exits": exits,
		"heroes": hero_state,
		"kits": _KIT.duplicate(true),
		"abilities": abilities,
		"bar": bar,
		"altar_progress": _stake_percent(),
		"altar_done": altar_done,
		"seal_done": seal_done,
		"font_done": font_done,
		"cleanse_charges": cleanse_charges,
		"stake_id": _stake_id(),
		"stake_name": _stake_label(),
		"stage": stage_reached,
		"revive_charges": revive_charges,
		"corruption": corruption,
		"corruption_warn": corruption_warned and not corruption,
		"idle_ticks": idle_ticks,
		"banner": banner if tick < banner_until or outcome != "" else "",
		"echo_style": echo_style,
		"echo_units": echo_units.duplicate(),
		"echo_traps": echo_traps,
		"echo_spent": echo_spent,
		"early": early_descend,
		"transform_until": transform_until,
		"telegraph": telegraph.duplicate(true),
		"hell_rain": hell_rain_marks.duplicate(true),
		"feed": feed.duplicate(true),
		"popups": popups.duplicate(true),
		"stats": stats.duplicate(true),
		"shield_wall": tick < shield_wall_until,
		"shield_facing": shield_wall_facing,
		"taunt_id": taunt_id if taunt_until > tick else 0,
		"beam_on": _beam_on(),
		"beam_aim": _beam_aim(),
		"beam_from": _hero("uriel").pos if _beam_on() else Vector2i.ZERO,
		"rooted": tick < root_until,
		"scatter_cd": maxi(0, int(maneuver_cd.scatter) - tick),
		"phalanx_cd": maxi(0, int(maneuver_cd.phalanx) - tick),
		"route_lock": route_lock_room if route_lock_until > tick else "",
		"boss_hp": _boss_hp(),
		"boss_hp_max": _boss_hp_max(),
		"channeling": channeling_altar,
		"party_hp_pct": party_hp_pct(),
		"golden_regen": Balance.golden_regen(_regen_index()),
		"dark_regen": 0 if opening_grace() else Balance.dark_regen(_regen_index()),
		"opening_grace": opening_grace(),
		"grace_left": grace_left(),
		"downed_ticks": Balance.DOWNED_TICKS,
		"threat": _threat_meter(),
		"shrine_tile": _shrine_tile(party_room_id),
		"shrine_progress": shrine_progress * 100 / maxi(Balance.SHRINE_CHANNEL, 1),
		"shrine_done": bool(shrines_done.get(party_room_id, false)),
		"channeling_shrine": channeling_shrine,
		"threat_boost": threat_boost_until > tick,
		"seed": run_seed,
		"next_spawn_in": director.next_spawn_in() if director != null else -1,
		"next_spawn_kind": director.pending_kind if director != null else "",
		"next_spawn_why": director.pending_why if director != null else "",
		"variance_penalty": director.last_penalty if director != null else 0,
		"sheets": _sheets(),
		"curse_grace": maxi(0, curse_grace_until - tick),
		"hero_report": hero_report.duplicate(true),
		"god_mode": god_mode,
		"infinite_elixir": infinite_elixir,
		"curses_on": curses_enabled,
		"traps_on": traps_enabled,
		"debug_lines": debug_log.duplicate(true),
		"debug_foes": _debug_foes(),
		"dev": Dev.ENABLED,
	}


func checksum() -> int:
	var h := 2166136261
	h = Fixed.mix(h, tick)
	h = Fixed.mix(h, rng_state)
	h = Fixed.mix(h, golden)
	h = Fixed.mix(h, dark)
	h = Fixed.mix(h, stage_reached)
	h = Fixed.mix(h, rooms_cleared)
	h = Fixed.mix(h, stance)
	h = Fixed.mix(h, focus_id)
	h = Fixed.mix(h, taunt_id)
	h = Fixed.mix(h, threat_boost_until)
	h = Fixed.mix(h, shrine_progress)
	h = Fixed.mix(h, shrines_done.size())
	h = Fixed.mix(h, _ally_code())
	h = Fixed.mix(h, anchor.x)
	h = Fixed.mix(h, anchor.y)
	h = Fixed.mix(h, 1 if phase == "lucifer" else 0)
	h = Fixed.mix(h, transform_until)
	h = Fixed.mix(h, lucifer_step)
	h = Fixed.mix(h, echo_spent)
	h = Fixed.mix(h, echo_traps)
	for id in order:
		var e: Dictionary = entities[id]
		h = Fixed.mix(h, int(e.id))
		h = Fixed.mix(h, int(e.hp))
		h = Fixed.mix(h, int(e.pos.x))
		h = Fixed.mix(h, int(e.pos.y))
		h = Fixed.mix(h, 1 if e.alive else 0)
		h = Fixed.mix(h, 1 if bool(e.get("final_death", false)) else 0)
		h = Fixed.mix(h, int(e.get("downed_until", 0)))
		h = Fixed.mix(h, 1 if bool(e.get("pulled", false)) else 0)
		h = Fixed.mix(h, _threat_sum(e))
		h = Fixed.mix(h, int(e.get("swing", 0)))
	return h


func debug_line(text: String) -> void:
	debug_log.append({"tick": tick, "text": text})
	while debug_log.size() > 80:
		debug_log.pop_front()


func _add_report(subtype: String, field: String, amount: int) -> void:
	if subtype == "" or amount <= 0:
		return
	if not hero_report.has(subtype):
		hero_report[subtype] = {"damage": 0, "healing": 0, "threat": 0, "taken": 0}
	hero_report[subtype][field] = int(hero_report[subtype].get(field, 0)) + amount


func _room_title(node: String) -> String:
	var room := node.split(":")[0]
	var info = map.by_id.get(room, {})
	if info.is_empty():
		return room
	return str(info.get("name", room))


func _debug_foes() -> Array:
	var rows: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		if not bool(e.get("alive", false)) or str(e.get("kind", "")) != "mob":
			continue
		var tgt := _mob_target(e)
		rows.append({
			"id": e.id,
			"subtype": e.subtype,
			"name": e.name,
			"hp": e.hp,
			"hp_max": e.hp_max,
			"target": str(tgt.get("subtype", "")) if not tgt.is_empty() else "",
			"room": str(e.get("home", e.get("room", ""))),
			"pos": e.pos,
		})
	return rows


func _cmd_debug_spawn(args: Dictionary) -> void:
	if not Dev.ENABLED:
		return
	var unit := str(args.get("unit", "imp"))
	if unit not in ["imp", "swarm", "heavy", "elite"]:
		unit = "imp"
	var node := "%s:center" % party_room_id
	if map.node_tile(node).x < 0:
		_fail("No node in this room.")
		return
	var pos := Fixed.tile_center(map.node_tile(node))
	var where := _room_title(node)
	if unit == "swarm":
		for i in 3:
			var off := Vector2i((i - 1) * 450, (i - 1) * 280)
			_make_mob("imp", "Imp", pos + off, Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, Balance.IMP_SPEED, [], node, 0)
		_log("Debug: imps in %s." % where, "bad")
	elif unit == "heavy":
		_make_mob("heavy", "Heavy Demon", pos, Balance.HEAVY_HP, Balance.HEAVY_ATK, Balance.HEAVY_PERIOD, Balance.HEAVY_RANGE, Balance.HEAVY_SPEED, [], node, 0)
		_log("Debug: heavy in %s." % where, "bad")
	elif unit == "elite":
		_make_mob("elite", "Elite", pos, Balance.ELITE_HP, Balance.ELITE_ATK, Balance.ELITE_PERIOD, Balance.ELITE_RANGE, Balance.ELITE_SPEED, ["teleporter", "molten"], node, 0)
		_log("Debug: elite in %s." % where, "bad")
	else:
		_make_mob("imp", "Imp", pos, Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, Balance.IMP_SPEED, [], node, 0)
		_log("Debug: imp in %s." % where, "bad")
	debug_line("debug spawn %s in %s" % [unit, where])


func _cmd_debug_flag(which: String) -> void:
	if not Dev.ENABLED:
		return
	if which == "god":
		god_mode = not god_mode
		debug_line("god %s" % god_mode)
		_log("God mode %s." % ("on" if god_mode else "off"), "info")
	elif which == "infinite":
		infinite_elixir = not infinite_elixir
		if infinite_elixir:
			golden = Balance.ELIXIR_MAX
		debug_line("infinite elixir %s" % infinite_elixir)
		_log("Infinite elixir %s." % ("on" if infinite_elixir else "off"), "info")


func _cmd_debug_heal() -> void:
	if not Dev.ENABLED:
		return
	corruption = false
	corruption_warned = false
	idle_ticks = 0
	turtle_clock = 0
	for a in _angels():
		a.alive = true
		a.final_death = false
		a.downed_until = 0
		a.hp = int(a.hp_max)
		a.silence_until = 0
		a.rot_until = 0
		a.rot_stacks = 0
		a.mark_until = 0
		a.weaken_until = 0
		a.pos = _clamp_pos(anchor)
	if outcome == "demon":
		outcome = ""
		banner = ""
	_log("Debug: the party is restored.", "good")
	debug_line("debug full heal")


func _cmd_debug_dread(fill: bool) -> void:
	if not Dev.ENABLED:
		return
	dark = Balance.ELIXIR_MAX if fill else 0
	_log("Debug: Dread %s." % ("filled" if fill else "emptied"), "info")
	debug_line("dread %d" % dark)


func _cmd_debug_teleport(room: String) -> void:
	if not Dev.ENABLED:
		return
	if not map.by_id.has(room):
		_fail("No such room.")
		return
	anchor = Fixed.tile_center(map.center_tile(room))
	path = []
	move_goal_room = ""
	for a in _angels():
		if a.alive:
			a.pos = anchor
	_sync_room()
	_log("Debug: the party is in %s." % _room_title(room), "info")
	debug_line("teleport %s" % room)


func _cmd_debug_toggle(which: String, on: bool) -> void:
	if not Dev.ENABLED:
		return
	if which == "curses":
		curses_enabled = on
		if not on:
			corruption = false
			corruption_warned = false
		_log("Debug: curses %s." % ("on" if on else "off"), "info")
	elif which == "traps":
		traps_enabled = on
		_log("Debug: traps %s." % ("on" if on else "off"), "info")
	debug_line("%s %s" % [which, "on" if on else "off"])


func _cmd_debug_seed(next: int) -> void:
	if not Dev.ENABLED:
		return
	run_seed = maxi(1, next)
	_reseed()
	debug_line("seed set %d" % run_seed)
	_log("Seed is %d. Replay keeps it." % run_seed, "info")


func debug_string() -> String:
	var hp := []
	for a in _angels():
		var tag := str(a.hp) if a.alive else ("down" if not bool(a.get("final_death", false)) else "final")
		hp.append("%s:%s/%s" % [a.subtype, tag, a.hp_max])
	return "t=%d room=%s st=%d clr=%d g=%d d=%d phase=%s mobs=%d out=%s seal=%s font=%s altar=%s [%s]" % [
		tick, party_room_id, stage_reached, rooms_cleared, golden, dark, phase, mob_count(), outcome,
		seal_done, font_done, altar_done, ", ".join(hp)
	]


# --- internals --------------------------------------------------------------

func _spawn_heroes() -> void:
	var offsets := _offsets(STANCE_TIGHT)
	for i in _HERO.size():
		var spec: Dictionary = _HERO[i]
		var id := _alloc()
		var pos := _clamp_pos(anchor + offsets[i])
		entities[id] = {
			"id": id,
			"team": "angel",
			"kind": "angel",
			"subtype": spec.subtype,
			"name": spec.name,
			"pos": pos,
			"hp": spec.hp,
			"hp_max": spec.hp,
			"shield": 0,
			"alive": true,
			"atk": spec.atk,
			"period": spec.period,
			"atk_cd": 10 + i * 2,
			"range": spec.range,
			"cooldowns": {},
			"casting": {},
			"silence_until": 0,
			"rot_until": 0,
			"rot_stacks": 0,
			"mark_until": 0,
			"weaken_until": 0,
			"body_block_until": 0,
			"untargetable_until": 0,
			"radiance": 0,
			"phalanx": 0,
			"room": "start",
			"downed_until": 0,
			"final_death": false,
		}
		order.append(id)


func _make_mob(subtype: String, name: String, pos: Vector2i, hp: int, atk: int, period: int, range: int, speed: int, affixes: Array, node: String, tell: int = -1) -> void:
	var id := _alloc()
	var room := node.split(":")[0]
	var windup := Balance.SPAWN_TELEGRAPH if tell < 0 else tell
	entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "mob",
		"subtype": subtype,
		"name": name,
		"pos": _clamp_pos(pos),
		"hp": hp,
		"hp_max": hp,
		"shield": 0,
		"alive": true,
		"atk": atk,
		"period": period,
		"atk_cd": period,
		"range": range,
		"speed": speed,
		"affixes": affixes.duplicate(),
		"active_at": tick + windup,
		"teleport_at": tick + Balance.BLINK_PERIOD,
		"blink": {},
		"node": node,
		"room": room,
		"home": room,
		"threat": {},
		"swing": 0,
		"pulled": false,
		"spawn_pos": _clamp_pos(pos),
	}
	order.append(id)
	order.sort()


func _add_zone(pos: Vector2i, radius: int, dur: int, dmg: int, subtype: String, stacks: int) -> void:
	var id := _alloc()
	entities[id] = {
		"id": id,
		"team": "neutral",
		"kind": "zone",
		"subtype": subtype,
		"name": subtype,
		"pos": pos,
		"hp": 1,
		"hp_max": 1,
		"alive": true,
		"radius": radius,
		"until": tick + dur,
		"born": tick,
		"dmg": dmg,
		"stacks": stacks,
		"start": tick,
	}
	order.append(id)
	order.sort()


func _alloc() -> int:
	var id := next_id
	next_id += 1
	return id


func _ent(id: int) -> Dictionary:
	return entities.get(id, {})


func _erase(id: int) -> void:
	entities.erase(id)
	var next: Array = []
	for x in order:
		if int(x) != id:
			next.append(x)
	order = next


func _erase_later(target: Dictionary) -> void:
	# Keep the body for a moment so the snapshot can omit it next tick.
	target.alive = false


func _angels() -> Array:
	var list: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "angel":
			list.append(e)
	return list


func _hero(subtype: String) -> Dictionary:
	for a in _angels():
		if str(a.subtype) == subtype:
			return a
	return {}


func _living_mobs() -> Array:
	var list: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		if bool(e.alive) and str(e.team) == "demon" and str(e.kind) in ["mob", "boss"]:
			list.append(e)
	return list


func _boss() -> Dictionary:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.subtype) == "lucifer":
			return e
	return {}


func _boss_hp() -> int:
	var b := _boss()
	return int(b.hp) if not b.is_empty() and b.alive else 0


func _boss_hp_max() -> int:
	var b := _boss()
	return int(b.hp_max) if not b.is_empty() else 0


func _lowest_living() -> Dictionary:
	var best: Dictionary = {}
	var best_pct := 999
	for a in _angels():
		if not a.alive:
			continue
		var pct := int(a.hp) * 100 / int(a.hp_max)
		if pct < best_pct or (pct == best_pct and (best.is_empty() or int(a.id) < int(best.id))):
			best = a
			best_pct = pct
	return best


func _revive_target() -> Dictionary:
	for a in _angels():
		if not a.alive and not bool(a.get("final_death", false)):
			return a
	return {}


func _first_dead() -> Dictionary:
	return _revive_target()


func _downed_count() -> int:
	var n := 0
	for a in _angels():
		if not a.alive and not bool(a.get("final_death", false)):
			n += 1
	return n


func _has_final_corpse() -> bool:
	for a in _angels():
		if not a.alive and bool(a.get("final_death", false)):
			return true
	return false


func _dead_count() -> int:
	var n := 0
	for a in _angels():
		if not a.alive:
			n += 1
	return n


func _lowest_living_pct() -> int:
	var a := _lowest_living()
	if a.is_empty():
		return 100
	return int(a.hp) * 100 / int(a.hp_max)


func _below_pct(pct: int) -> int:
	var n := 0
	for a in _angels():
		if a.alive and int(a.hp) * 100 / int(a.hp_max) < pct:
			n += 1
	return n


func _any_mark() -> bool:
	for a in _angels():
		if a.alive and int(a.mark_until) > tick:
			return true
	return false


func _is_backline(a: Dictionary) -> bool:
	return str(a.subtype) in ["raphael", "gabriel", "uriel"]


func _effective_stance() -> int:
	if tick < scatter_until:
		return STANCE_SPREAD
	if tick < phalanx_until:
		return STANCE_TIGHT
	return stance


func _offsets(which: int) -> Array:
	if which == STANCE_SPREAD:
		return _SPREAD
	if which == STANCE_COLUMN:
		return _COLUMN
	return _TIGHT


func _lead_angel() -> Dictionary:
	var best: Dictionary = {}
	var best_p: int = -(1 << 30)
	for a in _angels():
		if not a.alive:
			continue
		var p := int(a.pos.x) * facing.x + int(a.pos.y) * facing.y
		if p > best_p:
			best_p = p
			best = a
	return best


func _reseed() -> void:
	rng_state = run_seed & 0x7FFFFFFF
	if rng_state == 0:
		rng_state = 1


func rand_below(n: int) -> int:
	if n <= 1:
		return 0
	var x := rng_state & 0x7FFFFFFF
	if x == 0:
		x = 1
	x = x ^ ((x << 13) & 0x7FFFFFFF)
	x = x ^ ((x >> 17) & 0x7FFFFFFF)
	x = x ^ ((x << 5) & 0x7FFFFFFF)
	x = x & 0x7FFFFFFF
	if x == 0:
		x = 1
	rng_state = x
	return x % n


func _armor_of(a: Dictionary) -> int:
	if a.is_empty() or str(a.get("team", "")) != "angel":
		return 0
	var armor := Balance.ARMOR_MICHAEL if str(a.get("subtype", "")) == "michael" else 0
	if tick < shield_wall_until:
		armor += Balance.SHIELD_WALL_ARMOR
	if int(a.get("mark_until", 0)) > tick:
		armor -= Balance.MARK_ARMOR
	return clampi(armor, -150, Balance.ARMOR_CAP)


func _dodge_of(a: Dictionary) -> int:
	if a.is_empty():
		return 0
	var chance := Balance.DODGE_BASE + int(a.get("dodge_extra", 0))
	if int(a.get("dodge_until", 0)) > tick:
		chance += int(a.get("dodge_bonus", 0))
	return clampi(chance, 0, 95)


func _power_of(a: Dictionary) -> int:
	if a.is_empty():
		return Balance.POWER_BASE
	var power := Balance.POWER_BASE + int(a.get("power_extra", 0))
	if int(a.get("weaken_until", 0)) > tick:
		power = power * Balance.WEAKEN_DEALT / 100
	return maxi(power, 1)


func _crit_of(a: Dictionary) -> int:
	if a.is_empty():
		return 0
	return clampi(Balance.CRIT_BASE + int(a.get("crit_bonus", 0)), 0, 100)


func _threat_of(a: Dictionary) -> int:
	if a.is_empty() or str(a.get("team", "")) != "angel":
		return Balance.THREAT_BASE
	var threat := Balance.THREAT_MICHAEL if str(a.get("subtype", "")) == "michael" else Balance.THREAT_BASE
	threat += int(a.get("threat_extra", 0))
	if str(a.get("subtype", "")) == "michael" and tick < threat_boost_until:
		threat = threat * (100 + Balance.TAUNT_BOOST_PCT) / 100
	return maxi(threat, 1)


func _try_dodge(a: Dictionary) -> bool:
	var chance := _dodge_of(a)
	if chance <= 0:
		return false
	if rand_below(100) >= chance:
		return false
	_popup(a.pos, "Dodge", "good", int(a.id), "Dodge")
	debug_line("dodge %s (%d%%)" % [a.get("name", ""), chance])
	return true


func _try_crit(a: Dictionary) -> bool:
	var chance := _crit_of(a)
	if chance <= 0:
		return false
	return rand_below(100) < chance


func mob_near(subtype: String) -> bool:
	var hero := _hero(subtype)
	if hero.is_empty() or not bool(hero.get("alive", false)):
		return false
	var room := map.id_at_tile(Fixed.tile_of(hero.pos))
	for m in _living_mobs():
		if str(m.get("kind", "")) != "mob":
			continue
		if Fixed.dist(m.pos, hero.pos) <= Balance.CURSE_NEAR:
			return true
		var mroom := map.id_at_tile(Fixed.tile_of(m.pos))
		if room != "" and mroom == room and not _room_corridor(room):
			return true
	return false


func hero_sheet(subtype: String) -> Dictionary:
	var a := _hero(subtype)
	if a.is_empty():
		return {}
	var mods: Array = []
	var armor_base := Balance.ARMOR_MICHAEL if subtype == "michael" else 0
	var threat_base := Balance.THREAT_MICHAEL if subtype == "michael" else Balance.THREAT_BASE
	if tick < shield_wall_until:
		mods.append("Shield wall +%d Armor" % Balance.SHIELD_WALL_ARMOR)
	if int(a.get("mark_until", 0)) > tick:
		mods.append("Mark -%d Armor" % Balance.MARK_ARMOR)
	if int(a.get("dodge_until", 0)) > tick:
		mods.append("Dash +%d Dodge" % int(a.get("dodge_bonus", 0)))
	if int(a.get("weaken_until", 0)) > tick:
		mods.append("Weaken Power %d" % _power_of(a))
	if subtype == "michael" and tick < threat_boost_until:
		mods.append("Taunt boost Threat")
	return {
		"health": int(a.hp),
		"health_max": int(a.hp_max),
		"armor": _armor_of(a),
		"armor_base": armor_base,
		"dodge": _dodge_of(a),
		"dodge_base": Balance.DODGE_BASE,
		"power": _power_of(a),
		"power_base": Balance.POWER_BASE,
		"crit": _crit_of(a),
		"crit_base": Balance.CRIT_BASE,
		"threat": _threat_of(a),
		"threat_base": threat_base,
		"mods": mods,
	}


func _sheets() -> Dictionary:
	var out := {}
	for spec in _HERO:
		var subtype := str(spec.subtype)
		out[subtype] = hero_sheet(subtype)
	return out


func _apply_curse_now(tgt: Dictionary, kind: String) -> void:
	if tgt.is_empty() or not bool(tgt.get("alive", false)):
		return
	if kind == "silence":
		tgt.silence_until = tick + Balance.SILENCE_TICKS
		_log("%s is silenced." % tgt.name, "bad")
	elif kind == "rot":
		var stacks := int(tgt.get("rot_stacks", 0))
		if int(tgt.rot_until) > tick:
			stacks = mini(Balance.ROT_STACK_CAP, maxi(stacks, 1) + 1)
		else:
			stacks = 1
		tgt.rot_stacks = stacks
		tgt.rot_until = tick + Balance.ROT_TICKS
		_log("Rot takes %s (%d)." % [tgt.name, stacks], "bad")
		debug_line("rot %s stacks %d" % [tgt.name, stacks])
	elif kind == "mark":
		tgt.mark_until = tick + Balance.MARK_TICKS
		_log("%s is marked." % tgt.name, "bad")
	elif kind == "weaken":
		tgt.weaken_until = tick + Balance.WEAKEN_TICKS
		_log("%s is weakened." % tgt.name, "bad")


func _trap_curse(trap: Dictionary) -> void:
	var kind := str(trap.get("curse", ""))
	if kind == "":
		return
	if tick < curse_grace_until or not curses_enabled:
		_log("The trapped %s fails to take hold." % kind, "good")
		return
	for a in _angels():
		if not a.alive:
			continue
		if Fixed.dist(a.pos, trap.pos) > Balance.CURSE_NEAR and map.id_at_tile(Fixed.tile_of(a.pos)) != str(trap.get("room", "")):
			continue
		if cleanse_charges > 0:
			cleanse_charges -= 1
			_log("The font burns the trapped %s off %s." % [kind, a.name], "good")
			return
		_apply_curse_now(a, kind)
		debug_line("trap curse %s on %s" % [kind, a.name])
		return


func _out_damage(base: int, source_id: int = 0) -> int:
	var amount := base
	var g := _hero("gabriel")
	if not g.is_empty() and g.alive:
		amount = amount * Balance.GABRIEL_AURA / 100
	if source_id != 0:
		var src := _ent(source_id)
		if not src.is_empty() and str(src.get("team", "")) == "angel":
			amount = amount * _power_of(src) / 100
			if _try_crit(src):
				amount = amount * Balance.CRIT_MULT / 100
	if amount < 1 and base > 0:
		return 1
	return amount


func _beam_pulse(a: Dictionary) -> void:
	if bool(a.casting.get("steered", false)):
		var aim: Vector2i = a.casting.get("aim", a.pos)
		for m in _living_mobs():
			if Fixed.dist(a.pos, m.pos) > int(a.range):
				continue
			if _dist_to_segment(m.pos, a.pos, aim) <= Balance.BEAM_HALF_WIDTH:
				_hurt(m, _out_damage(Balance.BEAM_DMG, a.id), "single", a.id, false)
		return
	var tgt := _ent(int(a.casting.get("target", 0)))
	if tgt.is_empty() or not tgt.alive:
		tgt = _focus_or_nearest(a)
		if not tgt.is_empty():
			a.casting.target = tgt.id
	if tgt.is_empty() or not tgt.alive:
		return
	if Fixed.dist(a.pos, tgt.pos) > int(a.range):
		return
	a.casting.aim = tgt.pos
	_hurt(tgt, _out_damage(Balance.BEAM_DMG, a.id), "single", a.id, false)


func _beam_on() -> bool:
	var uriel := _hero("uriel")
	if uriel.is_empty() or uriel.casting.is_empty():
		return false
	return str(uriel.casting.get("ability", "")) == "beam"


func _beam_aim() -> Vector2i:
	var uriel := _hero("uriel")
	if uriel.is_empty() or uriel.casting.is_empty():
		return Vector2i.ZERO
	return uriel.casting.get("aim", Vector2i.ZERO)


func _lowest_backline() -> Dictionary:
	var best: Dictionary = {}
	var best_pct := 999
	for a in _angels():
		if not a.alive or not _is_backline(a):
			continue
		var pct := int(a.hp) * 100 / int(a.hp_max)
		if pct < best_pct or (pct == best_pct and (best.is_empty() or int(a.id) < int(best.id))):
			best = a
			best_pct = pct
	if best.is_empty():
		return _lowest_living()
	return best


func _focus_or_nearest(from: Dictionary) -> Dictionary:
	if focus_id != 0 and focus_until > tick:
		var f := _ent(focus_id)
		if not f.is_empty() and f.alive:
			return f
	return _nearest_demon(from.pos, 1 << 30)


func _attack_target(a: Dictionary) -> Dictionary:
	if focus_id != 0 and focus_until > tick:
		var f := _ent(focus_id)
		if not f.is_empty() and f.alive and Fixed.dist(a.pos, f.pos) <= int(a.range):
			return f
	return _nearest_demon(a.pos, int(a.range))


func _nearest_demon(pos: Vector2i, max_range: int) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_range + 1
	for m in _living_mobs():
		if int(m.get("active_at", 0)) > tick and str(m.kind) == "mob":
			continue
		var d := Fixed.dist(pos, m.pos)
		if d < best_d or (d == best_d and not best.is_empty() and int(m.id) < int(best.id)):
			best = m
			best_d = d
	if best_d > max_range:
		return {}
	return best


func _nearest_angel(pos: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1 << 30
	for a in _angels():
		if not a.alive or int(a.untargetable_until) > tick:
			continue
		var d := Fixed.dist(pos, a.pos)
		if d < best_d:
			best = a
			best_d = d
	return best


func _mob_target(m: Dictionary) -> Dictionary:
	if tick < taunt_until and int(m.id) == taunt_id:
		var michael := _hero("michael")
		if not michael.is_empty() and michael.alive and int(michael.get("untargetable_until", 0)) <= tick:
			return michael
	var marked: Dictionary = {}
	for a in _angels():
		if a.alive and int(a.mark_until) > tick and int(a.get("untargetable_until", 0)) <= tick:
			if marked.is_empty() or int(a.id) < int(marked.id):
				marked = a
	if not marked.is_empty():
		return marked
	var blink: Dictionary = m.get("blink", {})
	if not blink.is_empty():
		var blink_tgt := _ent(int(blink.get("target", 0)))
		if not blink_tgt.is_empty() and blink_tgt.alive and int(blink_tgt.get("untargetable_until", 0)) <= tick:
			return blink_tgt
	if not bool(m.get("pulled", false)):
		return {}
	return _highest_threat(m)


func _threat_meter() -> Dictionary:
	var totals := {}
	var holds := {}
	var engaged := 0
	var names := ["michael", "raphael", "azrael", "uriel", "gabriel"]
	for subtype in names:
		totals[subtype] = 0
		holds[subtype] = 0
	for m in _living_mobs():
		if str(m.kind) != "mob" or not bool(m.get("pulled", false)):
			continue
		engaged += 1
		var tgt := _mob_target(m)
		if not tgt.is_empty():
			var who := str(tgt.get("subtype", ""))
			if holds.has(who):
				holds[who] = int(holds[who]) + 1
		for a in _angels():
			var sub := str(a.subtype)
			if not totals.has(sub):
				continue
			totals[sub] = int(totals[sub]) + _effective_threat(m, a)
	var reason := "calm"
	var holder := ""
	if engaged > 0:
		reason = "mobs"
		var held := 0
		for subtype in holds.keys():
			var n := int(holds[subtype])
			if n > held or (n == held and n > 0 and (holder == "" or str(subtype) < holder)):
				held = n
				holder = str(subtype)
	else:
		var boss := _boss()
		if phase == "lucifer" and not boss.is_empty() and bool(boss.get("alive", false)) and tick >= transform_until:
			engaged = 1
			reason = "boss"
			var nearest := _nearest_angel(boss.pos)
			holder = str(nearest.get("subtype", "")) if not nearest.is_empty() else ""
		elif corruption:
			reason = "corruption"
		else:
			var curse_line := _curse_pressure()
			if curse_line != "":
				reason = "curse"
				holder = curse_line
	var tank_threat := int(totals.get("michael", 0))
	var rows: Array = []
	var pulling := ""
	for subtype in names:
		var threat := int(totals[subtype])
		var of_tank := 0
		if subtype == "michael":
			of_tank = 100 if tank_threat > 0 or (reason == "mobs" and holder == "michael") else 0
		elif tank_threat <= 0:
			of_tank = 100 if threat > 0 else 0
		else:
			of_tank = threat * 100 / tank_threat
		var aggro: bool = reason == "mobs" and subtype == holder and engaged > 0 and int(holds.get(subtype, 0)) > 0
		var soon: bool = reason == "mobs" and engaged > 0 and not aggro and of_tank >= Balance.THREAT_PULL_PCT and threat > 0
		if soon and pulling == "":
			pulling = subtype
		var heat := "safe"
		if subtype != "michael" and reason == "mobs":
			if of_tank >= Balance.THREAT_DANGER_PCT:
				heat = "pull"
			elif of_tank >= Balance.THREAT_WARN_PCT:
				heat = "warn"
		elif aggro:
			heat = "hold"
		var hero := _hero(subtype)
		rows.append({
			"subtype": subtype,
			"name": hero.name if not hero.is_empty() else subtype,
			"threat": threat,
			"pct": of_tank,
			"of_tank": of_tank,
			"tank": tank_threat,
			"aggro": aggro,
			"pulling": soon,
			"heat": heat,
		})
	var detail := ""
	if reason == "curse":
		detail = holder
		holder = ""
	elif reason == "corruption":
		detail = "Corruption"
	elif reason == "boss":
		detail = "Lucifer"
	return {
		"holder": holder if engaged > 0 else "",
		"pulling": pulling,
		"engaged": engaged,
		"reason": reason,
		"detail": detail,
		"tank": tank_threat,
		"rows": rows,
	}


func _curse_pressure() -> String:
	var best := ""
	var best_pri := 0
	for a in _angels():
		if not a.alive:
			continue
		var kind := ""
		var pri := 0
		if int(a.silence_until) > tick:
			kind = "Silence"
			pri = 4
		elif int(a.rot_until) > tick:
			kind = "Rot"
			pri = 3
		elif int(a.mark_until) > tick:
			kind = "Mark"
			pri = 2
		elif int(a.get("weaken_until", 0)) > tick:
			kind = "Weaken"
			pri = 1
		if pri > best_pri:
			best_pri = pri
			best = "%s on %s" % [kind, a.name]
	return best


func threat_of(mob_id: int, angel_id: int) -> int:
	var mob := _ent(mob_id)
	var angel := _ent(angel_id)
	if mob.is_empty() or angel.is_empty():
		return 0
	return _effective_threat(mob, angel)


func _highest_threat(m: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_t := -1
	for a in _angels():
		if not a.alive or int(a.get("untargetable_until", 0)) > tick:
			continue
		var t := _effective_threat(m, a)
		if best.is_empty() or t > best_t or (t == best_t and _threat_tie(m, a, best)):
			best = a
			best_t = t
	return best


func _effective_threat(m: Dictionary, angel: Dictionary) -> int:
	var table: Dictionary = m.get("threat", {})
	var base := int(table.get(str(angel.id), 0))
	if tick < taunt_until and int(m.id) == taunt_id and str(angel.subtype) == "michael":
		var top := 0
		for other in _angels():
			if int(other.id) == int(angel.id):
				continue
			top = maxi(top, int(table.get(str(other.id), 0)))
		return maxi(base, top) + Balance.TAUNT_SNAP
	return base


func _threat_tie(m: Dictionary, angel: Dictionary, best: Dictionary) -> bool:
	var da := Fixed.dist(m.pos, angel.pos)
	var db := Fixed.dist(m.pos, best.pos)
	if da != db:
		return da < db
	return int(angel.id) < int(best.id)


func _update_aggro(m: Dictionary) -> void:
	if tick < taunt_until and int(m.id) == taunt_id:
		m.pulled = true
		return
	if bool(m.get("pulled", false)):
		if _should_leash(m):
			m.pulled = false
			m.threat = {}
		return
	if _angel_provokes(m):
		var was_pulled := bool(m.get("pulled", false))
		m.pulled = true
		if not was_pulled:
			_seed_opener_threat(m)
			var tgt := _mob_target(m)
			debug_line("aggro %s onto %s in %s" % [m.name, str(tgt.get("name", "")), str(m.get("home", ""))])


func _angel_provokes(m: Dictionary) -> bool:
	# Same-room used to pull at any distance. The summoned door is 11 tiles
	# from the garrison, past the 9.8 leash, so a single step onto the
	# threshold pulled the pack and the next step back into the corridor
	# dropped it. That one-tick fight is the "came on and went" bug. A room
	# pull now requires leash range. Proximity (aggro) is unchanged, and the
	# antechamber stays quiet because nothing is garrisoned there.
	var mroom := map.id_at_tile(Fixed.tile_of(m.pos))
	for a in _angels():
		if not a.alive or int(a.get("untargetable_until", 0)) > tick:
			continue
		var dist := Fixed.dist(a.pos, m.pos)
		if dist <= Balance.AGGRO_RANGE:
			return true
		if mroom != "" and not _room_corridor(mroom) and map.id_at_tile(Fixed.tile_of(a.pos)) == mroom and dist <= Balance.LEASH_RANGE:
			return true
	return false


func _should_leash(m: Dictionary) -> bool:
	var mroom := map.id_at_tile(Fixed.tile_of(m.pos))
	for a in _angels():
		if not a.alive:
			continue
		if Fixed.dist(a.pos, m.pos) <= Balance.LEASH_RANGE:
			return false
		if mroom != "" and not _room_corridor(mroom) and map.id_at_tile(Fixed.tile_of(a.pos)) == mroom:
			return false
	return true


func _hold_post(m: Dictionary) -> void:
	var home: Vector2i = m.get("spawn_pos", m.pos)
	if Fixed.dist(m.pos, home) <= 80:
		return
	m.pos = _slide(m.pos, Fixed.step_toward(m.pos, home, int(m.speed)))


func _room_corridor(id: String) -> bool:
	var info = map.by_id.get(id, {})
	return not info.is_empty() and bool(info.get("corridor", false))


func _note_damage_threat(target: Dictionary, source_id: int, dealt: int) -> void:
	if dealt <= 0 or source_id == 0:
		return
	if str(target.get("team", "")) != "demon" or str(target.get("kind", "")) != "mob":
		return
	var src := _ent(source_id)
	if src.is_empty() or str(src.get("team", "")) != "angel":
		return
	var was_pulled := bool(target.get("pulled", false))
	target.pulled = true
	if not was_pulled:
		_seed_opener_threat(target)
	var amount := dealt * _threat_of(src) / 100
	_add_threat(target, source_id, amount)


func _threat_from_heal(source_id: int, amount: int) -> void:
	if source_id == 0 or amount <= 0:
		return
	var pool := amount * Balance.HEAL_THREAT_PCT / 100
	var healer := _ent(source_id)
	if not healer.is_empty() and str(healer.get("team", "")) == "angel":
		pool = pool * _threat_of(healer) / 100
	if pool <= 0:
		return
	var engaged: Array = []
	for m in _living_mobs():
		if str(m.kind) != "mob" or not bool(m.get("pulled", false)):
			continue
		engaged.append(m)
	if engaged.is_empty():
		return
	engaged.sort_custom(func(a, b): return int(a.id) < int(b.id))
	var each := pool / engaged.size()
	var rem := pool - each * engaged.size()
	for i in engaged.size():
		var add := each
		if i < rem:
			add += 1
		_add_threat(engaged[i], source_id, add)


func _seed_opener_threat(mob: Dictionary) -> void:
	var michael := _hero("michael")
	if michael.is_empty() or not michael.alive:
		return
	if typeof(mob.get("threat", null)) != TYPE_DICTIONARY:
		mob.threat = {}
	var key := str(michael.id)
	if int(mob.threat.get(key, 0)) < Balance.OPENER_THREAT:
		mob.threat[key] = Balance.OPENER_THREAT


func _add_threat(mob: Dictionary, angel_id: int, amount: int) -> void:
	if amount <= 0 or angel_id == 0:
		return
	if typeof(mob.get("threat", null)) != TYPE_DICTIONARY:
		mob.threat = {}
	var key := str(angel_id)
	mob.threat[key] = int(mob.threat.get(key, 0)) + amount
	var angel := _ent(angel_id)
	if not angel.is_empty():
		_add_report(str(angel.get("subtype", "")), "threat", amount)


func _threat_sum(e: Dictionary) -> int:
	var table = e.get("threat", {})
	if typeof(table) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for k in table.keys():
		total += int(table[k])
	return total


func _ally_code() -> int:
	match ally_target:
		"michael":
			return 1
		"raphael":
			return 2
		"azrael":
			return 3
		"uriel":
			return 4
		"gabriel":
			return 5
		_:
			return 0


func _heal_target(args: Dictionary) -> Dictionary:
	var named := _named_angel(args, true)
	if not named.is_empty():
		return named
	if ally_target != "":
		var marked := _hero(ally_target)
		if not marked.is_empty() and marked.alive:
			return marked
	return _lowest_living()


func _cluster_count() -> int:
	var uriel := _hero("uriel")
	if uriel.is_empty():
		return 0
	var n := 0
	for m in _living_mobs():
		if Fixed.dist(uriel.pos, m.pos) <= 2200:
			n += 1
	return n


func _cluster_point(owner: Dictionary) -> Vector2i:
	var sx := 0
	var sy := 0
	var n := 0
	for m in _living_mobs():
		if Fixed.dist(owner.pos, m.pos) <= 3000:
			sx += int(m.pos.x)
			sy += int(m.pos.y)
			n += 1
	if n == 0:
		return Vector2i.ZERO
	return Vector2i(sx / n, sy / n)


func _disarm_target() -> Dictionary:
	var azrael := _hero("azrael")
	if azrael.is_empty() or not azrael.alive:
		return {}
	var best: Dictionary = {}
	var best_d := Balance.DISARM_RANGE + 1
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("revealed", false)) or not bool(e.get("alive", false)):
			continue
		var arming := bool(e.get("echo", false)) and not bool(e.get("armed", false))
		if not bool(e.get("armed", false)) and not arming:
			continue
		var d := Fixed.dist(azrael.pos, e.pos)
		if d < best_d:
			best = e
			best_d = d
	return best


func _reveal_radius(origin: Vector2i, radius: int) -> int:
	var n := 0
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("armed", false)) or bool(e.get("revealed", false)):
			continue
		if Fixed.dist(origin, e.pos) <= radius:
			e.revealed = true
			n += 1
	return n


func _remove_trap(trap: Dictionary, rewarded: bool) -> void:
	trap.armed = false
	trap.alive = false
	trap.revealed = true
	stats.traps_disarmed += 1
	if rewarded:
		_grant_golden(Balance.DISARM_BOUNTY, str(trap.room))


func _trap_costs() -> Dictionary:
	if ignore_traps:
		return {}
	var extra := {}
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("armed", false)) or not bool(e.get("revealed", false)):
			continue
		var t := Fixed.tile_of(e.pos)
		if map.at(t) < 0:
			continue
		extra[t.y * map.width + t.x] = 80
	return extra


func _trap_at_tile(tile: Vector2i):
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)) and bool(e.get("revealed", false)):
			if Fixed.tile_of(e.pos) == tile:
				return e
	return null


func _standing_on(pos: Vector2i) -> bool:
	for a in _angels():
		if a.alive and Fixed.dist(a.pos, pos) <= Balance.SPIKE_STEP:
			return true
	return false


func _armed_trap_count() -> int:
	var n := 0
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)) and _trap_counts_for_cap(str(e.get("room", ""))):
			n += 1
		if _commitment_pending(e) and str(e.get("plan", "")) == "trap_cluster":
			for p in e.get("pieces", []):
				var room := str(p.get("node", "")).split(":")[0]
				if _trap_counts_for_cap(room):
					n += 1
	return n


func _trap_counts_for_cap(room: String) -> bool:
	if room == "":
		return true
	# Corridors are never "cleared", so a trap the party already walked
	# past would otherwise sit on the global cap for the rest of the stage
	# and the director could not lay the next one ahead.
	if room != party_room_id and bool(visited.get(room, false)):
		return false
	if bool(cleared.get(room, false)) and room != party_room_id:
		return false
	var info = map.by_id.get(room, {})
	if info.is_empty():
		return true
	if int(info.get("stage", 0)) < stage_reached:
		return false
	return true


func _visible_commitments() -> Array:
	var list: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		if not _commitment_pending(e):
			continue
		if not can_read(str(e.get("room", ""))):
			continue
		var pieces: Array = []
		for p in e.get("pieces", []):
			var node := str(p.get("node", ""))
			pieces.append({
				"kind": str(p.get("kind", "")),
				"node": node,
				"pos": Fixed.tile_center(map.node_tile(node)),
			})
		list.append({
			"plan": str(e.plan),
			"room": str(e.room),
			"node": str(e.node),
			"pos": e.pos,
			"land": int(e.land),
			"pieces": pieces,
		})
	return list


func _hostiles_in_room(room: String) -> int:
	var n := 0
	for m in _living_mobs():
		var here := map.id_at_tile(Fixed.tile_of(m.pos)) == room
		# A spawn still telegraphing in the room it was called to holds the party.
		# Once it has walked out, it no longer keeps that room from clearing.
		var spawning_here := str(m.get("home", "")) == room and int(m.get("active_at", 0)) > tick
		if here or spawning_here:
			n += 1
	return n


func _room_is_corridor() -> bool:
	var room = map.by_id.get(party_room_id, {})
	return not room.is_empty() and bool(room.corridor)


func _visible_rooms() -> Dictionary:
	# Current room, plus the next doorway. A corridor IS the doorway, so from
	# inside one you can see both rooms it joins. From a room you see the
	# adjoining corridors, not the room beyond them.
	var vis := {}
	vis[party_room_id] = 2
	var room = map.by_id.get(party_room_id, {})
	if room.is_empty():
		return vis
	for n in room.neighbors:
		vis[str(n)] = 1
	return vis


func _clamp_pos(pos: Vector2i) -> Vector2i:
	if _walkable_pos(pos):
		return pos
	var a := anchor
	var cursor := pos
	for _i in 6:
		cursor = Vector2i((cursor.x * 2 + a.x) / 3, (cursor.y * 2 + a.y) / 3)
		if _walkable_pos(cursor):
			return cursor
	if _walkable_pos(a):
		return a
	return Fixed.tile_center(map.center_tile("start"))


func _walkable_pos(pos: Vector2i) -> bool:
	return map.at(Fixed.tile_of(pos)) >= 0


func _slide(from: Vector2i, to: Vector2i) -> Vector2i:
	if _walkable_pos(to):
		return to
	var sx := Vector2i(to.x, from.y)
	var sy := Vector2i(from.x, to.y)
	if _walkable_pos(sx):
		return sx
	if _walkable_pos(sy):
		return sy
	return from


func _copy_unit(e: Dictionary) -> Dictionary:
	return {
		"id": e.id,
		"kind": e.kind,
		"subtype": e.subtype,
		"name": e.name,
		"pos": e.pos,
		"hp": e.hp,
		"hp_max": e.hp_max,
		"shield": int(e.get("shield", 0)),
		"alive": e.alive,
		"affixes": e.get("affixes", []).duplicate() if e.has("affixes") else [],
		"spawning": int(e.get("active_at", 0)) > tick,
		"blink": e.get("blink", {}).duplicate(true) if e.get("blink", {}) is Dictionary else {},
		"mark": int(e.get("mark_until", 0)) > tick,
		"silence": int(e.get("silence_until", 0)) > tick,
		"rot": int(e.get("rot_until", 0)) > tick,
		"weaken": int(e.get("weaken_until", 0)) > tick,
		"radiance": int(e.get("radiance", 0)),
		"downed": not bool(e.alive) and not bool(e.get("final_death", false)) and str(e.kind) == "angel",
		"downed_left": maxi(0, int(e.get("downed_until", 0)) - tick) if (not bool(e.alive) and not bool(e.get("final_death", false))) else 0,
		"final_death": bool(e.get("final_death", false)),
		"statuses": unit_statuses(e),
	}


## View-only buff and debuff rows. The indicator layer reads this; nothing
## here is written back into the tick.
func unit_statuses(e: Dictionary) -> Array:
	var out: Array = []
	_push_timed(out, e, "silence", "debuff", "SIL", "silence_until", Balance.SILENCE_TICKS, true)
	var rot_until := int(e.get("rot_until", 0))
	if rot_until > tick:
		var stacks := maxi(1, int(e.get("rot_stacks", 1)))
		out.append(_status_row("rot", "debuff", "ROT", stacks, rot_until - tick, Balance.ROT_TICKS, true))
	_push_timed(out, e, "mark", "debuff", "MRK", "mark_until", Balance.MARK_TICKS, true)
	_push_timed(out, e, "weaken", "debuff", "WEK", "weaken_until", Balance.WEAKEN_TICKS, true)
	if str(e.get("kind", "")) == "angel" and bool(e.get("alive", false)) and corruption:
		var period := Balance.TURTLE_DMG_PERIOD
		var into := turtle_clock % period
		var left := period - into
		if left <= 0:
			left = period
		out.append(_status_row("corruption", "debuff", "CORRUPT", 1, left, period, true))
	if str(e.get("kind", "")) == "angel" and bool(e.get("alive", false)) and tick < root_until:
		out.append(_status_row("snare", "debuff", "SNARE", 1, root_until - tick, maxi(root_total, root_until - tick), false))
	var shield := int(e.get("shield", 0))
	if shield > 0:
		out.append(_status_row("shield", "buff", "SH", shield, 0))
	var rad := int(e.get("radiance", 0))
	if rad > 0:
		out.append(_status_row("radiance", "buff", "DMG", rad, 0))
	if int(e.get("body_block_until", 0)) > tick:
		out.append(_status_row("block", "buff", "BLK", 1, int(e.body_block_until) - tick))
	var phx := int(e.get("phalanx", 0))
	if phx > 0 and tick < phalanx_until:
		out.append(_status_row("phalanx", "buff", "PHX", phx, phalanx_until - tick))
	if str(e.get("kind", "")) == "angel" and bool(e.get("alive", false)) and tick < shield_wall_until:
		out.append(_status_row("wall", "buff", "WALL", 1, shield_wall_until - tick))
	if tick < taunt_until and taunt_id != 0:
		if str(e.get("subtype", "")) == "michael" and bool(e.get("alive", false)):
			out.append(_status_row("taunt", "buff", "TNT", 1, taunt_until - tick))
		if int(e.get("id", -1)) == taunt_id:
			out.append(_status_row("taunt", "debuff", "TNT", 1, taunt_until - tick))
	if int(e.get("untargetable_until", 0)) > tick:
		out.append(_status_row("safe", "buff", "SAFE", 1, int(e.untargetable_until) - tick))
	if int(e.get("dodge_until", 0)) > tick:
		out.append(_status_row("dodge", "buff", "DODGE", int(e.get("dodge_bonus", 0)), int(e.dodge_until) - tick, Balance.DASH_DODGE_TICKS, false))
	return out


func _push_timed(out: Array, e: Dictionary, id: String, polarity: String, label: String, field: String, total: int, cleansable: bool) -> void:
	var until := int(e.get(field, 0))
	if until > tick:
		out.append(_status_row(id, polarity, label, 1, until - tick, total, cleansable))


func _status_row(id: String, polarity: String, label: String, stacks: int, left: int, total: int = 0, cleansable: bool = true) -> Dictionary:
	return {
		"id": id,
		"polarity": polarity,
		"label": label,
		"stacks": stacks,
		"left": left,
		"total": total if total > 0 else left,
		"cleansable": cleansable,
		"symbol": id,
		"note": "" if cleansable else "not cleansable",
	}


func _history_style() -> String:
	if traps_placed >= spawns_placed and traps_placed >= curses_cast and traps_placed > 0:
		return "traps"
	if spawns_placed >= curses_cast and spawns_placed > 0:
		return "summons"
	if curses_cast > 0:
		return "curses"
	return "summons"


func _pattern_for(style: String) -> Array:
	match style:
		"traps":
			return ["cleave", "hell_rain", "cleave", "grasp"]
		"summons":
			return ["grasp", "cleave", "hell_rain", "judgment"]
		"curses":
			return ["judgment", "hell_rain", "judgment", "cleave"]
		_:
			return ["hell_rain", "cleave", "judgment", "grasp"]


func _wave_from_budget(budget: int, hp_pct: int) -> Array:
	var units: Array = []
	if hp_pct < 40:
		if budget >= 2000:
			units.append("heavy")
		return units
	var left := budget
	var heavies := 0
	while left >= 3000 and heavies < 2 and units.size() < 6:
		units.append("heavy")
		left -= 3000
		heavies += 1
	while left >= 800 and units.size() < 6:
		units.append("imp")
		left -= 800
	return units


func _echo_node() -> String:
	var room := party_room_id
	var info = map.by_id.get(room, {})
	if info.is_empty() or info.nodes.is_empty():
		room = "throne" if map.by_id.has("throne") else "altar"
	for key in ["flank", "center", "rear", "choke"]:
		var node := "%s:%s" % [room, key]
		if map.node_tile(node).x >= 0:
			return node
	return "throne:center"


func _lucifer_spawn_pos() -> Vector2i:
	var room := party_room_id
	var info = map.by_id.get(room, {})
	if not info.is_empty() and info.nodes.has("rear"):
		return _clamp_pos(Fixed.tile_center(info.nodes.rear))
	if not info.is_empty() and not info.corridor:
		return _clamp_pos(Fixed.tile_center(map.center_tile(room)) + Vector2i(1500, 0))
	return _clamp_pos(anchor + Fixed.rotate_facing(Vector2i(2500, 0), facing))


func _shape_echo(budget: int, hp_pct: int) -> void:
	var units := _wave_from_budget(budget, hp_pct)
	echo_traps = 0
	trap_cap = Balance.ECHO_TRAP_CAP
	if echo_style == "traps" and traps_placed >= Balance.HISTORY_FLOOR:
		var kept: Array = []
		for u in units:
			if str(u) == "heavy" and kept.is_empty():
				kept.append("heavy")
		units = kept
		echo_traps = mini(2, 1 + traps_placed / 12)
		trap_cap = Balance.ECHO_TRAP_CAP_TRAPPY
		if early_descend:
			echo_traps = maxi(0, echo_traps - 1)
			trap_cap = Balance.ECHO_TRAP_CAP
			if not units.is_empty():
				units.pop_back()
	elif echo_style == "summons" and spawns_placed >= Balance.HISTORY_FLOOR:
		var bonus := mini(4, spawns_placed / 3)
		if early_descend:
			bonus = bonus / 2
		var i := 0
		while i < bonus and units.size() < Balance.MOB_CAP:
			units.append("imp")
			i += 1
	echo_units = units


func _schedule_echo_traps() -> void:
	if echo_traps <= 0:
		return
	var kinds := ["spike", "hellflame", "snare"]
	var slots := ["choke", "flank", "center"]
	var delay := Balance.TRANSFORM_CAST + 20
	var n := 0
	for slot in slots:
		if n >= echo_traps:
			break
		var node := "%s:%s" % [party_room_id, slot]
		if map.node_tile(node).x < 0:
			continue
		var kind := str(kinds[n % kinds.size()])
		submit("trap", {"kind": kind, "node": node, "echo": true}, "demon", delay)
		delay += 6
		n += 1


func _arm_echo_traps() -> void:
	for id in order.duplicate():
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("echo", false)):
			continue
		if bool(e.get("armed", false)) or not bool(e.get("alive", false)):
			continue
		if tick < int(e.get("arm_at", 0)):
			continue
		if _armed_trap_count() >= trap_cap:
			e.alive = false
			_log("The echo trap fades. The cap holds.", "info")
			continue
		e.armed = true
		_log("Echo %s arms." % str(e.subtype), "bad")


func _cut_traps() -> void:
	var keep := maxi(0, trap_cap - echo_traps)
	var armed: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)):
			armed.append(e)
	armed.sort_custom(func(a, b): return int(a.id) < int(b.id))
	while armed.size() > keep:
		var old: Dictionary = armed.pop_front()
		old.armed = false
		old.alive = false


func _reignite_traps() -> void:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("armed", false)):
			continue
		if not _visible_rooms().has(str(e.room)) and str(e.room) != party_room_id:
			continue
		_add_zone(e.pos, 1200, 50, 6, "hell", 0)


func _any_angel_coming_back() -> bool:
	if pending_revives.size() > 0:
		return true
	for a in _angels():
		if not a.casting.is_empty() and str(a.casting.get("ability", "")) == "slow_revive":
			return true
	return false


func _corridor_goal(room: String) -> Vector2i:
	# Any walkable tile of the corridor, nearest the party.
	var ri := -1
	for i in map.rooms.size():
		if map.rooms[i].id == room:
			ri = i
			break
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	var here := Fixed.tile_of(anchor)
	if ri < 0:
		return here
	for i in map.room_of.size():
		if int(map.room_of[i]) != ri:
			continue
		var t := Vector2i(i % map.width, i / map.width)
		var d := absi(t.x - here.x) + absi(t.y - here.y)
		if d < best_d:
			best_d = d
			best = t
	return best


func _dist_to_segment(p: Vector2i, a: Vector2i, b: Vector2i) -> int:
	var ab := b - a
	var ap := p - a
	var ab2 := ab.x * ab.x + ab.y * ab.y
	if ab2 <= 0:
		return Fixed.dist(p, a)
	var t := ap.x * ab.x + ap.y * ab.y
	if t <= 0:
		return Fixed.dist(p, a)
	if t >= ab2:
		return Fixed.dist(p, b)
	var cx := a.x + ab.x * t / ab2
	var cy := a.y + ab.y * t / ab2
	return Fixed.dist(p, Vector2i(cx, cy))


func _vec(v) -> Vector2i:
	if v is Vector2i:
		return v
	return Vector2i.ZERO


func _popup(pos: Vector2i, text: String, kind: String, unit_id: int = 0, source: String = "") -> void:
	if source != "" and unit_id != 0:
		for p in popups:
			if int(p.get("unit", 0)) != unit_id or str(p.get("source", "")) != source:
				continue
			var total := int(p.get("total", 0)) + _popup_amount(text)
			var count := int(p.get("count", 1)) + 1
			p.total = total
			p.count = count
			p.tick = tick
			p.pos = pos
			p.kind = kind
			p.text = "%s %d x%d" % [source, total, count] if count > 1 else "%s %d" % [source, total]
			return
	var total0 := _popup_amount(text)
	popups.append({
		"tick": tick,
		"pos": pos,
		"text": text if source == "" else ("%s %d" % [source, total0]),
		"kind": kind,
		"unit": unit_id,
		"source": source,
		"count": 1,
		"total": total0,
	})


func _popup_amount(text: String) -> int:
	var digits := ""
	var seen := false
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
			seen = true
		elif seen:
			break
	if digits == "":
		return 0
	return int(digits)


func _prune_popups() -> void:
	var keep: Array = []
	for p in popups:
		var life := 10 if str(p.get("source", "")) in ["Corruption", "Rot"] else 18
		if tick - int(p.tick) <= life:
			keep.append(p)
	popups = keep


func _log(text: String, kind: String) -> void:
	feed.append({"tick": tick, "text": text, "kind": kind})
	if feed.size() > 16:
		feed.pop_front()


func _fail(reason: String) -> void:
	if reason == last_fail and tick - last_fail_tick < 25:
		return
	last_fail = reason
	last_fail_tick = tick
	_log(reason, "bad")


