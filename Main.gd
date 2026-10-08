extends Control
## Combat Lab entry. The simulation lives in sim/; this scene only hosts it.

var _booted := false


func _ready() -> void:
	boot_host()


## Idempotent so a scene test can build the host before the tree flushes _ready.
## The root must ignore pointers: a full-rect STOP control is what Godot's GUI
## picker returns for any tap the HUD does not claim, and it marks ScreenTouch
## handled before _unhandled_input.
func boot_host() -> void:
	if _booted:
		return
	_booted = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		child.queue_free()
	var game := GameRoot.new()
	game.boot()
	game.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game)
	print("Celestial Q Siege v%s" % ProjectSettings.get_setting("application/config/version"))
