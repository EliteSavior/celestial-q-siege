extends Control
class_name GameRoot
## Owns the sim and the views. Input becomes commands; the sim stays authoritative.

const BoardScript = preload("res://game/board_view.gd")
const HudScript = preload("res://game/hud.gd")

var sim: CombatSim
var board
var hud: Control
var acc := 0.0
var speed := 1.0
var paused := false
var briefing := true
var _tap_frame := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim = CombatSim.new()
	board = BoardScript.new()
	board.game = self
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	hud = HudScript.new()
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	hud.build()


func _process(delta: float) -> void:
	if sim == null:
		return
	if not briefing and not paused and sim.outcome == "":
		acc += delta * speed
		var steps := 0
		while acc >= 0.05 and steps < 8:
			acc -= 0.05
			sim.tick_once()
			steps += 1
	var snap := sim.build_snapshot()
	board.snap = snap
	hud.refresh(snap)


func _unhandled_input(event: InputEvent) -> void:
	if briefing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)
		return
	if event is InputEventScreenDrag:
		board.handle_drag(event.position)
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		board.handle_drag(event.position)
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF:
		return
	var frame := Engine.get_process_frames()
	if frame == _tap_frame:
		return
	_tap_frame = frame
	board.handle_tap(pos)


func command(type: String, args: Dictionary = {}) -> void:
	if sim == null or sim.outcome != "":
		return
	sim.submit(type, args, "angel", 1)


func restart() -> void:
	sim.reset()
	acc = 0.0
	paused = false
	briefing = false
	board.cam_ready = false


func _key(code: Key) -> void:
	match code:
		KEY_1:
			command("shield")
		KEY_2:
			command("heal")
		KEY_3:
			command("cleanse")
		KEY_4:
			command("detect")
		KEY_5:
			command("burst")
		KEY_Z:
			command("scatter")
		KEY_X:
			command("phalanx")
		KEY_Q:
			command("stance", {"stance": CombatSim.STANCE_TIGHT})
		KEY_W:
			command("stance", {"stance": CombatSim.STANCE_SPREAD})
		KEY_E:
			command("stance", {"stance": CombatSim.STANCE_COLUMN})
		KEY_SPACE:
			paused = not paused
		KEY_R:
			if sim.outcome != "":
				restart()
