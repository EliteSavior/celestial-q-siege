extends Control
## Touch HUD. Commands go out through GameRoot; layout never mutates the sim.

var game
var _built := false
var _portraits := {}
var _hp := {}
var _bar := {}
var _stances := {}
var _scatter: Button
var _phalanx: Button
var _golden: ProgressBar
var _dark: ProgressBar
var _golden_l: Label
var _dark_l: Label
var _clock: Label
var _room: Label
var _feed: Label
var _boss: ProgressBar
var _boss_l: Label
var _pause: Button
var _speed: Button
var _passive: Label
var _brief: Control
var _end: Control
var _end_label: Label
var _inspect := ""
var _speed_i := 0
const _SPEEDS := [1.0, 2.0, 3.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	if _built:
		return
	_built = true
	_golden = _bar_at(Vector2(210, 10), 280, Color(0.85, 0.68, 0.25))
	_dark = _bar_at(Vector2(560, 10), 280, Color(0.55, 0.18, 0.62))
	_golden_l = _label(Vector2(210, 36), "Golden", 14)
	_dark_l = _label(Vector2(560, 36), "Dark", 14)
	_clock = _label(Vector2(860, 14), "0:00", 18)
	_room = _label(Vector2(210, 54), "", 14)
	_boss = _bar_at(Vector2(210, 78), 520, Color(0.75, 0.12, 0.12))
	_boss.visible = false
	_boss_l = _label(Vector2(740, 76), "", 14)
	_feed = _label(Vector2(210, 552), "", 14)
	_feed.size = Vector2(520, 60)
	_passive = _label(Vector2(740, 548), "", 13)
	_passive.size = Vector2(300, 48)
	_pause = _btn("Pause", Vector2(1060, 8), Vector2(90, 36), _on_pause)
	_speed = _btn("1x", Vector2(1160, 8), Vector2(70, 36), _on_speed)
	var names := ["Tight", "Spread", "Column"]
	for i in names.size():
		var b := _btn(names[i], Vector2(8, 560 + i * 0), Vector2(90, 48), _on_stance.bind(i))
		b.position = Vector2(210 + i * 98, 640)
		_stances[i] = b
	_scatter = _btn("Scatter", Vector2(520, 640), Vector2(100, 48), _on_scatter)
	_phalanx = _btn("Phalanx", Vector2(628, 640), Vector2(100, 48), _on_phalanx)
	var cmds := ["shield", "heal", "cleanse", "detect", "burst"]
	for i in cmds.size():
		var b2 := _btn(cmds[i].capitalize(), Vector2(748 + i * 104, 620), Vector2(100, 88), _on_cmd.bind(cmds[i]))
		_bar[cmds[i]] = b2
	_build_portraits()
	_build_brief()
	_build_end()


func refresh(snap: Dictionary) -> void:
	if not _built:
		return
	var max_e := float(maxi(int(snap.elixir_max), 1))
	_golden.max_value = max_e
	_dark.max_value = max_e
	_golden.value = float(snap.golden)
	_dark.value = float(snap.dark)
	var g_rate := float(snap.get("golden_regen", 0)) * float(Balance.TICK_HZ) / 1000.0
	var d_rate := float(snap.get("dark_regen", 0)) * float(Balance.TICK_HZ) / 1000.0
	_golden_l.text = "Golden  %0.1f/%0.0f  +%0.2f/s" % [float(snap.golden) / 1000.0, max_e / 1000.0, g_rate]
	_dark_l.text = "Dark  %0.1f/%0.0f  +%0.2f/s" % [float(snap.dark) / 1000.0, max_e / 1000.0, d_rate]
	var secs := int(snap.tick) / 20
	_clock.text = "%d:%02d" % [secs / 60, secs % 60]
	var room := str(snap.party_room)
	var lock := str(snap.route_lock)
	var stage_names := ["Descent", "Wards", "Sanctum", "Approach"]
	var stage_i := clampi(int(snap.get("stage", 0)), 0, stage_names.size() - 1)
	var marks := ""
	if bool(snap.get("seal_done", false)):
		marks += "  SEAL"
	if int(snap.get("cleanse_charges", 0)) > 0:
		marks += "  FONT"
	if int(snap.revive_charges) > 0:
		marks += "  REVIVE x%d" % int(snap.revive_charges)
	_room.text = "%s   %s   stance %s%s%s" % [
		stage_names[stage_i],
		room,
		snap.chosen_stance,
		"" if lock == "" else "   committed: " + lock,
		marks,
	]
	if bool(snap.corruption):
		_room.text += "   CORRUPTION"
	elif bool(snap.corruption_warn):
		_room.text += "   corruption creeps"
	var boss_max := int(snap.boss_hp_max)
	_boss.visible = boss_max > 0 and str(snap.phase) == "lucifer"
	_boss_l.visible = _boss.visible
	if _boss.visible:
		_boss.max_value = float(boss_max)
		_boss.value = float(snap.boss_hp)
		_boss_l.text = "Lucifer  %d" % int(snap.boss_hp)
	var lines: Array = snap.feed.slice(maxi(snap.feed.size() - 3, 0), snap.feed.size())
	var text := ""
	for row in lines:
		text += str(row.text) + "\n"
	_feed.text = text
	_style_stances(int(snap.stance))
	_scatter.text = "Scatter\n%s" % _cd(int(snap.scatter_cd))
	_phalanx.text = "Phalanx\n%s" % _cd(int(snap.phalanx_cd))
	_scatter.disabled = int(snap.scatter_cd) > 0
	_phalanx.disabled = int(snap.phalanx_cd) > 0
	if _inspect == "":
		_passive.text = ""
		for cmd in _bar.keys():
			var info: Dictionary = snap.bar[cmd]
			_apply_ability_button(_bar[cmd], info)
	else:
		_passive.text = _passive_line(_inspect)
		var kit: Array = snap.kits[_inspect]
		var i := 0
		for cmd2 in ["shield", "heal", "cleanse", "detect", "burst"]:
			var btn: Button = _bar[cmd2]
			if i < kit.size():
				btn.visible = true
				_apply_ability_button(btn, snap.abilities[str(kit[i])])
				_rewire_ability(btn, str(kit[i]))
			elif i == kit.size():
				btn.visible = true
				btn.text = "Back"
				btn.disabled = false
				_rewire_back(btn)
			else:
				btn.visible = false
			i += 1
	for subtype in _portraits.keys():
		var hs: Dictionary = snap.heroes[subtype]
		var btn3: Button = _portraits[subtype]
		var bar: ProgressBar = _hp[subtype]
		var flags := ""
		if bool(hs.silence):
			flags += " SIL"
		if bool(hs.rot):
			flags += " ROT"
		if bool(hs.mark):
			flags += " MARK"
		if bool(hs.get("weaken", false)):
			flags += " WEAK"
		if int(hs.get("radiance", 0)) > 0:
			flags += " R%d" % int(hs.radiance)
		if int(hs.get("shield", 0)) > 0:
			flags += " +%d" % int(hs.shield)
		if str(hs.get("casting", "")) != "":
			flags += " CAST"
		if bool(hs.get("downed", false)):
			bar.max_value = float(maxi(int(snap.get("downed_ticks", 60)), 1))
			bar.value = float(int(hs.get("downed_left", 0)))
			_paint(bar, Color(0.95, 0.48, 0.16))
			btn3.text = "%s\nDOWN %0.1fs%s" % [subtype.capitalize(), float(hs.get("downed_left", 0)) / 20.0, flags]
			btn3.modulate = Color(1.0, 0.78, 0.5)
		elif bool(hs.get("final_death", false)) or not bool(hs.alive):
			bar.max_value = float(maxi(int(hs.hp_max), 1))
			bar.value = 0
			_paint(bar, Color(0.28, 0.24, 0.24))
			btn3.text = "%s\nFALLEN" % subtype.capitalize()
			btn3.modulate = Color(0.45, 0.45, 0.45)
		else:
			var pct := int(hs.hp) * 100 / maxi(int(hs.hp_max), 1)
			var col := Color(0.35, 0.78, 0.42)
			if pct < 50:
				col = Color(0.86, 0.72, 0.28)
			if pct < 25:
				col = Color(0.86, 0.28, 0.22)
			bar.max_value = float(maxi(int(hs.hp_max), 1))
			bar.value = float(maxi(int(hs.hp), 0))
			_paint(bar, col)
			btn3.text = "%s\n%d%s" % [subtype.capitalize(), int(hs.hp), flags]
			btn3.modulate = Color(1, 1, 1)
	if str(snap.outcome) != "":
		_end.visible = true
		var secs2 := int(snap.tick) / 20
		if str(snap.outcome) == "angels":
			_end_label.text = "Lucifer falls.\nThe siege breaks.\n\n%d:%02d   angels standing   revives %d\nEcho was %s." % [
				secs2 / 60, secs2 % 60, int(snap.stats.revives), str(snap.echo_style)
			]
		else:
			_end_label.text = "The party is extinguished.\n\n%d:%02d   the siege holds." % [secs2 / 60, secs2 % 60]
	else:
		_end.visible = false


func _build_portraits() -> void:
	var order := ["michael", "raphael", "azrael", "uriel", "gabriel"]
	var colors := {
		"michael": Color(0.22, 0.32, 0.55),
		"raphael": Color(0.16, 0.38, 0.24),
		"azrael": Color(0.32, 0.18, 0.42),
		"uriel": Color(0.42, 0.28, 0.12),
		"gabriel": Color(0.4, 0.34, 0.14),
	}
	for i in order.size():
		var b := _btn(order[i].capitalize(), Vector2(8, 8 + i * 96), Vector2(188, 90), _on_portrait.bind(order[i]))
		var sb := b.get_theme_stylebox("normal").duplicate()
		sb.bg_color = colors[order[i]]
		b.add_theme_stylebox_override("normal", sb)
		var hover := b.get_theme_stylebox("hover")
		if hover:
			hover = hover.duplicate()
			hover.bg_color = colors[order[i]].lightened(0.15)
			b.add_theme_stylebox_override("hover", hover)
		_portraits[order[i]] = b
		_hp[order[i]] = _hp_bar(b, Vector2(10, 64), Vector2(168, 16))


func _build_brief() -> void:
	_brief = ColorRect.new()
	_brief.color = Color(0.04, 0.03, 0.07, 0.92)
	_brief.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brief.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_brief)
	var l := Label.new()
	l.text = "Celestial Q Siege\n\nFive angels, one squad. Each portrait is that angel's health. Tap the ground to move, a doorway to commit for 3 seconds, an enemy to focus.\n\nAttacks happen on their own. The five buttons spend Golden Elixir and route to the angel who owns them: Shield, Heal, Cleanse, Detect, Burst.\nTap a portrait for that angel's three actives. Drag while Uriel's beam is up to steer it.\nA downed angel has 3 seconds before the death is final. Heal, an emergency rite, or an altar charge can still reach them.\n\nThree stages. Each fork differs: still air (traps), skittering (summons), whispers (curses).\nEach stage has a stake. The seal locks out swarms. The font banks a cleanse. The altar banks a revive.\nElixir starts poor and compounds as you push. Idling in a cleared room feeds the demon.\n\nStance is the standing bet: Tight, Spread, or Column. Scatter Roll and Phalanx Push are the reactions.\n\nThen the throne. Lucifer is the bill for the siege, not the whole of it."
	l.position = Vector2(180, 70)
	l.size = Vector2(920, 460)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 22)
	_brief.add_child(l)
	_btn("Begin the siege", Vector2(480, 560), Vector2(280, 64), _on_begin, _brief)


