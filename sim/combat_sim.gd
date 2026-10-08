class_name CombatSim
extends RefCounted
## Authoritative combat simulation.
##
## Angels and the demon (the director now, a human later) submit the same
## commands. tick_once() is an integer step: no frame delta and no RNG.
## The renderer may only trust build_snapshot(). Fair play is assumed.

const STANCE_TIGHT := 0
const STANCE_SPREAD := 1
const STANCE_COLUMN := 2

const _STANCE_NAME := ["Tight", "Spread", "Column"]

const _KIT := {
	"michael": ["taunt", "shield_wall", "body_block"],
	"raphael": ["single_heal", "party_heal", "slow_revive"],
	"azrael": ["burst", "disarm", "escape_dash"],
	"uriel": ["beam", "aoe_zone", "disengage"],
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
var phase := "dungeon"
var outcome := ""
var max_depth := 0
var rooms_cleared := 0
var cleared := {}
var visited := {}
var shield_wall_until := 0
var taunt_until := 0
var root_until := 0
var scatter_until := 0
var iframe_until := 0
var phalanx_until := 0
var disengage_until := 0
var altar_progress := 0
var altar_done := false
var revive_charges := 0
var pending_revives: Array = []
var channeling_altar := false
var idle_ticks := 0
var corruption := false
var corruption_warned := false
var turtle_clock := 0

var traps_placed := 0
var spawns_placed := 0
var curses_cast := 0
var echo_style := ""
var echo_units: Array = []
var echo_spawned := false
var early_descend := false
var banner := ""
var banner_until := 0
var lucifer_pattern: Array = []
var lucifer_step := 0
var lucifer_next := 0
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
	phase = "dungeon"
	outcome = ""
	max_depth = 0
	rooms_cleared = 0
	cleared = {"start": true}
	visited = {"start": true}
	shield_wall_until = 0
	taunt_until = 0
	root_until = 0
	scatter_until = 0
	iframe_until = 0
	phalanx_until = 0
	disengage_until = 0
	altar_progress = 0
	altar_done = false
	revive_charges = 0
	pending_revives = []
	channeling_altar = false
	idle_ticks = 0
	corruption = false
	corruption_warned = false
	turtle_clock = 0
	traps_placed = 0
	spawns_placed = 0
	curses_cast = 0
	echo_style = ""
	echo_units = []
	echo_spawned = false
	early_descend = false
	banner = ""
	banner_until = 0
	lucifer_pattern = ["hell_rain", "cleave", "judgment", "grasp"]
	lucifer_step = 0
	lucifer_next = 0
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
	_log("The siege begins. The fork ahead is not one road.", "info")


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
	_reveal_traps()
	_maybe_repath()
	_trigger_traps()
	_mob_ai()
	_angel_autos()
	_channels()
	_zones_and_auras()
	_curses_land()
	_lucifer()
	_altar()
	_turtle()
	_resolve_revives()
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


func _exec(c: Dictionary) -> void:
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
		"shield", "heal", "cleanse", "detect", "burst":
			_cast(_route(type))
		"ability":
			_cast(str(args.get("name", "")))
		"scatter":
			_cast_scatter()
		"phalanx":
			_cast_phalanx()
		"channel_altar":
			channeling_altar = true
		"stop_channel":
			channeling_altar = false
		"spawn":
			_cmd_spawn(args)
		"trap":
			_cmd_trap(args)
		"curse":
			_cmd_curse(args)
		"descend":
			_cmd_descend(bool(args.get("early", false)))
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
	if room in ["trapped", "summoned", "cursed"]:
		route_lock_room = room
		route_lock_until = tick + Balance.ROUTE_LOCK_TICKS
		var hint: String = str(map.by_id[room].hint)
		_log("Committed: %s (%s)." % [map.by_id[room].name, hint], "info")


func _route_blocked(room: String) -> bool:
	if room == "" or route_lock_until <= tick:
		return false
	if room not in ["trapped", "summoned", "cursed"]:
		return false
	return room != route_lock_room


func _cmd_stance(next: int) -> void:
	if next < 0 or next > 2 or next == stance:
		return
	stance = next
	_log("Stance: %s." % _STANCE_NAME[stance], "info")


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
			if _dead_count() > 0 and _lowest_living_pct() >= 70:
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


func _cast(ability: String) -> void:
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
	if not _apply_ability(ability, owner):
		return
	golden -= price
	owner.cooldowns[ability] = tick + Balance.cooldown(ability)


func _apply_ability(ability: String, owner: Dictionary) -> bool:
	match ability:
		"taunt":
			taunt_until = tick + Balance.TAUNT_TICKS
			_log("Michael taunts.", "good")
			return true
		"shield_wall":
			shield_wall_until = tick + Balance.SHIELD_WALL_TICKS
			_log("Shield wall.", "good")
			return true
		"body_block":
			owner.body_block_until = tick + Balance.BODY_BLOCK_TICKS
			_log("Michael will intercept the next strike.", "good")
			return true
		"single_heal":
			var tgt := _lowest_living()
			if tgt.is_empty():
				_fail("No one to heal.")
				return false
			_heal(tgt, 62)
			_log("Raphael heals %s." % tgt.name, "good")
			return true
		"party_heal":
			for a in _angels():
				if a.alive:
					_heal(a, 32)
			_log("Raphael mends the party.", "good")
			return true
		"slow_revive":
			var dead := _first_dead()
			if dead.is_empty():
				_fail("No one is down.")
				return false
			owner.casting = {"ability": "slow_revive", "until": tick + 60, "target": dead.id}
			_log("Raphael begins a resurrection.", "good")
			return true
		"burst":
			var foe := _focus_or_nearest(owner)
			if foe.is_empty() or Fixed.dist(owner.pos, foe.pos) > int(owner.range) + 150:
				_fail("Burst has no target in reach.")
				return false
			_hurt(foe, _out_damage(74), "single", owner.id, false)
			_log("Azrael bursts %s." % foe.name, "good")
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
			owner.untargetable_until = tick + 30
			var back := Fixed.rotate_facing(Vector2i(-1600, 0), facing)
			owner.pos = _clamp_pos(anchor + back)
			_log("Azrael slips the line.", "good")
			return true
		"detect_pulse":
			var n := _reveal_radius(owner.pos, Balance.DETECT_PULSE)
			_log("Detect pulse reveals %d trap%s." % [n, "" if n == 1 else "s"], "info")
			return true
		"beam":
			var foe2 := _focus_or_nearest(owner)
			if foe2.is_empty():
				_fail("Beam has no target.")
				return false
			owner.casting = {"ability": "beam", "until": tick + 24, "next": tick + 8, "pulses": 3, "target": foe2.id}
			_log("Uriel's beam locks on.", "good")
			return true
		"aoe_zone":
			var spot := _cluster_point(owner)
			if spot == Vector2i.ZERO and _living_mobs().is_empty():
				_fail("No one to burn.")
				return false
			var stacks := int(owner.radiance)
			owner.radiance = 0
			_add_zone(spot, Balance.HELLFLAME_RADIUS, 60, 9, "holy", stacks)
			_log("Holy zone (Radiance %d)." % stacks, "good")
			return true
		"disengage":
			var back2 := Fixed.rotate_facing(Vector2i(-2500, 0), facing)
			anchor = _clamp_pos(anchor + back2)
			path = []
			move_goal_room = ""
			disengage_until = tick + 30
			channeling_altar = false
			_log("The squad disengages.", "good")
			return true
		"cleanse":
			return _do_cleanse()
		"self_shield":
			owner.shield += 55
			_log("Gabriel shields himself.", "good")
			return true
		"emergency_res":
			var dead2 := _first_dead()
			if dead2.is_empty():
				_fail("No one is down.")
				return false
			_revive(dead2, 25)
			_log("Gabriel forces %s back." % dead2.name, "good")
			return true
		_:
			_fail("No such rite.")
			return false


func _do_cleanse() -> bool:
	var best: Dictionary = {}
	var best_pri := 0
	var best_kind := ""
	for a in _angels():
		if not a.alive:
			continue
		if int(a.silence_until) > tick and best_pri < 3:
			best = a
			best_pri = 3
			best_kind = "silence"
		elif int(a.rot_until) > tick and best_pri < 2:
			best = a
			best_pri = 2
			best_kind = "rot"
		elif int(a.mark_until) > tick and best_pri < 1:
			best = a
			best_pri = 1
			best_kind = "mark"
	if best.is_empty():
		_fail("Nothing to cleanse.")
		return false
	if best_kind == "silence":
		best.silence_until = 0
	elif best_kind == "rot":
		best.rot_until = 0
	else:
		best.mark_until = 0
	stats.curses_cleansed += 1
	_grant_golden(Balance.CLEANSE_BOUNTY, party_room_id)
	_log("Gabriel cleanses %s from %s." % [best_kind, best.name], "good")
	return true


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
	var reason := "" if echo else legal_spawn(unit, node)
	if reason != "":
		return
	if not echo:
		dark -= Balance.summon_cost(unit)
		spawns_placed += 1
	var pos := Fixed.tile_center(map.node_tile(node))
	if unit == "swarm":
		for i in 3:
			var off := Vector2i((i - 1) * 450, (i - 1) * 280)
			_make_mob("imp", "Imp", pos + off, 34, 6, 18, 1100, 150, [], node)
		_log("Imps claw their way in.", "bad")
	elif unit == "heavy":
		_make_mob("heavy", "Heavy Demon", pos, 260, 13, 18, 1200, 85, [], node)
		_log("A heavy demon rises.", "bad")
	elif unit == "elite":
		var affixes: Array = [] if echo else ["teleporter", "molten"]
		_make_mob("elite", "Elite", pos, 420, 12, 20, 1300, 100, affixes, node)
		_log("An elite takes the node — Teleporter, Molten.", "bad")
	elif unit == "imp":
		_make_mob("imp", "Imp", pos, 34, 6, 18, 1100, 150, [], node)
		_log("An imp crawls out of the echo.", "bad")


func _cmd_trap(args: Dictionary) -> void:
	if phase != "dungeon":
		return
	var kind := str(args.get("kind", ""))
	var node := str(args.get("node", ""))
	if legal_trap(kind, node) != "":
		return
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
	}
	order.append(id)
	order.sort()


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


