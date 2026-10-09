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
var _threat := {}
var _aggro: Label
var _zoom_in: Button
var _zoom_out: Button
var _zoom_l: Label
var _bar := {}
var _acts := {}
var _tabs := {}
var _panic := {}
var _tab := "michael"
var _sheet: Label
var _cue: Label
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
var _highlight := ""
var _icons := {}
var _menu: Button
var _menu_dim: ColorRect
var _menu_restart: Button
var _menu_title: Button
var _menu_resume: Button
var _menu_held_pause := false
var _speed_i := 0
const _SPEEDS := [1.0, 2.0, 3.0, 4.0]
var _spawn_l: Label
var _seed_l: Label
var _feed_bg: ColorRect
var _debug_btn: Button
var _debug_dim: ColorRect
var _debug_log_panel: ColorRect
var _debug_log: TextEdit
var _debug_open := false
var _log_open := false
const ROLE_VERB := {
	"michael": "Taunt",
	"raphael": "Heal",
	"azrael": "Strike",
	"uriel": "Sunstrike",
	"gabriel": "Cleanse",
}
const TAB_ORDER := ["michael", "raphael", "azrael", "uriel", "gabriel"]
const TAB_ACTS := {
	"michael": ["taunt", "shield", "block"],
	"raphael": ["mend", "team", "revive"],
	"azrael": ["strike", "burst", "detect", "dash"],
	"uriel": ["sunstrike", "beam", "zone", "retreat"],
	"gabriel": ["cleanse", "aegis", "rescue"],
}
const PANIC_ORDER := ["taunt", "team", "cleanse"]


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
	_feed_bg = ColorRect.new()
	_feed_bg.color = Color(0.05, 0.04, 0.08, 0.94)
	_feed_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed_bg)
	_feed = _label(Vector2(210, 548), "", 15)
	_feed.size = Vector2(760, 88)
	_feed.clip_text = false
	_feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spawn_l = _label(Vector2(210, 100), "", 16)
	_spawn_l.size = Vector2(420, 24)
	_seed_l = _label(Vector2(640, 100), "", 16)
	_seed_l.size = Vector2(220, 24)
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
	_menu = _btn("Menu", Vector2(1088, 52), Vector2(176, 64), _on_menu)
	_aggro = _label(Vector2(210, 78), "Aggro", 16)
	_aggro.size = Vector2(640, 24)
	_zoom_l = _label(Vector2(8, 382), "ZOOM", 14)
	_zoom_l.size = Vector2(176, 20)
	_zoom_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_out = _btn("−", Vector2(8, 404), Vector2(84, 64), _on_zoom.bind(-1))
	_zoom_in = _btn("+", Vector2(100, 404), Vector2(84, 64), _on_zoom.bind(1))
	_zoom_out.add_theme_font_size_override("font_size", 32)
	_zoom_in.add_theme_font_size_override("font_size", 32)
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
	var act_names := ["taunt", "shield", "mend", "team", "strike", "burst", "detect", "sunstrike", "block", "revive", "dash", "beam", "zone", "retreat", "cleanse", "aegis", "rescue"]
	var act_labels := ["Taunt", "Shield", "Heal", "Party Heal", "Strike", "Burst", "Detect", "Sunstrike", "Block", "Revive", "Dash", "Beam", "Zone", "Retreat", "Cleanse", "Aegis", "Rescue"]
	for j in act_names.size():
		var b3 := _btn(act_labels[j], Vector2(200, 540), Vector2(160, 72), _on_act.bind(act_names[j]))
		_acts[act_names[j]] = b3
	var hero_names := ["michael", "raphael", "azrael", "uriel", "gabriel"]
	for h in hero_names.size():
		var tab := _btn(hero_names[h].capitalize(), Vector2(200, 480), Vector2(120, 64), _on_tab.bind(hero_names[h]))
		_tabs[hero_names[h]] = tab
	_panic["taunt"] = _btn("Taunt", Vector2(820, 480), Vector2(120, 64), _on_act.bind("taunt"))
	_panic["team"] = _btn("Party Heal", Vector2(948, 480), Vector2(140, 64), _on_act.bind("team"))
	_panic["cleanse"] = _btn("Cleanse", Vector2(1096, 480), Vector2(140, 64), _on_act.bind("cleanse"))
	_cue = _label(Vector2(210, 120), "", 16)
	_cue.size = Vector2(760, 24)
	_sheet = _label(Vector2(200, 150), "", 15)
	_sheet.size = Vector2(340, 210)
	_sheet.visible = false
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cmd in _bar.keys():
		var hidden: Button = _bar[cmd]
		hidden.visible = false
		hidden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_portraits()
	_build_brief()
	_build_end()
	_build_menu()
	_build_debug()
	_layout_bottom()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout_bottom()


func on_new_run(to_title: bool) -> void:
	_highlight = ""
	_coach_off = false
	_rewire_bar()
	if _end:
		_end.visible = false
	if _brief:
		_brief.visible = to_title
		_brief.mouse_filter = Control.MOUSE_FILTER_STOP if to_title else Control.MOUSE_FILTER_IGNORE
	if _pause:
		_pause.text = "Pause"
	_speed_i = 0
	if _speed:
		_speed.text = "1x"
	if _debug_dim:
		_debug_dim.visible = false
	_debug_open = false
	if _menu_dim:
		_menu_dim.visible = false
	_menu_held_pause = false
	_layout_bottom()


