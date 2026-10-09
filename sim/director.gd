class_name DemonDirector
extends RefCounted
## Kill-priority director. The goal is a wipe, not a surviving bank.
## Finish a downed angel, break the answer, threaten the occupied room
## within 2 seconds, deny a stake only as a kill setup, and bank only
## what the next kill costs. The same submit() path a human demon uses.
## Action types never repeat three times in a row. The seeded sim RNG
## breaks ties so a seed still replays.

const STANCE_TIGHT := 0
const STANCE_SPREAD := 1
const STANCE_COLUMN := 2

var sim: CombatSim
var next_decision := 30
var opening_done := false
var opening_abandoned := false
var committed := {}
var resolved := {}
var fortify_stake := ""
var fortify_step := 0
var fortified := {}
var pressure_lock := 0
var silence_lock := 0
var descended := false
var last_priority := ""
var recent: Array = []
var recent_detail: Array = []
var last_penalty := 0
var last_why := ""
var pending_kind := ""
var pending_why := ""
var _spent_spawn := false


func setup(s) -> void:
	sim = s


func on_tick() -> void:
	_spent_spawn = false
	if sim.phase == "lucifer":
		_press_boss()
		return
	if sim.phase != "dungeon" or descended:
		return
	_arm_branch_plan()
	_fire_current_room()
	if sim.tick < next_decision:
		return
	next_decision = sim.tick + _gap()
	if _maybe_descend():
		last_priority = "finish"
		return
	var choice := _choose()
	if choice.is_empty():
		return
	_execute(choice)


func _gap() -> int:
	if _marching():
		if sim.stage_reached >= 3:
			return 16
		if sim.stage_reached >= 2:
			return 18
		if sim.stage_reached >= 1:
			return 24
		return 36
	if sim.stage_reached <= 0:
		return 36
	if sim.stage_reached >= 2:
		return 18
	return 28


func _maybe_descend() -> bool:
	var room := str(sim.party_room())
	if room == "throne":
		_do_descend(false)
		return true
	if _early_room(room) and sim.stage_reached >= 2 and not sim.altar_done and sim.party_hp_pct() <= 48 and sim.dark >= 2500 and sim.rooms_cleared >= Balance.ELITE_ROOMS:
		_do_descend(true)
		return true
	if _early_room(room) and sim.stage_reached >= 2 and sim.party_hp_pct() < 32 and sim.dark >= 3000 and sim.rooms_cleared >= Balance.ELITE_ROOMS:
		_do_descend(true)
		return true
	return false


func _early_room(room: String) -> bool:
	return room in ["altar", "gallery3", "cross3", "fork3", "summoned3", "trapped3", "cursed3"]


func _press_boss() -> void:
	if sim.lucifer_pattern.is_empty() or sim.outcome != "":
		return
	var button := str(sim.lucifer_pattern[sim.lucifer_step % sim.lucifer_pattern.size()])
	if sim.legal_boss(button) != "":
		return
	sim.submit("boss", {"button": button}, "demon", 1)


func _do_descend(early: bool) -> void:
	descended = true
	sim.submit("descend", {"early": early}, "demon", 1)


func _run_opening() -> bool:
	if opening_abandoned or opening_done:
		return false
	var room := str(sim.party_room())
	var still_home := room in ["start", "fork", "corr_sf", "corr_ft", "trapped"] or _kind(room) == "start"
	if sim.max_depth >= 1 and not still_home:
		opening_abandoned = true
		return false
	# Commit from the antechamber. The cast is the read; the traps sit on the far nodes.
	var pieces: Array = [
		{"kind": "spike", "node": "trapped:flank", "curse": "rot"},
		{"kind": "snare", "node": "trapped:rear"},
	]
	var why := sim.legal_commit({"plan": "trap_cluster", "pieces": pieces})
	if why == "":
		sim.submit("commit", {"plan": "trap_cluster", "pieces": pieces}, "demon", 1)
		_note("trap", "trap:cluster", 0, "east still air")
		opening_done = true
		resolved["trapped"] = true
		return true
	if why == "dark" or why == "busy":
		return true
	opening_done = true
	return false


