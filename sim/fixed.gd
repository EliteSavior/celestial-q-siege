class_name Fixed
extends RefCounted
## Integer helpers. The sim does not use float math for outcomes.


static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


static func dist(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return isqrt(dx * dx + dy * dy)


static func sign_i(v: int) -> int:
	if v > 0:
		return 1
	if v < 0:
		return -1
	return 0


static func step_toward(pos: Vector2i, dest: Vector2i, speed: int) -> Vector2i:
	var d := dest - pos
	var len := isqrt(d.x * d.x + d.y * d.y)
	if len <= speed or len == 0:
		return dest
	return pos + Vector2i(d.x * speed / len, d.y * speed / len)


static func tile_of(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x / 1000, pos.y / 1000)


static func tile_center(tile: Vector2i) -> Vector2i:
	return tile * 1000 + Vector2i(500, 500)


## Facing-space offset (+x is forward) into world milli-tiles.
static func rotate_facing(off: Vector2i, facing: Vector2i) -> Vector2i:
	if facing.x > 0:
		return off
	if facing.x < 0:
		return Vector2i(-off.x, -off.y)
	if facing.y < 0:
		return Vector2i(off.y, -off.x)
	return Vector2i(-off.y, off.x)


static func mix(h: int, v: int) -> int:
	var x := (h ^ v) & 0x7FFFFFFF
	return (x * 16777619) & 0x7FFFFFFF


static func approach(pos: Vector2i, dest: Vector2i, dist: int) -> Vector2i:
	var d := dest - pos
	var len := isqrt(d.x * d.x + d.y * d.y)
	if len == 0:
		return pos + Vector2i(dist, 0)
	return pos + Vector2i(d.x * dist / len, d.y * dist / len)
