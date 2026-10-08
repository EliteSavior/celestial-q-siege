extends Control
## Reads a fogged snapshot plus the static map. Never writes sim state.

const TILE := 48.0
const INSET_L := 196.0
const INSET_T := 78.0
const INSET_B := 132.0

const HERO_COLOR := {
	"michael": Color(0.38, 0.58, 0.95),
	"raphael": Color(0.32, 0.82, 0.48),
	"azrael": Color(0.72, 0.42, 0.9),
	"uriel": Color(0.95, 0.62, 0.28),
	"gabriel": Color(0.95, 0.84, 0.42),
}

var game
var snap: Dictionary = {}
var cam := Vector2.ZERO
var cam_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func handle_tap(screen: Vector2) -> void:
	if snap.is_empty() or game == null:
		return
	var world := _screen_to_world(screen)
	if world.x < INSET_L or world.y < INSET_T or world.y > size.y - INSET_B:
		return
	var milli := _world_to_milli(world)
	if bool(snap.get("beam_on", false)):
		game.command("steer", {"pos": milli})
		return
	for foe in snap.foes:
		if Fixed.dist(milli, foe.pos) <= 900:
			game.command("focus", {"id": int(foe.id)})
			return
	var stake_id := str(snap.get("stake_id", ""))
	if stake_id != "":
		var stake_node: Vector2i = game.sim.map.node_tile("%s:rear" % stake_id)
		var claimed := false
		if stake_id == "altar":
			claimed = bool(snap.altar_done)
		elif stake_id == "seal":
			claimed = bool(snap.get("seal_done", false))
		elif stake_id == "font":
			claimed = bool(snap.get("font_done", false))
		if stake_node.x >= 0 and Fixed.dist(milli, Fixed.tile_center(stake_node)) <= 1400 and not claimed:
			if int(snap.get("boss_hp_max", 0)) <= 0:
				game.command("channel_altar", {})
				game.command("move_tile", {"tile": stake_node})
				return
	var best_d := 1600
	var best := {}
	for ex in snap.exits:
		var d := Fixed.dist(milli, Fixed.tile_center(ex.tile))
		if d < best_d:
			best_d = d
			best = ex
	if not best.is_empty():
		game.command("move_room", {"room": str(best.dest)})
		return
	var tile := Fixed.tile_of(milli)
	if game.sim.map.at(tile) >= 0:
		game.command("move_tile", {"tile": tile})


func handle_drag(screen: Vector2) -> void:
	if snap.is_empty() or game == null or not bool(snap.get("beam_on", false)):
		return
	if screen.x < INSET_L or screen.y < INSET_T or screen.y > size.y - INSET_B:
		return
	game.command("steer", {"pos": _world_to_milli(screen)})


func _process(_delta: float) -> void:
	if snap.is_empty():
		return
	var anchor: Vector2i = snap.anchor
	var target := _milli_to_world(anchor) - Vector2(INSET_L, INSET_T)
	target += Vector2(INSET_L, INSET_T)
	var view := _view_size()
	var desired := _milli_to_local_unoffset(anchor) - view * 0.5
	if not cam_ready:
		cam = desired
		cam_ready = true
	else:
		cam = cam.lerp(desired, 0.18)
	queue_redraw()