func refresh(snap: Dictionary) -> void:
	if not _built:
		return
	var max_e := float(maxi(int(snap.elixir_max), 1))
	_golden.max_value = max_e
	_dark.max_value = max_e
	_golden.value = float(snap.golden)
	_dark.value = float(snap.dark)
	var g_rate := float(snap.get("golden_regen", 0)) * float(Balance.TICK_HZ) / float(Balance.POINT)
	var d_rate := float(snap.get("dark_regen", 0)) * float(Balance.TICK_HZ) / float(Balance.POINT)
	_golden_l.text = "Golden  %d/%d  +%0.1f/s" % [Balance.points_of(int(snap.golden)), Balance.points_of(int(max_e)), g_rate]
	_dark_l.text = "Dark  %d/%d  +%0.1f/s" % [Balance.points_of(int(snap.dark)), Balance.points_of(int(max_e)), d_rate]
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
	if bool(snap.get("rooted", false)):
		_room.text += "   SNARE — not cleansable"
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
	var lines: Array = snap.feed.slice(maxi(snap.feed.size() - 4, 0), snap.feed.size())
	var text := ""
	for row in lines:
		text += str(row.text) + "\n"
	_feed.text = text
	var spawn_in := int(snap.get("next_spawn_in", -1))
	if _spawn_l:
		if spawn_in < 0:
			_spawn_l.text = ""
		else:
			var kind := str(snap.get("next_spawn_kind", ""))
			var why := str(snap.get("next_spawn_why", ""))
			var label := "Threat"
			if kind == "pack":
				label = "Pack"
			elif kind == "trap":
				label = "Traps"
			elif kind == "curse":
				label = "Curse"
			elif kind != "":
				label = kind.capitalize()
			_spawn_l.text = "%s in %0.1fs — %s" % [label, float(spawn_in) / 20.0, why]
	if _cue:
		_cue.text = _cue_line(snap)
	_refresh_sheet(snap)
	if _seed_l:
		_seed_l.text = "Seed %d" % int(snap.get("seed", 1))
	_refresh_debug(snap)
	_style_stances(int(snap.stance))
	_scatter.text = "Scatter\n%s" % _cd(int(snap.scatter_cd))
	_phalanx.text = "Phalanx\n%s" % _cd(int(snap.phalanx_cd))
	_scatter.disabled = int(snap.scatter_cd) > 0
	_phalanx.disabled = int(snap.phalanx_cd) > 0
	_set_cd(_scatter, int(snap.scatter_cd), Balance.cooldown("scatter"))
	_set_cd(_phalanx, int(snap.phalanx_cd), Balance.cooldown("phalanx"))
	_refresh_acts(snap)
	_refresh_panic(snap)
	_passive.text = _passive_line(_highlight) if _highlight != "" else ""
	for cmd in _bar.keys():
		var info: Dictionary = snap.bar[cmd]
		if cmd == "heal":
			info = snap.abilities.get("single_heal", info)
		_apply_ability_button(_bar[cmd], info)
		if cmd == "heal" and game != null and str(game.armed) == "single_heal":
			_bar[cmd].text = "Heal one\narmed"
	var threat_rows := {}
	var meter: Dictionary = snap.get("threat", {})
	for row in meter.get("rows", []):
		if typeof(row) == TYPE_DICTIONARY:
			threat_rows[str(row.get("subtype", ""))] = row
	var holder := str(meter.get("holder", ""))
	var pulling := str(meter.get("pulling", ""))
	if _aggro:
		var reason := str(meter.get("reason", ""))
		var detail := str(meter.get("detail", ""))
		if reason == "mobs" and int(meter.get("engaged", 0)) > 0:
			if pulling != "":
				_aggro.text = "Aggro  %s    %s is about to pull" % [holder.capitalize(), pulling.capitalize()]
			else:
				_aggro.text = "Aggro  %s holds" % holder.capitalize()
		elif reason == "boss":
			_aggro.text = "Aggro  Lucifer on %s" % (holder.capitalize() if holder != "" else "the party")
		elif reason == "corruption":
			_aggro.text = "Aggro  —  Corruption is ticking"
		elif reason == "curse":
			_aggro.text = "Aggro  —  %s, no mobs" % detail
		else:
			_aggro.text = "Aggro  —  no one is fighting"
	for subtype in _portraits.keys():
		var hs: Dictionary = snap.heroes[subtype]
		var btn3: Button = _portraits[subtype]
		var bar: ProgressBar = _hp[subtype]
		var trow: Dictionary = threat_rows.get(str(subtype), {})
		var tbar: ProgressBar = _threat.get(str(subtype), null)
		if tbar:
			var of_tank := mini(100, int(trow.get("of_tank", trow.get("pct", 0))))
			tbar.max_value = 100
			tbar.value = float(of_tank)
			var heat := str(trow.get("heat", ""))
			if bool(trow.get("aggro", false)) or heat == "hold":
				_paint(tbar, Color(0.95, 0.62, 0.2))
			elif heat == "pull" or bool(trow.get("pulling", false)) and of_tank >= Balance.THREAT_DANGER_PCT:
				_paint(tbar, Color(0.92, 0.22, 0.18))
			elif heat == "warn" or bool(trow.get("pulling", false)):
				_paint(tbar, Color(0.95, 0.82, 0.25))
			else:
				_paint(tbar, Color(0.45, 0.4, 0.36))
		var icons: StatusRow = _icons.get(str(subtype), null)
		if icons:
			var icon_rows: Array = []
			for angel_u in snap.get("angels", []):
				if typeof(angel_u) == TYPE_DICTIONARY and str(angel_u.get("subtype", "")) == str(subtype):
					icon_rows = angel_u.get("statuses", [])
					break
			icons.rows = icon_rows
			icons.visible = not icon_rows.is_empty()
			icons.queue_redraw()
		var verb := str(ROLE_VERB.get(str(subtype), ""))
		var mark := ""
		if bool(trow.get("aggro", false)):
			mark = "  AGGRO"
		elif bool(trow.get("pulling", false)):
			mark = "  PULL"
		var flags := ""
		if str(snap.get("ally_target", "")) == str(subtype):
			flags += " TGT"
		if str(hs.get("casting", "")) != "":
			flags += " " + Balance.ability_label(str(hs.casting))
		if bool(hs.get("downed", false)):
			bar.max_value = float(maxi(int(snap.get("downed_ticks", 60)), 1))
			bar.value = float(int(hs.get("downed_left", 0)))
			_paint(bar, Color(0.95, 0.48, 0.16))
			btn3.text = "%s  %s\nDOWN %0.1fs%s" % [subtype.capitalize(), verb, float(hs.get("downed_left", 0)) / 20.0, flags]
			btn3.modulate = Color(1.0, 0.78, 0.5)
		elif bool(hs.get("final_death", false)) or not bool(hs.alive):
			bar.max_value = float(maxi(int(hs.hp_max), 1))
			bar.value = 0
			_paint(bar, Color(0.28, 0.24, 0.24))
			btn3.text = "%s  %s\nFALLEN" % [subtype.capitalize(), verb]
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
			btn3.text = "%s  %s\n%d%s%s" % [subtype.capitalize(), verb, int(hs.hp), flags, mark]
			btn3.modulate = Color(1, 1, 1)
		if _highlight == str(subtype) and bool(hs.get("alive", false)):
			btn3.modulate = Color(1.35, 1.22, 0.72)
	_show_coach(snap)
	var in_run := game != null and not bool(game.briefing) and str(snap.outcome) == ""
	if _menu:
		_menu.visible = in_run
	if _menu_dim and not in_run:
		_menu_dim.visible = false
	for cmd in _bar.keys():
		if not bool(_bar[cmd].has_meta("flash_until")) or int(_bar[cmd].get_meta("flash_until")) <= Time.get_ticks_msec():
			_bar[cmd].modulate = Color(1, 1, 1)
	if _scatter and (not _scatter.has_meta("flash_until") or int(_scatter.get_meta("flash_until")) <= Time.get_ticks_msec()):
		_scatter.modulate = Color(1, 1, 1)
	if _phalanx and (not _phalanx.has_meta("flash_until") or int(_phalanx.get_meta("flash_until")) <= Time.get_ticks_msec()):
		_phalanx.modulate = Color(1, 1, 1)
	_apply_flashes()
	_paint_armed()
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
			_end_label.text = "Lucifer falls. The siege breaks.\n\n%s    revives %d    seed %d\nEcho %s    wave %d    traps %d\n%s" % [
				clock, int(snap.stats.revives), int(snap.get("seed", 1)), str(snap.echo_style),
				snap.get("echo_units", []).size(), int(snap.get("echo_traps", 0)), _report_text(snap)
			]
		else:
			_end.color = Color(0.12, 0.02, 0.03, 0.94)
			_victory_mark.visible = false
			_defeat_mark.visible = true
			_again.text = "Try again"
			var where := str(stage_names[stage_i])
			if str(snap.phase) == "lucifer":
				where = "the throne"
			_end_label.text = "The party is extinguished.\n\n%s    fell in %s    seed %d\n%s\n%s" % [clock, where, int(snap.get("seed", 1)), room, _report_text(snap)]
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
	if game == null or game.board == null or not game.board.has_method("guide"):
		return ""
	return str(game.board.guide(snap).get("line", ""))


