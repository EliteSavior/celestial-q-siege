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
# Knobs for a slower human policy. Defaults match the scripted competent run.
var act_every := 5
var react_remain := 40
var heal_below := 80
var burst_at := 5000
# Loose bursts once a Mend would still fit behind the nuke. 1.0.3 waited
# until 4000 of a 0–10 meter (shown as 4.0), which was most of a Burst.
var burst_loose_at := 2800
var burst_loose := true
var pre_shield := true
# The sim no longer cooldowns elixir rites. This policy still refuses to
# mash the same rite every decision, or a channel never finishes and the
# bar never recovers. It is play, not a rule.
var _cast_at := {}


func act(sim) -> void:
	if sim.outcome != "":
		return
	if sim.tick % act_every != 0:
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
		if name == "hell_rain" and remain <= react_remain:
			sim.submit("scatter", {})
		elif name == "cleave" and remain <= react_remain:
			sim.submit("scatter", {})
			if pre_shield:
				_cast_ability(sim, "shield_wall", 80)
		elif name == "grasp" and remain <= react_remain:
			sim.submit("phalanx", {})
		if name == "judgment":
			_cast_ability(sim, "body_block", 60)
			_cast_cmd(sim, "shield", 80)
			if remain <= react_remain - 10:
				sim.submit("phalanx", {})
		elif pre_shield and name in ["cleave", "grasp"]:
			_cast_cmd(sim, "shield", 80)
	for commit in sim._visible_commitments():
		var plan := str(commit.get("plan", ""))
		var remain: int = int(commit.get("land", 0)) - int(sim.tick)
		if plan == "elite" and remain <= react_remain + 30:
			_cast_ability(sim, "taunt", 80)
			sim.submit("phalanx", {})
		elif plan == "trap_cluster":
			_cast_cmd(sim, "detect", 80)
			_cast_ability(sim, "shield_wall", 80)
	if _elite_blinking(sim):
		_cast_ability(sim, "taunt", 80)
		sim.submit("phalanx", {})
	if _debuffed(sim):
		_cast_cmd(sim, "cleanse", 40)
	if sim.lowest_angel_hp_pct() < heal_below or sim._downed_count() > 0:
		_cast_cmd(sim, "heal", 40)
	var raphael: Dictionary = sim._hero("raphael")
	if sim._downed_count() > 0 and not raphael.is_empty() and raphael.alive and raphael.casting.is_empty() and sim.golden >= Balance.cost("slow_revive"):
		_cast_ability(sim, "slow_revive", 80)
	elif sim._downed_count() > 0 and sim.golden >= Balance.cost("emergency_res"):
		_cast_ability(sim, "emergency_res", 80)
	var room := str(sim.party_room())
	if not pulsed.has(room) and sim.golden >= Balance.cost("detect_pulse") + Balance.cost("single_heal"):
		var preview: Dictionary = sim.preview("detect")
		if str(preview.ability) == "disarm" or sim.golden >= Balance.GOLDEN_START:
			_cast_cmd(sim, "detect", 20)
			pulsed[room] = true
	elif str(sim.preview("detect").ability) == "disarm":
		_cast_cmd(sim, "detect", 20)


func _offense(sim) -> void:
	var focus := _focus_id(sim)
	if focus != 0 and focus != sim.focus_id:
		sim.submit("focus", {"id": focus})
	if focus == 0:
		return
	# While someone is still in the downed window, keep enough Golden for a slow revive.
	if sim._downed_count() > 0 and sim.golden < Balance.cost("slow_revive") + Balance.cost("burst"):
		return
	if sim.golden >= burst_at or (burst_loose and sim.golden >= burst_loose_at and sim.lowest_angel_hp_pct() > 75):
		_cast_cmd(sim, "burst", 80)


func _cast_ability(sim, ability: String, gap: int) -> void:
	if sim.tick - int(_cast_at.get(ability, -9999)) < gap:
		return
	if sim.golden < Balance.cost(ability):
		return
	var status: Dictionary = sim.ability_status(ability)
	if not bool(status.get("ready", false)):
		return
	_cast_at[ability] = sim.tick
	sim.submit("ability", {"name": ability})


func _cast_cmd(sim, cmd: String, gap: int) -> void:
	if sim.tick - int(_cast_at.get(cmd, -9999)) < gap:
		return
	var ability := str(sim.preview(cmd).get("ability", ""))
	if ability == "" or sim.golden < Balance.cost(ability):
		return
	var status: Dictionary = sim.ability_status(ability)
	if not bool(status.get("ready", false)):
		return
	_cast_at[cmd] = sim.tick
	sim.submit(cmd, {})


func _move(sim) -> void:
	if sim.phase == "lucifer":
		return
	var room := str(sim.party_room())
	var info: Dictionary = sim.map.by_id.get(room, {})
	var corridor: bool = bool(info.get("corridor", false))
	if sim._hostiles_in_room(room) > 0 and not corridor:
		if bool(sim.channeling_altar):
			sim.submit("stop_channel", {})
		# A garrison across a large room is past leash from the door, so it
		# does not pull until the squad walks in. Hold only once the fight
		# is actually joined. Otherwise close to the center.
		if _fight_joined(sim):
			sim.submit("move_tile", {"tile": Fixed.tile_of(sim.anchor)})
			return
		var center: Vector2i = sim.map.node_tile("%s:center" % room)
		if center != Vector2i.ZERO and Fixed.tile_of(sim.anchor) != center:
			sim.submit("move_tile", {"tile": center})
			return
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


func _fight_joined(sim) -> bool:
	var room := str(sim.party_room())
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.get("kind", "")) != "mob" or not bool(e.get("alive", false)):
			continue
		var here: bool = str(sim.map.id_at_tile(Fixed.tile_of(e.pos))) == room
		var spawning: bool = str(e.get("home", "")) == room and int(e.get("active_at", 0)) > int(sim.tick)
		if not here and not spawning:
			continue
		if bool(e.get("pulled", false)):
			return true
		for angel in sim._angels():
			if bool(angel.alive) and Fixed.dist(angel.pos, e.pos) <= Balance.LEASH_RANGE:
				return true
	return false


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
		if int(a.silence_until) > sim.tick or int(a.rot_until) > sim.tick or int(a.mark_until) > sim.tick or int(a.get("weaken_until", 0)) > sim.tick:
			return true
	return false


func _elite_blinking(sim) -> bool:
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.get("subtype", "")) != "elite" or not bool(e.get("alive", false)):
			continue
		var blink = e.get("blink", {})
		if blink is Dictionary and not blink.is_empty():
			return true
	return false