func _build_end() -> void:
	_end = ColorRect.new()
	_end.color = Color(0.04, 0.03, 0.07, 0.88)
	_end.visible = false
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_end)
	_end_label = Label.new()
	_end_label.position = Vector2(280, 180)
	_end_label.size = Vector2(720, 280)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 28)
	_end.add_child(_end_label)
	_btn("Run it again", Vector2(500, 500), Vector2(240, 60), _on_restart, _end)


func _passive_line(subtype: String) -> String:
	match subtype:
		"michael":
			return "Passive: highest HP, 25% less damage taken."
		"raphael":
			return "Passive: regenerates while he is not casting."
		"azrael":
			return "Passive: short aura that reveals nearby traps."
		"uriel":
			return "Passive: Radiance — attacks stack and boost the next holy zone."
		"gabriel":
			return "Passive: small damage aura for the whole party."
		_:
			return ""


func _on_begin() -> void:
	_brief.visible = false
	_brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.briefing = false


func _on_restart() -> void:
	_inspect = ""
	_rewire_bar()
	game.restart()
	_end.visible = false


func _on_pause() -> void:
	game.paused = not game.paused
	_pause.text = "Run" if game.paused else "Pause"


func _on_speed() -> void:
	_speed_i = (_speed_i + 1) % _SPEEDS.size()
	game.speed = _SPEEDS[_speed_i]
	_speed.text = "%dx" % int(_SPEEDS[_speed_i])