func _layout_bottom() -> void:
	var h := size.y
	var w := size.x
	if h < 400.0:
		h = 720.0
	if w < 400.0:
		w = 1280.0
	var pause_x := _top_pause_x(w)
	if _pause:
		_pause.position = Vector2(pause_x, 8)
		_pause.size = Vector2(96, 64)
	if _speed:
		_speed.position = Vector2(pause_x + 104.0, 8)
		_speed.size = Vector2(72, 64)
	if w < 1200.0:
		_layout_narrow(w, h)
	else:
		_layout_wide(w, h)
	if _menu:
		_menu.position = Vector2(w - 184.0, 8)
		_menu.size = Vector2(176, 64)
	if _menu_restart:
		var mx := (w - 320.0) * 0.5
		_menu_restart.position = Vector2(mx, h * 0.36)
		_menu_restart.size = Vector2(320, 72)
	if _menu_title:
		_menu_title.position = Vector2((w - 320.0) * 0.5, h * 0.36 + 84.0)
		_menu_title.size = Vector2(320, 64)
	if _menu_resume:
		_menu_resume.position = Vector2((w - 320.0) * 0.5, h * 0.36 + 160.0)
		_menu_resume.size = Vector2(320, 64)
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


func _top_pause_x(w: float) -> float:
	# Pause 96, gap 8, Speed 72, gap 8, Menu 176, margin 8.
	return w - 368.0


func _place_meters(w: float) -> void:
	var pause_x := _top_pause_x(w)
	var left := 210.0
	var right := pause_x - 12.0
	var span: float = maxf(80.0, floor((right - left - 16.0) * 0.5))
	if _golden:
		_golden.position = Vector2(left, 8)
		_golden.size = Vector2(span, 26)
	if _dark:
		_dark.position = Vector2(left + span + 16.0, 8)
		_dark.size = Vector2(span, 26)
	if _golden_l:
		_golden_l.position = Vector2(left, 36)
	if _dark_l:
		_dark_l.position = Vector2(left + span + 16.0, 36)
	if _room:
		_room.position = Vector2(left, 56)
		_room.size = Vector2(maxi(right - left, 160.0), 22)
	if _clock:
		_clock.position = Vector2(maxi(left, pause_x - 118.0), 78)
		_clock.size = Vector2(110, 26)
	if _aggro:
		_aggro.position = Vector2(left, 78)
		_aggro.size = Vector2(maxi(pause_x - left - 130.0, 120.0), 24)


