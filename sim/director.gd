class_name DemonDirector
extends RefCounted
## Budget director. Priority: Survive, Protect the stake, Exploit the
## stance, Spend excess Dark. The same commands a human demon will send.
## Marches spend the bank down so the finale echo is what the siege
## actually paid for, not the cap.

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


func setup(s) -> void:
	sim = s


func on_tick() -> void:
	if sim.phase == "lucifer":
		_press_boss()
		return
	if sim.phase != "dungeon" or descended:
		return
	# The room garrison is on the sim clock, not the decision gap. A 1.8s
	# gap used to sit on top of the commit delay, and an off-screen pack
	# could fill the cap before the party ever saw a mob.
	_arm_branch_plan()
	_fire_current_room()
	if sim.tick < next_decision:
		return
	next_decision = sim.tick + _gap()
	if _survive():
		return
	# Hold other purchases until this room's garrison exists. Spending
	# the decision on the Gate Seal used to log a swarm the fog hides.
	var here := str(sim.party_room())
	if committed.has(here) and not resolved.has(here):
		last_priority = "protect"
		return
	if _fire_committed():
		last_priority = "protect"
		return
	if _run_opening():
		last_priority = "protect"
		return
	if _protect():
		last_priority = "protect"
		return
	# Above the march line, excess Dark is spent before the next punish.
	# A cooldown must not be a hole the bank refills through.
	if _marching() and sim.dark > _vent_line() and _vent(6):
		last_priority = "spend"
		return
	# Exploit wins the decision. While that punish is on cooldown the
	# overflow still gets spent, or a long march refills the cap.
	if sim.tick >= pressure_lock and _exploit():
		var hold := 160
		if sim.stage_reached == 1:
			hold = 100
		elif sim.stage_reached >= 2:
			hold = 70
		pressure_lock = sim.tick + hold
		last_priority = "exploit"
		return
	if sim.dark > _vent_line() and _vent(8 if _marching() else 2):
		last_priority = "spend"
		return


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


func _survive() -> bool:
	if _maybe_descend():
		last_priority = "survive"
		return true
	return false


func _maybe_descend() -> bool:
	var room := str(sim.party_room())
	if room == "throne":
		_do_descend(false)
		return true
	# Early-descent gamble. The sanctum is open and the altar revive is not
	# banked, but the party is already hurt. Arrive now, spend less Dark,
	# and accept a weaker Lucifer plus a thinner echo.
	if _early_room(room) and sim.stage_reached >= 2 and not sim.altar_done and sim.party_hp_pct() <= 48 and sim.dark >= 2500 and sim.rooms_cleared >= Balance.ELITE_ROOMS:
		_do_descend(true)
		return true
	# The same lever, taken in panic: a party about to break is not worth
	# the rest of the crawl, even if the altar is already claimed.
	if _early_room(room) and sim.stage_reached >= 2 and sim.party_hp_pct() < 32 and sim.dark >= 3000 and sim.rooms_cleared >= Balance.ELITE_ROOMS:
		_do_descend(true)
		return true
	return false


func _early_room(room: String) -> bool:
	return room in ["altar", "gallery3", "cross3", "fork3", "summoned3"]


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
	if not sim.can_read("trapped"):
		return false
	var pieces: Array = [
		{"kind": "spike", "node": "trapped:choke"},
		{"kind": "snare", "node": "trapped:center"},
	]
	var why := sim.legal_commit({"plan": "trap_cluster", "pieces": pieces})
	if why == "":
		sim.submit("commit", {"plan": "trap_cluster", "pieces": pieces}, "demon", 1)
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
		sim.debug_line("plan %s in %s at tick %d" % [kind, room, int(committed[room])])


## Seconds until the party's current room pays its committed plan. -1 if none.
func next_spawn_in() -> int:
	var room := str(sim.party_room())
	if not committed.has(room) or resolved.has(room):
		return -1
	return maxi(0, int(committed[room]) - sim.tick)


func _fire_current_room() -> void:
	var room := str(sim.party_room())
	if not committed.has(room) or resolved.has(room):
		return
	if sim.tick < int(committed[room]):
		return
	_fire_one(room, true)


