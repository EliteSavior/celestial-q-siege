extends Control
## Touch HUD. Commands go out through GameRoot; layout never mutates the sim.

const OWNER_TINT := {
	"michael": Color(0.45, 0.62, 0.95),
	"raphael": Color(0.4, 0.82, 0.5),
	"azrael": Color(0.78, 0.48, 0.95),
	"uriel": Color(0.95, 0.66, 0.32),
	"gabriel": Color(0.95, 0.84, 0.4),
}

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
var _begin: Button
var _end: ColorRect
var _end_label: Label
var _victory_mark: Label
var _defeat_mark: Label
var _again: Button
var _to_title: Button
var _coach_bg: ColorRect
var _coach: Label
var _hide: Button
var _coach_off := false
var _inspect := ""
var _speed_i := 0
const _SPEEDS := [1.0, 2.0, 3.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	if _built:
		return
	_built = true
	_golden = _bar_at(Vector2(210, 8), 300, Color(0.95, 0.74, 0.22))
	_dark = _bar_at(Vector2(560, 8), 300, Color(0.62, 0.18, 0.72))
	_golden_l = _label(Vector2(210, 36), "Golden", 15)
	_dark_l = _label(Vector2(560, 36), "Dark", 15)
	_clock = _label(Vector2(980, 12), "0:00", 22)
	_room = _label(Vector2(210, 56), "", 15)
	_room.size = Vector2(760, 24)
	_boss = _bar_at(Vector2(210, 82), 560, Color(0.86, 0.14, 0.16))
	_boss.visible = false
	_boss_l = _label(Vector2(780, 80), "", 16)
	_boss_l.size = Vector2(360, 26)
	_feed = _label(Vector2(210, 548), "", 15)
	_feed.size = Vector2(760, 56)
	_passive = _label(Vector2(210, 508), "", 14)
	_passive.size = Vector2(760, 22)
	_coach_bg = ColorRect.new()
	_coach_bg.color = Color(0.05, 0.04, 0.08, 0.88)
	_coach_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_bg.position = Vector2(210, 496)
	_coach_bg.size = Vector2(760, 40)
	add_child(_coach_bg)
	_coach = _label(Vector2(218, 502), "", 16)
	_coach.size = Vector2(740, 32)
	_coach.clip_text = true
	_hide = _btn("Hide hints", Vector2(1000, 498), Vector2(150, 36), _on_hide_hints)
	_pause = _btn("Pause", Vector2(1088, 8), Vector2(90, 40), _on_pause)
	_speed = _btn("1x", Vector2(1188, 8), Vector2(76, 40), _on_speed)
	var names := ["Tight", "Spread", "Column"]
	for i in names.size():
		var b := _btn(names[i], Vector2(210 + i * 98, 640), Vector2(90, 48), _on_stance.bind(i))
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
	_layout_bottom()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout_bottom()


func on_new_run(to_title: bool) -> void:
	_inspect = ""
	_coach_off = false
	_rewire_bar()
	if _end:
		_end.visible = false
	if _brief:
		_brief.visible = to_title
		_brief.mouse_filter = Control.MOUSE_FILTER_STOP if to_title else Control.MOUSE_FILTER_IGNORE
	if _pause:
		_pause.text = "Pause"
	_layout_bottom()


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
	_room.text = "%s   %s   %s%s%s" % [
		stage_names[stage_i],
		room,
		snap.chosen_stance,
		"" if lock == "" else "   locked " + lock,
		marks,
	]
	var commits: Array = snap.get("commitments", [])
	if not commits.is_empty():
		var c0: Dictionary = commits[0]
		var left := maxi(0, int(c0.get("land", 0)) - int(snap.tick))
		var plan := "ELITE" if str(c0.get("plan", "")) == "elite" else "TRAPS"
		_room.text += "   %s %0.1fs" % [plan, float(left) / 20.0]
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
		var rising := int(snap.get("transform_until", 0)) > int(snap.tick)
		var tg: Dictionary = snap.get("telegraph", {})
		if rising:
			var left := maxi(0, int(snap.transform_until) - int(snap.tick))
			_boss_l.text = "Transforms  %0.1fs" % (float(left) / 20.0)
		elif not tg.is_empty():
			var left2 := maxi(0, int(tg.get("until", 0)) - int(snap.tick))
			_boss_l.text = "%s  %0.1fs" % [str(tg.get("name", "")).replace("_", " "), float(left2) / 20.0]
		else:
			_boss_l.text = "LUCIFER  %d" % int(snap.boss_hp)
		if str(snap.get("echo_style", "")) != "":
			_boss_l.text += "   echo %s" % str(snap.echo_style)
			var wave: Array = snap.get("echo_units", [])
			if wave.size() > 0:
				_boss_l.text += "  wave %d" % wave.size()
			if int(snap.get("echo_traps", 0)) > 0:
				_boss_l.text += "  traps %d" % int(snap.echo_traps)
	var lines: Array = snap.feed.slice(maxi(snap.feed.size() - 2, 0), snap.feed.size())
	var text := ""
	for row in lines:
		text += str(row.text) + "\n"
	_feed.text = text
	_style_stances(int(snap.stance))
	_scatter.text = "Scatter\n%s" % _cd(int(snap.scatter_cd))
	_phalanx.text = "Phalanx\n%s" % _cd(int(snap.phalanx_cd))
	_scatter.disabled = int(snap.scatter_cd) > 0
	_phalanx.disabled = int(snap.phalanx_cd) > 0
	_set_cd(_scatter, int(snap.scatter_cd), Balance.cooldown("scatter"))
	_set_cd(_phalanx, int(snap.phalanx_cd), Balance.cooldown("phalanx"))
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
				_set_cd(btn, 0, 1)
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
			flags += " " + Balance.ability_label(str(hs.casting))
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
			var col := Color(0.35, 0.82, 0.42)
			if pct < 50:
				col = Color(0.92, 0.74, 0.22)
			if pct < 25:
				col = Color(0.92, 0.28, 0.22)
			bar.max_value = float(maxi(int(hs.hp_max), 1))
			bar.value = float(maxi(int(hs.hp), 0))
			_paint(bar, col)
			btn3.text = "%s\n%d%s" % [subtype.capitalize(), int(hs.hp), flags]
			btn3.modulate = Color(1, 1, 1)
	_show_coach(snap)
	for cmd in _bar.keys():
		if not bool(_bar[cmd].has_meta("flash_until")) or int(_bar[cmd].get_meta("flash_until")) <= Time.get_ticks_msec():
			_bar[cmd].modulate = Color(1, 1, 1)
	if _scatter and (not _scatter.has_meta("flash_until") or int(_scatter.get_meta("flash_until")) <= Time.get_ticks_msec()):
		_scatter.modulate = Color(1, 1, 1)
	if _phalanx and (not _phalanx.has_meta("flash_until") or int(_phalanx.get_meta("flash_until")) <= Time.get_ticks_msec()):
		_phalanx.modulate = Color(1, 1, 1)
	_apply_flashes()
	if str(snap.outcome) != "":
		_end.visible = true
		_coach_bg.visible = false
		_coach.visible = false
		_hide.visible = false
		var secs2 := int(snap.tick) / 20
		var clock := "%d:%02d" % [secs2 / 60, secs2 % 60]
		if str(snap.outcome) == "angels":
			_end.color = Color(0.11, 0.08, 0.03, 0.94)
			_victory_mark.visible = true
			_defeat_mark.visible = false
			_again.text = "Siege again"
			_end_label.text = "Lucifer falls. The siege breaks.\n\n%s    revives %d\nEcho %s    wave %d    traps %d" % [
				clock, int(snap.stats.revives), str(snap.echo_style),
				snap.get("echo_units", []).size(), int(snap.get("echo_traps", 0))
			]
		else:
			_end.color = Color(0.12, 0.02, 0.03, 0.94)
			_victory_mark.visible = false
			_defeat_mark.visible = true
			_again.text = "Try again"
			var where := str(stage_names[stage_i])
			if str(snap.phase) == "lucifer":
				where = "the throne"
			_end_label.text = "The party is extinguished.\n\n%s    fell in %s\n%s" % [clock, where, room]
	else:
		_end.visible = false


func _show_coach(snap: Dictionary) -> void:
	var briefing := game != null and bool(game.briefing)
	var line := "" if briefing or _coach_off or str(snap.outcome) != "" else _coach_line(snap)
	var show := line != ""
	_coach_bg.visible = show
	_coach.visible = show
	_hide.visible = not briefing and not _coach_off and str(snap.outcome) == ""
	_coach.text = line


func _coach_line(snap: Dictionary) -> String:
	var tg: Dictionary = snap.get("telegraph", {})
	if not tg.is_empty():
		match str(tg.get("name", "")):
			"hell_rain":
				return "Hell rain — leave the red circles, or Scatter."
			"cleave":
				return "Cleave — step out of the orange lane."
			"judgment":
				return "Judgment — Shield or Body Block the marked angel."
			"grasp":
				return "Grasp — Phalanx refuses the pull."
			_:
				return "A blow is marked. Act before the bar fills."
	if int(snap.get("transform_until", 0)) > int(snap.tick):
		return "Lucifer is rising. Four marked blows come next."
	var curses: Array = snap.get("curses", [])
	if not curses.is_empty():
		var curse: Dictionary = curses[0]
		return "%s — %s. Cleanse before the bar fills." % [str(curse.subtype).capitalize(), str(curse.name)]
	var commits: Array = snap.get("commitments", [])
	if not commits.is_empty():
		if str(commits[0].get("plan", "")) == "elite":
			return "An elite is arming. The bar is the tell."
		return "A trap cluster is arming. The bar is the tell."
	var stake := str(snap.get("stake_id", ""))
	if stake != "" and not _stake_done(snap, stake) and int(snap.get("boss_hp_max", 0)) <= 0:
		return "Hold the gold node to claim %s." % str(snap.get("stake_name", "the stake"))
	for ex in snap.get("exits", []):
		if str(ex.get("hint", "")) in ["Still air", "Skittering", "Whispers"]:
			return "Still air = traps, Skittering = summons, Whispers = curses. A tap locks 3s."
	if str(snap.party_room) == "start" and int(snap.tick) < 200:
		return "Tap the floor. The five angels move as one squad."
	if int(snap.tick) < 500:
		return "Shield, Heal, Cleanse, Detect, Burst. Tap a portrait for that angel's kit."
	if int(snap.tick) < 900:
		return "Tight, Spread, or Column is the bet. Scatter and Phalanx are the reactions."
	return ""


func _stake_done(snap: Dictionary, stake: String) -> bool:
	match stake:
		"seal":
			return bool(snap.get("seal_done", false))
		"font":
			return bool(snap.get("font_done", false))
		"altar":
			return bool(snap.altar_done)
		_:
			return false


func _layout_bottom() -> void:
	var h := size.y
	var w := size.x
	if h < 400.0:
		h = 720.0
	if w < 400.0:
		w = 1280.0
	if _pause:
		_pause.position = Vector2(w - 192.0, 8)
	if _speed:
		_speed.position = Vector2(w - 92.0, 8)
	if w < 1200.0:
		_layout_narrow(w, h)
	else:
		_layout_wide(w, h)
	if _begin:
		_begin.position = Vector2((w - 320.0) * 0.5, h - 108.0)
		_begin.size = Vector2(320, 72)
	if _again:
		_again.position = Vector2((w - 320.0) * 0.5, h * 0.66)
		_again.size = Vector2(320, 72)
	if _to_title:
		_to_title.position = Vector2((w - 240.0) * 0.5, h * 0.66 + 84.0)
		_to_title.size = Vector2(240, 64)
	if _victory_mark:
		_victory_mark.position = Vector2((w - 720.0) * 0.5, h * 0.16)
	if _defeat_mark:
		_defeat_mark.position = Vector2((w - 720.0) * 0.5, h * 0.16)
	if _end_label:
		_end_label.position = Vector2((w - 760.0) * 0.5, h * 0.32)


func _layout_wide(w: float, h: float) -> void:
	if _golden:
		_golden.position = Vector2(210, 8)
		_golden.size = Vector2(300, 26)
	if _dark:
		_dark.position = Vector2(560, 8)
		_dark.size = Vector2(300, 26)
	if _golden_l:
		_golden_l.position = Vector2(210, 36)
	if _dark_l:
		_dark_l.position = Vector2(560, 36)
	if _clock:
		_clock.position = Vector2(980, 12)
		_clock.size = Vector2(460, 28)
	if _room:
		_room.position = Vector2(210, 56)
		_room.size = Vector2(760, 24)
	var cmd_y := h - 100.0
	var stance_y := h - 80.0
	var cmds := ["shield", "heal", "cleanse", "detect", "burst"]
	for i in cmds.size():
		if not _bar.has(cmds[i]):
			continue
		var btn: Button = _bar[cmds[i]]
		btn.position = Vector2(748 + i * 104, cmd_y)
		btn.size = Vector2(100, 88)
	for i in _stances.keys():
		var stance: Button = _stances[i]
		stance.position = Vector2(210 + int(i) * 98, stance_y)
		stance.size = Vector2(90, 48)
	if _scatter:
		_scatter.position = Vector2(520, stance_y)
		_scatter.size = Vector2(100, 48)
	if _phalanx:
		_phalanx.position = Vector2(628, stance_y)
		_phalanx.size = Vector2(100, 48)
	if _feed:
		_feed.position = Vector2(210, h - 176.0)
		_feed.size = Vector2(760, 56)
	if _passive:
		_passive.position = Vector2(210, h - 252.0)
		_passive.size = Vector2(760, 22)
	if _coach_bg:
		_coach_bg.position = Vector2(210, h - 224.0)
		_coach_bg.size = Vector2(1040, 40)
	if _coach:
		_coach.position = Vector2(218, h - 218.0)
		_coach.size = Vector2(860, 32)
	if _hide:
		_hide.position = Vector2(1090, h - 222.0)
		_hide.size = Vector2(150, 36)


func _layout_narrow(w: float, h: float) -> void:
	var bar_w := maxf(140.0, (w - 420.0) * 0.5 - 8.0)
	if _golden:
		_golden.position = Vector2(210, 8)
		_golden.size = Vector2(bar_w, 26)
	if _dark:
		_dark.position = Vector2(226.0 + bar_w, 8)
		_dark.size = Vector2(bar_w, 26)
	if _golden_l:
		_golden_l.position = Vector2(210, 36)
	if _dark_l:
		_dark_l.position = Vector2(226.0 + bar_w, 36)
	if _clock:
		_clock.position = Vector2(w - 150.0, 54)
		_clock.size = Vector2(140, 28)
	if _room:
		_room.position = Vector2(210, 56)
		_room.size = Vector2(maxi(w - 420.0, 200.0), 24)
	var cmds := ["shield", "heal", "cleanse", "detect", "burst"]
	var cmd_y := h - 116.0
	var cmd_w := 100.0
	var gap := 8.0
	var cmd_total := cmds.size() * cmd_w + (cmds.size() - 1) * gap
	if cmd_total > w - 16.0:
		cmd_w = floor((w - 16.0 - (cmds.size() - 1) * gap) / float(cmds.size()))
		cmd_total = cmds.size() * cmd_w + (cmds.size() - 1) * gap
	var x := (w - cmd_total) * 0.5
	for i in cmds.size():
		if not _bar.has(cmds[i]):
			continue
		var btn: Button = _bar[cmds[i]]
		btn.position = Vector2(x, cmd_y)
		btn.size = Vector2(cmd_w, 88)
		x += cmd_w + gap
	var stance_y := h - 176.0
	var row: Array = []
	for i in [0, 1, 2]:
		if _stances.has(i):
			row.append(_stances[i])
	if _scatter:
		row.append(_scatter)
	if _phalanx:
		row.append(_phalanx)
	var row_w := 0.0
	for b in row:
		row_w += b.size.x
	if row.size() > 1:
		row_w += gap * float(row.size() - 1)
	var sx := (w - row_w) * 0.5
	for b2 in row:
		var stance: Button = b2
		stance.position = Vector2(sx, stance_y)
		sx += stance.size.x + gap
	if _feed:
		_feed.position = Vector2(16, h - 300.0)
		_feed.size = Vector2(w - 32.0, 40)
	if _passive:
		_passive.position = Vector2(16, h - 252.0)
		_passive.size = Vector2(w - 32.0, 22)
	if _coach_bg:
		_coach_bg.position = Vector2(16, h - 222.0)
		_coach_bg.size = Vector2(w - 180.0, 40)
	if _coach:
		_coach.position = Vector2(24, h - 216.0)
		_coach.size = Vector2(maxi(w - 210.0, 80.0), 32)
	if _hide:
		_hide.position = Vector2(w - 156.0, h - 220.0)
		_hide.size = Vector2(140, 36)


func _build_portraits() -> void:
	var order := ["michael", "raphael", "azrael", "uriel", "gabriel"]
	var colors := {
		"michael": Color(0.16, 0.28, 0.52),
		"raphael": Color(0.12, 0.36, 0.24),
		"azrael": Color(0.32, 0.14, 0.4),
		"uriel": Color(0.42, 0.24, 0.1),
		"gabriel": Color(0.4, 0.32, 0.12),
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
		_hp[order[i]] = _hp_bar(b, Vector2(10, 64), Vector2(168, 18))


func _build_brief() -> void:
	_brief = ColorRect.new()
	_brief.color = Color(0.04, 0.03, 0.07, 0.96)
	_brief.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brief.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_brief)
	var title := Label.new()
	title.text = "Celestial Q Siege"
	title.position = Vector2(140, 36)
	title.size = Vector2(1000, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brief.add_child(title)
	var l := Label.new()
	l.text = "Five angels, one squad, against an AI Lucifer. The clock starts when you begin.\n\nTap the floor to move. Tap a door to commit for 3 seconds.\nStill air is traps. Skittering is summons. Whispers is curses.\n\nShield, Heal, Cleanse, Detect, and Burst spend Golden Elixir.\nTap a portrait for that angel's kit. Attacks are automatic. Downed lasts 3 seconds.\n\nHold the gold node for a stake: a seal, a cleanse, or a revive.\nTight, Spread, or Column is the bet. Scatter and Phalanx answer a tell.\nStanding in a cleared room feeds the demon.\n\nLucifer rises for 3 seconds, then four marked blows.\nKill him to win. A wiped party loses."
	l.position = Vector2(170, 104)
	l.size = Vector2(940, 470)
	l.clip_text = true
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brief.add_child(l)
	_begin = _btn("Begin the siege", Vector2(480, 612), Vector2(320, 72), _on_begin, _brief)
	_gold_button(_begin)


func _build_end() -> void:
	_end = ColorRect.new()
	_end.color = Color(0.05, 0.03, 0.06, 0.94)
	_end.visible = false
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_end)
	_victory_mark = Label.new()
	_victory_mark.text = "VICTORY"
	_victory_mark.position = Vector2(280, 120)
	_victory_mark.size = Vector2(720, 72)
	_victory_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_mark.add_theme_font_size_override("font_size", 54)
	_victory_mark.add_theme_color_override("font_color", Color(0.98, 0.84, 0.35))
	_victory_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(_victory_mark)
	_defeat_mark = Label.new()
	_defeat_mark.text = "DEFEAT"
	_defeat_mark.position = Vector2(280, 120)
	_defeat_mark.size = Vector2(720, 72)
	_defeat_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defeat_mark.add_theme_font_size_override("font_size", 54)
	_defeat_mark.add_theme_color_override("font_color", Color(0.95, 0.32, 0.28))
	_defeat_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_mark.visible = false
	_end.add_child(_defeat_mark)
	_end_label = Label.new()
	_end_label.position = Vector2(260, 230)
	_end_label.size = Vector2(760, 200)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 26)
	_end_label.add_theme_color_override("font_color", Color(0.94, 0.91, 0.84))
	_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(_end_label)
	_again = _btn("Siege again", Vector2(480, 470), Vector2(320, 72), _on_restart, _end)
	_gold_button(_again)
	_to_title = _btn("Title", Vector2(520, 554), Vector2(240, 64), _on_title, _end)