func _layout_wide(w: float, h: float) -> void:
	_place_meters(w)
	var stance_y := h - 80.0
	var skill_y := h - 152.0
	var tab_y := h - 236.0
	var coach_y := tab_y - 64.0
	var log_y := coach_y - 96.0
	_place_row(_util_buttons(), stance_y, 72.0, w, 200.0)
	_place_tabs(tab_y, w)
	_place_acts(skill_y, 72.0, w, 200.0)
	_place_log(Vector2(210, log_y), Vector2(maxi(w - 380.0, 200.0), 88.0))
	if _passive:
		_passive.position = Vector2(210, log_y - 20.0)
		_passive.size = Vector2(maxi(w - 380.0, 200.0), 18)
	if _coach_bg:
		_coach_bg.position = Vector2(210, coach_y)
		_coach_bg.size = Vector2(maxi(w - 210.0 - 156.0, 80.0), 56)
	if _coach:
		_coach.position = Vector2(218, coach_y + 4.0)
		_coach.size = Vector2(maxi(w - 400.0, 80.0), 22)
		_coach.clip_text = false
		_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _hide:
		_hide.position = Vector2(w - 148.0, coach_y)
		_hide.size = Vector2(140, 56)
	_place_readout(210.0, coach_y, maxi(w - 380.0, 200.0))
	_place_column()
	_place_debug_button()


func _layout_narrow(w: float, h: float) -> void:
	_place_meters(w)
	var stance_y := h - 80.0
	var skill_y := h - 152.0
	var tab_y := h - 236.0
	var coach_y := tab_y - 64.0
	var log_y := coach_y - 96.0
	_place_tabs(tab_y, w)
	_place_acts(skill_y, 72.0, w, 8.0)
	_place_row(_util_buttons(), stance_y, 72.0, w, 8.0)
	_place_log(Vector2(16, log_y), Vector2(w - 32.0, 88.0))
	if _passive:
		_passive.position = Vector2(16, log_y - 20.0)
		_passive.size = Vector2(w - 32.0, 18)
	if _coach_bg:
		_coach_bg.position = Vector2(16, coach_y)
		_coach_bg.size = Vector2(maxi(w - 180.0, 80.0), 56)
	if _coach:
		_coach.position = Vector2(24, coach_y + 4.0)
		_coach.size = Vector2(maxi(w - 210.0, 80.0), 22)
		_coach.clip_text = false
		_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _hide:
		_hide.position = Vector2(w - 148.0, coach_y)
		_hide.size = Vector2(132, 56)
	_place_readout(16.0, coach_y, maxi(w - 32.0, 80.0))
	_place_column()
	_place_debug_button()


func _place_readout(left: float, coach_y: float, width: float) -> void:
	if _cue:
		_cue.position = Vector2(left + 8.0, coach_y + 28.0)
		_cue.size = Vector2(maxi(width - 16.0, 40.0), 22)
	if _sheet:
		_sheet.position = Vector2(left, 148)
		_sheet.size = Vector2(mini(360.0, width), 210)


func _place_log(at: Vector2, sz: Vector2) -> void:
	if _feed_bg:
		_feed_bg.position = at
		_feed_bg.size = sz
	if _feed:
		_feed.position = at + Vector2(8, 4)
		_feed.size = Vector2(maxi(sz.x - 16.0, 40.0), sz.y - 8.0)
		_feed.clip_text = false


func _place_debug_button() -> void:
	if _debug_btn == null:
		return
	_debug_btn.visible = Dev.ENABLED
	if not Dev.ENABLED:
		return
	var zoom_y := 8.0 + 5.0 * 74.0 + 8.0
	_debug_btn.position = Vector2(8, zoom_y + 96.0)
	_debug_btn.size = Vector2(176, 48)


func _place_column() -> void:
	var order := ["michael", "raphael", "azrael", "uriel", "gabriel"]
	var stride := 74.0
	for i in order.size():
		if not _portraits.has(order[i]):
			continue
		var portrait: Button = _portraits[order[i]]
		portrait.custom_minimum_size = Vector2(176, 70)
		portrait.position = Vector2(8, 8 + float(i) * stride)
		portrait.size = Vector2(176, 70)
	var zoom_y := 8.0 + 5.0 * stride + 8.0
	if _zoom_l:
		_zoom_l.position = Vector2(8, zoom_y)
		_zoom_l.size = Vector2(176, 20)
	if _zoom_out:
		_zoom_out.custom_minimum_size = Vector2(84, 64)
		_zoom_out.position = Vector2(8, zoom_y + 22.0)
		_zoom_out.size = Vector2(84, 64)
	if _zoom_in:
		_zoom_in.custom_minimum_size = Vector2(84, 64)
		_zoom_in.position = Vector2(100, zoom_y + 22.0)
		_zoom_in.size = Vector2(84, 64)


func _stance_buttons() -> Array:
	var row: Array = []
	for i in [0, 1, 2]:
		if _stances.has(i):
			row.append(_stances[i])
	if _scatter:
		row.append(_scatter)
	if _phalanx:
		row.append(_phalanx)
	return row


func _util_buttons() -> Array:
	return _stance_buttons()


