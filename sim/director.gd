class_name DemonDirector
extends RefCounted
## Budget director. Priority: Survive, Protect the stake, Exploit the
## stance, Spend excess Dark. The same commands a human demon will send.
## Early stages act rarely. Later stages spend faster, with the altar elite
## saved for the last stake.

const STANCE_TIGHT := 0
const STANCE_SPREAD := 1
const STANCE_COLUMN := 2

var sim: CombatSim
var next_decision := 30
var opening_i := 0
var opening_abandoned := false
var committed := {}
var resolved := {}
var fortify_stake := ""
var fortify_step := 0
var fortified := {}
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
	var gap := 28
	if sim.stage_reached <= 0:
		gap = 36
	elif sim.stage_reached >= 2:
		gap = 18
	next_decision = sim.tick + gap
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
		var hold := 160
		if sim.stage_reached == 1:
			hold = 100
		elif sim.stage_reached >= 2:
			hold = 70
		pressure_lock = sim.tick + hold
		return
	if sim.dark > (9000 if sim.stage_reached <= 0 else 7000):
		_spend_excess()


func _maybe_descend() -> bool:
	var room := str(sim.party_room())
	if room == "throne":
		_do_descend(false)
		return true
	# A late gamble only. Descending in the first two stages would skip the siege.
	if sim.stage_reached >= 2 and sim.party_hp_pct() < 32 and sim.dark >= 3000 and sim.rooms_cleared >= Balance.ELITE_ROOMS:
		if room in ["altar", "gallery3", "cross3", "fork3", "summoned3"]:
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
	var still_home := room in ["start", "fork", "corr_sf", "corr_ft", "trapped"] or str(_kind(room)) == "start"
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
	var kind := _kind(room)
	if kind in ["summoned", "cursed", "trapped", "gallery"] and not committed.has(room):
		committed[room] = sim.tick + 30


func _fire_committed() -> bool:
	var keys: Array = committed.keys()
	keys.sort()
	for room in keys:
		if resolved.has(room):
			continue
		if sim.tick < int(committed[room]):
			continue
		var kind := _kind(str(room))
		var fired := false
		var waiting := false
		if kind == "summoned" or kind == "gallery":
			var unit := "heavy" if Balance.tier_ok("heavy", sim.rooms_cleared) else "swarm"
			if unit == "swarm" and sim.seal_done:
				unit = "heavy"
			var node := "%s:center" % room
			var reason := sim.legal_spawn(unit, node)
			if reason == "" :
				sim.submit("spawn", {"unit": unit, "node": node}, "demon", 1)
				fired = true
			elif reason == "dark":
				waiting = true
			elif reason == "tier" and unit == "heavy":
				var fallback := sim.legal_spawn("swarm", node)
				if fallback == "" and not sim.seal_done:
					sim.submit("spawn", {"unit": "swarm", "node": node}, "demon", 1)
					fired = true
				elif fallback == "dark":
					waiting = true
				else:
					fired = true
			else:
				fired = true
		elif kind == "cursed":
			var curse := "silence"
			var target := "raphael"
			if sim.stance == STANCE_SPREAD:
				curse = "mark"
			elif sim.angel_hp_pct("raphael") < 45:
				curse = "rot"
				target = sim.lowest_angel_subtype()
			var why := sim.legal_curse(curse, target)
			if why == "":
				sim.submit("curse", {"kind": curse, "target": target}, "demon", 1)
				fired = true
			elif why == "dark":
				waiting = true
			else:
				fired = true
		elif kind == "trapped":
			var trap_node := "%s:flank" % room
			var why2 := sim.legal_trap("hellflame", trap_node)
			if why2 == "":
				sim.submit("trap", {"kind": "hellflame", "node": trap_node}, "demon", 1)
				fired = true
			elif why2 == "dark":
				waiting = true
			else:
				fired = true
		else:
			fired = true
		if fired:
			resolved[room] = true
			return true
		if waiting:
			return true
		resolved[room] = true
		return true
	return false


func _protect() -> bool:
	var stake := _wanted_stake()
	if stake == "" or fortified.has(stake):
		return false
	if fortify_stake != stake:
		fortify_stake = stake
		fortify_step = 0
	if fortify_step == 0:
		var unit := _defender(stake)
		var node := "%s:%s" % [stake, "rear" if stake == "altar" else "center"]
		var reason := sim.legal_spawn(unit, node)
		if reason == "":
			sim.submit("spawn", {"unit": unit, "node": node}, "demon", 1)
			fortify_step = 1
			return true
		if reason == "dark":
			return true
		if reason == "tier":
			# Don't freeze the director waiting on a tier the party has not earned.
			return false
		if reason == "sealed" and unit == "swarm":
			fortify_step = 1
		else:
			fortify_step = 1
	if fortify_step == 1:
		var trap := "spike" if stake == "seal" else "hellflame"
		var choke := "%s:choke" % stake
		var why := sim.legal_trap(trap, choke)
		if why == "":
			sim.submit("trap", {"kind": trap, "node": choke}, "demon", 1)
			fortified[stake] = true
			return true
		if why == "dark":
			return true
		fortified[stake] = true
	return false


