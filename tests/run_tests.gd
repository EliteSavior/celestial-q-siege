extends SceneTree

func _initialize() -> void:
	var script = load("res://tests/sim_tests.gd")
	if script == null:
		print("failed to load tests")
		quit(1)
		return
	var tests = script.new()
	quit(int(tests.run_all()))
