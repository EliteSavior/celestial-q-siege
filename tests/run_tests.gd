extends SceneTree

var tests
var phase := 0


func _initialize() -> void:
	var script = load("res://tests/sim_tests.gd")
	if script == null or not script.can_instantiate():
		print("failed to load tests")
		quit(1)
		return
	tests = script.new()
	tests.host = self


func _process(_dt: float) -> bool:
	if tests == null:
		quit(1)
		return true
	if phase == 0:
		phase = 1
		tests.run_all()
		if tests.after_frame.is_empty():
			_finish()
			return true
		return false
	for cb in tests.after_frame:
		cb.call()
	_finish()
	return true


func _finish() -> void:
	if tests.failures.is_empty():
		print("OK %d tests" % tests.ran)
		quit(0)
		return
	for f in tests.failures:
		print("FAIL ", f)
	print("%d failed" % tests.failures.size())
	quit(1)