func _on_stance(which: int) -> void:
	game.command("stance", {"stance": which})


func _on_scatter() -> void:
	game.command("scatter", {})


func _on_phalanx() -> void:
	game.command("phalanx", {})


func _on_cmd(cmd: String) -> void:
	game.command(cmd, {})


func _on_portrait(subtype: String) -> void:
	if _inspect == subtype:
		_inspect = ""
	else:
		_inspect = subtype
	_rewire_bar()


func _on_ability(ability: String) -> void:
	game.command("ability", {"name": ability})


func _rewire_bar() -> void:
	var cmds := ["shield", "heal", "cleanse", "detect", "burst"]
	for cmd in cmds:
		var btn: Button = _bar[cmd]
		btn.visible = true
		_clear_pressed(btn)
		btn.pressed.connect(_on_cmd.bind(cmd))


func _rewire_ability(btn: Button, ability: String) -> void:
	_clear_pressed(btn)
	btn.pressed.connect(_on_ability.bind(ability))


func _rewire_back(btn: Button) -> void:
	_clear_pressed(btn)
	btn.pressed.connect(_on_portrait.bind(_inspect))


func _clear_pressed(btn: Button) -> void:
	var conns := btn.pressed.get_connections()
	for c in conns:
		btn.pressed.disconnect(c.callable)


