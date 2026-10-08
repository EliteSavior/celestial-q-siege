extends Control
## Reads a fogged snapshot plus the static map. Never writes sim state.

const TILE := 48.0
const INSET_L := 196.0
const INSET_T := 112.0
const INSET_B := 236.0

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
var cam_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)


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
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(view_pos, view_size))
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
			var here := str(room.id) == str(snap.party_room)
			var col := _room_color(str(room.kind), here)
			draw_rect(Rect2(p, Vector2(TILE - 1, TILE - 1)), col)
			_draw_fog_edge(tx, ty, vis, map, p)
	for room in map.rooms:
		if room.corridor or not vis.has(str(room.id)):
			continue
		for node_name in room.nodes.keys():
			var t: Vector2i = room.nodes[node_name]
			var c := _tile_screen(t.x, t.y) + Vector2(TILE * 0.5, TILE * 0.5)
			var stake_node := str(room.kind) in ["altar", "seal", "font"] and str(node_name) == "rear"
			if stake_node:
				var diamond := PackedVector2Array([
					c + Vector2(0, -14), c + Vector2(12, 0), c + Vector2(0, 14), c + Vector2(-12, 0),
				])
				draw_colored_polygon(diamond, Color(0.98, 0.78, 0.22, 0.95))
				if font:
					_plaque(font, c + Vector2(-28, -18), "STAKE", Color(0.15, 0.1, 0.02), Color(0.98, 0.82, 0.3), 13)
			else:
				draw_circle(c, 5, Color(0.7, 0.64, 0.5, 0.45))
	if snap.path is Array:
		var prev := _milli_screen(snap.anchor)
		for tile in snap.path:
			var p2 := _tile_screen(tile.x, tile.y) + Vector2(TILE * 0.5, TILE * 0.5)
			draw_line(prev, p2, Color(0.95, 0.9, 0.6, 0.45), 2.0)
			prev = p2
	for zone in snap.zones:
		var colz := Color(0.95, 0.35, 0.12, 0.28) if str(zone.subtype) == "hell" else Color(0.95, 0.85, 0.4, 0.28)
		draw_circle(_milli_screen(zone.pos), float(zone.radius) / 1000.0 * TILE, colz)
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
	for trap in snap.traps:
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
	_draw_kits(font)
	_draw_transform(font)
	_draw_telegraphs(font)
	for foe in snap.foes:
		_draw_unit(foe, _foe_color(str(foe.subtype)), font, true)
		var blink = foe.get("blink", {})
		if blink is Dictionary and not blink.is_empty():
			draw_line(_milli_screen(foe.pos), _milli_screen(blink.pos), Color(1, 0.3, 0.8, 0.8), 2.0)
			draw_circle(_milli_screen(blink.pos), 10, Color(1, 0.3, 0.8, 0.35))
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
		var hint := str(ex.hint)
		var hc: Color = HINT_COLOR.get(hint, Color(1.0, 0.92, 0.7))
		draw_rect(Rect2(sp, Vector2(TILE - 1, TILE - 1)), Color(hc.r, hc.g, hc.b, 0.34))
		draw_rect(Rect2(sp, Vector2(TILE - 1, 5)), hc)
		if font:
			if hint != "":
				_plaque(font, sp + Vector2(2, -8), hint, Color(0.08, 0.06, 0.04), hc, 15)
			draw_string(font, sp + Vector2(4, 28), str(ex.label), HORIZONTAL_ALIGNMENT_LEFT, 140, 12, Color(1, 0.97, 0.88))
	for pop in snap.popups:
		if font:
			var age := int(snap.tick) - int(pop.tick)
			var colp := Color(1, 0.45, 0.4) if str(pop.kind) == "bad" else Color(0.6, 1, 0.65)
			draw_string(font, _milli_screen(pop.pos) + Vector2(-8, -18 - age), str(pop.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colp)
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
			draw_circle(mp, Balance.HELL_RAIN_RADIUS / 1000.0 * TILE, Color(tell.r, tell.g, tell.b, 0.32))
			draw_arc(mp, Balance.HELL_RAIN_RADIUS / 1000.0 * TILE, 0, TAU, 24, tell, 2.0)
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
		_plaque(font, Vector2(INSET_L + 8, INSET_T + 28), "%s  %0.1fs" % [str(TELL_LABEL.get(name, name)), float(remain) / 20.0], tell, Color(0.06, 0.04, 0.05, 0.92), 20)


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


func _draw_fog_edge(tx: int, ty: int, vis: Dictionary, map, p: Vector2) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n := Vector2i(tx, ty) + d
		var hidden := true
		if n.x >= 0 and n.y >= 0 and n.x < map.width and n.y < map.height:
			var nri := int(map.at(n))
			if nri >= 0 and vis.has(str(map.rooms[nri].id)):
				hidden = false
		if not hidden:
			continue
		var ink := Color(0.015, 0.012, 0.02, 0.92)
		if d.x > 0:
			draw_rect(Rect2(p.x + TILE - 6, p.y, 5, TILE - 1), ink)
		elif d.x < 0:
			draw_rect(Rect2(p.x, p.y, 5, TILE - 1), ink)
		elif d.y > 0:
			draw_rect(Rect2(p.x, p.y + TILE - 6, TILE - 1, 5), ink)
		else:
			draw_rect(Rect2(p.x, p.y, TILE - 1, 5), ink)


func _plaque(font, at: Vector2, text: String, fg: Color, bg: Color, sz: int) -> void:
	if font == null or text == "":
		return
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
	draw_rect(Rect2(at + Vector2(-5, -sz + 1), Vector2(ts.x + 10, float(sz) + 8)), bg)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, fg)