func _arm_branch_plan() -> void:
	var room := str(sim.party_room())
	var kind := _kind(room)
	if kind in ["summoned", "cursed", "trapped", "gallery"] and not committed.has(room) and not resolved.has(room):
		committed[room] = sim.tick + Balance.ROOM_SPAWN_DELAY
		pending_kind = _signature(kind)
		pending_why = "room commit"
		sim.debug_line("plan %s in %s at tick %d (%s)" % [pending_kind, room, int(committed[room]), pending_why])


func next_spawn_in() -> int:
	var room := str(sim.party_room())
	if not committed.has(room) or resolved.has(room):
		return -1
	return maxi(0, int(committed[room]) - sim.tick)


func _signature(kind: String) -> String:
	if kind == "trapped":
		return "trap"
	if kind == "cursed":
		return "curse"
	return "pack"


func _fire_current_room() -> void:
	var room := str(sim.party_room())
	if not committed.has(room) or resolved.has(room):
		return
	if sim.tick < int(committed[room]):
		return
	_fire_one(room)


func _fire_one(room: String) -> void:
	if resolved.has(room):
		return
	var options := _room_options(room, _kind(room))
	var choice := _pick(options)
	if choice.is_empty():
		if sim.dark < 800 and _homed(room) == 0 and sim.traps_in_room(room) == 0:
			return
		resolved[room] = true
		pending_kind = ""
		return
	_execute(choice)
	if str(choice.get("wait", "")) == "dark":
		return
	resolved[room] = true
	pending_kind = ""


func _choose() -> Dictionary:
	var options: Array = []
	if not opening_done and not opening_abandoned:
		if _run_opening():
			return {}
	_opt_finish(options)
	_opt_break(options)
	_opt_empty_room(options)
	_opt_stake(options)
	_opt_spend(options)
	return _pick(options)


func _opt_finish(options: Array) -> void:
	if sim._downed_count() <= 0:
		return
	var who := ""
	for a in sim._angels():
		if not a.alive and not bool(a.get("final_death", false)):
			who = str(a.subtype)
			break
	if who == "":
		return
	if sim.mob_near("raphael"):
		options.append(_curse_opt("silence", "raphael", 1000, "finish downed"))
		options.append(_curse_opt("rot", who, 980, "finish downed"))
	_add_spawns(options, str(sim.party_room()), 960, "finish downed", true)


func _opt_break(options: Array) -> void:
	var grace := int(sim.curse_grace_until) - int(sim.tick)
	if grace <= 0 and sim.mob_near("raphael"):
		var healer := sim._hero("raphael")
		# Start the next cast before the current one falls off. The cast itself
		# is 50 ticks, and Dark regen is what spaces the buys.
		if not healer.is_empty() and healer.alive and int(healer.get("silence_until", 0)) <= sim.tick + 90:
			options.append(_curse_opt("silence", "raphael", 240, "break heals"))
	if grace > 0 and grace <= 80:
		var cloth := _cloth_target()
		if sim.mob_near(cloth):
			options.append(_curse_opt("rot", cloth, 860, "immunity ending"))
	if _detect_up():
		_add_traps(options, _ahead_room(), 840, "detect up", true)
	if sim.taunt_until > sim.tick or sim.threat_boost_until > sim.tick:
		var cloth2 := _cloth_target()
		if sim.mob_near(cloth2):
			options.append(_curse_opt("mark", cloth2, 820, "taunt holding"))
		elif not _spent_spawn:
			_add_spawns(options, str(sim.party_room()), 800, "taunt holding", false)


func _opt_empty_room(options: Array) -> void:
	var room := str(sim.party_room())
	var kind := _kind(room)
	if kind in ["start", "fork", "corridor", "throne", ""]:
		return
	if _room_has_threat(room):
		return
	if _spent_spawn:
		return
	var why := "room empty"
	if kind in ["seal", "font", "altar"]:
		why = "stake kill"
	_add_spawns(options, room, 720, why, true)
	if kind == "trapped":
		_add_traps(options, room, 700, why, false)


