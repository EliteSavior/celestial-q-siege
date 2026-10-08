extends Control
class_name BoardView
## Reads a fogged snapshot plus the static map. Never writes sim state.
## Fixed 2:1 dimetric view. Screen position is derived from tiles and never fed back.

const TILE_W := 64.0
const TILE_H := 32.0
const INSET_L := 196.0
const INSET_T := 112.0
const INSET_B := 236.0
const INSET_R := 8.0
const NARROW_W := 1200.0
const NARROW_INSET_B := 308.0

const TELL_COLOR := {
	"silence": Color(0.38, 0.66, 1.0),
	"rot": Color(0.48, 0.86, 0.28),
	"mark": Color(1.0, 0.24, 0.28),
	"spike": Color(0.95, 0.82, 0.35),
	"snare": Color(0.45, 0.85, 0.95),
	"hellflame": Color(1.0, 0.38, 0.1),
	"hell_rain": Color(0.95, 0.16, 0.1),
	"cleave": Color(1.0, 0.48, 0.12),
	"judgment": Color(1.0, 0.86, 0.25),
	"grasp": Color(0.82, 0.22, 0.48),
	"commit": Color(1.0, 0.55, 0.72),
	"echo": Color(1.0, 0.72, 0.28),
	"transform": Color(0.95, 0.12, 0.18),
}

const TELL_LABEL := {
	"silence": "SILENCE",
	"rot": "ROT",
	"mark": "MARK",
	"spike": "SPIKE",
	"snare": "SNARE",
	"hellflame": "HELLFLAME",
	"hell_rain": "HELL RAIN  move",
	"cleave": "CLEAVE  leave the lane",
	"judgment": "JUDGMENT  shield",
	"grasp": "GRASP  phalanx",
	"commit": "ARMING",
	"echo": "ECHO WAVE",
	"transform": "TRANSFORMS",
}

const HINT_COLOR := {
	"Still air": Color(0.95, 0.72, 0.22),
	"Skittering": Color(0.95, 0.32, 0.24),
	"Whispers": Color(0.72, 0.42, 0.98),
	"Seal the gate": Color(0.4, 0.7, 0.98),
	"Bank a cleanse": Color(0.35, 0.88, 0.7),
	"Bank a revive": Color(0.98, 0.8, 0.28),
	"Held": Color(0.75, 0.58, 0.38),
}

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
var zoom := 1.0
var cam_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)


func handle_tap(screen: Vector2) -> void:
	if snap.is_empty() or game == null:
		return
	if not playfield_rect().has_point(screen):
		return
	var milli := _screen_to_milli(screen)
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
	var tile := _nearest_walkable(milli)
	if tile.x >= 0:
		game.command("move_tile", {"tile": tile})


func handle_drag(screen: Vector2) -> void:
	if snap.is_empty() or game == null or not bool(snap.get("beam_on", false)):
		return
	if not playfield_rect().has_point(screen):
		return
	game.command("steer", {"pos": _screen_to_milli(screen)})


