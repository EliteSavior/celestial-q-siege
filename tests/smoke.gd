extends SceneTree

func _initialize() -> void:
	print("smoke start")
	var map := DungeonMap.new()
	var errors: Array = map.validate()
	print("map errors ", errors.size())
	if not errors.is_empty():
		print(errors)
		print(map.ascii())
	var sim := CombatSim.new()
	var t0 := Time.get_ticks_msec()
	for i in 100:
		sim.tick_once()
	print("100 ticks ", Time.get_ticks_msec() - t0, " ms ", sim.debug_string())
	quit(0 if errors.is_empty() else 1)