func _opt_stake(options: Array) -> void:
	var stake := _wanted_stake()
	if stake == "" or fortified.has(stake):
		return
	var here := str(sim.party_room())
	if here != stake and here != _approach(stake):
		return
	if stake == "altar" and Balance.tier_ok("elite", sim.rooms_cleared) and not sim.elite_alive() and not sim.commitment_open("elite"):
		var node := "altar:rear"
		if sim.legal_commit({"plan": "elite", "node": node}) == "":
			options.append({
				"type": "commit",
				"detail": "spawn:elite",
				"action": "spawn",
				"plan": "elite",
				"node": node,
				"score": 680,
				"why": "stake kill",
			})
		return
	if not _room_has_threat(stake) and not _spent_spawn:
		_add_spawns(options, stake, 640, "stake kill", false)


func _opt_spend(options: Array) -> void:
	if _lobby():
		return
	var bank := _kill_bank()
	if sim.dark <= bank:
		return
	var ahead := _ahead_room()
	if ahead != "" and ahead != str(sim.party_room()) and _homed(ahead) == 0:
		_add_spawns(options, ahead, 140, "spend", false)
	_add_traps(options, ahead if ahead != "" else str(sim.party_room()), 120, "spend", true)
	if sim.curses_cast % 4 == 3:
		var who := "azrael" if sim.mob_near("azrael") else _any_near()
		if who != "":
			options.append(_curse_opt("weaken", who, 160, "spend"))
	else:
		var who2 := _any_near()
		if who2 != "":
			var kinds := ["rot", "mark", "silence"]
			var curse := str(kinds[sim.curses_cast % kinds.size()])
			options.append(_curse_opt(curse, who2, 150, "spend"))


func _room_options(room: String, kind: String) -> Array:
	var options: Array = []
	var why := "room commit"
	if kind == "trapped":
		_add_traps(options, room, 700, why, false)
		if options.is_empty():
			_add_traps(options, _ahead_room(), 680, why, true)
		if _homed(room) == 0:
			_add_spawns(options, room, 660, why, true)
	elif kind == "cursed":
		var who := _any_near()
		if who != "":
			var curse := "weaken" if sim.curses_cast % 4 == 3 else "rot"
			options.append(_curse_opt(curse, who, 700, why))
		if _homed(room) == 0:
			_add_spawns(options, room, 660, why, true)
	else:
		_add_spawns(options, room, 700, why, true)
		if _homed(room) == 0 and options.is_empty():
			_add_spawns(options, room, 700, why, true)
	return options


func _add_spawns(options: Array, room: String, score: int, why: String, garrison: bool) -> void:
	if room == "" or _kind(room) in ["start", "fork", "corridor", "throne"]:
		return
	var units: Array = []
	if Balance.tier_ok("heavy", sim.rooms_cleared):
		units.append("heavy")
	if not sim.seal_done:
		units.append("swarm")
	if units.is_empty():
		return
	var nodes := ["center", "flank", "rear", "choke"]
	var added := 0
	for unit in units:
		for node_name in nodes:
			var node := "%s:%s" % [room, node_name]
			if sim.map.node_tile(node).x < 0:
				continue
			var in_room := room == str(sim.party_room())
			var use_garrison := garrison and in_room and _homed(room) == 0
			if sim.legal_spawn(str(unit), node, use_garrison) != "":
				continue
			if not use_garrison and not _can_pay(Balance.summon_cost(str(unit))):
				continue
			var bias := 25 if str(unit) == "heavy" else 0
			options.append({
				"type": "spawn",
				"detail": "spawn:%s" % unit,
				"action": "spawn",
				"unit": str(unit),
				"node": node,
				"garrison": use_garrison,
				"score": score + bias,
				"why": why,
			})
			added += 1
			if added >= 4:
				return