func _cmd_descend(early: bool) -> void:
	if phase == "lucifer":
		return
	phase = "lucifer"
	early_descend = early
	var hp_pct := party_hp_pct()
	var budget := Balance.echo_budget(dark, hp_pct, early)
	dark -= budget
	if dark < 0:
		dark = 0
	echo_style = _history_style()
	echo_units = _wave_from_budget(budget, hp_pct)
	if echo_style == "summons" and echo_units.size() < 6:
		echo_units.append("imp")
	trap_cap = Balance.ECHO_TRAP_CAP
	_cut_traps()
	if echo_style == "traps":
		_reignite_traps()
	lucifer_pattern = _pattern_for(echo_style)
	lucifer_step = 0
	lucifer_next = tick + 30
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
	banner = "LUCIFER PHASE"
	banner_until = tick + 90
	var when := "early" if early else "at the throne"
	_log("Lucifer descends %s. Echo of %s." % [when, echo_style], "bad")
	# The one committed wave is already paid for. It arrives on a timer.
	var delay := Balance.ECHO_DELAY
	for u in echo_units:
		var node := _echo_node()
		var unit := "heavy" if str(u) == "heavy" else "imp"
		submit("spawn", {"unit": unit, "node": node, "echo": true}, "demon", delay)
		delay += 8
	echo_spawned = true


