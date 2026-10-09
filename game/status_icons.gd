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


static func _rid(canvas: CanvasItem) -> RID:
	return canvas.get_canvas_item()


static func _box(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	RenderingServer.canvas_item_add_rect(_rid(canvas), rect, color)


static func _frame(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var a := rect.position
	var b := rect.position + Vector2(rect.size.x, 0)
	var c := rect.position + rect.size
	var d := rect.position + Vector2(0, rect.size.y)
	var item := _rid(canvas)
	RenderingServer.canvas_item_add_line(item, a, b, color, width)
	RenderingServer.canvas_item_add_line(item, b, c, color, width)
	RenderingServer.canvas_item_add_line(item, c, d, color, width)
	RenderingServer.canvas_item_add_line(item, d, a, color, width)


static func _seg(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	RenderingServer.canvas_item_add_line(_rid(canvas), a, b, color, width)


static func _dot(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	RenderingServer.canvas_item_add_circle(_rid(canvas), center, radius, color)


static func _poly(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	RenderingServer.canvas_item_add_polygon(_rid(canvas), points, colors)


static func _ring(canvas: CanvasItem, center: Vector2, radius: float, start: float, end_ang: float, color: Color, width: float) -> void:
	var n := 12
	var prev := center + Vector2(cos(start), sin(start)) * radius
	for i in range(1, n + 1):
		var t := start + (end_ang - start) * float(i) / float(n)
		var nxt := center + Vector2(cos(t), sin(t)) * radius
		_seg(canvas, prev, nxt, color, width)
		prev = nxt


static func draw_icon(canvas: CanvasItem, rect: Rect2, st: Dictionary) -> void:
	draws += 1
	var id := str(st.get("id", ""))
	var debuff := str(st.get("polarity", "")) == "debuff"
	var border := Color(0.95, 0.2, 0.22) if debuff else Color(0.96, 0.8, 0.28)
	if not debuff and id in ["shield", "safe", "phalanx", "wall"]:
		border = Color(0.42, 0.9, 0.5)
	var bg := Color(0.16, 0.04, 0.05, 0.95) if debuff else Color(0.08, 0.1, 0.05, 0.95)
	_box(canvas, rect, bg)
	_frame(canvas, rect, border, 2.0)
	_symbol(canvas, id, rect.grow(-3.0), Color(0.97, 0.95, 0.88))
	var total := int(st.get("total", 0))
	var left := int(st.get("left", 0))
	if total > 1 and left > 0 and left < total:
		var spent := 1.0 - clampf(float(left) / float(total), 0.0, 1.0)
		_sweep(canvas, rect, spent)
	if not bool(st.get("cleansable", true)):
		var font := ThemeDB.fallback_font
		if font:
			font.draw_string(_rid(canvas), rect.position + Vector2(1, rect.size.y - 1), "no", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 9, Color(1, 0.86, 0.35))


static func _symbol(canvas: CanvasItem, id: String, rect: Rect2, ink: Color) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.38
	match id:
		"silence":
			_ring(canvas, c, r, 0, TAU, ink, 1.6)
			_seg(canvas, c + Vector2(-r, r), c + Vector2(r, -r), ink, 1.8)
		"rot":
			_dot(canvas, c + Vector2(0, r * 0.15), r * 0.7, Color(0.45, 0.85, 0.28))
			_poly(canvas, PackedVector2Array([
				c + Vector2(0, -r * 1.15),
				c + Vector2(r * 0.45, -r * 0.1),
				c + Vector2(-r * 0.45, -r * 0.1),
			]), Color(0.55, 0.95, 0.32))
		"mark":
			_ring(canvas, c, r, 0, TAU, Color(1, 0.35, 0.32), 1.5)
			_seg(canvas, c + Vector2(-r, 0), c + Vector2(r, 0), Color(1, 0.35, 0.32), 1.4)
			_seg(canvas, c + Vector2(0, -r), c + Vector2(0, r), Color(1, 0.35, 0.32), 1.4)
		"weaken":
			_poly(canvas, PackedVector2Array([
				c + Vector2(0, r),
				c + Vector2(-r, -r * 0.2),
				c + Vector2(r, -r * 0.2),
			]), Color(0.82, 0.55, 1.0))
		"corruption":
			_ring(canvas, c, r, 0.4, 5.4, Color(0.72, 0.28, 0.95), 2.0)
			_ring(canvas, c, r * 0.45, 2.2, 6.0, Color(0.85, 0.4, 1.0), 1.6)
		"snare":
			_seg(canvas, c + Vector2(-r, -r * 0.35), c + Vector2(r, -r * 0.35), ink, 1.8)
			_seg(canvas, c + Vector2(-r, r * 0.35), c + Vector2(r, r * 0.35), ink, 1.8)
			_seg(canvas, c + Vector2(-r * 0.2, -r), c + Vector2(r * 0.15, r), ink, 1.4)
		"shield":
			_poly(canvas, PackedVector2Array([
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
				_seg(canvas, c, c + Vector2(cos(a), sin(a)) * r, Color(1, 0.86, 0.3), 1.6)
			_dot(canvas, c, r * 0.28, Color(1, 0.9, 0.45))
		"taunt":
			_box(canvas, Rect2(c + Vector2(-r * 0.18, -r), Vector2(r * 0.36, r * 1.35)), Color(1, 0.55, 0.2))
			_dot(canvas, c + Vector2(0, r * 0.72), r * 0.22, Color(1, 0.55, 0.2))
		"wall":
			_box(canvas, Rect2(c + Vector2(-r, -r * 0.7), Vector2(r * 2.0, r * 0.4)), Color(0.7, 0.86, 1.0))
			_box(canvas, Rect2(c + Vector2(-r, -r * 0.15), Vector2(r * 2.0, r * 0.4)), Color(0.55, 0.74, 0.95))
			_box(canvas, Rect2(c + Vector2(-r, r * 0.4), Vector2(r * 2.0, r * 0.4)), Color(0.7, 0.86, 1.0))
		"block":
			_box(canvas, Rect2(c + Vector2(-r * 0.85, -r * 0.2), Vector2(r * 1.7, r * 0.45)), Color(1, 0.68, 0.35))
			_seg(canvas, c + Vector2(0, -r), c + Vector2(0, r), Color(1, 0.68, 0.35), 2.0)
		"phalanx":
			_poly(canvas, PackedVector2Array([
				c + Vector2(0, -r),
				c + Vector2(r, r * 0.2),
				c + Vector2(0, -r * 0.15),
				c + Vector2(-r, r * 0.2),
			]), Color(0.9, 0.94, 1.0))
		"safe":
			_ring(canvas, c, r, 0, TAU, Color(0.7, 0.95, 0.82), 1.6)
			_seg(canvas, c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, 0), Color(0.7, 0.95, 0.82), 1.6)
		"dodge":
			_ring(canvas, c, r, 0.6, 5.2, Color(0.75, 0.95, 1.0), 1.8)
			_seg(canvas, c + Vector2(-r * 0.2, r * 0.4), c + Vector2(r * 0.55, -r * 0.45), Color(0.75, 0.95, 1.0), 1.8)
		_:
			_dot(canvas, c, r * 0.45, ink)


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
	_poly(canvas, pts, Color(0, 0, 0, 0.58))