func _add_traps(options: Array, room: String, score: int, why: String, allow_curse: bool) -> void:
	if room == "" or sim.traps_in_room(room) >= Balance.TRAP_CAP_PER_ROOM:
		return
	var kinds := ["spike", "snare", "hellflame"]
	var nodes := ["rear", "flank", "center", "choke"]
	var added := 0
	for kind in kinds:
		for node_name in nodes:
			var node := "%s:%s" % [room, node_name]
			if sim.map.node_tile(node).x < 0:
				continue
			if sim.legal_trap(str(kind), node) != "":
				continue
			if not _can_pay(Balance.trap_cost(str(kind))):
				continue
			var curse := ""
			if allow_curse or _kind(room) == "cursed" or (_kind(room) == "trapped" and sim.traps_placed % 2 == 0):
				curse = "rot" if sim.traps_placed % 3 != 2 else "weaken"
			options.append({
				"type": "trap",
				"detail": "trap:%s" % kind,
				"action": "trap",
				"kind": str(kind),
				"node": node,
				"curse": curse,
				"score": score,
				"why": why,
			})
			added += 1
			if added >= 3:
				return


func _curse_opt(kind: String, who: String, score: int, why: String) -> Dictionary:
	return {
		"type": "curse",
		"detail": "curse:%s" % kind,
		"action": "curse",
		"kind": kind,
		"target": who,
		"score": score,
		"why": why,
	}


func _pick(options: Array) -> Dictionary:
	var best := -(1 << 30)
	var tied: Array = []
	for raw in options:
		var opt: Dictionary = raw
		if opt.is_empty():
			continue
		if str(opt.get("type", "")) == "curse":
			if sim.legal_curse(str(opt.get("kind", "")), str(opt.get("target", ""))) != "":
				continue
			if not sim.mob_near(str(opt.get("target", ""))):
				continue
		var pen := _penalty(str(opt.get("action", "")), str(opt.get("detail", "")))
		if pen >= 100000:
			continue
		var score := int(opt.get("score", 0)) - pen
		opt["penalty"] = pen
		if score > best:
			best = score
			tied = [opt]
		elif score == best:
			tied.append(opt)
	if tied.is_empty():
		return {}
	tied.sort_custom(func(a, b): return str(a.get("detail", "")) < str(b.get("detail", "")))
	var idx := 0
	if tied.size() > 1:
		idx = sim.rand_below(tied.size())
	return tied[idx]


func _execute(choice: Dictionary) -> void:
	var action := str(choice.get("action", ""))
	var detail := str(choice.get("detail", ""))
	var why := str(choice.get("why", ""))
	var pen := int(choice.get("penalty", _penalty(action, detail)))
	var kind := str(choice.get("type", ""))
	if kind == "spawn":
		sim.submit("spawn", {
			"unit": str(choice.get("unit", "imp")),
			"node": str(choice.get("node", "")),
			"garrison": bool(choice.get("garrison", false)),
		}, "demon", 1)
		_spent_spawn = true
		pending_kind = "pack"
	elif kind == "trap":
		var args := {"kind": str(choice.get("kind", "spike")), "node": str(choice.get("node", ""))}
		if str(choice.get("curse", "")) != "":
			args["curse"] = str(choice.curse)
		sim.submit("trap", args, "demon", 1)
		pending_kind = "trap"
	elif kind == "curse":
		sim.submit("curse", {"kind": str(choice.get("kind", "")), "target": str(choice.get("target", ""))}, "demon", 1)
		if str(choice.get("kind", "")) == "silence":
			silence_lock = sim.tick + 220
		pending_kind = "curse"
	elif kind == "commit":
		sim.submit("commit", {"plan": str(choice.get("plan", "")), "node": str(choice.get("node", ""))}, "demon", 1)
		fortified["altar"] = true
		pending_kind = "pack"
	else:
		return
	pending_why = why
	last_priority = why
	_note(action, detail, pen, why)
	sim.debug_line("buy %s (%s)" % [detail, why])


func _note(action: String, detail: String, penalty: int, why: String) -> void:
	recent.append(action)
	recent_detail.append(detail)
	while recent.size() > 8:
		recent.pop_front()
		recent_detail.pop_front()
	last_penalty = penalty
	last_why = why
	sim.debug_line("variance penalty %d on %s (%s)" % [penalty, detail, why])


func _penalty(action: String, detail: String) -> int:
	if recent.size() >= 2 and str(recent[recent.size() - 1]) == action and str(recent[recent.size() - 2]) == action:
		return 100000
	var pen := 0
	for prev in recent:
		if str(prev) == action:
			pen += 15
	for prev_d in recent_detail:
		if str(prev_d) == detail:
			pen += 30
	return pen


