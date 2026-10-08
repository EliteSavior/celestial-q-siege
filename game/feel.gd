extends Control
## Hit, heal, and ability feedback. Reads snapshots. Never calls submit().

const SfxScript = preload("res://game/sfx.gd")

var game
var sfx
var motes: Array = []
var vignette := Color(0, 0, 0, 0)
var _seen := {}
var _cast := {}
var _tell := ""
var _outcome := ""
var _rising := false
var _echo := false


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sfx != null:
		return
	sfx = SfxScript.new()
	sfx.name = "Sfx"
	add_child(sfx)
	sfx.setup()


func reset() -> void:
	motes.clear()
	vignette = Color(0, 0, 0, 0)
	_seen.clear()
	_cast.clear()
	_tell = ""
	_outcome = ""
	_rising = false
	_echo = false
	if sfx:
		sfx.reset()
	queue_redraw()


func follow(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	for pop in snap.popups:
		var key := "%s|%s|%s" % [pop.tick, pop.text, pop.pos]
		if _seen.has(key):
			continue
		_seen[key] = true
		var kind := str(pop.kind)
		var hit := kind == "bad" or kind == "dmg"
		_burst(pop.pos, Color(1.0, 0.4, 0.3) if hit else Color(0.5, 1.0, 0.62))
		if sfx:
			sfx.play("hit" if hit else "heal")
	var heroes: Dictionary = snap.get("heroes", {})
	for subtype in heroes.keys():
		var casting := str(heroes[subtype].get("casting", ""))
		var prev := str(_cast.get(subtype, ""))
		if casting != "" and casting != prev:
			var pos := _hero_pos(snap, str(subtype))
			if pos != Vector2i.ZERO:
				_burst(pos, Color(0.95, 0.88, 0.45))
			if sfx:
				sfx.play("ability")
		_cast[subtype] = casting
	var tell := str(snap.get("telegraph", {}).get("name", ""))
	if tell != "" and tell != _tell:
		if sfx:
			sfx.play("warn")
		vignette = Color(1.0, 0.4, 0.15, 0.18)
	_tell = tell
	var rising := int(snap.get("transform_until", 0)) > int(snap.tick)
	if rising and not _rising:
		if sfx:
			sfx.play("warn")
		vignette = Color(0.75, 0.05, 0.08, 0.28)
	_rising = rising
	var echo := false
	for foe in snap.get("foes", []):
		if bool(foe.get("spawning", false)):
			echo = true
			break
	if echo and not _echo:
		if sfx:
			sfx.play("warn")
	_echo = echo
	var out := str(snap.outcome)
	if out != "" and out != _outcome:
		if sfx:
			sfx.play("victory" if out == "angels" else "defeat")
		vignette = Color(0.95, 0.78, 0.28, 0.26) if out == "angels" else Color(0.55, 0.04, 0.06, 0.34)
	_outcome = out
	if _seen.size() > 400:
		_seen.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if motes.is_empty() and vignette.a <= 0.01:
		return
	var keep: Array = []
	for m in motes:
		m.life = float(m.life) - delta
		m.p = m.p + m.v * delta
		if float(m.life) > 0.0:
			keep.append(m)
	motes = keep
	if vignette.a > 0.0:
		vignette.a = maxf(0.0, vignette.a - delta * 0.85)
	queue_redraw()


func _draw() -> void:
	if vignette.a > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), vignette)
	for m in motes:
		var life := float(m.life)
		var span := maxf(float(m.max_life), 0.01)
		var a := clampf(life / span, 0.0, 1.0)
		var c: Color = m.color
		c.a = a
		draw_circle(m.p, float(m.r) * (1.5 - 0.5 * a), c)


func _burst(milli: Vector2i, color: Color) -> void:
	if motes.size() > 80:
		return
	var origin := _screen(milli)
	for i in 7:
		var ang := float(i) / 7.0 * TAU
		motes.append({
			"p": origin,
			"v": Vector2(cos(ang), sin(ang)) * 64.0,
			"life": 0.32,
			"max_life": 0.32,
			"r": 4.5,
			"color": color,
		})


func _screen(milli: Vector2i) -> Vector2:
	if game != null and game.board != null:
		return game.board._milli_screen(milli)
	return Vector2(640, 360)


func _hero_pos(snap: Dictionary, subtype: String) -> Vector2i:
	for angel in snap.angels:
		if str(angel.subtype) == subtype:
			return angel.pos
	return Vector2i.ZERO