func _fire_committed() -> bool:
	var keys: Array = committed.keys()
	keys.sort()
	for room in keys:
		if resolved.has(str(room)):
			continue
		if sim.tick < int(committed[room]):
			continue
		var here := str(room) == str(sim.party_room())
		var state := _fire_one(str(room), here)
		if state == "waiting":
			return true
		return true
	return false


func _fire_one(room: String, in_room: bool) -> String:
	if resolved.has(room):
		return "done"
	var kind := _kind(room)
	var fired := false
	var waiting := false
	if kind == "summoned" or kind == "gallery":
		var spawned := _spawn_into(room, in_room)
		if spawned == "wait":
			waiting = true
		else:
			fired = true
	elif kind == "cursed":
		var curse := "silence"
		var target := "raphael"
		if sim.curses_cast % 4 == 3:
			curse = "weaken"
			target = "azrael"
		elif sim.stance == STANCE_SPREAD:
			curse = "mark"
		elif sim.angel_hp_pct("raphael") < 45:
			curse = "rot"
			target = sim.lowest_angel_subtype()
		var why := sim.legal_curse(curse, target)
		if why == "":
			sim.submit("curse", {"kind": curse, "target": target}, "demon", 1)
			sim.debug_line("buy %s on %s in %s" % [curse, target, room])
			fired = true
		elif why == "dark":
			waiting = true
		else:
			fired = true
	elif kind == "trapped":
		if sim.traps_in_room(room) >= Balance.TRAP_CAP_PER_ROOM:
			fired = true
		elif sim.can_read(room) and sim.traps_in_room(room) == 0:
			var pieces: Array = [
				{"kind": "spike", "node": "%s:choke" % room},
				{"kind": "hellflame", "node": "%s:center" % room},
			]
			var why_c := sim.legal_commit({"plan": "trap_cluster", "pieces": pieces})
			if why_c == "":
				sim.submit("commit", {"plan": "trap_cluster", "pieces": pieces}, "demon", 1)
				sim.debug_line("buy trap cluster in %s" % room)
				fired = true
			elif why_c == "dark" or why_c == "busy":
				waiting = true
			else:
				fired = _place_one_trap(room)
		else:
			fired = _place_one_trap(room)
			if not fired and sim.legal_trap("hellflame", "%s:flank" % room) == "dark":
				waiting = true
				fired = false
	else:
		fired = true
	if waiting:
		sim.debug_line("wait on %s (%s), dark %d" % [room, kind, sim.dark])
		return "waiting"
	resolved[room] = true
	return "fired" if fired else "skip"


func _spawn_into(room: String, in_room: bool) -> String:
	var unit := "heavy" if Balance.tier_ok("heavy", sim.rooms_cleared) else "swarm"
	if unit == "swarm" and sim.seal_done:
		unit = "heavy"
	var node := "%s:center" % room
	var garrison := in_room and _homed(room) == 0
	var reason := sim.legal_spawn(unit, node, garrison)
	if reason == "":
		sim.submit("spawn", {"unit": unit, "node": node, "garrison": garrison}, "demon", 1)
		sim.debug_line("buy %s at %s (%s)" % [unit, node, "garrison" if garrison else "paid"])
		return "fired"
	if reason == "dark":
		return "wait"
	if reason == "tier" and unit == "heavy":
		var fallback := sim.legal_spawn("swarm", node, garrison)
		if fallback == "" and not sim.seal_done:
			sim.submit("spawn", {"unit": "swarm", "node": node, "garrison": garrison}, "demon", 1)
			sim.debug_line("buy swarm at %s (heavy gated)" % node)
			return "fired"
		if fallback == "dark":
			return "wait"
	return "skip"


func _place_one_trap(room: String) -> bool:
	var trap_node := "%s:flank" % room
	var why2 := sim.legal_trap("hellflame", trap_node)
	if why2 == "":
		sim.submit("trap", {"kind": "hellflame", "node": trap_node}, "demon", 1)
		return true
	if why2 == "dark":
		return false
	return true