func _process(_delta: float) -> void:
	if snap.is_empty() or game == null:
		return
	var rect := _focus_rect()
	var bounds := _iso_bounds(rect)
	var view := _view_size()
	var fit := minf(view.x / maxf(bounds.size.x, 1.0), view.y / maxf(bounds.size.y, 1.0))
	zoom = clampf(fit / 1.12, 0.35, 1.45)
	var span := view / zoom
	var iso := _iso_milli(snap.anchor)
	var desired := iso - span * 0.5
	desired.x = _clamp_cam(desired.x, bounds.position.x, bounds.end.x, span.x)
	desired.y = _clamp_cam(desired.y, bounds.position.y, bounds.end.y, span.y)
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
	var view_pos := _view_origin()
	var view_size := _view_size()
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(view_pos, view_size))
	draw_rect(Rect2(view_pos, view_size), Color(0.03, 0.03, 0.05))
	var map = game.sim.map
	var vis := {}
	for id in snap.visible:
		vis[str(id)] = true
	var cells: Array[Vector2i] = []
	var cull := _cull_rect()
	var y_from := maxi(cull.position.y, 0)
	var y_to := mini(cull.position.y + cull.size.y, map.height)
	var x_from := maxi(cull.position.x, 0)
	var x_to := mini(cull.position.x + cull.size.x, map.width)
	for ty in range(y_from, y_to):
		for tx in range(x_from, x_to):
			var ri: int = int(map.at(Vector2i(tx, ty)))
			if ri < 0:
				continue
			var room: Dictionary = map.rooms[ri]
			if not vis.has(str(room.id)):
				continue
			cells.append(Vector2i(tx, ty))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := a.x + a.y
		var db := b.x + b.y
		if da != db:
			return da < db
		return a.x < b.x
	)
	for cell in cells:
		var ri2: int = int(map.at(cell))
		var room2: Dictionary = map.rooms[ri2]
		var center := _tile_center_screen(cell.x, cell.y)
		var here := str(room2.id) == str(snap.party_room)
		_draw_tile_diamond(center, _room_color(str(room2.kind), here), 0.86)
		_draw_fog_edge(cell.x, cell.y, vis, map, center)
	for ex in snap.exits:
		var door: Vector2i = ex.tile
		var hc: Color = HINT_COLOR.get(str(ex.hint), Color(1.0, 0.92, 0.7))
		_draw_tile_diamond(_tile_center_screen(door.x, door.y), Color(hc.r, hc.g, hc.b, 0.42), 0.98)
	for room3 in map.rooms:
		if room3.corridor or not vis.has(str(room3.id)):
			continue
		for node_name in room3.nodes.keys():
			var t: Vector2i = room3.nodes[node_name]
			var c := _tile_center_screen(t.x, t.y)
			var stake_node := str(room3.kind) in ["altar", "seal", "font"] and str(node_name) == "rear"
			if stake_node:
				_draw_tile_diamond(c, Color(0.98, 0.78, 0.22, 0.95), 0.46)
				if font:
					_plaque(font, c + Vector2(-28, -22), "STAKE", Color(0.15, 0.1, 0.02), Color(0.98, 0.82, 0.3), 13)
			else:
				_draw_tile_diamond(c, Color(0.7, 0.64, 0.5, 0.55), 0.16)
	if snap.path is Array:
		var prev := _milli_screen(snap.anchor)
		for tile in snap.path:
			var p2 := _tile_center_screen(tile.x, tile.y)
			draw_line(prev, p2, Color(0.95, 0.9, 0.6, 0.55), 2.0)
			prev = p2
	for zone in snap.zones:
		var colz := Color(0.95, 0.35, 0.12, 0.28) if str(zone.subtype) == "hell" else Color(0.95, 0.85, 0.4, 0.28)
		_draw_world_disk(zone.pos, float(zone.radius), colz)
	for commit in snap.get("commitments", []):
		var cp := _milli_screen(commit.pos)
		var total := maxi(Balance.COMMIT_CAST, 1)
		var remain_c := maxi(0, int(commit.land) - int(snap.tick))
		var frac_c := 1.0 - float(remain_c) / float(total)
		var arm: Color = TELL_COLOR.commit
		draw_arc(cp, 28.0, -PI * 0.5, -PI * 0.5 + TAU * frac_c, 28, arm, 5.0)
		draw_circle(cp, 10.0, Color(arm.r, arm.g, arm.b, 0.35))
		if font:
			var label := "ELITE" if str(commit.plan) == "elite" else "TRAP CLUSTER"
			_plaque(font, cp + Vector2(-52, -36), "%s  %0.1fs" % [label, float(remain_c) / 20.0], arm, Color(0.08, 0.03, 0.05, 0.9), 16)
		for piece in commit.get("pieces", []):
			draw_circle(_milli_screen(piece.pos), 7.0, Color(1.0, 0.5, 0.2, 0.55))
	for curse in snap.get("curses", []):
		var cpos := _milli_screen(curse.pos)
		var crest := maxi(0, int(curse.land) - int(snap.tick))
		var sub := str(curse.subtype)
		var span := Balance.CURSE_CAST_MARK if sub == "mark" else Balance.CURSE_CAST
		var cfrac := 1.0 - float(crest) / float(maxi(span, 1))
		var cc: Color = TELL_COLOR.get(sub, Color(0.72, 0.45, 0.95))
		draw_arc(cpos, 30.0, -PI * 0.5, -PI * 0.5 + TAU * cfrac, 24, cc, 5.0)
		draw_circle(cpos, 8.0, Color(cc.r, cc.g, cc.b, 0.35))
		if font:
			var who := str(curse.get("name", ""))
			_plaque(font, cpos + Vector2(-46, 40), "%s  %s  %0.1fs" % [TELL_LABEL.get(sub, sub), who, float(crest) / 20.0], cc, Color(0.04, 0.03, 0.08, 0.9), 15)
	_draw_kits(font)
	_draw_transform(font)
	_draw_telegraphs(font)
	_draw_actors(font)
	for ex2 in snap.exits:
		var door2: Vector2i = ex2.tile
		var sp := _tile_center_screen(door2.x, door2.y)
		var hint := str(ex2.hint)
		var hc2: Color = HINT_COLOR.get(hint, Color(1.0, 0.92, 0.7))
		if font:
			if hint != "":
				_plaque(font, sp + Vector2(-34, -28), hint, Color(0.08, 0.06, 0.04), hc2, 15)
			draw_string(font, sp + Vector2(-40, 18), str(ex2.label), HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(1, 0.97, 0.88))
	for pop in snap.popups:
		if font:
			var age := int(snap.tick) - int(pop.tick)
			var colp := Color(1, 0.45, 0.4) if str(pop.kind) == "bad" else Color(0.6, 1, 0.65)
			draw_string(font, _milli_screen(pop.pos) + Vector2(-8, -18 - age), str(pop.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colp)
	_draw_guide()
	if str(snap.banner) != "" and font:
		var bp := view_pos + Vector2(12, 36)
		_plaque(font, bp, str(snap.banner), Color(1, 0.86, 0.45), Color(0.08, 0.05, 0.03, 0.9), 22)
	var spawning := false
	for foe2 in snap.foes:
		if bool(foe2.get("spawning", false)):
			spawning = true
			break
	if spawning and font:
		_plaque(font, view_pos + Vector2(view_size.x * 0.5 - 70, 36), TELL_LABEL.echo, TELL_COLOR.echo, Color(0.1, 0.05, 0.02, 0.92), 18)
	if bool(snap.channeling) and font:
		var stake_name := str(snap.get("stake_name", "the stake"))
		draw_string(font, view_pos + Vector2(12, view_size.y - 16), "Channeling %s  %d%%" % [stake_name, int(snap.altar_progress)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5))


func _draw_kits(font) -> void:
	if bool(snap.get("beam_on", false)):
		var a0 := _milli_screen(snap.beam_from)
		var a1 := _milli_screen(snap.beam_aim)
		draw_line(a0, a1, Color(1.0, 0.82, 0.35, 0.9), 6.0)
		if font:
			_plaque(font, a1 + Vector2(8, -8), "URIEL  beam  drag", Color(0.15, 0.1, 0.02), Color(1.0, 0.86, 0.4), 14)
	if bool(snap.get("shield_wall", false)):
		var mp := _hero_pos("michael")
		if mp != Vector2i.ZERO:
			var face: Vector2i = snap.get("shield_facing", snap.facing)
			var mid := mp + Fixed.rotate_facing(Vector2i(700, 0), face)
			var left := mid + Fixed.rotate_facing(Vector2i(0, -1100), face)
			var right := mid + Fixed.rotate_facing(Vector2i(0, 1100), face)
			draw_line(_milli_screen(left), _milli_screen(right), Color(0.55, 0.78, 1.0, 0.95), 7.0)
			if font:
				_plaque(font, _milli_screen(mid) + Vector2(-36, -16), "MICHAEL  shield", Color(0.04, 0.08, 0.16), Color(0.7, 0.84, 1.0), 14)
	var tid := int(snap.get("taunt_id", 0))
	if tid > 0:
		var mp2 := _hero_pos("michael")
		var foe := _unit_pos(tid)
		if mp2 != Vector2i.ZERO and foe != Vector2i.ZERO:
			draw_line(_milli_screen(mp2), _milli_screen(foe), Color(0.95, 0.35, 0.25, 0.9), 3.0)
			if font:
				_plaque(font, _milli_screen(foe) + Vector2(8, -18), "TAUNT", Color(0.16, 0.04, 0.03), Color(1.0, 0.45, 0.3), 13)
	_draw_casts(font)


func _hero_pos(subtype: String) -> Vector2i:
	for a in snap.angels:
		if str(a.subtype) == subtype and bool(a.alive):
			return a.pos
	return Vector2i.ZERO


func _draw_transform(font) -> void:
	if int(snap.get("transform_until", 0)) <= int(snap.tick):
		return
	var boss := _boss_pos()
	if boss == Vector2i.ZERO:
		return
	var p := _milli_screen(boss)
	var remain := maxi(0, int(snap.transform_until) - int(snap.tick))
	var frac := 1.0 - float(remain) / float(maxi(Balance.TRANSFORM_CAST, 1))
	draw_arc(p, 42.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, TELL_COLOR.transform, 6.0)
	draw_circle(p, 30.0, Color(0.7, 0.05, 0.08, 0.4))
	if font:
		_plaque(font, p + Vector2(-70, -50), "%s  %0.1fs" % [TELL_LABEL.transform, float(remain) / 20.0], TELL_COLOR.transform, Color(0.1, 0.02, 0.03, 0.92), 18)


func _draw_telegraphs(font) -> void:
	var tg: Dictionary = snap.telegraph
	if tg.is_empty():
		return
	var name := str(tg.get("name", ""))
	var boss := _boss_pos()
	var tell: Color = TELL_COLOR.get(name, Color(1.0, 0.45, 0.15))
	if boss != Vector2i.ZERO:
		var remain_b := maxi(0, int(tg.get("until", 0)) - int(snap.tick))
		var frac_b := 1.0 - float(remain_b) / float(maxi(Balance.BOSS_TELL, 1))
		draw_arc(_milli_screen(boss), 40.0, -PI * 0.5, -PI * 0.5 + TAU * frac_b, 32, tell, 6.0)
	if name == "hell_rain":
		var marked := 0
		for mark in snap.hell_rain:
			var mp := _milli_screen(mark.pos)
			_draw_world_disk(mark.pos, float(Balance.HELL_RAIN_RADIUS), Color(tell.r, tell.g, tell.b, 0.32), tell, 2.0)
			if font and marked == 0:
				_plaque(font, mp + Vector2(-22, -16), "MOVE", Color(0.15, 0.02, 0.02), tell, 14)
			marked += 1
	elif name == "cleave":
		var origin: Vector2i = tg.get("from", boss)
		var end: Vector2i = tg.get("end", Vector2i.ZERO)
		if end == Vector2i.ZERO and origin != Vector2i.ZERO:
			var aim: Vector2i = tg.get("aim", snap.anchor)
			end = Fixed.approach(origin, aim, Balance.CLEAVE_LENGTH)
		if origin != Vector2i.ZERO and end != Vector2i.ZERO:
			draw_line(_milli_screen(origin), _milli_screen(end), Color(tell.r, tell.g, tell.b, 0.75), 22.0)
			if font:
				_plaque(font, _milli_screen(end) + Vector2(6, -8), "LEAVE", Color(0.16, 0.06, 0.02), tell, 14)
	elif name == "judgment":
		var tgt := _unit_pos(int(tg.get("target", 0)))
		if tgt != Vector2i.ZERO:
			draw_circle(_milli_screen(tgt), 32, Color(tell.r, tell.g, tell.b, 0.4))
			if font:
				_plaque(font, _milli_screen(tgt) + Vector2(-28, -40), "SHIELD", Color(0.12, 0.08, 0.02), tell, 14)
			if boss != Vector2i.ZERO:
				draw_line(_milli_screen(boss), _milli_screen(tgt), Color(tell.r, tell.g, tell.b, 0.9), 3.0)
	elif name == "grasp":
		if boss != Vector2i.ZERO:
			draw_arc(_milli_screen(boss), 78, 0, TAU, 32, Color(tell.r, tell.g, tell.b, 0.85), 3.0)
			draw_circle(_milli_screen(boss), 74, Color(tell.r, tell.g, tell.b, 0.18))
			for angel in snap.angels:
				if bool(angel.alive):
					draw_line(_milli_screen(boss), _milli_screen(angel.pos), Color(tell.r, tell.g, tell.b, 0.7), 3.0)
			if font:
				_plaque(font, _milli_screen(boss) + Vector2(-36, -88), "PHALANX", Color(0.12, 0.02, 0.06), tell, 14)
	if font:
		var remain := maxi(0, int(tg.get("until", 0)) - int(snap.tick))
		_plaque(font, _view_origin() + Vector2(8, 28), "%s  %0.1fs" % [str(TELL_LABEL.get(name, name)), float(remain) / 20.0], tell, Color(0.06, 0.04, 0.05, 0.92), 20)


func _draw_unit(u: Dictionary, col: Color, font, foe: bool) -> void:
	var p := _milli_screen(u.pos)
	var radius := 16.0 if str(u.subtype) == "lucifer" else (11.0 if foe else 10.0)
	if str(u.subtype) == "heavy" or str(u.subtype) == "elite":
		radius = 14.0
	if bool(u.get("spawning", false)):
		col.a = 0.55
		draw_arc(p, radius + 10, 0, TAU, 18, TELL_COLOR.echo, 3.0)
	if foe and int(u.id) == int(snap.focus_id):
		draw_arc(p, radius + 8, 0, TAU, 18, Color(1, 1, 1, 0.9), 2.0)
	var foot := PackedVector2Array([
		p + Vector2(0, -radius * 0.55),
		p + Vector2(radius * 1.15, 0),
		p + Vector2(0, radius * 0.55),
		p + Vector2(-radius * 1.15, 0),
	])
	draw_colored_polygon(foot, Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.85))
	draw_circle(p, radius * 0.82, col)
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
	var w := 36.0
	draw_rect(Rect2(p + Vector2(-w * 0.5 - 1, -radius - 12), Vector2(w + 2, 7)), Color(0, 0, 0, 0.75))
	var hp_col := Color(0.4, 0.88, 0.45) if not foe else Color(0.95, 0.28, 0.22)
	if not foe and hp / mx < 0.35:
		hp_col = Color(0.95, 0.32, 0.22)
	draw_rect(Rect2(p + Vector2(-w * 0.5, -radius - 11), Vector2(w * hp / mx, 5)), hp_col)
	if font and (str(u.subtype) == "lucifer" or str(u.subtype) == "elite" or not foe):
		var tag := str(u.name)[0] if not foe else str(u.subtype)
		if str(u.subtype) == "lucifer":
			tag = "L"
		draw_string(font, p + Vector2(-4, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.04, 0.08))
	if foe and bool(u.get("spawning", false)) and font:
		_plaque(font, p + Vector2(-22, 24), "ECHO", TELL_COLOR.echo, Color(0.1, 0.05, 0.02, 0.9), 12)