func _place_row(buttons: Array, y: float, bh: float, w: float, left: float) -> void:
	var n := buttons.size()
	if n == 0:
		return
	var gap := 8.0
	var avail := w - left - 8.0 - gap * float(n - 1)
	var bw: float = floor(avail / float(n))
	if bw < 64.0:
		bw = 64.0
	var x := left
	for b in buttons:
		var btn: Button = b
		btn.custom_minimum_size = Vector2(bw, bh)
		btn.position = Vector2(x, y)
		btn.size = Vector2(bw, bh)
		x += bw + gap


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
		var b := _btn(order[i].capitalize(), Vector2(8, 8 + i * 74), Vector2(176, 70), _on_portrait.bind(order[i]))
		var sb := b.get_theme_stylebox("normal").duplicate()
		sb.bg_color = colors[order[i]]
		b.add_theme_stylebox_override("normal", sb)
		var hover := b.get_theme_stylebox("hover")
		if hover:
			hover = hover.duplicate()
			hover.bg_color = colors[order[i]].lightened(0.15)
			b.add_theme_stylebox_override("hover", hover)
		_portraits[order[i]] = b
		_hp[order[i]] = _hp_bar(b, Vector2(6, 32), Vector2(146, 8))
		var threat := _hp_bar(b, Vector2(158, 6), Vector2(12, 58))
		threat.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		_threat[order[i]] = threat
		_paint(threat, Color(0.95, 0.62, 0.2))
		var icons := StatusRow.new()
		icons.position = Vector2(4, 46)
		icons.size = Vector2(150, 20)
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icons)
		_icons[order[i]] = icons


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
	l.text = "Five angels, one squad, against an AI Lucifer. The clock starts when you begin.\n\nTap the floor to move. Tap a door to commit for 3 seconds.\nStill air is traps. Skittering is summons. Whispers is curses.\nA gold arrow points at the next doorway.\n\nShield, Heal, Cleanse, Detect, and Burst spend Golden Elixir.\nTaunt, Heal, Team, Strike, and Sunstrike sit on the bar. Team heals every living angel.\nHeal arms Raphael's single heal; tap a hero to cast it. Zoom − and + sit under the portraits.\nEvery rite is on the bar. Tapping a portrait only aims a single-target rite.\nAttacks are automatic. Downed lasts 10 seconds.\n\nHold the gold node for a stake: a seal, a cleanse, or a revive.\nTight, Spread, or Column is the bet. Scatter and Phalanx answer a tell.\nThe antechamber is quiet. The first fight starts in the next room.\n\nLucifer rises for 3 seconds, then four marked blows.\nKill him to win. A wiped party loses.\nMenu, at the top right, restarts the run or returns here."
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
	_end_label.size = Vector2(860, 280)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_label.clip_text = false
	_end_label.add_theme_font_size_override("font_size", 18)
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
			return "Azrael — Detect is the only thing that shows a trap."
		"uriel":
			return "Uriel — passive: Radiance. Attacks stack and boost the next holy zone."
		"gabriel":
			return "Gabriel — passive: a small damage aura for the whole party."
		_:
			return ""


func _report_text(snap: Dictionary) -> String:
	var report: Dictionary = snap.get("hero_report", {})
	var lines: Array = []
	for subtype in ["michael", "raphael", "azrael", "uriel", "gabriel"]:
		var row: Dictionary = report.get(subtype, {})
		lines.append("%s  dmg %d  heal %d  threat %d  taken %d" % [
			subtype.capitalize(), int(row.get("damage", 0)), int(row.get("healing", 0)),
			int(row.get("threat", 0)), int(row.get("taken", 0)),
		])
	return "\n".join(lines)


func _build_debug() -> void:
	_debug_btn = _btn("Debug", Vector2(8, 520), Vector2(176, 48), _on_debug)
	_debug_btn.visible = Dev.ENABLED
	_debug_dim = ColorRect.new()
	_debug_dim.color = Color(0.03, 0.02, 0.06, 0.92)
	_debug_dim.visible = false
	_debug_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_debug_dim)
	var title := Label.new()
	title.text = "Debug"
	title.position = Vector2(24, 8)
	title.size = Vector2(400, 36)
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_dim.add_child(title)
	var close := _btn("Close", Vector2(900, 8), Vector2(140, 48), _on_debug_close, _debug_dim)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 64)
	scroll.size = Vector2(700, 620)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_dim.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(660, 0)
	scroll.add_child(box)
	_debug_row(box, "Spawn imp", _on_debug_spawn.bind("imp"))
	_debug_row(box, "Spawn swarm", _on_debug_spawn.bind("swarm"))
	_debug_row(box, "Spawn heavy", _on_debug_spawn.bind("heavy"))
	_debug_row(box, "Spawn elite", _on_debug_spawn.bind("elite"))
	_debug_row(box, "Curses on", _on_debug_curses.bind(true))
	_debug_row(box, "Curses off", _on_debug_curses.bind(false))
	_debug_row(box, "Traps on", _on_debug_traps.bind(true))
	_debug_row(box, "Traps off", _on_debug_traps.bind(false))
	_debug_row(box, "God mode", _on_debug_cmd.bind("debug_god", {}))
	_debug_row(box, "Infinite elixir", _on_debug_cmd.bind("debug_infinite", {}))
	_debug_row(box, "Full heal + revive", _on_debug_cmd.bind("debug_heal", {}))
	_debug_row(box, "Fill Dread", _on_debug_cmd.bind("debug_dread", {"fill": true}))
	_debug_row(box, "Empty Dread", _on_debug_cmd.bind("debug_dread", {"fill": false}))
	_debug_row(box, "Force summon", _on_debug_cmd.bind("debug_summon", {}))
	for room in ["start", "fork", "trapped", "summoned", "cursed", "seal", "font", "altar", "throne"]:
		_debug_row(box, "Teleport %s" % room, _on_debug_cmd.bind("debug_teleport", {"room": room}))
	_debug_row(box, "Toggle log", _on_debug_log)
	_debug_row(box, "Replay this seed", _on_debug_replay)
	_debug_log_panel = ColorRect.new()
	_debug_log_panel.color = Color(0.02, 0.02, 0.04, 0.92)
	_debug_log_panel.visible = false
	_debug_log_panel.position = Vector2(740, 64)
	_debug_log_panel.size = Vector2(500, 620)
	_debug_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_dim.add_child(_debug_log_panel)
	_debug_log = TextEdit.new()
	_debug_log.editable = false
	_debug_log.position = Vector2(8, 8)
	_debug_log.size = Vector2(484, 604)
	_debug_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_debug_log.scroll_fit_content_height = false
	_debug_log_panel.add_child(_debug_log)
	close.move_to_front()


