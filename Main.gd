extends Control
## Combat Lab entry. The simulation lives in sim/; this scene only hosts it.


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	var game := GameRoot.new()
	game.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game)
	print("Celestial Q Siege v%s" % ProjectSettings.get_setting("application/config/version"))