func _room_color(kind: String, here: bool) -> Color:
	var c := Color(0.16, 0.15, 0.2)
	match kind:
		"start":
			c = Color(0.16, 0.2, 0.3)
		"fork":
			c = Color(0.28, 0.22, 0.4)
		"trapped":
			c = Color(0.42, 0.22, 0.12)
		"summoned":
			c = Color(0.46, 0.14, 0.16)
		"cursed":
			c = Color(0.32, 0.14, 0.42)
		"cross":
			c = Color(0.2, 0.2, 0.24)
		"altar":
			c = Color(0.42, 0.32, 0.12)
		"seal":
			c = Color(0.16, 0.28, 0.42)
		"font":
			c = Color(0.12, 0.34, 0.3)
		"gallery":
			c = Color(0.32, 0.16, 0.12)
		"throne":
			c = Color(0.4, 0.08, 0.12)
		"corridor":
			c = Color(0.12, 0.12, 0.16)
	if here:
		c = c.lightened(0.08)
	else:
		c = c.darkened(0.45)
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


func _view_origin() -> Vector2:
	return Vector2(INSET_L, INSET_T)


func _inset_b() -> float:
	if size.x < NARROW_W and size.x >= 400.0:
		return NARROW_INSET_B
	return INSET_B


func _view_size() -> Vector2:
	return Vector2(maxi(size.x - INSET_L - INSET_R, 100), maxi(size.y - INSET_T - _inset_b(), 100))


