class_name DungeonMap
extends RefCounted
## Three-stage siege. Each stage is a fork whose branches differ
## (trapped / summoned / cursed), a reconvergence, and a stake.
## Long marches between stages are where elixir actually compounds.
## Shortest path is the east (summoned) branch; the other two are real detours.

const HALL := 4
const MIN_THRONE_TILES := 800

var width := 1100
var height := 104
var room_of := PackedInt32Array()
var walk := PackedByteArray()
var rooms: Array = []
var by_id := {}


func _init() -> void:
	room_of.resize(width * height)
	room_of.fill(-1)
	_build()
	_place_nodes()
	_compute_exits()
	walk.resize(width * height)
	for i in room_of.size():
		walk[i] = 0 if int(room_of[i]) < 0 else 1


func _build() -> void:
	# Stage 0 — Descent. Regen is a crawl. The seal locks out swarms.
	_rect("start", "Antechamber", "start", Rect2i(2, 40, 16, 16), "S", 0, 0)
	_cluster(0, 0, 1, "fork", "The Fork", "trapped", "Still Gallery", "cursed", "Whisper Chapel", "summoned", "Skittering Hall", "cross", "Gate Cross", "seal", "Gate Seal", "seal", "E")
	_hall("corr_sf", "Passage", 0, 0, Vector2i(18, 46), Vector2i(33, 46), ["start", "fork"])
	# March into the Wards, with a held nave in the middle.
	_rect("gallery1", "Bone Nave", "gallery", Rect2i(248, 78, 22, 16), "G", 2, 1)
	_snake("m1a", 1, 2, "seal", "gallery1", [
		Vector2i(166, 46), Vector2i(230, 46), Vector2i(230, 86), Vector2i(247, 86),
	])
	# Stage 1 — Wards. Heavies come online. The font banks a cleanse.
	_cluster(328, 1, 2, "fork2", "Ash Fork", "trapped2", "Blade Cloister", "cursed2", "Rot Sacristy", "summoned2", "Pit of Names", "cross2", "Ward Cross", "font", "Cleansing Font", "font", "N")
	_snake("m1b", 1, 2, "gallery1", "fork2", [
		Vector2i(270, 86), Vector2i(330, 86), Vector2i(330, 46), Vector2i(361, 46),
	])
	_rect("gallery2", "Cinder Nave", "gallery", Rect2i(580, 78, 22, 16), "G", 3, 2)
	_snake("m2a", 2, 3, "font", "gallery2", [
		Vector2i(494, 46), Vector2i(560, 46), Vector2i(560, 86), Vector2i(579, 86),
	])
	# Stage 2 — Sanctum. Elites defend the altar. Regen is finally loose.
	_cluster(688, 2, 3, "fork3", "Black Fork", "trapped3", "Nail Gallery", "cursed3", "Mark Chapel", "summoned3", "Throneward Hall", "cross3", "Sanctum Cross", "altar", "Reviving Altar", "altar", "A")
	_snake("m2b", 2, 3, "gallery2", "fork3", [
		Vector2i(602, 86), Vector2i(680, 86), Vector2i(680, 46), Vector2i(721, 46),
	])
	# Stage 3 — the last march. Fast elixir, one held room, then the throne.
	_rect("gallery3", "Threshold", "gallery", Rect2i(940, 2, 24, 16), "H", 4, 3)
	_rect("throne", "Throne", "throne", Rect2i(1056, 34, 22, 24), "L", 4, 3)
	_snake("m3a", 3, 4, "altar", "gallery3", [
		Vector2i(854, 46), Vector2i(920, 46), Vector2i(920, 8), Vector2i(939, 8),
	])
	_snake("m3b", 3, 4, "gallery3", "throne", [
		Vector2i(964, 8), Vector2i(1020, 8), Vector2i(1020, 46), Vector2i(1055, 46),
	])