func _passive_line(subtype: String) -> String:
	match subtype:
		"michael":
			return "Michael — passive: highest HP, 25% less damage taken."
		"raphael":
			return "Raphael — passive: regenerates while he is not casting."
		"azrael":
			return "Azrael — passive: a short aura that reveals nearby traps."
		"uriel":
			return "Uriel — passive: Radiance. Attacks stack and boost the next holy zone."
		"gabriel":
			return "Gabriel — passive: a small damage aura for the whole party."
		_:
			return ""


func _on_begin() -> void:
	_brief.visible = false
	_brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.briefing = false


func _on_restart() -> void:
	game.restart()


func _on_title() -> void:
	game.title()


func _on_hide_hints() -> void:
	_coach_off = true
	_coach_bg.visible = false
	_coach.visible = false
	_hide.visible = false


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


func _on_press_fx(btn: Button) -> void:
	btn.set_meta("flash_until", Time.get_ticks_msec() + 140)
	if game != null and game.juice != null and game.juice.sfx != null:
		game.juice.sfx.play("ui")


func _rewire_bar() -> void:
	var cmds := ["shield", "heal", "cleanse", "detect", "burst"]
	for cmd in cmds:
		var btn: Button = _bar[cmd]
		btn.visible = true
		_clear_pressed(btn)
		btn.pressed.connect(_on_cmd.bind(cmd))
		btn.pressed.connect(_on_press_fx.bind(btn))