func playfield_rect() -> Rect2:
	return Rect2(_view_origin(), _view_size())


## Tile corner (col, row) in unzoomed iso pixels. Width:height of each step is 2:1.
static func iso_of_tile(col: float, row: float) -> Vector2:
	return Vector2((col - row) * (TILE_W * 0.5), (col + row) * (TILE_H * 0.5))


## Inverse of iso_of_tile. (a + b) / 2, (b - a) / 2 with a = x/(w/2), b = y/(h/2).
static func tile_of_iso(p: Vector2) -> Vector2:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Painter depth. Larger values are closer to the camera (lower on screen) and draw later.
static func iso_depth(col: float, row: float) -> float:
	return col + row


func _iso_milli(m: Vector2i) -> Vector2:
	return iso_of_tile(float(m.x) / 1000.0, float(m.y) / 1000.0)


func _milli_screen(m: Vector2i) -> Vector2:
	return _view_origin() + (_iso_milli(m) - cam) * zoom


func _screen_to_milli(screen: Vector2) -> Vector2i:
	var iso: Vector2 = (screen - _view_origin()) / zoom + cam
	var t := tile_of_iso(iso)
	return Vector2i(roundi(t.x * 1000.0), roundi(t.y * 1000.0))


func _tile_center_screen(tx: int, ty: int) -> Vector2:
	return _milli_screen(Fixed.tile_center(Vector2i(tx, ty)))