# --- legality ---------------------------------------------------------------

func legal_trap(kind: String, node: String) -> String:
	if phase != "dungeon":
		return "echo"
	if Balance.trap_cost(kind) > dark:
		return "dark"
	if _armed_trap_count() >= trap_cap:
		return "cap"
	var tile := map.node_tile(node)
	if tile.x < 0:
		return "node"
	if node_occupied_by_trap(node):
		return "occupied"
	var room := node.split(":")[0]
	if room == party_room_id:
		return "too close"
	var pos := Fixed.tile_center(tile)
	for a in _angels():
		if a.alive and Fixed.dist(a.pos, pos) < Balance.TRAP_MIN_DIST:
			return "too close"
	return ""


func legal_spawn(unit: String, node: String) -> String:
	if phase != "dungeon":
		return "echo"
	if not Balance.tier_ok(unit, max_depth):
		return "tier"
	if Balance.summon_cost(unit) > dark:
		return "dark"
	if map.node_tile(node).x < 0:
		return "node"
	if mob_count() >= Balance.MOB_CAP:
		return "cap"
	return ""


func legal_curse(kind: String, target_name: String) -> String:
	if phase != "dungeon":
		return "echo"
	if Balance.curse_cost(kind) > dark:
		return "dark"
	if curse_pending_or_active():
		return "busy"
	var hero := _hero(target_name)
	if hero.is_empty() or not hero.alive:
		return "target"
	return ""