func _rewire_ability(btn: Button, ability: String) -> void:
	_clear_pressed(btn)
	btn.pressed.connect(_on_ability.bind(ability))
	btn.pressed.connect(_on_press_fx.bind(btn))


func _rewire_back(btn: Button) -> void:
	_clear_pressed(btn)
	btn.pressed.connect(_on_portrait.bind(_inspect))
	btn.pressed.connect(_on_press_fx.bind(btn))


func _clear_pressed(btn: Button) -> void:
	var conns := btn.pressed.get_connections()
	for c in conns:
		btn.pressed.disconnect(c.callable)


func _apply_ability_button(btn: Button, info: Dictionary) -> void:
	var cost := float(info.cost) / 1000.0
	var cd := int(info.cd_left)
	var extra := ""
	if not bool(info.ready):
		if str(info.reason) == "Cooling" and cd > 0:
			extra = "\n%0.1fs" % (float(cd) / 20.0)
		else:
			extra = "\n" + str(info.reason)
	elif cd > 0:
		extra = "\n%0.1fs" % (float(cd) / 20.0)
	elif cost > 0.0:
		extra = "\n%0.0f" % cost
	var owner := str(info.get("owner", ""))
	if owner != "":
		extra += "\n" + owner.capitalize()
	btn.text = "%s%s" % [info.label, extra]
	btn.disabled = not bool(info.ready)
	var normal := btn.get_theme_stylebox("normal") as StyleBoxFlat
	if normal and OWNER_TINT.has(owner):
		normal.border_color = OWNER_TINT[owner]
	var total := Balance.cooldown(str(info.get("ability", "")))
	_set_cd(btn, cd if not bool(info.ready) else 0, total)