## ox shifts a whole fork → three branches → cross → stake cluster.
func _cluster(ox: int, stage: int, depth: int, fork_id: String, fork_name: String, trap_id: String, trap_name: String, curse_id: String, curse_name: String, summon_id: String, summon_name: String, cross_id: String, cross_name: String, stake_id: String, stake_name: String, stake_kind: String, stake_glyph: String) -> void:
	_rect(fork_id, fork_name, "fork", Rect2i(34 + ox, 38, 18, 18), "F", (depth - 1) if depth > 0 else 0, stage)
	_rect(trap_id, trap_name, "trapped", Rect2i(34 + ox, 4, 22, 14), "T", depth, stage)
	_rect(curse_id, curse_name, "cursed", Rect2i(34 + ox, 76, 22, 14), "C", depth, stage)
	_rect(summon_id, summon_name, "summoned", Rect2i(70 + ox, 40, 22, 16), "M", depth, stage)
	_rect(cross_id, cross_name, "cross", Rect2i(112 + ox, 40, 16, 16), "X", depth, stage)
	_rect(stake_id, stake_name, stake_kind, Rect2i(148 + ox, 38, 18, 18), stake_glyph, depth, stage)
	_hall("c_%s_t" % fork_id, "North door", stage, depth, Vector2i(40 + ox, 18), Vector2i(40 + ox, 37), [fork_id, trap_id])
	_hall("c_%s_c" % fork_id, "South door", stage, depth, Vector2i(40 + ox, 56), Vector2i(40 + ox, 75), [fork_id, curse_id])
	_hall("c_%s_s" % fork_id, "East door", stage, depth, Vector2i(52 + ox, 46), Vector2i(69 + ox, 46), [fork_id, summon_id])
	_hall("c_%s_x" % summon_id, "Passage", stage, depth, Vector2i(92 + ox, 46), Vector2i(111 + ox, 46), [summon_id, cross_id])
	_hall("c_%s_a" % trap_id, "High hall", stage, depth, Vector2i(56 + ox, 8), Vector2i(118 + ox, 8), [trap_id])
	_hall("c_%s_b" % trap_id, "High hall", stage, depth, Vector2i(118 + ox, 12), Vector2i(118 + ox, 39), [cross_id])
	_join("c_%s_a" % trap_id, "c_%s_b" % trap_id)
	_hall("c_%s_a" % curse_id, "Low hall", stage, depth, Vector2i(56 + ox, 82), Vector2i(122 + ox, 82), [curse_id])
	_hall("c_%s_b" % curse_id, "Low hall", stage, depth, Vector2i(122 + ox, 56), Vector2i(122 + ox, 81), [cross_id])
	_join("c_%s_a" % curse_id, "c_%s_b" % curse_id)
	_hall("c_%s_k" % stake_id, "Stake door", stage, depth, Vector2i(128 + ox, 46), Vector2i(147 + ox, 46), [cross_id, stake_id])


func _rect(id: String, display: String, kind: String, rect: Rect2i, glyph: String, depth: int, stage: int) -> void:
	_add_room(id, display, kind, rect, glyph, depth, stage, false)
	_carve_rect(id)


func _hall(id: String, display: String, stage: int, depth: int, a: Vector2i, b: Vector2i, links: Array) -> void:
	_add_room(id, display, "corridor", Rect2i(0, 0, 0, 0), ",", depth, stage, true)
	_carve_segment(id, a, b)
	for other in links:
		_join(id, str(other))


func _snake(prefix: String, stage: int, depth: int, origin: String, dest: String, corners: Array) -> void:
	var prev := origin
	for i in range(corners.size() - 1):
		var id := "%s_%d" % [prefix, i]
		var links: Array = [prev]
		if i == corners.size() - 2:
			links.append(dest)
		_hall(id, "Passage", stage, depth, corners[i], corners[i + 1], links)
		prev = id