func _iso_screen_delta(a: Vector2i, b: Vector2i) -> Vector2:
	return _milli_screen(b) - _milli_screen(a)


func _iso_bounds(rect: Rect2i) -> Rect2:
	var x0 := float(rect.position.x)
	var y0 := float(rect.position.y)
	var x1 := x0 + float(rect.size.x)
	var y1 := y0 + float(rect.size.y)
	var pts: Array[Vector2] = [
		iso_of_tile(x0, y0),
		iso_of_tile(x1, y0),
		iso_of_tile(x0, y1),
		iso_of_tile(x1, y1),
	]
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.y)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.y)
	return Rect2(lo, hi - lo)


func _focus_rect() -> Rect2i:
	var map = game.sim.map
	var room = map.by_id.get(str(snap.party_room), {})
	if room.is_empty():
		var t := Fixed.tile_of(snap.anchor)
		return Rect2i(t.x - 7, t.y - 7, 14, 14)
	if bool(room.corridor):
		var t2 := Fixed.tile_of(snap.anchor)
		return Rect2i(t2.x - 8, t2.y - 5, 17, 11)
	var rect: Rect2i = room.rect
	return rect.grow(1)


func _clamp_cam(desired: float, lo: float, hi: float, span: float) -> float:
	if hi - lo >= span:
		return desired
	return clampf(desired, hi - span, lo)