func _protect() -> bool:
	var stake := _wanted_stake()
	if stake == "" or fortified.has(stake):
		return false
	# The fork used to fortify the Gate Seal the moment it was visited.
	# That swarm logged "Imps claw their way in" from a room the fog does
	# not show, then a second pack filled the cap before the first fight.
	if _lobby() and str(sim.party_room()) != stake:
		return false
	if fortify_stake != stake:
		fortify_stake = stake
		fortify_step = 0
	var unit := _defender(stake)
	if fortify_step == 0:
		if unit == "elite":
			if not sim.can_read(stake):
				return false
			if sim.elite_alive() or sim.commitment_open("elite"):
				fortify_step = 1
			else:
				var node := "%s:rear" % stake
				var why := sim.legal_commit({"plan": "elite", "node": node})
				if why == "":
					sim.submit("commit", {"plan": "elite", "node": node}, "demon", 1)
					fortify_step = 1
					return true
				if why == "dark" or why == "busy":
					return true
				fortify_step = 1
		else:
			var node2 := "%s:%s" % [stake, "rear" if stake == "altar" else "center"]
			var reason := sim.legal_spawn(unit, node2)
			if reason == "":
				sim.submit("spawn", {"unit": unit, "node": node2}, "demon", 1)
				fortify_step = 1
				return true
			if reason == "dark":
				return true
			if reason == "tier":
				return false
			fortify_step = 1
	if fortify_step == 1 and unit == "elite" and sim.commitment_open("elite") and not sim.elite_alive():
		return true
	if fortify_step == 1:
		var trap := "spike" if stake == "seal" else "hellflame"
		var choke := "%s:choke" % stake
		var why3 := sim.legal_trap(trap, choke)
		if why3 == "":
			sim.submit("trap", {"kind": trap, "node": choke}, "demon", 1)
			fortified[stake] = true
			return true
		if why3 == "dark":
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
	if _exploit_weakness():
		return true
	if sim.mob_count() >= Balance.MOB_CAP:
		return false
	return _reinforce_ahead(0)


func _exploit_weakness() -> bool:
	if sim.curse_pending_or_active():
		return false
	var stance: int = sim.stance
	if stance == STANCE_SPREAD and not _lobby() and sim.legal_curse("mark", "raphael") == "" and _can_pay(Balance.curse_cost("mark"), 0):
		sim.submit("curse", {"kind": "mark", "target": "raphael"}, "demon", 1)
		return true
	if stance == STANCE_TIGHT:
		var node := _ahead_node()
		if node != "" and sim.legal_trap("hellflame", node) == "" and _can_pay(Balance.trap_cost("hellflame"), 0):
			sim.submit("trap", {"kind": "hellflame", "node": node}, "demon", 1)
			return true
	if stance == STANCE_COLUMN:
		var node2 := _ahead_node()
		if node2 != "" and sim.legal_trap("spike", node2) == "" and _can_pay(Balance.trap_cost("spike"), 0):
			sim.submit("trap", {"kind": "spike", "node": node2}, "demon", 1)
			return true
		if node2 != "" and sim.legal_trap("snare", node2) == "" and _can_pay(Balance.trap_cost("snare"), 0):
			sim.submit("trap", {"kind": "snare", "node": node2}, "demon", 1)
			return true
	if sim.lowest_angel_hp_pct() < 48 and sim.stage_reached >= 1:
		var who: String = sim.lowest_angel_subtype()
		if sim.legal_curse("rot", who) == "" and _can_pay(Balance.curse_cost("rot"), 0):
			sim.submit("curse", {"kind": "rot", "target": who}, "demon", 1)
			return true
	return false


func _vent(limit: int) -> bool:
	var reserved := 0
	var blocked := {"spawn": false, "trap": false, "curse": false}
	var used_nodes := {}
	var did := false
	for _i in limit:
		if sim.dark - reserved <= _vent_line():
			break
		var order := _spend_order()
		var progressed := false
		for kind in order:
			if bool(blocked[kind]):
				continue
			var cost := 0
			if kind == "spawn":
				cost = _try_spawn(reserved)
			elif kind == "trap":
				cost = _try_trap(reserved, used_nodes)
			else:
				cost = _try_curse(reserved)
			if cost > 0:
				reserved += cost
				did = true
				progressed = true
				blocked[kind] = true
				break
			blocked[kind] = true
		if not progressed:
			break
	return did