func node_occupied_by_trap(node: String) -> bool:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)) and str(e.get("node", "")) == node:
			return true
	return false


# --- simulation steps -------------------------------------------------------

func _regen() -> void:
	var stage := mini(rooms_cleared, 5)
	var g := Balance.GOLDEN_REGEN_BASE + stage * Balance.REGEN_PER_STAGE
	var d := Balance.DARK_REGEN_BASE + stage * Balance.REGEN_PER_STAGE
	if phase == "lucifer":
		g += Balance.LUCIFER_REGEN_BONUS
		d += Balance.LUCIFER_REGEN_BONUS
	if corruption:
		d += Balance.TURTLE_DARK_PER_TICK
	golden = mini(Balance.ELIXIR_MAX, golden + g)
	dark = mini(Balance.ELIXIR_MAX, dark + d)


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
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		facing = Vector2i(Fixed.sign_i(delta.x), 0)
	elif delta.y != 0:
		facing = Vector2i(0, Fixed.sign_i(delta.y))


func _idle_tick() -> void:
	if phase == "lucifer":
		idle_ticks = 0
		return
	if _hostiles_in_room(party_room_id) > 0:
		idle_ticks = 0
		return
	var room = map.by_id.get(party_room_id, {})
	if room.is_empty():
		return
	var is_cleared := bool(cleared.get(party_room_id, false)) or str(room.kind) == "start" or str(room.kind) == "corridor"
	if party_room_id == "fork":
		is_cleared = true
	if not is_cleared:
		idle_ticks = 0
		return
	idle_ticks += 1


func _formation() -> void:
	var offsets := _offsets(_effective_stance())
	var i := 0
	for a in _angels():
		if not a.alive:
			i += 1
			continue
		if not a.casting.is_empty() and str(a.casting.get("ability", "")) == "slow_revive":
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


func _passives() -> void:
	var raphael := _hero("raphael")
	if raphael.alive and raphael.casting.is_empty() and raphael.hp < raphael.hp_max:
		if tick % 8 == 0:
			raphael.hp = mini(raphael.hp_max, int(raphael.hp) + 1)
	var azrael := _hero("azrael")
	if azrael.alive:
		_reveal_radius(azrael.pos, Balance.DETECT_AURA)


func _reveal_traps() -> void:
	var lead := _lead_angel()
	if lead.is_empty():
		return
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap" or not bool(e.get("armed", false)) or bool(e.get("revealed", false)):
			continue
		if Fixed.dist(lead.pos, e.pos) <= 1300:
			e.revealed = true
			_log("The lead tile exposes a %s." % e.subtype, "bad")


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
	e.revealed = true
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
		path = []
		_log("Snared.", "bad")
	elif kind == "hellflame":
		_add_zone(e.pos, Balance.HELLFLAME_RADIUS, 60, 8, "hell", 0)
		_log("Hellflame erupts.", "bad")


func _mob_ai() -> void:
	for m in _living_mobs():
		if str(m.kind) == "boss":
			continue
		if int(m.get("active_at", 0)) > tick:
			continue
		if str(m.subtype) == "elite":
			_elite_affixes(m)
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
				if int(tgt.get("untargetable_until", 0)) > tick:
					continue
				_hurt(tgt, int(m.atk), "single", m.id, false)
	_separate_mobs()


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
	if m.affixes.has("molten") and tick % 20 == 0:
		for a in _angels():
			if a.alive and Fixed.dist(a.pos, m.pos) <= Balance.MOLTEN_RADIUS:
				_hurt(a, Balance.MOLTEN_DMG, "aoe", m.id, true)
	if not m.affixes.has("teleporter"):
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
		_hurt(tgt, _out_damage(int(a.atk)), "single", a.id, false)
		if str(a.subtype) == "uriel":
			a.radiance = mini(5, int(a.radiance) + 1)
		stats.damage_dealt += int(a.atk)


