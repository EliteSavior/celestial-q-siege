extends Control
## Placeholder main scene for Celestial Q Siege.
## Build-pipeline scaffolding only: it just shows the title so we can confirm
## that Godot -> Android APK export works. No game logic lives here yet.


func _ready() -> void:
	$TitleLabel.text = "Celestial Q Siege"
	print("Celestial Q Siege scaffold v%s started" % ProjectSettings.get_setting("application/config/version"))
