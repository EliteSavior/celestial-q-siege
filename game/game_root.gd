extends Control
class_name GameRoot
## Owns the sim and the views. Input becomes commands; the sim stays authoritative.

const BoardScript = preload("res://game/board_view.gd")
const HudScript = preload("res://game/hud.gd")
const FeelScript = preload("res://game/feel.gd")

var sim: CombatSim
var board
var juice
var hud: Control
var acc := 0.0
var speed := 1.0
var paused := false
var briefing := true
var _tap_frame := -1
var _booted := false
## View-only. Arming a single-target rite does not touch the sim.
var armed := ""

const ALLY_ARM := ["single_heal", "slow_revive", "emergency_res"]
const FOE_ARM := ["taunt", "strike", "burst", "sunstrike"]


func _ready() -> void:
	boot()


func boot() -> void:
	if _booted:
		return
	_booted = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim = CombatSim.new()
	board = BoardScript.new()
	board.game = self
	# STOP so the play field is the control Godot's picker hits for a map tap.
	# ScreenTouch is delivered to that control and never reaches _unhandled_input
	# once any full-rect STOP node (the old root) claims it.
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	juice = FeelScript.new()
	juice.game = self
	juice.set_anchors_preset(Control.PRESET_FULL_RECT)
	juice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(juice)
	juice.setup()
	hud = HudScript.new()
	hud.game = self
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if juice:
		juice.follow(snap)
	hud.refresh(snap)


func _unhandled_input(event: InputEvent) -> void:
	if briefing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)
		return
	if event is InputEventScreenDrag:
		note_drag(event.position)
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		note_drag(event.position)
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF:
		return
	note_tap(pos)


func note_tap(screen: Vector2) -> void:
	if briefing or board == null:
		return
	var frame := Engine.get_process_frames()
	if frame == _tap_frame:
		return
	_tap_frame = frame
	board.handle_tap(screen)


func note_drag(screen: Vector2) -> void:
	if briefing or board == null:
		return
	board.handle_drag(screen)


func needs_target(ability: String) -> bool:
	return ability in ALLY_ARM or ability in FOE_ARM


func arm(ability: String) -> void:
	if armed == ability:
		armed = ""
	else:
		armed = ability


func cast_armed(args: Dictionary) -> void:
	if armed == "":
		return
	var ability := armed
	armed = ""
	var payload := args.duplicate()
	payload["name"] = ability
	command("ability", payload)


func command(type: String, args: Dictionary = {}) -> void:
	if sim == null or briefing or sim.outcome != "":
		return
	sim.submit(type, args, "angel", 1)


func restart() -> void:
	_reset_run(false)


func title() -> void:
	_reset_run(true)


func _reset_run(to_title: bool) -> void:
	sim.reset()
	acc = 0.0
	speed = 1.0
	paused = false
	briefing = to_title
	if board:
		board.cam_ready = false
	if juice:
		juice.reset()
	armed = ""
	if hud and hud.has_method("on_new_run"):
		hud.on_new_run(to_title)


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
			restart()