func _try_spawn(reserved: int) -> int:
	# Do not pre-seed the next branch while the party is still in the opening.
	if _lobby():
		return 0
	var room := _next_content_room()
	if room == "" or room == str(sim.party_room()):
		return 0
	if _kind(room) in ["throne", "fork", "start", "seal", "font", "altar"]:
		return 0
	if _homed(room) > 0:
		return 0
	var unit := "swarm"
	if Balance.tier_ok("heavy", sim.rooms_cleared):
		unit = "heavy"
	elif sim.seal_done:
		return 0
	var node := "%s:center" % room
	if sim.map.node_tile(node).x < 0:
		return 0
	if sim.legal_spawn(unit, node) != "":
		if unit == "heavy" and not sim.seal_done and sim.legal_spawn("swarm", node) == "":
			unit = "swarm"
		else:
			return 0
	var cost := Balance.summon_cost(unit)
	if not _can_pay(cost, reserved):
		return 0
	sim.submit("spawn", {"unit": unit, "node": node}, "demon", 1)
	return cost


func _reinforce_ahead(reserved: int) -> bool:
	return _try_spawn(reserved) > 0


func _try_trap(reserved: int, used_nodes: Dictionary) -> int:
	var node := _ahead_trap_node(used_nodes)
	if node == "":
		return 0
	var room := node.split(":")[0]
	var info = sim.map.by_id.get(room, {})
	var corridor := false
	if not info.is_empty():
		corridor = bool(info.get("corridor", false))
	var kind := "spike"
	if corridor:
		kind = "snare" if sim.traps_placed % 3 == 2 else "spike"
	else:
		var kinds := ["spike", "snare", "hellflame"]
		kind = str(kinds[sim.traps_placed % 3])
	if sim.legal_trap(kind, node) != "":
		kind = "spike"
		if sim.legal_trap(kind, node) != "":
			return 0
	var queued := 0
	for used in used_nodes.keys():
		if str(used).begins_with(room + ":"):
			queued += 1
	if sim.traps_in_room(room) + queued >= Balance.TRAP_CAP_PER_ROOM:
		return 0
	var cost := Balance.trap_cost(kind)
	if not _can_pay(cost, reserved):
		return 0
	sim.submit("trap", {"kind": kind, "node": node}, "demon", 1)
	used_nodes[node] = true
	return cost


## The antechamber, the fork, and the halls that lead into the first
## branch are not a fight yet. The east door is depth 1, so max_depth
## alone used to end the lobby in that hall and drop a swarm on the
## Gate Seal — logged, fogged, and invisible.
func _lobby() -> bool:
	if sim.phase == "lucifer":
		return false
	if sim.stage_reached > 0 or sim.rooms_cleared > 0 or sim.seal_done:
		return false
	var kind := _kind(str(sim.party_room()))
	if kind in ["summoned", "cursed", "trapped", "gallery"]:
		return false
	return true


func _try_curse(reserved: int) -> int:
	if _lobby():
		return 0
	if sim._curse_casting() or sim._command_pending("curse"):
		return 0
	# Prefer a hero who is clean. Refresh Rot or Mark when the bank is
	# still over the line — Silence is not refreshed, so it cannot stick.
	var fresh: Array = []
	var refresh: Array = []
	if int(sim._hero("michael").get("rot_until", 0)) <= sim.tick:
		fresh.append(["rot", "michael"])
	else:
		refresh.append(["rot", "michael"])
	if int(sim._hero("uriel").get("mark_until", 0)) <= sim.tick:
		fresh.append(["mark", "uriel"])
	else:
		refresh.append(["mark", "uriel"])
	if sim.tick >= silence_lock and int(sim._hero("azrael").get("silence_until", 0)) <= sim.tick:
		fresh.append(["silence", "azrael"])
	var options: Array = []
	# Every fourth curse leads with Weaken. Otherwise it is the fallback
	# when Silence, Rot, and Mark cannot be paid.
	if sim.curses_cast % 4 == 3:
		options.append(["weaken", "azrael"])
	options.append_array(fresh)
	options.append_array(refresh)
	options.append(["weaken", "uriel"])
	# Michael, Uriel, and Azrael are the named targets. When all three are
	# dead the vent used to stop, and a healer standing outside leash never
	# died. Fall back to whoever is still up.
	var named_ok := false
	for opt in options:
		if sim.legal_curse(str(opt[0]), str(opt[1])) == "":
			named_ok = true
			break
	if not named_ok:
		var last := sim.lowest_angel_subtype()
		if last != "":
			options.append(["rot", last])
	for opt in options:
		var curse := str(opt[0])
		var who := str(opt[1])
		var cost := Balance.curse_cost(curse)
		if not _can_pay(cost, reserved):
			continue
		if sim.legal_curse(curse, who) != "":
			continue
		sim.submit("curse", {"kind": curse, "target": who}, "demon", 1)
		if curse == "silence":
			silence_lock = sim.tick + 220
		return cost
	return 0