func _channels() -> void:
	for a in _angels():
		if a.casting.is_empty():
			continue
		var ability := str(a.casting.ability)
		if ability == "beam":
			if tick >= int(a.casting.next) and int(a.casting.pulses) > 0:
				var tgt := _ent(int(a.casting.target))
				if tgt.is_empty() or not tgt.alive:
					tgt = _focus_or_nearest(a)
					if not tgt.is_empty():
						a.casting.target = tgt.id
				if not tgt.is_empty() and tgt.alive:
					_hurt(tgt, _out_damage(16), "single", a.id, false)
				a.casting.pulses = int(a.casting.pulses) - 1
				a.casting.next = tick + 8
			if int(a.casting.pulses) <= 0 or tick >= int(a.casting.until):
				a.casting = {}
		elif ability == "slow_revive":
			if not a.alive or tick < root_until:
				_interrupt_revive(a)
			elif tick >= int(a.casting.until):
				var dead := _ent(int(a.casting.target))
				a.casting = {}
				if not dead.is_empty() and not dead.alive:
					_revive(dead, 40)
					_log("%s stands again." % dead.name, "good")


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
		var mult := 100 + 20 * int(e.get("stacks", 0))
		if holy:
			for m in _living_mobs():
				if Fixed.dist(m.pos, e.pos) <= int(e.radius):
					_hurt(m, _out_damage(int(e.dmg) * mult / 100), "aoe", 0, true)
		else:
			for a in _angels():
				if a.alive and Fixed.dist(a.pos, e.pos) <= int(e.radius):
					_hurt(a, int(e.dmg), "aoe", e.id, true)
	for a in _angels():
		if not a.alive:
			continue
		if int(a.rot_until) > tick and tick % Balance.ROT_PERIOD == 0:
			_hurt(a, Balance.ROT_DMG, "dot", 0, true)


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
		if kind == "silence":
			tgt.silence_until = tick + Balance.SILENCE_TICKS
			_log("%s is silenced." % tgt.name, "bad")
		elif kind == "rot":
			tgt.rot_until = tick + Balance.ROT_TICKS
			_log("Rot takes %s." % tgt.name, "bad")
		elif kind == "mark":
			tgt.mark_until = tick + Balance.MARK_TICKS
			_log("%s is marked." % tgt.name, "bad")


func _lucifer() -> void:
	var boss := _boss()
	if boss.is_empty() or not boss.alive:
		return
	var tgt := _nearest_angel(boss.pos)
	if not tgt.is_empty():
		var dist := Fixed.dist(boss.pos, tgt.pos)
		if dist > 1800:
			boss.pos = _slide(boss.pos, Fixed.step_toward(boss.pos, tgt.pos, int(boss.speed)))
		elif dist <= int(boss.range):
			boss.atk_cd = int(boss.atk_cd) - 1
			if int(boss.atk_cd) <= 0:
				boss.atk_cd = int(boss.period)
				_hurt(tgt, int(boss.atk), "single", boss.id, false)
	if telegraph.is_empty():
		if tick >= lucifer_next:
			_open_telegraph(boss)
		return
	if tick < int(telegraph.until):
		return
	_resolve_telegraph(boss)
	telegraph = {}
	hell_rain_marks = []
	lucifer_step += 1
	lucifer_next = tick + 36


