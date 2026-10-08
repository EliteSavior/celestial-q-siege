extends SceneTree

func _initialize() -> void:
	var script = load("res://tests/sim_tests.gd")
	if script == null or not script.can_instantiate():
		print("failed to load tests")
		quit(1)
		return
	var tests = script.new()
	tests.host = self
	quit(int(tests.run_all()))