func _draw() -> void:
	if snap.is_empty() or game == null:
		return
	var font := ThemeDB.fallback_font
	var view_pos := Vector2(INSET_L, INSET_T)
	var view_size := _view_size()
	draw_rect(Rect2(view_pos, view_size), Color(0.03, 0.03, 0.05))
	var map = game.sim.map
	var vis := {}
	for id in snap.visible:
		vis[str(id)] = true
	var x0 := int(cam.x / TILE) - 1
	var y0 := int(cam.y / TILE) - 1
	var x1 := int((cam.x + view_size.x) / TILE) + 2
	var y1 := int((cam.y + view_size.y) / TILE) + 2
	for ty in range(maxi(y0, 0), mini(y1, map.height)):
		for tx in range(maxi(x0, 0), mini(x1, map.width)):
			var ri: int = int(map.at(Vector2i(tx, ty)))
			if ri < 0:
				continue
			var room: Dictionary = map.rooms[ri]
			if not vis.has(str(room.id)):
				continue
			var p := _tile_screen(tx, ty)
			var col := _room_color(str(room.kind), str(room.id) == str(snap.party_room))
			draw_rect(Rect2(p, Vector2(TILE - 1, TILE - 1)), col)
	for room in map.rooms:
		if room.corridor or not vis.has(str(room.id)):
			continue
		for node_name in room.nodes.keys():
			var t: Vector2i = room.nodes[node_name]
			var c := _tile_screen(t.x, t.y) + Vector2(TILE * 0.5, TILE * 0.5)
			var stake_node := str(room.kind) in ["altar", "seal", "font"] and str(node_name) == "rear"
			var mark := Color(0.85, 0.75, 0.35, 0.55) if stake_node else Color(0.55, 0.5, 0.4, 0.35)
			draw_circle(c, 5, mark)
	if snap.path is Array:
		var prev := _milli_screen(snap.anchor)
		for tile in snap.path:
			var p2 := _tile_screen(tile.x, tile.y) + Vector2(TILE * 0.5, TILE * 0.5)
			draw_line(prev, p2, Color(0.95, 0.9, 0.6, 0.45), 2.0)
			prev = p2
	for zone in snap.zones:
		var colz := Color(0.95, 0.35, 0.12, 0.28) if str(zone.subtype) == "hell" else Color(0.95, 0.85, 0.4, 0.28)
		draw_circle(_milli_screen(zone.pos), float(zone.radius) / 1000.0 * TILE, colz)
	for trap in snap.traps:
		var c3 := _milli_screen(trap.pos)
		var tc := Color(0.95, 0.55, 0.15) if str(trap.subtype) == "hellflame" else Color(0.85, 0.8, 0.45)
		if not bool(trap.armed):
			tc.a = 0.35
		draw_rect(Rect2(c3 - Vector2(8, 8), Vector2(16, 16)), tc)
		if font:
			draw_string(font, c3 + Vector2(-18, 22), str(trap.subtype), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.8))
	_draw_kits(font)
	_draw_telegraphs(font)
	for foe in snap.foes:
		_draw_unit(foe, _foe_color(str(foe.subtype)), font, true)
		if foe.blink is Dictionary and not foe.blink.is_empty():
			draw_line(_milli_screen(foe.pos), _milli_screen(foe.blink.pos), Color(1, 0.3, 0.8, 0.8), 2.0)
			draw_circle(_milli_screen(foe.blink.pos), 10, Color(1, 0.3, 0.8, 0.35))
	for angel in snap.angels:
		if not bool(angel.alive):
			var fallen := Color(0.25, 0.25, 0.28)
			_draw_unit(angel, fallen, font, false)
			if bool(angel.get("downed", false)):
				var p_down := _milli_screen(angel.pos)
				var left := int(angel.get("downed_left", 0))
				var frac := float(left) / float(maxi(int(snap.get("downed_ticks", 60)), 1))
				draw_arc(p_down, 18.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(1.0, 0.45, 0.18), 3.0)
				if font:
					draw_string(font, p_down + Vector2(-12, 28), "%0.1f" % (float(left) / 20.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.62, 0.3))
			continue
		var col: Color = HERO_COLOR.get(str(angel.subtype), Color.WHITE)
		if int(angel.id) == int(snap.focus_id):
			draw_circle(_milli_screen(angel.pos), 22, Color(1, 1, 1, 0.15))
		_draw_unit(angel, col, font, false)
	for ex in snap.exits:
		var tile: Vector2i = ex.tile
		var sp := _tile_screen(tile.x, tile.y)
		draw_rect(Rect2(sp, Vector2(TILE, TILE)), Color(0.95, 0.85, 0.4, 0.18))
		if font:
			var label := str(ex.label)
			if str(ex.hint) != "":
				label = "%s\n%s" % [ex.hint, ex.label]
			draw_string(font, sp + Vector2(4, -4), label, HORIZONTAL_ALIGNMENT_LEFT, 140, 13, Color(1, 0.95, 0.75))
	for pop in snap.popups:
		if font:
			var age := int(snap.tick) - int(pop.tick)
			var colp := Color(1, 0.45, 0.4) if str(pop.kind) == "bad" else Color(0.6, 1, 0.65)
			draw_string(font, _milli_screen(pop.pos) + Vector2(-8, -18 - age), str(pop.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colp)
	if str(snap.banner) != "" and font:
		var bp := view_pos + Vector2(view_size.x * 0.5 - 160, 18)
		draw_string(font, bp, str(snap.banner), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 0.82, 0.45))
	if bool(snap.channeling) and font:
		var stake_name := str(snap.get("stake_name", "the stake"))
		draw_string(font, view_pos + Vector2(12, view_size.y - 16), "Channeling %s  %d%%" % [stake_name, int(snap.altar_progress)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5))