func _debug_row(box: VBoxContainer, label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(280, 48)
	b.pressed.connect(cb)
	box.add_child(b)


func _on_debug() -> void:
	if not Dev.ENABLED:
		return
	_debug_open = true
	_debug_dim.visible = true
	if game:
		game.paused = true


func _on_debug_close() -> void:
	_debug_open = false
	_debug_dim.visible = false
	if game:
		game.paused = false


func _on_debug_spawn(unit: String) -> void:
	_on_debug_cmd("debug_spawn", {"unit": unit})


func _on_debug_curses(on: bool) -> void:
	_on_debug_cmd("debug_curses", {"on": on})


func _on_debug_traps(on: bool) -> void:
	_on_debug_cmd("debug_traps", {"on": on})


func _on_debug_cmd(type: String, args: Dictionary) -> void:
	if game == null or not Dev.ENABLED:
		return
	game.command(type, args)


func _threat_by_hero(snap: Dictionary) -> Dictionary:
	var out := {}
	var meter: Dictionary = snap.get("threat", {})
	for row in meter.get("rows", []):
		if typeof(row) == TYPE_DICTIONARY:
			out[str(row.get("subtype", ""))] = int(row.get("threat", 0))
	return out


func _on_debug_log() -> void:
	_log_open = not _log_open
	if _debug_log_panel:
		_debug_log_panel.visible = _log_open


func _on_debug_replay() -> void:
	if game:
		_debug_dim.visible = false
		_debug_open = false
		game.restart()


func _refresh_debug(snap: Dictionary) -> void:
	if not Dev.ENABLED:
		return
	var lines: Array = snap.get("debug_lines", [])
	var threat_of := _threat_by_hero(snap)
	var file := FileAccess.open("user://debug_log.txt", FileAccess.WRITE)
	if file:
		file.store_line("tick %s speed %s seed %s" % [snap.get("tick", 0), game.speed if game else 1, snap.get("seed", 1)])
		file.store_line("golden %s dark %s regen g %s d %s god %s infinite %s curses %s traps %s" % [
			snap.get("golden", 0), snap.get("dark", 0), snap.get("golden_regen", 0), snap.get("dark_regen", 0),
			snap.get("god_mode", false), snap.get("infinite_elixir", false), snap.get("curses_on", true), snap.get("traps_on", true),
		])
		var heroes: Dictionary = snap.get("heroes", {})
		file.store_line("variance penalty %s next %s (%s)" % [
			snap.get("variance_penalty", 0), snap.get("next_spawn_kind", ""), snap.get("next_spawn_why", ""),
		])
		var sheets_f: Dictionary = snap.get("sheets", {})
		for subtype in heroes.keys():
			var hs: Dictionary = heroes[subtype]
			var shf: Dictionary = sheets_f.get(str(subtype), {})
			file.store_line("hero %s hp %s/%s threat %s downed %s final %s silence %s rot %s mark %s weaken %s" % [
				subtype, hs.get("hp", 0), hs.get("hp_max", 0), int(threat_of.get(str(subtype), 0)),
				hs.get("downed", false), hs.get("final_death", false),
				hs.get("silence", false), hs.get("rot", false), hs.get("mark", false), hs.get("weaken", false),
			])
			file.store_line("sheet %s arm %s dodge %s pow %s crit %s thr %s" % [
				subtype, shf.get("armor", 0), shf.get("dodge", 0), shf.get("power", 0), shf.get("crit", 0), shf.get("threat", 0),
			])
		for foe in snap.get("debug_foes", []):
			file.store_line("foe %s %s hp %s/%s target %s room %s" % [foe.get("subtype", ""), foe.get("name", ""), foe.get("hp", 0), foe.get("hp_max", 0), foe.get("target", ""), foe.get("room", "")])
		for row in lines:
			file.store_line("%s %s" % [row.get("tick", 0), row.get("text", "")])
	if _debug_log == null or not _log_open:
		return
	var meter: Dictionary = snap.get("threat", {})
	var body := "tick %s  speed %s  seed %s\n" % [snap.get("tick", 0), game.speed if game else 1, snap.get("seed", 1)]
	body += "Golden %s (+%s)  Dread %s (+%s)  god %s  elixir %s\n" % [
		snap.get("golden", 0), snap.get("golden_regen", 0), snap.get("dark", 0), snap.get("dark_regen", 0),
		snap.get("god_mode", false), snap.get("infinite_elixir", false),
	]
	body += "aggro %s  reason %s\n" % [meter.get("holder", ""), meter.get("reason", "")]
	body += "variance penalty %s  next %s (%s)\n" % [
		snap.get("variance_penalty", 0), snap.get("next_spawn_kind", ""), snap.get("next_spawn_why", ""),
	]
	var heroes2: Dictionary = snap.get("heroes", {})
	var sheets: Dictionary = snap.get("sheets", {})
	for subtype2 in ["michael", "raphael", "azrael", "uriel", "gabriel"]:
		var hs2: Dictionary = heroes2.get(subtype2, {})
		var sh: Dictionary = sheets.get(subtype2, {})
		body += "%s hp %s/%s threat %s sil %s rot %s mark %s weak %s\n" % [
			subtype2, hs2.get("hp", 0), hs2.get("hp_max", 0), int(threat_of.get(subtype2, 0)),
			hs2.get("silence", false), hs2.get("rot", false), hs2.get("mark", false), hs2.get("weaken", false),
		]
		body += "sheet %s arm %s dodge %s pow %s crit %s thr %s\n" % [
			subtype2, sh.get("armor", 0), sh.get("dodge", 0), sh.get("power", 0), sh.get("crit", 0), sh.get("threat", 0),
		]
	for foe2 in snap.get("debug_foes", []):
		body += "foe %s %s/%s -> %s @ %s\n" % [foe2.get("name", ""), foe2.get("hp", 0), foe2.get("hp_max", 0), foe2.get("target", ""), foe2.get("room", "")]
	for row2 in lines:
		body += "%s %s\n" % [row2.get("tick", 0), row2.get("text", "")]
	_debug_log.text = body
	_debug_log.set_caret_line(maxi(_debug_log.get_line_count() - 1, 0))


func _build_menu() -> void:
	_menu.visible = false
	_menu_dim = ColorRect.new()
	_menu_dim.color = Color(0.03, 0.02, 0.06, 0.88)
	_menu_dim.visible = false
	_menu_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_dim)
	var title := Label.new()
	title.text = "Siege menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(280, 150)
	title.size = Vector2(720, 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.55))
	_menu_dim.add_child(title)
	_menu_restart = _btn("Restart run", Vector2(480, 250), Vector2(320, 72), _on_menu_restart, _menu_dim)
	_gold_button(_menu_restart)
	_menu_title = _btn("Title", Vector2(480, 334), Vector2(320, 64), _on_menu_title, _menu_dim)
	_menu_resume = _btn("Resume", Vector2(480, 410), Vector2(320, 64), _on_menu_resume, _menu_dim)