func _defender(stake: String) -> String:
	if stake == "altar" and Balance.tier_ok("elite", sim.rooms_cleared):
		return "elite"
	if Balance.tier_ok("heavy", sim.rooms_cleared):
		return "heavy"
	if not sim.seal_done:
		return "swarm"
	return "heavy"


func _wanted_stake() -> String:
	if not sim.seal_done and bool(sim.visited.get("fork", false)):
		return "seal"
	if sim.seal_done and not sim.font_done and sim.stage_reached >= 1:
		return "font"
	if sim.font_done and not sim.altar_done and sim.stage_reached >= 2:
		return "altar"
	return ""


func _exploit() -> bool:
	# The opening stage is the fork puzzle, not a swarm clock.
	if sim.stage_reached <= 0 and sim.dark < 7500:
		return false
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
		if sim.lowest_angel_hp_pct() < 48 and sim.stage_reached >= 1:
			var who: String = sim.lowest_angel_subtype()
			if sim.legal_curse("rot", who) == "":
				sim.submit("curse", {"kind": "rot", "target": who}, "demon", 1)
				return true
	var room := _combat_room()
	if room != "" and sim.elite_alive() and sim.elite_hp_pct() < 35 and sim.mob_count() < 5:
		var flank := "%s:flank" % room
		if not sim.seal_done and sim.legal_spawn("swarm", flank) == "":
			sim.submit("spawn", {"unit": "swarm", "node": flank}, "demon", 1)
			return true
	# Reinforce the NEXT room. Restocking the room the party is already
	# fighting turns every clear into a grind and blows the run length.
	var ahead := _next_content_room()
	if ahead == "" or ahead == str(sim.party_room()):
		return false
	if sim.mob_count() >= 3:
		return false
	if sim.count_subtype("heavy") == 0 and sim.legal_spawn("heavy", "%s:center" % ahead) == "":
		sim.submit("spawn", {"unit": "heavy", "node": "%s:center" % ahead}, "demon", 1)
		return true
	if not sim.seal_done and sim.mob_count() < 2 and sim.legal_spawn("swarm", "%s:flank" % ahead) == "":
		sim.submit("spawn", {"unit": "swarm", "node": "%s:flank" % ahead}, "demon", 1)
		return true
	return false


func _spend_excess() -> void:
	var node := _ahead_node()
	if node == "":
		return
	if sim.legal_trap("snare", node) == "":
		sim.submit("trap", {"kind": "snare", "node": node}, "demon", 1)
		return
	var room := node.split(":")[0]
	if sim.seal_done:
		return
	if sim.legal_spawn("swarm", "%s:rear" % room) == "":
		sim.submit("spawn", {"unit": "swarm", "node": "%s:rear" % room}, "demon", 1)


func _reserve() -> int:
	if _objective_threatened():
		return 0
	if sim.stage_reached >= 2:
		return 800
	return 1800


func _objective_threatened() -> bool:
	var room := str(sim.party_room())
	if room == "throne" or _kind(room) == "throne":
		return true
	var stake := _wanted_stake()
	if stake == "":
		return false
	if room == stake:
		return true
	var info = sim.map.by_id.get(room, {})
	if info.is_empty():
		return false
	if bool(info.corridor) and info.neighbors.has(stake):
		return true
	return false


func _combat_room() -> String:
	var id := str(sim.party_room())
	var room = sim.map.by_id.get(id, {})
	if room.is_empty():
		return ""
	if not room.corridor and room.nodes.size() > 0 and str(room.kind) != "fork":
		return id
	for n in room.neighbors:
		var other = sim.map.by_id.get(n, {})
		if other.is_empty() or other.corridor:
			continue
		if int(other.depth) >= int(room.depth) and str(other.kind) != "fork":
			return str(other.id)
	return ""


func _ahead_node() -> String:
	var room := _combat_room()
	if room == "" or room == str(sim.party_room()):
		room = _next_content_room()
	if room == "":
		return ""
	for key in ["choke", "center", "flank", "rear"]:
		var node := "%s:%s" % [room, key]
		if sim.map.node_tile(node).x < 0:
			continue
		if not sim.node_occupied_by_trap(node):
			return node
	return ""


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
			seen[nid] = true
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
