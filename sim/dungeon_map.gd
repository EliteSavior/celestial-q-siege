class_name DungeonMap
extends RefCounted
## One branching dungeon. Three forks differ: traps, summons, curses.
## They reconverge, then the altar (push objective) and Lucifer's throne.

var width := 108
var height := 48
var room_of := PackedInt32Array()
var walk := PackedByteArray()
var rooms: Array = []
var by_id := {}


func _init() -> void:
	room_of.resize(width * height)
	room_of.fill(-1)
	_add_room("start", "Antechamber", "start", Rect2i(2, 18, 14, 12), "S", 0, false)
	_add_room("fork", "The Fork", "fork", Rect2i(20, 14, 16, 16), "F", 0, false)
	_add_room("trapped", "Still Gallery", "trapped", Rect2i(20, 1, 16, 9), "T", 1, false)
	_add_room("cursed", "Whisper Chapel", "cursed", Rect2i(20, 34, 16, 9), "C", 1, false)
	_add_room("summoned", "Skittering Hall", "summoned", Rect2i(40, 16, 16, 12), "M", 1, false)
	_add_room("cross", "Crossroads", "cross", Rect2i(60, 16, 14, 12), "X", 2, false)
	_add_room("altar", "Reviving Altar", "altar", Rect2i(78, 14, 14, 16), "A", 3, false)
	_add_room("throne", "Throne", "throne", Rect2i(96, 14, 12, 16), "L", 4, false)
	_add_room("corr_sf", "Passage", "corridor", Rect2i(0, 0, 0, 0), "s", 0, true)
	_add_room("corr_ft", "North door", "corridor", Rect2i(0, 0, 0, 0), "t", 1, true)
	_add_room("corr_fc", "South door", "corridor", Rect2i(0, 0, 0, 0), "c", 1, true)
	_add_room("corr_fs", "East door", "corridor", Rect2i(0, 0, 0, 0), "m", 1, true)
	_add_room("corr_sc", "Passage", "corridor", Rect2i(0, 0, 0, 0), "x", 2, true)
	_add_room("corr_tc", "High hall", "corridor", Rect2i(0, 0, 0, 0), "h", 2, true)
	_add_room("corr_cc", "Low hall", "corridor", Rect2i(0, 0, 0, 0), "l", 2, true)
	_add_room("corr_ca", "Altar door", "corridor", Rect2i(0, 0, 0, 0), "a", 3, true)
	_add_room("corr_at", "Throne door", "corridor", Rect2i(0, 0, 0, 0), "r", 4, true)
	_carve_rect("start")
	_carve_rect("fork")
	_carve_rect("trapped")
	_carve_rect("cursed")
	_carve_rect("summoned")
	_carve_rect("cross")
	_carve_rect("altar")
	_carve_rect("throne")
	_carve_corridor("corr_sf", 16, 19, 22, 24)
	_carve_corridor("corr_ft", 26, 28, 10, 13)
	_carve_corridor("corr_fc", 26, 28, 30, 33)
	_carve_corridor("corr_fs", 36, 39, 20, 22)
	_carve_corridor("corr_sc", 56, 59, 20, 22)
	_carve_box("corr_tc", Rect2i(36, 3, 31, 3))
	_carve_box("corr_tc", Rect2i(64, 6, 3, 10))
	_carve_box("corr_cc", Rect2i(36, 37, 31, 3))
	_carve_box("corr_cc", Rect2i(64, 28, 3, 9))
	_carve_corridor("corr_ca", 74, 77, 20, 22)
	_carve_corridor("corr_at", 92, 95, 20, 22)
	_link("corr_sf", ["start", "fork"])
	_link("corr_ft", ["fork", "trapped"])
	_link("corr_fc", ["fork", "cursed"])
	_link("corr_fs", ["fork", "summoned"])
	_link("corr_sc", ["summoned", "cross"])
	_link("corr_tc", ["trapped", "cross"])
	_link("corr_cc", ["cursed", "cross"])
	_link("corr_ca", ["cross", "altar"])
	_link("corr_at", ["altar", "throne"])
	_place_nodes()
	_compute_exits()
	walk.resize(width * height)
	for i in room_of.size():
		walk[i] = 0 if int(room_of[i]) < 0 else 1


func _add_room(id: String, display: String, kind: String, rect: Rect2i, glyph: String, depth: int, corridor: bool) -> void:
	var room := {
		"id": id,
		"name": display,
		"kind": kind,
		"rect": rect,
		"glyph": glyph,
		"depth": depth,
		"corridor": corridor,
		"neighbors": [],
		"nodes": {},
		"exits": [],
		"hint": "",
	}
	if id == "trapped":
		room.hint = "Still air"
	elif id == "summoned":
		room.hint = "Skittering"
	elif id == "cursed":
		room.hint = "Whispers"
	by_id[id] = room
	rooms.append(room)


func _room_index(id: String) -> int:
	for i in rooms.size():
		if rooms[i].id == id:
			return i
	return -1


func _carve_rect(id: String) -> void:
	var room: Dictionary = by_id[id]
	var rect: Rect2i = room.rect
	var ri := _room_index(id)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			room_of[y * width + x] = ri


func _carve_corridor(id: String, x0: int, x1: int, y0: int, y1: int) -> void:
	_carve_box(id, Rect2i(mini(x0, x1), mini(y0, y1), absi(x1 - x0) + 1, absi(y1 - y0) + 1))


func _carve_box(id: String, rect: Rect2i) -> void:
	var ri := _room_index(id)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= width or y >= height:
				continue
			if int(room_of[y * width + x]) >= 0:
				continue
			room_of[y * width + x] = ri