func _on_menu() -> void:
	_menu_held_pause = game.paused
	game.paused = true
	_menu_dim.visible = true
	_layout_bottom()


func _on_menu_resume() -> void:
	_menu_dim.visible = false
	game.paused = _menu_held_pause


func _on_menu_restart() -> void:
	_menu_dim.visible = false
	game.restart()


func _on_menu_title() -> void:
	_menu_dim.visible = false
	game.title()


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


func _on_zoom(dir: int) -> void:
	if game == null or game.board == null:
		return
	game.board.nudge_zoom(dir)


func _on_cmd(cmd: String) -> void:
	if cmd == "heal":
		_arm_or_fire("single_heal")
		return
	if game != null:
		game.armed = ""
	game.command(cmd, {})


func _act_ability(which: String) -> String:
	match which:
		"taunt":
			return "taunt"
		"shield":
			return "shield_wall"
		"mend":
			return "single_heal"
		"team":
			return "party_heal"
		"strike":
			return "strike"
		"sunstrike":
			return "sunstrike"
		"block":
			return "body_block"
		"revive":
			return "slow_revive"
		"dash":
			return "escape_dash"
		"beam":
			return "beam"
		"zone":
			return "aoe_zone"
		"retreat":
			return "disengage"
		"aegis":
			return "self_shield"
		"rescue":
			return "emergency_res"
		"cleanse":
			return "cleanse"
		"detect":
			return "detect_pulse"
		"burst":
			return "burst"
		_:
			return ""


func _on_tab(which: String) -> void:
	select_tab(which)


func select_tab(which: String) -> void:
	if not TAB_ACTS.has(which):
		return
	_tab = which
	if _built:
		_layout_bottom()


func _on_act(which: String) -> void:
	if game == null:
		return
	if which == "detect":
		game.armed = ""
		game.command("detect", {})
		return
	if which == "cleanse":
		game.armed = ""
		game.command("cleanse", {})
		return
	var ability := _act_ability(which)
	if ability == "":
		return
	if which == "team" or which == "shield":
		game.armed = ""
		if which == "shield":
			game.command("shield", {})
		else:
			game.command("ability", {"name": ability})
		return
	_arm_or_fire(ability)


func _arm_or_fire(ability: String) -> void:
	if game != null and game.needs_target(ability):
		game.arm(ability)
		return
	if game != null:
		game.armed = ""
	game.command("ability", {"name": ability})


func _refresh_acts(snap: Dictionary) -> void:
	for key in _acts.keys():
		var ability := _act_ability(str(key))
		if ability == "":
			continue
		var info: Dictionary = snap.abilities.get(ability, {})
		if info.is_empty():
			continue
		_apply_ability_button(_acts[key], info)


func _refresh_panic(snap: Dictionary) -> void:
	var routed := {"taunt": "taunt", "team": "party_heal", "cleanse": "cleanse"}
	for key in PANIC_ORDER:
		if not _panic.has(key):
			continue
		var info: Dictionary = snap.abilities.get(str(routed[key]), {})
		if info.is_empty():
			continue
		_apply_ability_button(_panic[key], info)


func _place_tabs(y: float, w: float) -> void:
	var left := 8.0 if w < 1200.0 else 200.0
	var panic_w := 132.0
	var gap := 8.0
	var panic_total := panic_w * float(PANIC_ORDER.size()) + gap * float(PANIC_ORDER.size() - 1)
	var panic_x := w - 8.0 - panic_total
	var tab_right := panic_x - gap
	var spans := float(TAB_ORDER.size() - 1) * gap
	var tab_w: float = floor((tab_right - left - spans) / float(TAB_ORDER.size()))
	if tab_w < 64.0:
		tab_w = 64.0
	var x := left
	for name in TAB_ORDER:
		if not _tabs.has(name):
			continue
		var tab: Button = _tabs[name]
		tab.visible = true
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.custom_minimum_size = Vector2(tab_w, 64)
		tab.position = Vector2(x, y)
		tab.size = Vector2(tab_w, 64)
		tab.modulate = Color(1.4, 1.22, 0.72) if name == _tab else Color(1, 1, 1)
		x += tab_w + gap
	var px := panic_x
	for pname in PANIC_ORDER:
		if not _panic.has(pname):
			continue
		var panic: Button = _panic[pname]
		panic.visible = true
		panic.mouse_filter = Control.MOUSE_FILTER_STOP
		panic.custom_minimum_size = Vector2(panic_w, 64)
		panic.position = Vector2(px, y)
		panic.size = Vector2(panic_w, 64)
		px += panic_w + gap