func _open_telegraph(boss: Dictionary) -> void:
	if lucifer_pattern.is_empty():
		return
	var name := str(lucifer_pattern[lucifer_step % lucifer_pattern.size()])
	var dur := 44
	if name == "judgment":
		dur = 60
	elif name == "grasp":
		dur = 40
	telegraph = {"name": name, "until": tick + dur, "from": boss.pos}
	if name == "hell_rain":
		hell_rain_marks = []
		for a in _angels():
			if a.alive:
				hell_rain_marks.append({"id": a.id, "pos": a.pos})
		_log("Hell rain — move.", "bad")
	elif name == "cleave":
		var aim := anchor
		telegraph.aim = aim
		_log("Lucifer cleaves.", "bad")
	elif name == "judgment":
		var victim := _lowest_living()
		telegraph.target = victim.id if not victim.is_empty() else 0
		_log("Judgment gathers on %s." % (victim.name if not victim.is_empty() else "the party"), "bad")
	elif name == "grasp":
		_log("Lucifer reaches.", "bad")


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
		var aim: Vector2i = telegraph.get("aim", anchor)
		var end := Fixed.approach(boss.pos, aim, Balance.CLEAVE_LENGTH)
		for a in _angels():
			if not a.alive:
				continue
			if _dist_to_segment(a.pos, boss.pos, end) <= Balance.CLEAVE_HALF_WIDTH:
				_hurt(a, Balance.CLEAVE_DMG, "boss", boss.id, true)
	elif name == "judgment":
		var a2 := _ent(int(telegraph.get("target", 0)))
		if not a2.is_empty() and a2.alive:
			_hurt(a2, Balance.JUDGMENT_DMG, "single", boss.id, false)
	elif name == "grasp":
		for a3 in _angels():
			if not a3.alive:
				continue
			var pulled := true
			if tick < phalanx_until:
				pulled = false
			if pulled:
				a3.pos = _clamp_pos(Fixed.step_toward(a3.pos, boss.pos, Balance.GRASP_PULL))
			_hurt(a3, Balance.GRASP_DMG if pulled else Balance.GRASP_DMG / 2, "boss", boss.id, true)


func _altar() -> void:
	if altar_done or phase == "lucifer":
		channeling_altar = false
		return
	if party_room_id != "altar":
		if channeling_altar:
			altar_progress = maxi(0, altar_progress - 2)
		channeling_altar = false
		return
	if not channeling_altar:
		return
	if _hostiles_in_room("altar") > 0:
		altar_progress = maxi(0, altar_progress - 4)
		return
	var altar_pos := Fixed.tile_center(map.node_tile("altar:rear"))
	var close := false
	for a in _angels():
		if a.alive and Fixed.dist(a.pos, altar_pos) <= Balance.ALTAR_RANGE:
			close = true
			break
	if not close:
		altar_progress = maxi(0, altar_progress - 2)
		return
	altar_progress += Balance.ALTAR_PER_TICK
	if altar_progress >= Balance.ALTAR_NEED:
		altar_progress = Balance.ALTAR_NEED
		altar_done = true
		revive_charges += 1
		channeling_altar = false
		_grant_golden(Balance.CLEAR_BOUNTY, "altar")
		_log("The altar banks a revive charge.", "good")


func _turtle() -> void:
	if idle_ticks == Balance.TURTLE_WARN_TICKS and not corruption_warned:
		corruption_warned = true
		_log("Corruption creeps. Move.", "bad")
	if idle_ticks < Balance.TURTLE_TICKS:
		return
	if not corruption:
		corruption = true
		_log("The cleared room turns on you. Dark swells.", "bad")
	turtle_clock += 1
	if turtle_clock % Balance.TURTLE_DMG_PERIOD == 0:
		for a in _angels():
			if a.alive:
				_hurt(a, Balance.TURTLE_DMG, "dot", 0, true)


func _resolve_revives() -> void:
	var keep: Array = []
	for p in pending_revives:
		if tick < int(p.at):
			keep.append(p)
			continue
		var a := _ent(int(p.id))
		if not a.is_empty() and not a.alive:
			_revive(a, 50)
			_log("The altar restores %s." % a.name, "good")
	pending_revives = keep


func _clears() -> void:
	for id in ["summoned", "cursed", "trapped", "cross"]:
		if bool(cleared.get(id, false)):
			continue
		if not bool(visited.get(id, false)):
			continue
		if _hostiles_in_room(id) > 0:
			continue
		if id in ["trapped", "cursed"]:
			var center: Vector2i = map.center_tile(id)
			if anchor.x < center.x * 1000:
				continue
		_mark_cleared(id)
	if altar_done and not bool(cleared.get("altar", false)):
		_mark_cleared("altar")


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
	if _any_angel_coming_back():
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

