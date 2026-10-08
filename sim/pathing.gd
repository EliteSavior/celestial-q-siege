class_name Pathing
extends RefCounted
## Deterministic 8-direction A*. Cardinal steps cost 10, diagonals cost 14.
## A diagonal is legal only when both adjacent cardinal tiles are open,
## so the path cannot cut a corner. Tie-break is insertion order.


static func find(walk: PackedByteArray, width: int, height: int, start: Vector2i, goal: Vector2i, extra_cost: Dictionary) -> Array:
	if start == goal:
		return [start]
	var s := _idx(start, width)
	var g0 := _idx(goal, width)
	if not _open(walk, width, height, start) or not _open(walk, width, height, goal):
		return []
	var heap: Array = []
	var gscore := {s: 0}
	var came := {}
	var closed := {}
	var seq := 0
	_push(heap, _heur(start, goal), seq, s)
	var dirs := [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var found := false
	while heap.size() > 0:
		var cur: Dictionary = _pop(heap)
		var ci: int = cur.i
		if closed.has(ci):
			continue
		closed[ci] = true
		if ci == g0:
			found = true
			break
		var cx := ci % width
		var cy := ci / width
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var ni: int = ny * width + nx
			if walk[ni] == 0:
				continue
			if d.x != 0 and d.y != 0:
				if walk[cy * width + nx] == 0 or walk[ny * width + cx] == 0:
					continue
			var step: int = (14 if d.x != 0 and d.y != 0 else 10) + int(extra_cost.get(ni, 0))
			var ng: int = int(gscore[ci]) + step
			if ng < int(gscore.get(ni, 1 << 30)):
				gscore[ni] = ng
				came[ni] = ci
				seq += 1
				_push(heap, ng + _heur(Vector2i(nx, ny), goal), seq, ni)
	if not found:
		return []
	var tiles: Array = []
	var cursor := g0
	while true:
		tiles.append(Vector2i(cursor % width, cursor / width))
		if cursor == s:
			break
		cursor = int(came[cursor])
	tiles.reverse()
	return tiles


static func _open(walk: PackedByteArray, width: int, height: int, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= width or t.y >= height:
		return false
	return walk[t.y * width + t.x] != 0


static func _idx(t: Vector2i, width: int) -> int:
	return t.y * width + t.x


static func _heur(a: Vector2i, b: Vector2i) -> int:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	var diag := mini(dx, dy)
	var straight := maxi(dx, dy) - diag
	return diag * 14 + straight * 10


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.f) != int(b.f):
		return int(a.f) < int(b.f)
	return int(a.s) < int(b.s)


static func _push(heap: Array, f: int, seq: int, idx: int) -> void:
	heap.append({"f": f, "s": seq, "i": idx})
	var n := heap.size() - 1
	while n > 0:
		var p := (n - 1) >> 1
		if _before(heap[n], heap[p]):
			var tmp = heap[p]
			heap[p] = heap[n]
			heap[n] = tmp
			n = p
		else:
			break


static func _pop(heap: Array) -> Dictionary:
	var top: Dictionary = heap[0]
	var last = heap[heap.size() - 1]
	heap.remove_at(heap.size() - 1)
	if heap.is_empty():
		return top
	heap[0] = last
	var n := 0
	while true:
		var l := n * 2 + 1
		var r := l + 1
		var smallest := n
		if l < heap.size() and _before(heap[l], heap[smallest]):
			smallest = l
		if r < heap.size() and _before(heap[r], heap[smallest]):
			smallest = r
		if smallest == n:
			break
		var tmp = heap[n]
		heap[n] = heap[smallest]
		heap[smallest] = tmp
		n = smallest
	return top