func _place_acts(y: float, bh: float, w: float, left: float) -> void:
	var names: Array = TAB_ACTS.get(_tab, [])
	var row: Array = []
	for name in names:
		if not _acts.has(name):
			continue
		var shown: Button = _acts[name]
		shown.visible = true
		shown.mouse_filter = Control.MOUSE_FILTER_STOP
		row.append(shown)
	_place_row(row, y, maxf(bh, 64.0), w, left)
	var park := Vector2(left, y)
	var park_size := Vector2(64, maxf(bh, 64.0))
	if row.size() > 0:
		var first: Button = row[0]
		park = first.position
		park_size = first.size
	for key in _acts.keys():
		if str(key) in names:
			continue
		var hidden: Button = _acts[key]
		hidden.visible = false
		hidden.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hidden.position = park
		hidden.size = park_size


func _cue_line(snap: Dictionary) -> String:
	var parts: PackedStringArray = []
	var meter: Dictionary = snap.get("threat", {})
	var pulling := str(meter.get("pulling", ""))
	if pulling != "":
		parts.append("Taunt: %s is about to pull" % pulling.capitalize())
	elif str(meter.get("reason", "")) == "mobs" and str(meter.get("holder", "")) != "":
		parts.append("Taunt: %s holds" % str(meter.get("holder", "")).capitalize())
	var commits: Array = snap.get("commitments", [])
	if not commits.is_empty():
		var c0: Dictionary = commits[0]
		var left := maxi(0, int(c0.get("land", 0)) - int(snap.tick))
		var plan := "Elite" if str(c0.get("plan", "")) == "elite" else "Traps"
		parts.append("Shield: %s %0.1fs" % [plan, float(left) / 20.0])
	var hurt := 0
	var cursed := 0
	var heroes: Dictionary = snap.get("heroes", {})
	for sub in heroes.keys():
		var hs: Dictionary = heroes[sub]
		if bool(hs.get("downed", false)):
			parts.append("Revive: %s %0.1fs" % [str(sub).capitalize(), float(hs.get("downed_left", 0)) / 20.0])
		elif bool(hs.get("alive", false)) and int(hs.get("hp", 0)) < int(hs.get("hp_max", 1)):
			hurt += 1
		if bool(hs.get("silence", false)) or bool(hs.get("rot", false)) or bool(hs.get("mark", false)) or bool(hs.get("weaken", false)):
			cursed += 1
	if hurt == 1:
		parts.append("Heal the wounded")
	elif hurt > 1:
		parts.append("Party Heal: %d wounded" % hurt)
	var room := str(snap.get("party_room", ""))
	if room.begins_with("fork"):
		parts.append("Detect: read the fork before you commit")
	var sheets: Dictionary = snap.get("sheets", {})
	var az: Dictionary = sheets.get("azrael", {})
	if int(az.get("dodge", 0)) > int(az.get("dodge_base", 0)):
		parts.append("Dash: Dodge %d%%" % int(az.get("dodge", 0)))
	if bool(snap.get("corruption", false)) or bool(snap.get("corruption_warn", false)):
		parts.append("Cleanse: Corruption is ticking")
	elif cursed > 0:
		parts.append("Cleanse: %d cursed" % cursed)
	var foes: Array = snap.get("foes", [])
	if foes.size() > 0:
		parts.append("%s: %d foes" % [str(snap.get("chosen_stance", "Stance")), foes.size()])
	return "   ".join(parts)


func _refresh_sheet(snap: Dictionary) -> void:
	if _sheet == null:
		return
	if _highlight == "":
		_sheet.visible = false
		return
	var sheet: Dictionary = snap.get("sheets", {}).get(_highlight, {})
	if sheet.is_empty():
		_sheet.visible = false
		return
	_sheet.visible = true
	var mods := ""
	for row in sheet.get("mods", []):
		mods += "\n" + str(row)
	_sheet.text = "%s\nHealth %d / %d\nArmor %d\nDodge %d%%\nPower %d\nCrit %d%%\nThreat %d%s" % [
		_highlight.capitalize(),
		int(sheet.get("health", 0)), int(sheet.get("health_max", 0)),
		int(sheet.get("armor", 0)), int(sheet.get("dodge", 0)),
		int(sheet.get("power", 0)), int(sheet.get("crit", 0)),
		int(sheet.get("threat", 0)), mods,
	]


func _on_portrait(subtype: String) -> void:
	# Ally taps never rebuild the bar. They only cast an armed single-target rite,
	# or highlight the portrait when nothing is armed.
	if game != null and str(game.armed) in GameRoot.ALLY_ARM:
		game.cast_armed({"target": subtype})
		return
	if _highlight == subtype:
		_highlight = ""
	else:
		_highlight = subtype


func _on_ability(ability: String) -> void:
	_arm_or_fire(ability)


func _paint_armed() -> void:
	if game == null:
		return
	var armed := str(game.armed)
	var lit := Color(1.45, 1.15, 0.45)
	for key in _acts.keys():
		var want := _act_ability(str(key))
		if armed != "" and armed == want:
			_acts[key].modulate = lit
	if _bar.has("heal") and armed == "single_heal":
		_bar.heal.modulate = lit


func _on_press_fx(btn: Button) -> void:
	btn.set_meta("flash_until", Time.get_ticks_msec() + 140)
	if game != null and game.juice != null and game.juice.sfx != null:
		game.juice.sfx.play("ui")


func _rewire_bar() -> void:
	# The contextual row stays hidden. Hero tabs and the emergency strip
	# are the only skill buttons.
	var cmds := ["shield", "heal", "cleanse", "detect", "burst"]
	for cmd in cmds:
		var btn: Button = _bar[cmd]
		btn.visible = false
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_pressed(btn: Button) -> void:
	var conns := btn.pressed.get_connections()
	for c in conns:
		btn.pressed.disconnect(c.callable)


func _apply_ability_button(btn: Button, info: Dictionary) -> void:
	var cost := float(Balance.points_of(int(info.cost)))
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
	for act in _acts.keys():
		buttons.append(_acts[act])
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
