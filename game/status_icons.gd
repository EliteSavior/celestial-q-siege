class_name StatusRow
extends Control
## WoW-style buff and debuff icons. Drawn from snapshot rows only.

var rows: Array = []
## Incremented every time an icon is actually drawn. Tests read this.
static var draws := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var x := 0.0
	var box := 18.0
	for st in rows:
		if typeof(st) != TYPE_DICTIONARY:
			continue
		if x + box > size.x + 0.5:
			break
		draw_icon(self, Rect2(x, 0, box, box), st)
		x += box + 2.0


static func draw_icon(canvas: CanvasItem, rect: Rect2, st: Dictionary) -> void:
	draws += 1
	var id := str(st.get("id", ""))
	var debuff := str(st.get("polarity", "")) == "debuff"
	var border := Color(0.95, 0.2, 0.22) if debuff else Color(0.96, 0.8, 0.28)
	if not debuff and id in ["shield", "safe", "phalanx", "wall"]:
		border = Color(0.42, 0.9, 0.5)
	var bg := Color(0.16, 0.04, 0.05, 0.95) if debuff else Color(0.08, 0.1, 0.05, 0.95)
	canvas.draw_rect(rect, bg)
	canvas.draw_rect(rect, border, false, 2.0)
	_symbol(canvas, id, rect.grow(-3.0), Color(0.97, 0.95, 0.88))
	var total := int(st.get("total", 0))
	var left := int(st.get("left", 0))
	if total > 1 and left > 0 and left < total:
		var spent := 1.0 - clampf(float(left) / float(total), 0.0, 1.0)
		_sweep(canvas, rect, spent)
	if not bool(st.get("cleansable", true)):
		var font := ThemeDB.fallback_font
		if font:
			canvas.draw_string(font, rect.position + Vector2(1, rect.size.y - 1), "no", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 9, Color(1, 0.86, 0.35))


static func _symbol(canvas: CanvasItem, id: String, rect: Rect2, ink: Color) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.38
	match id:
		"silence":
			canvas.draw_arc(c, r, 0, TAU, 12, ink, 1.6)
			canvas.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), ink, 1.8)
		"rot":
			canvas.draw_circle(c + Vector2(0, r * 0.15), r * 0.7, Color(0.45, 0.85, 0.28))
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 1.15),
				c + Vector2(r * 0.45, -r * 0.1),
				c + Vector2(-r * 0.45, -r * 0.1),
			]), Color(0.55, 0.95, 0.32))
		"mark":
			canvas.draw_arc(c, r, 0, TAU, 14, Color(1, 0.35, 0.32), 1.5)
			canvas.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(1, 0.35, 0.32), 1.4)
			canvas.draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(1, 0.35, 0.32), 1.4)
		"weaken":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, r),
				c + Vector2(-r, -r * 0.2),
				c + Vector2(r, -r * 0.2),
			]), Color(0.82, 0.55, 1.0))
		"corruption":
			canvas.draw_arc(c, r, 0.4, 5.4, 10, Color(0.72, 0.28, 0.95), 2.0)
			canvas.draw_arc(c, r * 0.45, 2.2, 6.0, 8, Color(0.85, 0.4, 1.0), 1.6)
		"snare":
			canvas.draw_line(c + Vector2(-r, -r * 0.35), c + Vector2(r, -r * 0.35), ink, 1.8)
			canvas.draw_line(c + Vector2(-r, r * 0.35), c + Vector2(r, r * 0.35), ink, 1.8)
			canvas.draw_line(c + Vector2(-r * 0.2, -r), c + Vector2(r * 0.15, r), ink, 1.4)
		"shield":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r),
				c + Vector2(r, -r * 0.2),
				c + Vector2(r * 0.7, r),
				c + Vector2(0, r * 0.45),
				c + Vector2(-r * 0.7, r),
				c + Vector2(-r, -r * 0.2),
			]), Color(0.45, 0.88, 1.0))
		"radiance":
			for i in 6:
				var a := TAU * float(i) / 6.0
				canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(1, 0.86, 0.3), 1.6)
			canvas.draw_circle(c, r * 0.28, Color(1, 0.9, 0.45))
		"taunt":
			canvas.draw_rect(Rect2(c + Vector2(-r * 0.18, -r), Vector2(r * 0.36, r * 1.35)), Color(1, 0.55, 0.2))
			canvas.draw_circle(c + Vector2(0, r * 0.72), r * 0.22, Color(1, 0.55, 0.2))
		"wall":
			canvas.draw_rect(Rect2(c + Vector2(-r, -r * 0.7), Vector2(r * 2.0, r * 0.4)), Color(0.7, 0.86, 1.0))
			canvas.draw_rect(Rect2(c + Vector2(-r, -r * 0.15), Vector2(r * 2.0, r * 0.4)), Color(0.55, 0.74, 0.95))
			canvas.draw_rect(Rect2(c + Vector2(-r, r * 0.4), Vector2(r * 2.0, r * 0.4)), Color(0.7, 0.86, 1.0))
		"block":
			canvas.draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.2), Vector2(r * 1.7, r * 0.45)), Color(1, 0.68, 0.35))
			canvas.draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(1, 0.68, 0.35), 2.0)
		"phalanx":
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r),
				c + Vector2(r, r * 0.2),
				c + Vector2(0, -r * 0.15),
				c + Vector2(-r, r * 0.2),
			]), Color(0.9, 0.94, 1.0))
		"safe":
			canvas.draw_arc(c, r, 0, TAU, 12, Color(0.7, 0.95, 0.82), 1.6)
			canvas.draw_line(c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, 0), Color(0.7, 0.95, 0.82), 1.6)
		_:
			canvas.draw_circle(c, r * 0.45, ink)


static func _sweep(canvas: CanvasItem, rect: Rect2, spent: float) -> void:
	if spent <= 0.02:
		return
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.55
	var steps := maxi(1, int(ceil(spent * 10.0)))
	var pts := PackedVector2Array()
	pts.append(center)
	pts.append(center + Vector2(0, -radius))
	for i in steps:
		var a := -PI * 0.5 + TAU * spent * float(i + 1) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.58))
