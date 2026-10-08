class_name DemonDirector
extends RefCounted
## Budget director. Priority: Survive, Protect the objective, Exploit the
## stance, Spend excess Dark. Plans are committed a moment ahead of time;
## this is not a frame-by-frame optimizer.

# Match CombatSim stance ints.
const STANCE_TIGHT := 0
const STANCE_SPREAD := 1
const STANCE_COLUMN := 2

var sim: CombatSim
var next_decision := 30
var opening_i := 0
var opening_abandoned := false
var committed := {}
var resolved := {}
var fortify_step := 0
var fortified := false
var pressure_lock := 0
var descended := false

var _opening := [
	["trap", "spike", "trapped:choke"],
	["trap", "snare", "trapped:center"],
]


func setup(s) -> void:
	sim = s


func on_tick() -> void:
	if sim.phase != "dungeon" or descended:
		return
	if sim.tick < next_decision:
		return
	next_decision = sim.tick + 20
	if _maybe_descend():
		return
	_arm_branch_plan()
	if _fire_committed():
		return
	if _run_opening():
		return
	if sim.dark < _reserve() and not _objective_threatened():
		return
	if _protect():
		return
	if sim.tick < pressure_lock:
		return
	if _exploit():
		pressure_lock = sim.tick + 160
		return
	if sim.dark > 8200:
		_spend_excess()


func _maybe_descend() -> bool:
	var room := str(sim.party_room())
	if room == "throne":
		_do_descend(false)
		return true
	if sim.max_depth >= 2 and sim.party_hp_pct() < 42 and sim.dark >= 2500 and sim.rooms_cleared >= 1:
		_do_descend(true)
		return true
	return false


func _do_descend(early: bool) -> void:
	descended = true
	sim.submit("descend", {"early": early}, "demon", 1)


func _run_opening() -> bool:
	if opening_abandoned or opening_i >= _opening.size():
		return false
	var room := str(sim.party_room())
	var still_home := room in ["start", "fork", "corr_sf", "corr_ft", "trapped"]
	if sim.max_depth >= 1 and not still_home:
		opening_abandoned = true
		return false
	var step: Array = _opening[opening_i]
	var reason: String = sim.legal_trap(str(step[1]), str(step[2]))
	if reason != "":
		if reason.begins_with("dark"):
			return true
		opening_i += 1
		return true
	sim.submit("trap", {"kind": step[1], "node": step[2]}, "demon", 1)
	opening_i += 1
	return true


func _arm_branch_plan() -> void:
	var room := str(sim.party_room())
	if room in ["summoned", "cursed", "trapped"] and not committed.has(room):
		committed[room] = sim.tick + 30


func _fire_committed() -> bool:
	var keys: Array = committed.keys()
	keys.sort()
	for room in keys:
		if resolved.has(room):
			continue
		if sim.tick < int(committed[room]):
			continue
		var fired := false
		if room == "summoned":
			if sim.legal_spawn("swarm", "summoned:center") == "":
				sim.submit("spawn", {"unit": "swarm", "node": "summoned:center"}, "demon", 1)
				fired = true
			elif sim.legal_spawn("swarm", "summoned:center") != "dark":
				fired = true
		elif room == "cursed":
			var kind := "silence"
			var target := "raphael"
			if sim.stance == STANCE_SPREAD:
				kind = "mark"
			elif sim.angel_hp_pct("raphael") < 45:
				kind = "rot"
				target = sim.lowest_angel_subtype()
			if sim.legal_curse(kind, target) == "":
				sim.submit("curse", {"kind": kind, "target": target}, "demon", 1)
				fired = true
			elif sim.legal_curse(kind, target) != "dark":
				fired = true
		elif room == "trapped":
			if sim.legal_trap("hellflame", "trapped:flank") == "":
				sim.submit("trap", {"kind": "hellflame", "node": "trapped:flank"}, "demon", 1)
				fired = true
			elif sim.legal_trap("hellflame", "trapped:flank") != "dark":
				fired = true
		if fired:
			resolved[room] = true
			return true
		return true
	return false


func _protect() -> bool:
	if sim.max_depth < 2 or fortified:
		return false
	if fortify_step == 0:
		if sim.legal_spawn("elite", "altar:rear") == "":
			sim.submit("spawn", {"unit": "elite", "node": "altar:rear"}, "demon", 1)
			fortify_step = 1
			return true
		if sim.legal_spawn("heavy", "altar:center") == "":
			sim.submit("spawn", {"unit": "heavy", "node": "altar:center"}, "demon", 1)
			fortify_step = 1
			return true
		if sim.legal_spawn("elite", "altar:rear").begins_with("dark") or sim.legal_spawn("heavy", "altar:center").begins_with("dark"):
			return true
		fortify_step = 1
	if fortify_step == 1:
		if sim.legal_trap("hellflame", "altar:choke") == "":
			sim.submit("trap", {"kind": "hellflame", "node": "altar:choke"}, "demon", 1)
			fortified = true
			return true
		if sim.legal_trap("hellflame", "altar:choke").begins_with("dark"):
			return true
		fortified = true
	return false