func _draw_kits(font) -> void:
	if bool(snap.get("beam_on", false)):
		var a0 := _milli_screen(snap.beam_from)
		var a1 := _milli_screen(snap.beam_aim)
		draw_line(a0, a1, Color(1.0, 0.82, 0.35, 0.9), 5.0)
		if font:
			draw_string(font, a1 + Vector2(8, -6), "drag to steer", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.9, 0.55))
	if bool(snap.get("shield_wall", false)):
		var mp := _hero_pos("michael")
		if mp != Vector2i.ZERO:
			var face: Vector2i = snap.get("shield_facing", snap.facing)
			var mid := mp + Fixed.rotate_facing(Vector2i(700, 0), face)
			var left := mid + Fixed.rotate_facing(Vector2i(0, -1100), face)
			var right := mid + Fixed.rotate_facing(Vector2i(0, 1100), face)
			draw_line(_milli_screen(left), _milli_screen(right), Color(0.55, 0.75, 1.0, 0.85), 6.0)
	var tid := int(snap.get("taunt_id", 0))
	if tid > 0:
		var mp2 := _hero_pos("michael")
		var foe := _unit_pos(tid)
		if mp2 != Vector2i.ZERO and foe != Vector2i.ZERO:
			draw_line(_milli_screen(mp2), _milli_screen(foe), Color(0.95, 0.35, 0.25, 0.8), 2.0)


func _hero_pos(subtype: String) -> Vector2i:
	for a in snap.angels:
		if str(a.subtype) == subtype and bool(a.alive):
			return a.pos
	return Vector2i.ZERO


func _draw_telegraphs(font) -> void:
	var tg: Dictionary = snap.telegraph
	if tg.is_empty():
		return
	var name := str(tg.get("name", ""))
	if name == "hell_rain":
		for mark in snap.hell_rain:
			draw_circle(_milli_screen(mark.pos), Balance.HELL_RAIN_RADIUS / 1000.0 * TILE, Color(0.9, 0.2, 0.1, 0.25))
	elif name == "cleave":
		var boss := _boss_pos()
		if boss != Vector2i.ZERO:
			var aim: Vector2i = tg.get("aim", snap.anchor)
			var end := Fixed.approach(boss, aim, Balance.CLEAVE_LENGTH)
			draw_line(_milli_screen(boss), _milli_screen(end), Color(1, 0.35, 0.2, 0.7), 18.0)
	elif name == "judgment":
		var tgt := _unit_pos(int(tg.get("target", 0)))
		if tgt != Vector2i.ZERO:
			draw_circle(_milli_screen(tgt), 28, Color(1, 0.85, 0.2, 0.35))
	elif name == "grasp":
		var boss2 := _boss_pos()
		if boss2 != Vector2i.ZERO:
			draw_circle(_milli_screen(boss2), 70, Color(0.6, 0.1, 0.2, 0.25))
	if font:
		var remain := maxi(0, int(tg.get("until", 0)) - int(snap.tick))
		draw_string(font, Vector2(INSET_L + 12, INSET_T + 22), "%s  %0.1fs" % [name.replace("_", " "), float(remain) / 20.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.7, 0.45))


