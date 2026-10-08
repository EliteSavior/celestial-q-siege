extends RefCounted
## A competent, non-cheating angel policy used to prove the lab is winnable.
## It only submits the same commands a player can.

var step := 0
var plan := [
	"fork", "summoned", "cross", "seal",
	"fork2", "summoned2", "cross2", "font",
	"fork3", "summoned3", "cross3", "altar",
	"throne",
]
var pulsed := {}


func act(sim) -> void:
	if sim.outcome != "":
		return
	if sim.tick % 5 != 0:
		return
	_stance(sim)
	_defense(sim)
	_offense(sim)
	_move(sim)


func _stance(sim) -> void:
	var desired: int = CombatSim.STANCE_TIGHT
	var room: String = str(sim.party_room())
	var info: Dictionary = sim.map.by_id.get(room, {})
	var corridor: bool = bool(info.get("corridor", false))
	var tg: Dictionary = sim.telegraph
	if not tg.is_empty() and str(tg.get("name", "")) in ["hell_rain", "cleave"]:
		desired = CombatSim.STANCE_SPREAD
	elif corridor and sim.phase != "lucifer":
		desired = CombatSim.STANCE_COLUMN
	elif sim.phase == "lucifer":
		desired = CombatSim.STANCE_TIGHT
	elif sim.elite_alive() or sim.mob_count() >= 3:
		desired = CombatSim.STANCE_SPREAD
	if desired != sim.stance:
		sim.submit("stance", {"stance": desired})


func _defense(sim) -> void:
	var tg: Dictionary = sim.telegraph
	if not tg.is_empty():
		var name := str(tg.get("name", ""))
		var remain: int = int(tg.get("until", 0)) - int(sim.tick)
		if name == "hell_rain" and remain <= 22:
			sim.submit("scatter", {})
		elif name == "cleave" and remain <= 28:
			sim.submit("scatter", {})
		elif name == "grasp" and remain <= 22:
			sim.submit("phalanx", {})
		if name in ["judgment", "cleave", "grasp"]:
			sim.submit("shield", {})
		if name == "judgment" and remain <= 18:
			sim.submit("phalanx", {})
	if _elite_blinking(sim):
		sim.submit("ability", {"name": "taunt"})
		sim.submit("phalanx", {})
	if _debuffed(sim):
		sim.submit("cleanse", {})
	if sim.lowest_angel_hp_pct() < 80 or sim._dead_count() > 0:
		sim.submit("heal", {})
	var raphael: Dictionary = sim._hero("raphael")
	if sim._dead_count() > 0 and not raphael.is_empty() and raphael.alive and sim.golden >= 6000:
		sim.submit("ability", {"name": "slow_revive"})
	if sim._dead_count() > 0 and sim.golden >= 8000:
		sim.submit("ability", {"name": "emergency_res"})
	var room := str(sim.party_room())
	if not pulsed.has(room) and sim.golden >= 5500:
		var preview: Dictionary = sim.preview("detect")
		if str(preview.ability) == "disarm" or sim.golden >= 6500:
			sim.submit("detect", {})
			pulsed[room] = true
	elif str(sim.preview("detect").ability) == "disarm":
		sim.submit("detect", {})


func _offense(sim) -> void:
	var focus := _focus_id(sim)
	if focus != 0 and focus != sim.focus_id:
		sim.submit("focus", {"id": focus})
	if focus == 0:
		return
	if sim.golden >= 6000 or (sim.golden >= 4000 and sim.lowest_angel_hp_pct() > 75):
		sim.submit("burst", {})


func _move(sim) -> void:
	if sim.phase == "lucifer":
		return
	var room := str(sim.party_room())
	var info: Dictionary = sim.map.by_id.get(room, {})
	var corridor: bool = bool(info.get("corridor", false))
	if sim._hostiles_in_room(room) > 0 and not corridor:
		if bool(sim.channeling_altar):
			sim.submit("stop_channel", {})
		# Drop the march. A path already in flight would otherwise walk through the fight.
		sim.submit("move_tile", {"tile": Fixed.tile_of(sim.anchor)})
		return
	var stake := _stake_here(sim)
	if stake != "" and not _stake_done(sim, stake):
		var node: Vector2i = sim.map.node_tile("%s:rear" % stake)
		if Fixed.dist(sim.anchor, Fixed.tile_center(node)) > 1100:
			sim.submit("move_tile", {"tile": node})
		else:
			sim.submit("channel_altar", {})
		return
	var goal := _goal(sim)
	if goal != "" and goal != room:
		sim.submit("move_room", {"room": goal})


func _goal(sim) -> String:
	while step < plan.size() - 1 and _reached(sim, str(plan[step])):
		step += 1
	return str(plan[step])


func _stake_here(sim) -> String:
	var room := str(sim.party_room())
	var kind := str(sim.map.by_id.get(room, {}).get("kind", ""))
	if kind in ["seal", "font", "altar"]:
		return room
	return ""


func _stake_done(sim, id: String) -> bool:
	match id:
		"seal":
			return bool(sim.seal_done)
		"font":
			return bool(sim.font_done)
		"altar":
			return bool(sim.altar_done)
		_:
			return true


func _reached(sim, room: String) -> bool:
	var info: Dictionary = sim.map.by_id.get(room, {})
	var kind := str(info.get("kind", ""))
	if kind == "fork":
		return bool(sim.visited.get(room, false))
	if kind in ["trapped", "summoned", "cursed", "cross"]:
		if bool(sim.cleared.get(room, false)):
			return true
		if str(sim.party_room()) == room and sim._hostiles_in_room(room) == 0:
			return true
		return _visited_later(sim, room)
	if kind == "seal":
		return bool(sim.seal_done)
	if kind == "font":
		return bool(sim.font_done)
	if kind == "altar":
		return bool(sim.altar_done)
	return false


func _visited_later(sim, room: String) -> bool:
	var seen := false
	for p in plan:
		if str(p) == room:
			seen = true
			continue
		if seen and bool(sim.visited.get(p, false)):
			return true
	return false


func _focus_id(sim) -> int:
	var best_id := 0
	var best_score := -1
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if not bool(e.alive) or str(e.team) != "demon":
			continue
		var score := 10
		if str(e.subtype) == "elite":
			score = 100
		elif str(e.subtype) == "lucifer":
			score = 90
		elif str(e.subtype) == "heavy":
			score = 40
		elif str(e.subtype) == "imp":
			score = 20
		score = score * 1000 - int(e.hp)
		if score > best_score:
			best_score = score
			best_id = int(e.id)
	return best_id


func _focus_low(sim, id: int) -> bool:
	var e: Dictionary = sim.entities.get(id, {})
	if e.is_empty() or not bool(e.alive):
		return false
	return int(e.hp) * 100 / maxi(int(e.hp_max), 1) < 45


func _debuffed(sim) -> bool:
	for a in sim._angels():
		if not a.alive:
			continue
		if int(a.silence_until) > sim.tick or int(a.rot_until) > sim.tick or int(a.mark_until) > sim.tick:
			return true
	return false


func _elite_blinking(sim) -> bool:
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.subtype) == "elite" and e.alive and e.blink is Dictionary and not e.blink.is_empty():
			return true
	return false