func _set_cd(btn: Button, left: int, total: int) -> void:
	var fill := btn.get_node_or_null("CdFill") as ColorRect
	if fill == null:
		return
	if total <= 0 or left <= 0:
		fill.visible = false
		return
	var frac := clampf(float(left) / float(total), 0.0, 1.0)
	fill.visible = true
	fill.anchor_left = 0.0
	fill.anchor_right = 1.0
	fill.anchor_bottom = 1.0
	fill.anchor_top = 1.0 - frac
	fill.offset_left = 0.0
	fill.offset_right = 0.0
	fill.offset_top = 0.0
	fill.offset_bottom = 0.0


func _apply_flashes() -> void:
	var now := Time.get_ticks_msec()
	var buttons: Array = []
	for subtype in _portraits.keys():
		buttons.append(_portraits[subtype])
	for cmd in _bar.keys():
		buttons.append(_bar[cmd])
	for i in _stances.keys():
		buttons.append(_stances[i])
	buttons.append(_scatter)
	buttons.append(_phalanx)
	for btn in buttons:
		if btn == null or not btn.has_meta("flash_until"):
			continue
		if int(btn.get_meta("flash_until")) > now:
			btn.modulate = Color(1.45, 1.25, 0.7)


func _style_stances(current: int) -> void:
	for i in _stances.keys():
		var b: Button = _stances[i]
		b.modulate = Color(1.2, 1.08, 0.62) if int(i) == current else Color(0.72, 0.72, 0.78)


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
	fill.bg_color = Color(0.35, 0.82, 0.42)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.03, 0.06)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)
	return bar


func _bar_at(at: Vector2, width: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.size = Vector2(width, 26)
	bar.show_percentage = false
	bar.max_value = 10000
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.05, 0.08)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	add_child(bar)
	return bar


func _label(at: Vector2, text: String, sz: int) -> Label:
	var l := Label.new()
	l.position = at
	l.size = Vector2(460, 28)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l


func _gold_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.62, 0.44, 0.12)
	normal.border_color = Color(0.98, 0.86, 0.42)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.78, 0.56, 0.16)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.42, 0.28, 0.08)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_font_size_override("font_size", 22)


func _btn(text: String, at: Vector2, sz: Vector2, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.position = at
	b.size = sz
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.12, 0.2)
	normal.border_color = Color(0.55, 0.46, 0.28)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.24, 0.2, 0.32)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.4, 0.32, 0.14)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.1, 0.09, 0.12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48))
	var cd := ColorRect.new()
	cd.name = "CdFill"
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.color = Color(0.02, 0.015, 0.04, 0.62)
	cd.visible = false
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(cd)
	b.pressed.connect(cb)
	b.pressed.connect(_on_press_fx.bind(b))
	(self if parent == null else parent).add_child(b)
	return b