func _draw_unit(u: Dictionary, col: Color, font, foe: bool) -> void:
	var p := _milli_screen(u.pos)
	var radius := 16.0 if str(u.subtype) == "lucifer" else (11.0 if foe else 10.0)
	if str(u.subtype) == "heavy" or str(u.subtype) == "elite":
		radius = 14.0
	if bool(u.get("spawning", false)):
		col.a = 0.45
	draw_circle(p, radius, col)
	if bool(u.get("mark", false)):
		draw_arc(p, radius + 5, 0, TAU, 16, Color(1, 0.2, 0.25), 2.0)
	if bool(u.get("silence", false)):
		draw_arc(p, radius + 8, 0, TAU, 12, Color(0.6, 0.7, 1.0), 2.0)
	if bool(u.get("weaken", false)):
		draw_arc(p, radius + 11, PI, TAU, 8, Color(0.7, 0.55, 0.85), 2.0)
	if bool(u.get("rot", false)):
		draw_arc(p, radius + 11, 0, PI, 8, Color(0.45, 0.7, 0.3), 2.0)
	var hp := float(maxi(int(u.hp), 0))
	var mx := float(maxi(int(u.hp_max), 1))
	var w := 28.0
	draw_rect(Rect2(p + Vector2(-w * 0.5, -radius - 10), Vector2(w, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(p + Vector2(-w * 0.5, -radius - 10), Vector2(w * hp / mx, 4)), Color(0.4, 0.85, 0.45) if not foe else Color(0.9, 0.3, 0.25))
	if font and (str(u.subtype) == "lucifer" or str(u.subtype) == "elite" or not foe):
		var tag := str(u.name)[0] if not foe else str(u.subtype)
		draw_string(font, p + Vector2(-4, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.04, 0.08))


func _room_color(kind: String, here: bool) -> Color:
	var c := Color(0.16, 0.15, 0.2)
	match kind:
		"start":
			c = Color(0.14, 0.16, 0.22)
		"fork":
			c = Color(0.18, 0.15, 0.24)
		"trapped":
			c = Color(0.26, 0.14, 0.12)
		"summoned":
			c = Color(0.28, 0.12, 0.14)
		"cursed":
			c = Color(0.2, 0.12, 0.26)
		"cross":
			c = Color(0.16, 0.16, 0.18)
		"altar":
			c = Color(0.24, 0.2, 0.12)
		"seal":
			c = Color(0.18, 0.22, 0.28)
		"font":
			c = Color(0.16, 0.24, 0.22)
		"gallery":
			c = Color(0.22, 0.14, 0.12)
		"throne":
			c = Color(0.22, 0.08, 0.1)
		"corridor":
			c = Color(0.1, 0.1, 0.13)
	if not here:
		c = c.darkened(0.35)
	return c


func _foe_color(subtype: String) -> Color:
	match subtype:
		"imp":
			return Color(0.9, 0.28, 0.22)
		"heavy":
			return Color(0.55, 0.12, 0.14)
		"elite":
			return Color(0.9, 0.25, 0.55)
		"lucifer":
			return Color(0.85, 0.08, 0.08)
		_:
			return Color(0.8, 0.2, 0.2)


func _view_size() -> Vector2:
	return Vector2(maxi(size.x - INSET_L - 8, 100), maxi(size.y - INSET_T - INSET_B, 100))


func _screen_to_world(screen: Vector2) -> Vector2:
	return screen


func _world_to_milli(screen: Vector2) -> Vector2i:
	var local := screen - Vector2(INSET_L, INSET_T) + cam
	return Vector2i(int(local.x / TILE * 1000.0), int(local.y / TILE * 1000.0))


func _milli_to_local_unoffset(m: Vector2i) -> Vector2:
	return Vector2(float(m.x) / 1000.0 * TILE, float(m.y) / 1000.0 * TILE)


func _milli_to_world(m: Vector2i) -> Vector2:
	return _milli_to_local_unoffset(m)


func _milli_screen(m: Vector2i) -> Vector2:
	return Vector2(INSET_L, INSET_T) + _milli_to_local_unoffset(m) - cam


func _tile_screen(tx: int, ty: int) -> Vector2:
	return Vector2(INSET_L, INSET_T) + Vector2(tx * TILE, ty * TILE) - cam


func _boss_pos() -> Vector2i:
	for foe in snap.foes:
		if str(foe.subtype) == "lucifer":
			return foe.pos
	return Vector2i.ZERO


func _unit_pos(id: int) -> Vector2i:
	for a in snap.angels:
		if int(a.id) == id:
			return a.pos
	for f in snap.foes:
		if int(f.id) == id:
			return f.pos
	return Vector2i.ZERO