func _cull_rect() -> Rect2i:
	var span := _view_size() / zoom
	var min_c := 1000000.0
	var min_r := 1000000.0
	var max_c := -1000000.0
	var max_r := -1000000.0
	var corners: Array[Vector2] = [cam, cam + Vector2(span.x, 0.0), cam + Vector2(0.0, span.y), cam + span]
	for corner in corners:
		var t := tile_of_iso(corner)
		min_c = minf(min_c, t.x)
		min_r = minf(min_r, t.y)
		max_c = maxf(max_c, t.x)
		max_r = maxf(max_r, t.y)
	var x0 := int(floor(min_c)) - 2
	var y0 := int(floor(min_r)) - 2
	var x1 := int(ceil(max_c)) + 3
	var y1 := int(ceil(max_r)) + 3
	return Rect2i(x0, y0, maxi(x1 - x0, 1), maxi(y1 - y0, 1))


## Diamond under the finger if it is walkable, otherwise the nearest walkable tile within 16.
func _nearest_walkable(milli: Vector2i) -> Vector2i:
	var origin := Fixed.tile_of(milli)
	if game.sim.map.at(origin) >= 0:
		return origin
	var best := Vector2i(-1, -1)
	var best_d := 16001
	for dy in range(-16, 17):
		for dx in range(-16, 17):
			var t := origin + Vector2i(dx, dy)
			if game.sim.map.at(t) < 0:
				continue
			var d := Fixed.dist(milli, Fixed.tile_center(t))
			if d < best_d:
				best_d = d
				best = t
	if best_d > 16000:
		return Vector2i(-1, -1)
	return best


func _draw_tile_diamond(center: Vector2, col: Color, inset: float = 0.96) -> void:
	var hw := TILE_W * 0.5 * zoom * inset
	var hh := TILE_H * 0.5 * zoom * inset
	var pts := PackedVector2Array([
		center + Vector2(0, -hh),
		center + Vector2(hw, 0),
		center + Vector2(0, hh),
		center + Vector2(-hw, 0),
	])
	draw_colored_polygon(pts, col)
	var hi := col.lightened(0.28)
	var lo := col.darkened(0.35)
	var edge := maxf(1.25, 1.6 * zoom)
	draw_line(pts[0], pts[1], hi, edge)
	draw_line(pts[0], pts[3], hi, edge)
	draw_line(pts[1], pts[2], lo, edge)
	draw_line(pts[3], pts[2], lo, edge)