func _apply_ability_button(btn: Button, info: Dictionary) -> void:
	var cost := float(info.cost) / 1000.0
	var cd := int(info.cd_left)
	var extra := ""
	if not bool(info.ready):
		extra = "\n" + str(info.reason)
	elif cd > 0:
		extra = "\n%0.1fs" % (float(cd) / 20.0)
	elif cost > 0.0:
		extra = "\n%0.0f" % cost
	var owner := str(info.get("owner", "")).capitalize()
	if owner != "":
		extra += "\n" + owner
	btn.text = "%s%s" % [info.label, extra]
	btn.disabled = not bool(info.ready)


func _style_stances(current: int) -> void:
	for i in _stances.keys():
		var b: Button = _stances[i]
		b.modulate = Color(1.15, 1.05, 0.7) if int(i) == current else Color(0.75, 0.75, 0.8)


func _cd(ticks: int) -> String:
	if ticks <= 0:
		return "ready"
	return "%0.1fs" % (float(ticks) / 20.0)


func _paint(bar: ProgressBar, color: Color) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = color


func _hp_bar(parent: Control, at: Vector2, sz: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = sz
	bar.custom_minimum_size = sz
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.78, 0.42)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.07)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)
	return bar


func _bar_at(at: Vector2, width: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(width, 22)
	bar.show_percentage = false
	bar.max_value = 10000
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	add_child(bar)
	return bar


func _label(at: Vector2, text: String, sz: int) -> Label:
	var l := Label.new()
	l.position = at
	l.size = Vector2(420, 28)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	add_child(l)
	return l


func _btn(text: String, at: Vector2, sz: Vector2, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.position = at
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.14, 0.22)
	normal.border_color = Color(0.45, 0.38, 0.25)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.2, 0.32)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.32, 0.26, 0.14)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48))
	b.pressed.connect(cb)
	(self if parent == null else parent).add_child(b)
	return b