func _add_room(id: String, display: String, kind: String, rect: Rect2i, glyph: String, depth: int, stage: int, corridor: bool) -> void:
	var room := {
		"id": id,
		"name": display,
		"kind": kind,
		"rect": rect,
		"glyph": glyph,
		"depth": depth,
		"stage": stage,
		"corridor": corridor,
		"neighbors": [],
		"nodes": {},
		"exits": [],
		"hint": "",
	}
	if kind == "trapped":
		room.hint = "Still air"
	elif kind == "summoned":
		room.hint = "Skittering"
	elif kind == "cursed":
		room.hint = "Whispers"
	elif kind == "gallery":
		room.hint = "Held"
	elif kind == "seal":
		room.hint = "Seal the gate"
	elif kind == "font":
		room.hint = "Bank a cleanse"
	elif kind == "altar":
		room.hint = "Bank a revive"
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


func _carve_segment(id: String, a: Vector2i, b: Vector2i) -> void:
	var x0 := mini(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var x1 := maxi(a.x, b.x)
	var y1 := maxi(a.y, b.y)
	if x1 - x0 < HALL - 1:
		x1 = x0 + HALL - 1
	if y1 - y0 < HALL - 1:
		y1 = y0 + HALL - 1
	_carve_box(id, Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))


func _carve_box(id: String, rect: Rect2i) -> void:
	var ri := _room_index(id)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= width or y >= height:
				push_error("corridor %s out of bounds %s" % [id, rect])
				continue
			if int(room_of[y * width + x]) >= 0:
				continue
			room_of[y * width + x] = ri


func _join(a: String, b: String) -> void:
	var ra: Dictionary = by_id[a]
	var rb: Dictionary = by_id[b]
	if not ra.neighbors.has(b):
		ra.neighbors.append(b)
	if not rb.neighbors.has(a):
		rb.neighbors.append(a)


func _place_nodes() -> void:
	var tiles_by_room := {}
	var w := width
	for i in room_of.size():
		var ri := int(room_of[i])
		if ri < 0:
			continue
		if not tiles_by_room.has(ri):
			tiles_by_room[ri] = []
		tiles_by_room[ri].append(Vector2i(i % w, int(i / w)))
	for room in rooms:
		if room.corridor:
			_corridor_nodes(str(room.id), tiles_by_room.get(_room_index(str(room.id)), []))
			continue
		var rect: Rect2i = room.rect
		var x0 := rect.position.x
		var y0 := rect.position.y
		var rw := rect.size.x
		var rh := rect.size.y
		_nodes(room.id, {
			"choke": Vector2i(x0 + 2, y0 + rh / 2),
			"center": Vector2i(x0 + rw / 2, y0 + rh / 2),
			"flank": Vector2i(x0 + rw / 2, y0 + 2),
			"rear": Vector2i(x0 + rw - 3, y0 + rh / 2),
		})


func _corridor_nodes(id: String, tiles: Array) -> void:
	if tiles.is_empty():
		return
	var min_x := 999999
	var max_x := -1
	var min_y := 999999
	var max_y := -1
	for t in tiles:
		var tv: Vector2i = t
		min_x = mini(min_x, tv.x)
		max_x = maxi(max_x, tv.x)
		min_y = mini(min_y, tv.y)
		max_y = maxi(max_y, tv.y)
	var horizontal := (max_x - min_x) >= (max_y - min_y)
	var columns := {}
	for t2 in tiles:
		var tv2: Vector2i = t2
		var key := tv2.x if horizontal else tv2.y
		if not columns.has(key):
			columns[key] = []
		columns[key].append(tv2)
	var keys: Array = columns.keys()
	keys.sort()
	if keys.is_empty():
		return
	var i1: int = keys.size() / 3
	var i2: int = mini(keys.size() - 1, keys.size() * 2 / 3)
	var nodes := {
		"center": _median_tile(columns[keys[i2]], horizontal),
	}
	if keys.size() >= 3 and i1 != i2:
		nodes["choke"] = _median_tile(columns[keys[i1]], horizontal)
	_nodes(id, nodes)