func _link(corr: String, ends: Array) -> void:
	var c: Dictionary = by_id[corr]
	for e in ends:
		if not c.neighbors.has(e):
			c.neighbors.append(e)
		var r: Dictionary = by_id[e]
		if not r.neighbors.has(corr):
			r.neighbors.append(corr)


func _place_nodes() -> void:
	_nodes("trapped", {
		"choke": Vector2i(27, 8),
		"center": Vector2i(27, 5),
		"flank": Vector2i(32, 4),
		"rear": Vector2i(22, 3),
	})
	_nodes("cursed", {
		"choke": Vector2i(27, 35),
		"center": Vector2i(27, 38),
		"flank": Vector2i(32, 38),
		"rear": Vector2i(22, 40),
	})
	_nodes("summoned", {
		"choke": Vector2i(42, 21),
		"center": Vector2i(47, 21),
		"flank": Vector2i(47, 18),
		"rear": Vector2i(52, 21),
	})
	_nodes("cross", {
		"choke": Vector2i(62, 21),
		"center": Vector2i(66, 21),
		"flank": Vector2i(66, 18),
		"rear": Vector2i(70, 21),
	})
	_nodes("altar", {
		"choke": Vector2i(80, 21),
		"center": Vector2i(84, 21),
		"flank": Vector2i(84, 17),
		"rear": Vector2i(88, 21),
	})
	_nodes("throne", {
		"choke": Vector2i(98, 21),
		"center": Vector2i(102, 21),
		"flank": Vector2i(102, 17),
		"rear": Vector2i(105, 21),
	})
	_nodes("fork", {
		"center": Vector2i(27, 21),
		"choke": Vector2i(27, 16),
		"flank": Vector2i(32, 21),
		"rear": Vector2i(24, 26),
	})


func _nodes(id: String, nodes: Dictionary) -> void:
	by_id[id].nodes = nodes


func _compute_exits() -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for room in rooms:
		if room.corridor:
			continue
		var tiles_by_dest := {}
		var rect: Rect2i = room.rect
		var ri := _room_index(room.id)
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				if int(room_of[y * width + x]) != ri:
					continue
				var p := Vector2i(x, y)
				for d in dirs:
					var n: Vector2i = p + d
					var ni := at(n)
					if ni < 0:
						continue
					var nr: Dictionary = rooms[ni]
					if not nr.corridor:
						continue
					for other_id in nr.neighbors:
						if other_id == room.id:
							continue
						var other: Dictionary = by_id[other_id]
						if other.corridor:
							continue
						if not tiles_by_dest.has(other_id):
							tiles_by_dest[other_id] = []
						tiles_by_dest[other_id].append(p)
		var dest_ids: Array = tiles_by_dest.keys()
		dest_ids.sort()
		for dest_id in dest_ids:
			var tiles: Array = tiles_by_dest[dest_id]
			tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				if a.y != b.y:
					return a.y < b.y
				return a.x < b.x
			)
			var mid: Vector2i = tiles[tiles.size() / 2]
			var dest: Dictionary = by_id[dest_id]
			room.exits.append({
				"dest": dest_id,
				"tile": mid,
				"label": dest.name,
				"hint": dest.hint,
				"kind": dest.kind,
			})


func at(t: Vector2i) -> int:
	if t.x < 0 or t.y < 0 or t.x >= width or t.y >= height:
		return -1
	return int(room_of[t.y * width + t.x])


func room_at_tile(t: Vector2i) -> Dictionary:
	var i := at(t)
	if i < 0:
		return {}
	return rooms[i]


func id_at_tile(t: Vector2i) -> String:
	var r := room_at_tile(t)
	if r.is_empty():
		return ""
	return str(r.id)


func center_tile(id: String) -> Vector2i:
	var rect: Rect2i = by_id[id].rect
	if rect.size == Vector2i.ZERO:
		return Vector2i.ZERO
	return rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)


func node_tile(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	var room = by_id.get(parts[0], {})
	if room.is_empty():
		return Vector2i(-1, -1)
	if not room.nodes.has(parts[1]):
		return Vector2i(-1, -1)
	return room.nodes[parts[1]]


func node_keys(room_id: String) -> Array:
	var room = by_id.get(room_id, {})
	if room.is_empty():
		return []
	var keys: Array = []
	for n in room.nodes.keys():
		keys.append("%s:%s" % [room_id, n])
	keys.sort()
	return keys


func validate() -> Array:
	var errors: Array = []
	for room in rooms:
		if room.corridor:
			continue
		var center := center_tile(room.id)
		if at(center) < 0:
			errors.append("center off map %s" % room.id)
		for n in room.nodes.keys():
			var t: Vector2i = room.nodes[n]
			if id_at_tile(t) != room.id:
				errors.append("node %s:%s not in room (%s)" % [room.id, n, t])
		if room.exits.is_empty() and room.id != "start":
			errors.append("no exits %s" % room.id)
	var start := center_tile("start")
	for id in ["fork", "trapped", "summoned", "cursed", "cross", "altar", "throne"]:
		var path := Pathing.find(walk, width, height, start, center_tile(id), {})
		if path.is_empty():
			errors.append("no path start -> %s" % id)
	var fork_dests: Array = []
	for e in by_id["fork"].exits:
		fork_dests.append(e.dest)
	for need in ["trapped", "summoned", "cursed"]:
		if not fork_dests.has(need):
			errors.append("fork missing %s" % need)
	return errors


func ascii() -> String:
	var s := ""
	for y in height:
		for x in width:
			var i := int(room_of[y * width + x])
			if i < 0:
				s += "."
			else:
				s += str(rooms[i].glyph)
		s += "\n"
	return s
