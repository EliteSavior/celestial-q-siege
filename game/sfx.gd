extends Node
## View-layer placeholder tones. Generated at runtime. Never read by the sim.


var played: Array = []
var _clips := {}
var _pool: Array = []
var _next := 0
var _silent := true


func setup() -> void:
	_silent = OS.has_feature("headless") or DisplayServer.get_name() == "headless"
	_clips = {
		"ui": _tone(920.0, 0.04, 0.32, "sine"),
		"hit": _tone(160.0, 0.07, 0.4, "noise"),
		"heal": _tone(680.0, 0.11, 0.26, "sine"),
		"ability": _tone(430.0, 0.09, 0.3, "sine"),
		"warn": _tone(230.0, 0.15, 0.3, "square"),
		"victory": _arpeggio([523.0, 659.0, 784.0], 0.11, 0.28),
		"defeat": _tone(140.0, 0.34, 0.3, "sine"),
	}
	if _silent:
		return
	for _i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -10.0
		add_child(player)
		_pool.append(player)


func play(id: String) -> void:
	if not _clips.has(id):
		return
	played.append(id)
	if played.size() > 24:
		played.pop_front()
	if _silent or _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	player.stream = _clips[id]
	player.play()


func reset() -> void:
	played.clear()


func _tone(freq: float, dur: float, vol: float, kind: String) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(int(rate * dur), 1)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for i in count:
		var env := 1.0 - float(i) / float(count)
		phase += TAU * freq / float(rate)
		var sample := 0.0
		if kind == "noise":
			var n := int(hash(i * 13 + int(freq * 10.0))) & 255
			sample = (float(n) / 127.5 - 1.0) * env * vol
		elif kind == "square":
			sample = (1.0 if sin(phase) >= 0.0 else -1.0) * env * vol
		else:
			sample = sin(phase) * env * vol
		_write(bytes, i, sample)
	return _wav(bytes, rate)


func _arpeggio(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var each := maxi(int(rate * step), 1)
	var bytes := PackedByteArray()
	bytes.resize(each * freqs.size() * 2)
	var index := 0
	for freq in freqs:
		var phase := 0.0
		for i in each:
			var env := 1.0 - float(i) / float(each)
			phase += TAU * float(freq) / float(rate)
			_write(bytes, index, sin(phase) * env * vol)
			index += 1
	return _wav(bytes, rate)


func _write(bytes: PackedByteArray, i: int, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 30000.0)
	bytes[i * 2] = v & 255
	bytes[i * 2 + 1] = (v >> 8) & 255


func _wav(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