func _world_radii(radius_milli: float) -> Vector2:
	var r := radius_milli / 1000.0 * sqrt(2.0) * zoom
	return Vector2(r * TILE_W * 0.5, r * TILE_H * 0.5)


func _draw_world_disk(center_milli: Vector2i, radius_milli: float, fill: Color, ring: Color = Color(0, 0, 0, 0), width: float = 2.0) -> void:
	if radius_milli <= 0.0:
		return
	var center := _milli_screen(center_milli)
	var radii := _world_radii(radius_milli)
	var n := 28
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(a) * radii.x, sin(a) * radii.y)
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	if ring.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, ring, width)


func _draw_actors(font) -> void:
	var actors: Array = []
	for trap in snap.traps:
		actors.append({"depth": int(trap.pos.x) + int(trap.pos.y), "kind": "trap", "u": trap})
	for foe in snap.foes:
		actors.append({"depth": int(foe.pos.x) + int(foe.pos.y), "kind": "foe", "u": foe})
	for angel in snap.angels:
		actors.append({"depth": int(angel.pos.x) + int(angel.pos.y), "kind": "angel", "u": angel})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.depth) < int(b.depth)
	)
	for actor in actors:
		var u: Dictionary = actor.u
		if str(actor.kind) == "trap":
			_draw_trap_actor(u, font)
		elif str(actor.kind) == "foe":
			_draw_unit(u, _foe_color(str(u.subtype)), font, true)
			var blink = u.get("blink", {})
			if blink is Dictionary and not blink.is_empty():
				draw_line(_milli_screen(u.pos), _milli_screen(blink.pos), Color(1, 0.3, 0.8, 0.8), 2.0)
				draw_circle(_milli_screen(blink.pos), 10, Color(1, 0.3, 0.8, 0.35))
		elif not bool(u.alive):
			_draw_unit(u, Color(0.25, 0.25, 0.28), font, false)
			if bool(u.get("downed", false)):
				var p_down := _milli_screen(u.pos)
				var left := int(u.get("downed_left", 0))
				var frac := float(left) / float(maxi(int(snap.get("downed_ticks", 60)), 1))
				draw_arc(p_down, 18.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(1.0, 0.45, 0.18), 3.0)
				if font:
					draw_string(font, p_down + Vector2(-12, 28), "%0.1f" % (float(left) / 20.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.62, 0.3))
		else:
			var col: Color = HERO_COLOR.get(str(u.subtype), Color.WHITE)
			if int(u.id) == int(snap.focus_id):
				draw_circle(_milli_screen(u.pos), 22, Color(1, 1, 1, 0.15))
			_draw_unit(u, col, font, false)


func _draw_trap_actor(trap: Dictionary, font) -> void:
	var c3 := _milli_screen(trap.pos)
	var kind := str(trap.subtype)
	var tc: Color = TELL_COLOR.get(kind, Color(0.9, 0.8, 0.4))
	if not bool(trap.armed):
		tc.a = 0.55
	_draw_trap_glyph(c3, kind, tc)
	if bool(trap.get("echo", false)) and not bool(trap.armed):
		var arm_at := int(trap.get("arm_at", 0))
		var remain_a := maxi(0, arm_at - int(snap.tick))
		var frac_a := 1.0 - float(remain_a) / float(maxi(Balance.BOSS_TELL, 1))
		draw_arc(c3, 22.0, -PI * 0.5, -PI * 0.5 + TAU * frac_a, 24, TELL_COLOR.echo, 4.0)
		if font:
			_plaque(font, c3 + Vector2(-36, -22), "ECHO  %0.1fs" % (float(remain_a) / 20.0), TELL_COLOR.echo, Color(0.08, 0.04, 0.02, 0.9), 14)
	elif font:
		_plaque(font, c3 + Vector2(-28, 26), str(TELL_LABEL.get(kind, kind)), tc, Color(0.05, 0.04, 0.03, 0.88), 13)