func _median_tile(list: Array, horizontal: bool) -> Vector2i:
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if horizontal:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	return list[list.size() / 2]


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
					# A march is many corridor pieces. The doorway names the
					# next real room, not the next 4-tile segment.
					for other_id in _first_rooms_beyond(str(nr.id), str(room.id)):
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


func _first_rooms_beyond(start_corr: String, origin: String) -> Array:
	var found: Array = []
	var stack: Array = [start_corr]
	var seen := {start_corr: true, origin: true}
	while stack.size() > 0:
		var id: String = str(stack.pop_back())
		var room: Dictionary = by_id[id]
		for n in room.neighbors:
			var nid := str(n)
			if seen.has(nid):
				continue
			seen[nid] = true
			var other: Dictionary = by_id[nid]
			if other.corridor:
				stack.append(nid)
			else:
				found.append(nid)
	found.sort()
	return found


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


func path_between(a: String, b: String) -> Array:
	return Pathing.find(walk, width, height, center_tile(a), center_tile(b), {})


func validate() -> Array:
	var errors: Array = []
	for room in rooms:
		if room.corridor:
			if room.nodes.is_empty():
				errors.append("corridor %s has no anchor" % room.id)
			for n in room.nodes.keys():
				var ct: Vector2i = room.nodes[n]
				if id_at_tile(ct) != room.id:
					errors.append("node %s:%s not in room (%s)" % [room.id, n, ct])
			continue
		var center := center_tile(room.id)
		if id_at_tile(center) != room.id:
			errors.append("center off room %s" % room.id)
		for n in room.nodes.keys():
			var t: Vector2i = room.nodes[n]
			if id_at_tile(t) != room.id:
				errors.append("node %s:%s not in room (%s)" % [room.id, n, t])
		if room.exits.is_empty() and room.id != "start":
			errors.append("no exits %s" % room.id)
	var forks: Array = []
	for room2 in rooms:
		if str(room2.kind) == "fork":
			forks.append(room2)
	if forks.size() < 3:
		errors.append("need 3 forks, have %d" % forks.size())
	for fork in forks:
		var kinds := {}
		for e in fork.exits:
			var k := str(e.kind)
			if k in ["trapped", "summoned", "cursed"]:
				kinds[k] = true
		for need in ["trapped", "summoned", "cursed"]:
			if not kinds.has(need):
				errors.append("%s missing %s exit" % [fork.id, need])
	for stake in ["seal", "font", "altar", "throne", "gallery1", "gallery2", "gallery3"]:
		if not by_id.has(stake):
			errors.append("missing %s" % stake)
	var throne_path := path_between("start", "throne")
	if throne_path.size() < MIN_THRONE_TILES:
		errors.append("throne path %d tiles is under %d" % [throne_path.size(), MIN_THRONE_TILES])
	for must in ["summoned", "seal", "gallery1", "summoned2", "font", "gallery2", "summoned3", "altar", "gallery3", "throne"]:
		if not _path_hits(throne_path, must):
			errors.append("shortest path skips %s" % must)
	# North and south branches are longer roads than the east (summoned) branch.
	for pair in [["fork", "trapped", "cross", "summoned"], ["fork2", "cursed2", "cross2", "summoned2"], ["fork3", "trapped3", "cross3", "summoned3"]]:
		var detour := path_between(pair[0], pair[1]).size() + path_between(pair[1], pair[2]).size()
		var east := path_between(pair[0], pair[3]).size() + path_between(pair[3], pair[2]).size()
		if detour <= east:
			errors.append("%s detour %d is not longer than east %d" % [pair[1], detour, east])
	return errors


func _path_hits(path: Array, id: String) -> bool:
	var ri := _room_index(id)
	if ri < 0:
		return false
	for t in path:
		if at(t) == ri:
			return true
	return false


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