func _spend_order() -> Array:
	var rows: Array = [
		["curse", sim.curses_cast],
		["spawn", sim.spawns_placed],
		["trap", sim.traps_placed],
	]
	rows.sort_custom(func(a, b):
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		return str(a[0]) < str(b[0])
	)
	var out: Array = []
	for row in rows:
		out.append(str(row[0]))
	return out


func _vent_line() -> int:
	var line := _reserve()
	if _marching():
		var idx := clampi(sim.stage_reached, 0, Balance.MARCH_BANK.size() - 1)
		line = maxi(line, int(Balance.MARCH_BANK[idx]))
	else:
		line = maxi(line, 8500 if sim.stage_reached <= 0 else 7800)
	return line


func _can_pay(cost: int, reserved: int) -> bool:
	return sim.dark - reserved - cost >= _reserve()


func _reserve() -> int:
	if _objective_threatened():
		return 0
	if _elite_still_to_buy():
		return Balance.summon_cost("elite")
	if not sim.font_done and not fortified.has("font") and sim.stage_reached >= 1 and Balance.tier_ok("heavy", sim.rooms_cleared):
		return Balance.summon_cost("heavy")
	if sim.stage_reached >= 2:
		return 600
	return 1500


func _elite_still_to_buy() -> bool:
	if sim.altar_done or fortified.has("altar"):
		return false
	if sim.stage_reached < 2 or not Balance.tier_ok("elite", sim.rooms_cleared):
		return false
	if sim.elite_alive() or sim.commitment_open("elite"):
		return false
	return true


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


func _homed(room: String) -> int:
	var n := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if bool(e.get("alive", false)) and str(e.get("kind", "")) == "mob" and str(e.get("home", "")) == room:
			n += 1
	return n


func _ahead_node() -> String:
	return _ahead_trap_node({})


func _ahead_trap_node(used_nodes: Dictionary) -> String:
	var start := str(sim.party_room())
	var queue: Array = [start]
	var seen := {start: true}
	var qi := 0
	var steps := 0
	while qi < queue.size() and steps < 16:
		var cur: String = str(queue[qi])
		qi += 1
		steps += 1
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
			if nid != start and _kind(nid) not in ["fork", "start", "seal", "font", "altar", "throne"]:
				var picked := _open_node(nid, used_nodes)
				if picked != "":
					return picked
			if other.corridor or _kind(nid) in ["gallery", "cross", "trapped", "summoned", "cursed"]:
				queue.append(nid)
	return ""


func _open_node(room_id: String, used_nodes: Dictionary) -> String:
	var queued := 0
	for used in used_nodes.keys():
		if str(used).begins_with(room_id + ":"):
			queued += 1
	if sim.traps_in_room(room_id) + queued >= Balance.TRAP_CAP_PER_ROOM:
		return ""
	var keys: Array = sim.map.node_keys(room_id)
	for key in keys:
		var node := str(key)
		if used_nodes.has(node):
			continue
		if sim.legal_trap("spike", node) == "" or sim.legal_trap("snare", node) == "" or sim.legal_trap("hellflame", node) == "":
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