func _can_pay(cost: int) -> bool:
	return sim.dark - cost >= 0


func _kill_bank() -> int:
	if not sim.altar_done and sim.stage_reached >= 2 and Balance.tier_ok("elite", sim.rooms_cleared) and not sim.elite_alive():
		return Balance.summon_cost("elite")
	if Balance.tier_ok("heavy", sim.rooms_cleared):
		return Balance.summon_cost("heavy")
	return Balance.summon_cost("swarm")


func _room_has_threat(room: String) -> bool:
	if _homed(room) > 0 or sim.traps_in_room(room) > 0:
		return true
	return false


func _detect_up() -> bool:
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.get("kind", "")) == "trap" and bool(e.get("revealed", false)) and bool(e.get("armed", false)):
			return true
	return false


func _cloth_target() -> String:
	var best := "uriel"
	var best_hp := 1 << 30
	for name in ["uriel", "gabriel", "raphael", "azrael"]:
		var a := sim._hero(name)
		if a.is_empty() or not a.alive:
			continue
		if int(a.hp) < best_hp:
			best_hp = int(a.hp)
			best = name
	return best


func _any_near() -> String:
	for name in ["raphael", "uriel", "gabriel", "azrael", "michael"]:
		if sim.mob_near(name):
			return name
	return ""


func _approach(stake: String) -> String:
	if stake == "seal":
		return "cross"
	if stake == "font":
		return "cross2"
	if stake == "altar":
		return "cross3"
	return ""


func _wanted_stake() -> String:
	if not sim.seal_done and bool(sim.visited.get("fork", false)):
		return "seal"
	if sim.seal_done and not sim.font_done and sim.stage_reached >= 1:
		return "font"
	if sim.font_done and not sim.altar_done and sim.stage_reached >= 2:
		return "altar"
	return ""


func _homed(room: String) -> int:
	var n := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if bool(e.get("alive", false)) and str(e.get("kind", "")) == "mob" and str(e.get("home", "")) == room:
			n += 1
	return n


func _ahead_room() -> String:
	return _next_content_room()


func _lobby() -> bool:
	if sim.phase == "lucifer":
		return false
	if sim.stage_reached > 0 or sim.rooms_cleared > 0 or sim.seal_done:
		return false
	var kind := _kind(str(sim.party_room()))
	if kind in ["summoned", "cursed", "trapped", "gallery"]:
		return false
	return true


func _next_content_room() -> String:
	var start := str(sim.party_room())
	var queue: Array = [start]
	var seen := {start: true}
	var qi := 0
	while qi < queue.size():
		var cur: String = str(queue[qi])
		qi += 1
		var room = sim.map.by_id.get(cur, {})
		if room.is_empty():
			continue
		var neigh: Array = room.neighbors.duplicate()
		neigh.sort()
		for n in neigh:
			var nid := str(n)
			if seen.has(nid):
				continue
			var other = sim.map.by_id.get(nid, {})
			if other.is_empty():
				continue
			if int(other.get("stage", 0)) < int(room.get("stage", 0)):
				continue
			if int(other.get("depth", 0)) < int(room.get("depth", 0)) and not other.corridor:
				continue
			seen[nid] = true
			if bool(sim.visited.get(nid, false)) and not other.corridor and nid != start:
				continue
			if not other.corridor and nid != start and str(other.kind) != "start":
				return nid
			if other.corridor:
				queue.append(nid)
	return ""


func _kind(room: String) -> String:
	var info = sim.map.by_id.get(room, {})
	if info.is_empty():
		return ""
	return str(info.get("kind", ""))


func _marching() -> bool:
	if sim.phase != "dungeon":
		return false
	var info = sim.map.by_id.get(str(sim.party_room()), {})
	if info.is_empty():
		return false
	if bool(info.get("corridor", false)):
		return true
	if str(info.get("kind", "")) in ["gallery", "cross"] and not sim.path.is_empty() and sim._hostiles_in_room(str(sim.party_room())) == 0:
		return true
	return false