func _guide_milli() -> Vector2i:
	if snap.is_empty() or game == null:
		return Vector2i.ZERO
	var stake := str(snap.get("stake_id", ""))
	if stake != "" and not _stake_done(stake) and int(snap.get("boss_hp_max", 0)) <= 0:
		var node: Vector2i = game.sim.map.node_tile("%s:rear" % stake)
		if node.x >= 0:
			return Fixed.tile_center(node)
	if snap.path is Array and not snap.path.is_empty():
		var step: Vector2i = snap.path[mini(3, snap.path.size() - 1)]
		return Fixed.tile_center(step)
	var best := Vector2i.ZERO
	var best_d := 1 << 30
	var anchor: Vector2i = snap.anchor
	for ex in snap.exits:
		var c: Vector2i = Fixed.tile_center(ex.tile)
		var d := Fixed.dist(anchor, c)
		if d < best_d:
			best_d = d
			best = c
	if best == Vector2i.ZERO or best_d < 400:
		return Vector2i.ZERO
	return best


func _stake_done(stake: String) -> bool:
	match stake:
		"seal":
			return bool(snap.get("seal_done", false))
		"font":
			return bool(snap.get("font_done", false))
		"altar":
			return bool(snap.get("altar_done", false))
		_:
			return false


func _draw_guide() -> void:
	var target := _guide_milli()
	if target == Vector2i.ZERO:
		return
	var dir := _iso_screen_delta(snap.anchor, target)
	if dir.length() < 18.0:
		return
	dir = dir.normalized()
	var from := _milli_screen(snap.anchor)
	var base := from + dir * 30.0
	var tip := from + dir * 76.0
	var side := Vector2(-dir.y, dir.x)
	draw_line(from + dir * 16.0, base, Color(0.98, 0.82, 0.22, 0.85), 3.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side * 11.0, base - side * 11.0]), Color(0.98, 0.84, 0.28, 0.96))


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


func _draw_casts(font) -> void:
	if font == null:
		return
	var heroes: Dictionary = snap.get("heroes", {})
	for angel in snap.angels:
		if not bool(angel.alive):
			continue
		var casting := str(heroes.get(str(angel.subtype), {}).get("casting", ""))
		if casting == "":
			continue
		var col: Color = HERO_COLOR.get(str(angel.subtype), Color.WHITE)
		_plaque(font, _milli_screen(angel.pos) + Vector2(-46, -30), "%s  %s" % [str(angel.name), Balance.ability_label(casting)], col, Color(0.05, 0.04, 0.08, 0.92), 14)


func _draw_trap_glyph(c: Vector2, kind: String, col: Color) -> void:
	match kind:
		"spike":
			var pts := PackedVector2Array([c + Vector2(0, -13), c + Vector2(12, 10), c + Vector2(-12, 10)])
			draw_colored_polygon(pts, col)
		"snare":
			draw_line(c + Vector2(-11, -11), c + Vector2(11, 11), col, 3.0)
			draw_line(c + Vector2(-11, 11), c + Vector2(11, -11), col, 3.0)
		"hellflame":
			draw_circle(c, 10, col)
			draw_arc(c, 16, 0, TAU, 18, Color(1.0, 0.8, 0.25), 2.0)
		_:
			draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), col)


func _draw_fog_edge(tx: int, ty: int, vis: Dictionary, map, center: Vector2) -> void:
	var hw := TILE_W * 0.5 * zoom
	var hh := TILE_H * 0.5 * zoom
	var top := center + Vector2(0, -hh)
	var right := center + Vector2(hw, 0)
	var bottom := center + Vector2(0, hh)
	var left := center + Vector2(-hw, 0)
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var edges: Array = [top, right, bottom, left, top]
	var ink := Color(0.015, 0.012, 0.02, 0.95)
	for i in dirs.size():
		var d: Vector2i = dirs[i]
		var n := Vector2i(tx, ty) + d
		var hidden := true
		if n.x >= 0 and n.y >= 0 and n.x < map.width and n.y < map.height:
			var nri := int(map.at(n))
			if nri >= 0 and vis.has(str(map.rooms[nri].id)):
				hidden = false
		if not hidden:
			continue
		draw_line(edges[i], edges[i + 1], ink, maxf(3.0, 4.0 * zoom))


func _plaque(font, at: Vector2, text: String, fg: Color, bg: Color, sz: int) -> void:
	if font == null or text == "":
		return
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
	draw_rect(Rect2(at + Vector2(-5, -sz + 1), Vector2(ts.x + 10, float(sz) + 8)), bg)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, fg)
