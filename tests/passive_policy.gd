extends RefCounted
## Walks the short road and auto-attacks. No kit, no stakes, no tells.
## Used to show the siege is not won by marching alone.


var step := 0
var plan := [
	"fork", "trapped", "cross", "seal",
	"fork2", "trapped2", "cross2", "font",
	"fork3", "trapped3", "cross3", "altar",
	"throne",
]


func act(sim) -> void:
	if sim.outcome != "":
		return
	if sim.tick % 10 != 0:
		return
	if sim.phase == "lucifer":
		return
	var room := str(sim.party_room())
	var info: Dictionary = sim.map.by_id.get(room, {})
	if sim._hostiles_in_room(room) > 0 and not bool(info.get("corridor", false)):
		var joined := false
		for id in sim.order:
			var e: Dictionary = sim.entities[id]
			if str(e.get("kind", "")) == "mob" and bool(e.get("alive", false)) and bool(e.get("pulled", false)):
				joined = true
				break
		var center: Vector2i = sim.map.node_tile("%s:center" % room)
		if not joined and center != Vector2i.ZERO and Fixed.tile_of(sim.anchor) != center:
			sim.submit("move_tile", {"tile": center})
		else:
			sim.submit("move_tile", {"tile": Fixed.tile_of(sim.anchor)})
		return
	var goal := _goal(sim)
	if goal != "" and goal != room:
		sim.submit("move_room", {"room": goal})


func _goal(sim) -> String:
	while step < plan.size() - 1 and _reached(sim, str(plan[step])):
		step += 1
	return str(plan[step])


func _reached(sim, room: String) -> bool:
	var info: Dictionary = sim.map.by_id.get(room, {})
	var kind := str(info.get("kind", ""))
	if kind == "fork" or kind in ["seal", "font", "altar"]:
		return bool(sim.visited.get(room, false))
	if kind in ["trapped", "summoned", "cursed", "cross", "gallery"]:
		if bool(sim.cleared.get(room, false)):
			return true
		if str(sim.party_room()) == room and sim._hostiles_in_room(room) == 0:
			return true
		return _visited_later(sim, room)
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