func _exploit() -> bool:
	var stance: int = sim.stance
	if not sim.curse_pending_or_active():
		if stance == STANCE_SPREAD and sim.legal_curse("mark", "raphael") == "":
			sim.submit("curse", {"kind": "mark", "target": "raphael"}, "demon", 1)
			return true
		if stance == STANCE_TIGHT:
			var node := _ahead_node()
			if node != "" and sim.legal_trap("hellflame", node) == "":
				sim.submit("trap", {"kind": "hellflame", "node": node}, "demon", 1)
				return true
		if stance == STANCE_COLUMN:
			var node2 := _ahead_node()
			if node2 != "" and sim.legal_trap("spike", node2) == "":
				sim.submit("trap", {"kind": "spike", "node": node2}, "demon", 1)
				return true
			if node2 != "" and sim.legal_trap("snare", node2) == "":
				sim.submit("trap", {"kind": "snare", "node": node2}, "demon", 1)
				return true
		if sim.lowest_angel_hp_pct() < 48:
			var who: String = sim.lowest_angel_subtype()
			if sim.legal_curse("rot", who) == "":
				sim.submit("curse", {"kind": "rot", "target": who}, "demon", 1)
				return true
	var room := _combat_room()
	if sim.elite_alive() and sim.elite_hp_pct() < 35 and sim.mob_count() < 5 and sim.legal_spawn("swarm", "altar:flank") == "":
		sim.submit("spawn", {"unit": "swarm", "node": "altar:flank"}, "demon", 1)
		return true
	if not sim.elite_alive() and room in ["summoned", "altar", "cross", "cursed"] and sim.mob_count() < 3:
		if sim.count_subtype("heavy") == 0 and sim.legal_spawn("heavy", "%s:center" % room) == "":
			sim.submit("spawn", {"unit": "heavy", "node": "%s:center" % room}, "demon", 1)
			return true
		if sim.mob_count() < 2 and sim.legal_spawn("swarm", "%s:flank" % room) == "":
			sim.submit("spawn", {"unit": "swarm", "node": "%s:flank" % room}, "demon", 1)
			return true
	return false


func _spend_excess() -> void:
	var node := _ahead_node()
	if node == "":
		node = "cross:flank"
	if sim.legal_trap("snare", node) == "":
		sim.submit("trap", {"kind": "snare", "node": node}, "demon", 1)
		return
	var room := _combat_room()
	if room != "" and sim.legal_spawn("swarm", "%s:rear" % room) == "":
		sim.submit("spawn", {"unit": "swarm", "node": "%s:rear" % room}, "demon", 1)


func _reserve() -> int:
	if _objective_threatened():
		return 0
	if sim.max_depth >= 3:
		return 1200
	return 2200


func _objective_threatened() -> bool:
	var room := str(sim.party_room())
	return room in ["altar", "corr_ca", "throne", "corr_at"]


func _combat_room() -> String:
	var id := str(sim.party_room())
	var room = sim.map.by_id.get(id, {})
	if room.is_empty():
		return ""
	if not room.corridor and room.nodes.size() > 0:
		return id
	for n in room.neighbors:
		var other = sim.map.by_id.get(n, {})
		if other.is_empty():
			continue
		if not other.corridor and int(other.depth) >= int(room.depth):
			return str(other.id)
	return ""


func _ahead_node() -> String:
	var room := _combat_room()
	if room == "" or room == str(sim.party_room()):
		var id := str(sim.party_room())
		var here = sim.map.by_id.get(id, {})
		if here.is_empty():
			return ""
		for e in here.exits:
			var dest = sim.map.by_id.get(e.dest, {})
			if dest.is_empty() or dest.corridor:
				continue
			if int(dest.depth) < int(here.get("depth", 0)):
				continue
			for key in ["choke", "center", "flank", "rear"]:
				var node := "%s:%s" % [e.dest, key]
				if sim.map.node_tile(node).x < 0:
					continue
				if not sim.node_occupied_by_trap(node):
					return node
		return ""
	for key in ["choke", "center", "flank", "rear"]:
		var node2 := "%s:%s" % [room, key]
		if sim.map.node_tile(node2).x < 0:
			continue
		if not sim.node_occupied_by_trap(node2):
			return node2
	return ""