func _hurt(target: Dictionary, amount: int, kind: String, source_id: int, area: bool) -> int:
	if target.is_empty() or not bool(target.get("alive", false)):
		return 0
	if amount <= 0:
		return 0
	if area and tick < iframe_until and str(target.team) == "angel":
		_popup(target.pos, "Dodge", "good")
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
		if tick < shield_wall_until:
			amount = amount * 50 / 100
		if int(target.mark_until) > tick:
			amount = amount * Balance.MARK_AMP / 100
		if str(target.subtype) == "michael":
			amount = amount * 75 / 100
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
	if str(target.team) == "angel":
		stats.damage_taken += dealt
		_dark_from_damage(str(target.get("room", party_room_id)), dealt)
		target.room = party_room_id
		if not target.casting.is_empty() and str(target.casting.get("ability", "")) == "slow_revive" and dealt >= 14:
			_interrupt_revive(target)
	else:
		stats.damage_dealt += dealt
	_popup(target.pos, str(dealt), "bad" if str(target.team) == "angel" else "good")
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
		_log("%s falls." % target.name, "bad")
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


func _heal(target: Dictionary, amount: int) -> void:
	if not target.alive:
		return
	if int(target.rot_until) > tick:
		amount = amount * 50 / 100
	if amount < 1:
		return
	target.hp = mini(int(target.hp_max), int(target.hp) + amount)
	_popup(target.pos, "+%s" % amount, "good")


func _revive(target: Dictionary, pct: int) -> void:
	target.alive = true
	target.hp = maxi(1, int(target.hp_max) * pct / 100)
	target.pos = _clamp_pos(anchor)
	target.silence_until = 0
	target.rot_until = 0
	target.mark_until = 0
	target.shield = 0
	target.casting = {}
	stats.revives += 1


func _interrupt_revive(owner: Dictionary) -> void:
	if owner.casting.is_empty():
		return
	owner.casting = {}
	golden = mini(Balance.ELIXIR_MAX, golden + 3000)
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


func curse_pending_or_active() -> bool:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "curse" and not bool(e.get("landed", false)):
			return true
		if str(e.team) == "angel" and e.alive:
			if int(e.silence_until) > tick or int(e.rot_until) > tick or int(e.mark_until) > tick:
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
				foes.append(_copy_unit(e))
		elif kind == "trap":
			if bool(e.get("revealed", false)) and (vis.has(str(e.room)) or not bool(e.get("armed", false))):
				traps.append({
					"id": e.id,
					"subtype": e.subtype,
					"pos": e.pos,
					"armed": e.armed,
					"node": e.node,
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
		hero_state[subtype] = {
			"id": a.id,
			"alive": a.alive,
			"hp": a.hp,
			"hp_max": a.hp_max,
			"shield": a.shield,
			"silence": int(a.silence_until) > tick,
			"rot": int(a.rot_until) > tick,
			"mark": int(a.mark_until) > tick,
			"radiance": int(a.get("radiance", 0)),
			"casting": str(a.casting.get("ability", "")),
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
		"exits": exits,
		"heroes": hero_state,
		"kits": _KIT.duplicate(true),
		"abilities": abilities,
		"bar": bar,
		"altar_progress": altar_progress,
		"altar_done": altar_done,
		"revive_charges": revive_charges,
		"corruption": corruption,
		"corruption_warn": corruption_warned and not corruption,
		"idle_ticks": idle_ticks,
		"banner": banner if tick < banner_until or outcome != "" else "",
		"echo_style": echo_style,
		"early": early_descend,
		"telegraph": telegraph.duplicate(true),
		"hell_rain": hell_rain_marks.duplicate(true),
		"feed": feed.duplicate(true),
		"popups": popups.duplicate(true),
		"stats": stats.duplicate(true),
		"shield_wall": tick < shield_wall_until,
		"rooted": tick < root_until,
		"scatter_cd": maxi(0, int(maneuver_cd.scatter) - tick),
		"phalanx_cd": maxi(0, int(maneuver_cd.phalanx) - tick),
		"route_lock": route_lock_room if route_lock_until > tick else "",
		"boss_hp": _boss_hp(),
		"boss_hp_max": _boss_hp_max(),
		"channeling": channeling_altar,
		"party_hp_pct": party_hp_pct(),
	}


func checksum() -> int:
	var h := 2166136261
	h = Fixed.mix(h, tick)
	h = Fixed.mix(h, golden)
	h = Fixed.mix(h, dark)
	h = Fixed.mix(h, stance)
	h = Fixed.mix(h, focus_id)
	h = Fixed.mix(h, anchor.x)
	h = Fixed.mix(h, anchor.y)
	h = Fixed.mix(h, 1 if phase == "lucifer" else 0)
	for id in order:
		var e: Dictionary = entities[id]
		h = Fixed.mix(h, int(e.id))
		h = Fixed.mix(h, int(e.hp))
		h = Fixed.mix(h, int(e.pos.x))
		h = Fixed.mix(h, int(e.pos.y))
		h = Fixed.mix(h, 1 if e.alive else 0)
	return h


func debug_string() -> String:
	var hp := []
	for a in _angels():
		hp.append("%s:%s/%s" % [a.subtype, a.hp if a.alive else "dead", a.hp_max])
	return "t=%d room=%s g=%d d=%d phase=%s mobs=%d out=%s altar=%s [%s]" % [
		tick, party_room_id, golden, dark, phase, mob_count(), outcome, altar_done, ", ".join(hp)
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
			"mark_until": 0,
			"body_block_until": 0,
			"untargetable_until": 0,
			"radiance": 0,
			"phalanx": 0,
			"room": "start",
		}
		order.append(id)


func _make_mob(subtype: String, name: String, pos: Vector2i, hp: int, atk: int, period: int, range: int, speed: int, affixes: Array, node: String) -> void:
	var id := _alloc()
	var room := node.split(":")[0]
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
		"active_at": tick + Balance.SPAWN_TELEGRAPH,
		"teleport_at": tick + Balance.BLINK_PERIOD,
		"blink": {},
		"node": node,
		"room": room,
		"home": room,
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


func _first_dead() -> Dictionary:
	for a in _angels():
		if not a.alive:
			return a
	return {}


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


func _out_damage(base: int) -> int:
	var g := _hero("gabriel")
	if g.is_empty() or not g.alive:
		return base
	return base * 112 / 100


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
	if tick < taunt_until:
		var michael := _hero("michael")
		if michael.alive:
			return michael
	var marked: Dictionary = {}
	for a in _angels():
		if a.alive and int(a.mark_until) > tick:
			if marked.is_empty() or int(a.id) < int(marked.id):
				marked = a
	if not marked.is_empty():
		return marked
	var blink: Dictionary = m.get("blink", {})
	if not blink.is_empty():
		var blink_tgt := _ent(int(blink.get("target", 0)))
		if not blink_tgt.is_empty() and blink_tgt.alive:
			return blink_tgt
	return _nearest_angel(m.pos)


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
		if str(e.kind) != "trap" or not bool(e.get("armed", false)) or not bool(e.get("revealed", false)):
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
		if str(e.kind) == "trap" and bool(e.get("armed", false)):
			n += 1
	return n


func _hostiles_in_room(room: String) -> int:
	var n := 0
	for m in _living_mobs():
		if str(m.get("home", m.get("room", ""))) == room or map.id_at_tile(Fixed.tile_of(m.pos)) == room:
			if int(m.get("active_at", 0)) <= tick or str(m.kind) == "boss":
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
		"radiance": int(e.get("radiance", 0)),
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


func _cut_traps() -> void:
	var armed: Array = []
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)):
			armed.append(e)
	armed.sort_custom(func(a, b): return int(a.id) < int(b.id))
	while armed.size() > trap_cap:
		var old: Dictionary = armed.pop_front()
		old.armed = false
		old.alive = false


func _reignite_traps() -> void:
	for id in order:
		var e: Dictionary = entities[id]
		if str(e.kind) != "trap":
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


func _popup(pos: Vector2i, text: String, kind: String) -> void:
	popups.append({"tick": tick, "pos": pos, "text": text, "kind": kind})


func _prune_popups() -> void:
	var keep: Array = []
	for p in popups:
		if tick - int(p.tick) <= 18:
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


