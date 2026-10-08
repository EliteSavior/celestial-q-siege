extends RefCounted

var failures: Array = []


func run_all() -> int:
	var tests := [
		"test_map_connects",
		"test_elixir_compounds_by_stage",
		"test_tiers_follow_rooms_cleared",
		"test_seal_blocks_swarms_and_font_eats_curse",
		"test_fixed_math",
		"test_determinism",
		"test_elixir_cap_and_no_rubber_band",
		"test_fog_hides_far_rooms",
		"test_traps_hidden_until_detect",
		"test_column_spike_hits_lead_only",
		"test_tight_hellflame_hits_more_than_spread",
		"test_curse_telegraphs_before_it_lands",
		"test_cleanse_priority",
		"test_shield_routes_to_michael",
		"test_route_commitment",
		"test_turtle_corruption",
		"test_echo_budget_scales_with_hp",
		"test_echo_rejects_new_curses_and_affixes",
		"test_altar_revive_and_wipe_and_win",
		"test_gabriel_aura",
		"test_michael_kit",
		"test_raphael_kit",
		"test_azrael_kit",
		"test_uriel_kit",
		"test_gabriel_kit",
		"test_command_bar_drives_kits",
		"test_kit_commands_are_deterministic",
		"test_director_uses_nodes_only",
		"test_competent_policy_can_win",
		"test_march_takes_minutes",
	]
	for name in tests:
		call(name)
	if failures.is_empty():
		print("OK %d tests" % tests.size())
		return 0
	for f in failures:
		print("FAIL ", f)
	print("%d failed" % failures.size())
	return 1


func fail(msg: String) -> void:
	failures.append(msg)
	print("  x ", msg)


func test_map_connects() -> void:
	var map := DungeonMap.new()
	var errors: Array = map.validate()
	var tiles := map.path_between("start", "throne").size()
	print("  throne path ", tiles, " tiles")
	if not errors.is_empty():
		fail("map: %s" % str(errors))


func test_elixir_compounds_by_stage() -> void:
	var prev := -1
	var prev_step := 0
	for s in 5:
		var g := Balance.golden_regen(s)
		if Balance.dark_regen(s) <= 0:
			fail("dark regen missing at %d" % s)
		if s == 0 and g > 4:
			fail("opening golden regen %d is not slow" % g)
		if s > 0:
			var step := g - prev
			if step <= prev_step:
				fail("golden regen did not accelerate at stage %d (%d -> %d)" % [s, prev, g])
			prev_step = step
		prev = g
	if Balance.golden_regen(3) < Balance.golden_regen(0) * 6:
		fail("late crawl is not a multiple of the opening")
	if Balance.golden_regen(4) <= Balance.golden_regen(3):
		fail("lucifer is not the regen peak")
	var sim := CombatSim.new()
	sim.director_enabled = false
	var before := sim.golden
	sim.tick_once()
	var early := sim.golden - before
	sim.stage_reached = 3
	before = sim.golden
	sim.tick_once()
	var late := sim.golden - before
	if late < early * 6:
		fail("sim regen early %d late %d" % [early, late])


func test_tiers_follow_rooms_cleared() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 9000
	sim.rooms_cleared = Balance.HEAVY_ROOMS - 1
	if sim.legal_spawn("swarm", "summoned:center") != "":
		fail("swarm should be open from the first room")
	if sim.legal_spawn("heavy", "summoned:center") != "tier":
		fail("heavy unlocked too early")
	if sim.legal_spawn("elite", "altar:rear") != "tier":
		fail("elite unlocked too early")
	sim.rooms_cleared = Balance.HEAVY_ROOMS
	if sim.legal_spawn("heavy", "gallery1:center") != "":
		fail("heavy still locked at %d rooms" % Balance.HEAVY_ROOMS)
	if sim.legal_spawn("elite", "altar:rear") != "tier":
		fail("elite should wait until %d rooms" % Balance.ELITE_ROOMS)
	sim.rooms_cleared = Balance.ELITE_ROOMS
	if sim.legal_spawn("elite", "altar:rear") != "":
		fail("elite still locked at the gate")


func test_seal_blocks_swarms_and_font_eats_curse() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 9000
	sim.seal_done = true
	if sim.legal_spawn("swarm", "summoned:center") != "sealed":
		fail("seal did not lock swarms")
	sim.submit("spawn", {"unit": "swarm", "node": "summoned:center"}, "demon", 1)
	sim.tick_once()
	if sim.mob_count() != 0:
		fail("a sealed swarm still spawned")
	sim.rooms_cleared = Balance.HEAVY_ROOMS
	if sim.legal_spawn("heavy", "gallery1:center") != "":
		fail("seal also locked heavies")
	sim.cleanse_charges = 1
	sim.dark = 9000
	sim.submit("curse", {"kind": "silence", "target": "raphael"}, "demon", 1)
	for _i in 90:
		sim.tick_once()
	if int(sim._hero("raphael").silence_until) > sim.tick:
		fail("font charge did not burn the silence")
	if sim.cleanse_charges != 0:
		fail("font charge was not spent")


func test_fixed_math() -> void:
	if Fixed.isqrt(0) != 0 or Fixed.isqrt(9) != 3 or Fixed.isqrt(10) != 3:
		fail("isqrt")
	var step := Fixed.step_toward(Vector2i(0, 0), Vector2i(1000, 0), 400)
	if step != Vector2i(400, 0):
		fail("step %s" % step)
	var east := Fixed.rotate_facing(Vector2i(-1000, 0), Vector2i(0, -1))
	if east != Vector2i(0, 1000):
		fail("rotate %s" % east)


func test_determinism() -> void:
	var a := CombatSim.new()
	var b := CombatSim.new()
	for i in 250:
		if i == 15:
			a.submit("stance", {"stance": CombatSim.STANCE_SPREAD})
			b.submit("stance", {"stance": CombatSim.STANCE_SPREAD})
		if i == 30:
			a.submit("move_room", {"room": "fork"})
			b.submit("move_room", {"room": "fork"})
		a.tick_once()
		b.tick_once()
		if a.checksum() != b.checksum():
			fail("diverged at %d %s vs %s" % [i, a.debug_string(), b.debug_string()])
			return


func test_elixir_cap_and_no_rubber_band() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.golden = Balance.ELIXIR_MAX
	sim.dark = Balance.ELIXIR_MAX
	sim.rooms_cleared = 5
	for _i in 30:
		sim.tick_once()
	if sim.golden > Balance.ELIXIR_MAX or sim.dark > Balance.ELIXIR_MAX:
		fail("elixir exceeded cap")
	var behind := CombatSim.new()
	behind.director_enabled = false
	for a in behind._angels():
		a.hp = 20
	var ahead := CombatSim.new()
	ahead.director_enabled = false
	for _j in 40:
		behind.tick_once()
		ahead.tick_once()
	if behind.golden > ahead.golden + 5:
		fail("hurt party regen'd faster than a healthy one")


func test_fog_hides_far_rooms() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 8000
	sim.submit("spawn", {"unit": "swarm", "node": "throne:center"}, "demon", 1)
	sim.tick_once()
	var snap := sim.build_snapshot()
	if snap.foes.size() != 0:
		fail("throne swarm visible from the antechamber")
	sim.anchor = Fixed.tile_center(sim.map.center_tile("throne"))
	for a in sim._angels():
		a.pos = sim.anchor
	sim.tick_once()
	snap = sim.build_snapshot()
	if snap.foes.is_empty():
		fail("swarm still hidden inside the throne")


func test_traps_hidden_until_detect() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 5000
	sim.submit("trap", {"kind": "spike", "node": "trapped:rear"}, "demon", 1)
	sim.tick_once()
	sim.anchor = Fixed.tile_center(sim.map.center_tile("trapped"))
	for a in sim._angels():
		a.pos = sim.anchor
	sim.tick_once()
	var hidden: Array = sim.build_snapshot().traps
	if not hidden.is_empty():
		fail("trap visible before detect, count %d" % hidden.size())
	var rear := Fixed.tile_center(sim.map.node_tile("trapped:rear"))
	sim.anchor = rear + Vector2i(1400, 0)
	for a2 in sim._angels():
		a2.pos = sim.anchor
	sim.tick_once()
	if sim.build_snapshot().traps.is_empty():
		fail("Azrael aura did not reveal the spike")


func test_column_spike_hits_lead_only() -> void:
	var sim := _fresh_trap("spike", "trapped:center")
	sim.stance = CombatSim.STANCE_COLUMN
	sim.facing = Vector2i(1, 0)
	var trap := _find_kind(sim, "trap")
	var pos: Vector2i = trap.pos
	sim._hero("michael").pos = pos
	sim._hero("raphael").pos = pos + Vector2i(-2200, 0)
	sim._hero("azrael").pos = pos + Vector2i(-3000, 0)
	sim._hero("uriel").pos = pos + Vector2i(-3800, 0)
	sim._hero("gabriel").pos = pos + Vector2i(-4600, 0)
	var before := {}
	for a in sim._angels():
		before[a.subtype] = int(a.hp)
	sim._spring_trap(trap)
	if int(sim._hero("michael").hp) >= int(before.michael):
		fail("spike missed the lead")
	for other in ["raphael", "azrael", "uriel", "gabriel"]:
		if int(sim._hero(other).hp) != int(before[other]):
			fail("column spike hit %s" % other)


func test_tight_hellflame_hits_more_than_spread() -> void:
	var tight_hits := _hell_hits(CombatSim.STANCE_TIGHT, 200)
	var spread_hits := _hell_hits(CombatSim.STANCE_SPREAD, 2100)
	if tight_hits <= spread_hits:
		fail("tight hellflame hits %d, spread hits %d" % [tight_hits, spread_hits])


func test_curse_telegraphs_before_it_lands() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 8000
	var started := sim.tick
	sim.submit("curse", {"kind": "mark", "target": "raphael"}, "demon", 1)
	sim.tick_once()
	var curse := _find_kind(sim, "curse")
	if curse.is_empty():
		fail("mark was not created")
		return
	if int(curse.land) - started < 60:
		fail("mark telegraph shorter than 3s (%d)" % (int(curse.land) - started))
	if int(sim._hero("raphael").mark_until) > sim.tick:
		fail("mark landed during the cast")
	if sim.build_snapshot().curses.is_empty():
		fail("cast bar missing from the angel snapshot")
	while sim.tick < int(curse.land):
		sim.tick_once()
	sim.tick_once()
	if int(sim._hero("raphael").mark_until) <= sim.tick:
		fail("mark did not land")


func test_cleanse_priority() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.golden = 8000
	var raphael := sim._hero("raphael")
	raphael.silence_until = 500
	raphael.rot_until = 500
	sim.submit("cleanse", {})
	sim.tick_once()
	if int(raphael.silence_until) > sim.tick:
		fail("silence was not cleansed first")
	if int(raphael.rot_until) <= sim.tick:
		fail("cleanse removed rot in the same cast")
	sim._hero("gabriel").cooldowns.erase("cleanse")
	sim.golden = 8000
	sim.submit("cleanse", {})
	sim.tick_once()
	if int(raphael.rot_until) > sim.tick:
		fail("second cleanse did not remove rot")
	raphael.mark_until = 500
	raphael.weaken_until = 500
	sim._hero("gabriel").cooldowns.erase("cleanse")
	sim.golden = 8000
	sim.submit("cleanse", {})
	sim.tick_once()
	if int(raphael.mark_until) > sim.tick:
		fail("mark was not cleansed before weaken")
	if int(raphael.weaken_until) <= sim.tick:
		fail("cleanse removed weaken in the same cast as mark")
	sim._hero("gabriel").cooldowns.erase("cleanse")
	sim.golden = 8000
	sim.submit("cleanse", {})
	sim.tick_once()
	if int(raphael.weaken_until) > sim.tick:
		fail("fourth cleanse did not remove weaken")
	var cross := _lab()
	cross._hero("azrael").silence_until = 500
	cross._hero("raphael").rot_until = 500
	cross.submit("cleanse", {})
	cross.tick_once()
	if int(cross._hero("azrael").silence_until) > cross.tick:
		fail("silence on Azrael lost to rot on Raphael")
	if int(cross._hero("raphael").rot_until) <= cross.tick:
		fail("cross-angel cleanse removed rot early")


func test_shield_routes_to_michael() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.golden = 8000
	sim.submit("shield", {})
	sim.tick_once()
	if sim.shield_wall_until <= sim.tick:
		fail("shield did not become shield wall: %s" % _feed(sim))
	sim._hero("raphael").mark_until = sim.tick + 80
	sim._hero("michael").cooldowns.erase("body_block")
	sim.golden = 8000
	sim.submit("shield", {})
	sim.tick_once()
	if int(sim._hero("michael").body_block_until) <= sim.tick:
		fail("marked shield did not body-block")


func test_route_commitment() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.submit("move_room", {"room": "trapped"})
	sim.tick_once()
	sim.submit("move_room", {"room": "summoned"})
	sim.tick_once()
	if sim.route_lock_room != "trapped":
		fail("lock room %s" % sim.route_lock_room)
	if sim.move_goal_room != "trapped":
		fail("goal switched under commitment to %s" % sim.move_goal_room)
	if not _feed(sim).contains("Committed"):
		fail("no commitment log")


func test_turtle_corruption() -> void:
	var idle := CombatSim.new()
	idle.director_enabled = false
	var moving := CombatSim.new()
	moving.director_enabled = false
	for _i in 420:
		if idle.tick % 50 == 0:
			var t := Fixed.tile_of(moving.anchor) + Vector2i(1, 0)
			if moving.map.at(t) < 0:
				t = Fixed.tile_of(moving.anchor) + Vector2i(0, 1)
			moving.submit("move_tile", {"tile": t})
		idle.tick_once()
		moving.tick_once()
	if not idle.corruption:
		fail("idle party was not corrupted")
	var idle_hp := 0
	var move_hp := 0
	for a in idle._angels():
		idle_hp += int(a.hp)
	for b in moving._angels():
		move_hp += int(b.hp)
	if idle_hp >= move_hp:
		fail("corruption did not hurt the idle party %d vs %d" % [idle_hp, move_hp])


func test_echo_budget_scales_with_hp() -> void:
	var low := _descend_with_hp(30, 9000, false)
	var high := _descend_with_hp(100, 8000, false)
	var early := _descend_with_hp(100, 8000, true)
	if low.echo_units.size() != 1 or str(low.echo_units[0]) != "heavy":
		fail("low hp echo %s" % str(low.echo_units))
	if high.echo_units.size() <= low.echo_units.size():
		fail("healthy echo was not larger %s vs %s" % [str(high.echo_units), str(low.echo_units)])
	if early.echo_units.size() > high.echo_units.size():
		fail("early descend was stronger than a prepared one")
	if high.trap_cap != Balance.ECHO_TRAP_CAP:
		fail("trap cap was not cut")


func test_echo_rejects_new_curses_and_affixes() -> void:
	var sim := _descend_with_hp(100, 6000, false)
	var before := sim.mob_count()
	sim.submit("curse", {"kind": "silence", "target": "raphael"}, "demon", 1)
	sim.submit("spawn", {"unit": "elite", "node": "throne:center"}, "demon", 1)
	sim.tick_once()
	if int(sim._hero("raphael").silence_until) > sim.tick:
		fail("echo allowed a new curse")
	if sim.count_subtype("elite") > 0:
		fail("echo allowed a new elite")
	sim.submit("spawn", {"unit": "elite", "node": "throne:center", "echo": true}, "demon", 1)
	sim.tick_once()
	var elite := _find_subtype(sim, "elite")
	if elite.is_empty():
		fail("echo elite did not spawn for the affix check")
	elif not elite.affixes.is_empty():
		fail("echo elite kept affixes %s" % str(elite.affixes))
	if before < 0:
		fail("unused")


func test_altar_revive_and_wipe_and_win() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.altar_done = true
	sim.revive_charges = 1
	var michael := sim._hero("michael")
	sim._hurt(michael, 99999, "single", 0, false)
	if michael.alive:
		fail("michael should have fallen")
	if sim.outcome == "demon":
		fail("wipe fired while an altar revive was pending")
	for _i in 25:
		sim.tick_once()
	if not michael.alive:
		fail("altar revive did not fire")
	for a in sim._angels():
		a.alive = false
		a.hp = 0
	sim.pending_revives = []
	sim.tick_once()
	if sim.outcome != "demon":
		fail("wipe did not end the run")
	var win := _descend_with_hp(80, 4000, false)
	var boss := win._boss()
	boss.hp = 1
	win._hurt(boss, 50, "single", 1, false)
	win.tick_once()
	if win.outcome != "angels":
		fail("lucifer's death was not a win")


func test_gabriel_aura() -> void:
	var sim := CombatSim.new()
	var base := sim._out_damage(100)
	sim._hero("gabriel").alive = false
	var bare := sim._out_damage(100)
	if base <= bare:
		fail("aura %d vs %d" % [base, bare])


func test_director_uses_nodes_only() -> void:
	var sim := CombatSim.new()
	for _i in 200:
		sim.tick_once()
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) != "trap":
			continue
		var node := str(e.node)
		if sim.map.node_tile(node).x < 0:
			fail("trap off a node %s" % node)


func test_competent_policy_can_win() -> void:
	var sim := CombatSim.new()
	var policy := preload("res://tests/angel_policy.gd").new()
	# 16 minutes of ticks. The crawl should finish well inside this.
	var limit := 20 * 60 * 16
	var announced := false
	var lucifer_tick := -1
	var dead_noted := {}
	for _i in limit:
		if sim.outcome != "":
			break
		policy.act(sim)
		sim.tick_once()
		if sim.phase == "lucifer" and lucifer_tick < 0:
			lucifer_tick = sim.tick
		for a in sim._angels():
			if not a.alive and not dead_noted.has(a.subtype):
				dead_noted[a.subtype] = true
				print("  died ", a.subtype, " ", sim.debug_string())
				print("  feed ", _feed(sim))
		if sim.phase == "lucifer" and not announced:
			announced = true
			print("  lucifer ", sim.debug_string(), " echo=", sim.echo_units, " style=", sim.echo_style)
		if sim.tick % 2000 == 0:
			print("  ", sim.debug_string())
	var crawl_s := float(lucifer_tick) / 20.0
	var total_s := float(sim.tick) / 20.0
	var boss_s := total_s - crawl_s if lucifer_tick >= 0 else -1.0
	print("  pacing crawl=%0.1fs boss=%0.1fs total=%0.1fs outcome=%s" % [crawl_s, boss_s, total_s, sim.outcome])
	if sim.outcome != "angels":
		fail("policy did not win: %s" % sim.debug_string())
		print(_feed(sim))
		return
	# Fought crawl is the siege. A skipped-fight stroll lands near 7 minutes;
	# holding rooms pushes it past 8. The boss is the climax, not the clock.
	if lucifer_tick < 20 * 60 * 8:
		fail("throne in %0.1fs — the crawl is still too short" % crawl_s)
	if total_s > 14.0 * 60.0:
		fail("full run %0.1fs is past the 8–12 minute band" % total_s)
	if boss_s >= crawl_s:
		fail("boss %0.1fs lasted as long as the crawl %0.1fs" % [boss_s, crawl_s])
	if boss_s < 60.0:
		fail("boss ended in %0.1fs — not a climax" % boss_s)
	if not bool(sim.visited.get("throne", false)):
		fail("won without reaching the throne")


func test_march_takes_minutes() -> void:
	# No demon. This is the geometry: walking and claiming the three stakes.
	var sim := CombatSim.new()
	sim.director_enabled = false
	var policy := preload("res://tests/angel_policy.gd").new()
	var limit := 20 * 60 * 12
	var throne_tick := -1
	for _i in limit:
		if bool(sim.visited.get("throne", false)):
			throne_tick = sim.tick
			break
		policy.act(sim)
		sim.tick_once()
	print("  empty march ", throne_tick, " ticks (", float(throne_tick) / 20.0, "s) ", sim.debug_string())
	if throne_tick < 0:
		fail("empty march never reached the throne")
		return
	var march_s := float(throne_tick) / 20.0
	if march_s < 6.0 * 60.0 or march_s > 9.0 * 60.0:
		fail("empty march reached the throne in %0.1fs (want 6–9 min of road)" % march_s)
	if not sim.seal_done or not sim.font_done or not sim.altar_done:
		fail("march skipped a stake seal=%s font=%s altar=%s" % [sim.seal_done, sim.font_done, sim.altar_done])


func test_michael_kit() -> void:
	for ability in ["taunt", "shield_wall", "body_block"]:
		_assert_priced("michael", ability)
	var sim := _lab()
	var michael := sim._hero("michael")
	for other in ["raphael", "azrael", "uriel", "gabriel"]:
		if int(sim._hero(other).hp_max) >= int(michael.hp_max):
			fail("michael is not the highest HP")
	var raphael := sim._hero("raphael")
	var base := int(raphael.hp)
	sim._hurt(raphael, 100, "single", 0, false)
	if int(raphael.hp) != base - 100:
		fail("spread baseline hit %d" % (base - int(raphael.hp)))
	raphael.hp = base
	var m0 := int(michael.hp)
	sim._hurt(michael, 100, "single", 0, false)
	if m0 - int(michael.hp) != 100 * Balance.MICHAEL_MITIGATION / 100:
		fail("passive mitigation kept %d" % (m0 - int(michael.hp)))
	michael.hp = m0
	_pay(sim, "shield_wall")
	sim._hurt(raphael, 100, "single", 0, false)
	if base - int(raphael.hp) != 50:
		fail("shield wall reduced to %d" % (base - int(raphael.hp)))
	_pay_blocked(sim, "shield_wall")
	raphael.hp = base
	michael.hp = m0
	_pay(sim, "body_block")
	sim.shield_wall_until = 0
	sim._hurt(raphael, 40, "aoe", 1, true)
	if int(raphael.hp) != base - 40:
		fail("body block ate an AoE hit")
	if int(michael.body_block_until) <= sim.tick:
		fail("AoE cleared body block")
	sim._hurt(raphael, 40, "single", 1, false)
	if int(raphael.hp) != base - 40:
		fail("body block did not intercept the single hit")
	if m0 - int(michael.hp) != 40 * Balance.MICHAEL_MITIGATION / 100:
		fail("intercept damage %d" % (m0 - int(michael.hp)))
	sim._hurt(raphael, 40, "single", 1, false)
	if int(raphael.hp) != base - 80:
		fail("body block stayed up for a second hit")
	var on_raphael := _mob(sim, "imp", raphael.pos + Vector2i(180, 0))
	var bystander := _mob(sim, "heavy", sim._hero("azrael").pos + Vector2i(200, 0))
	_pay(sim, "taunt")
	if sim.taunt_id != int(on_raphael.id):
		fail("taunt did not pull the mob on Raphael")
	if str(sim._mob_target(on_raphael).subtype) != "michael":
		fail("taunted mob is not on Michael")
	if int(sim._mob_target(bystander).id) == int(michael.id):
		fail("taunt is not single-target")
	_pay_blocked(sim, "taunt")
	michael.cooldowns.erase("taunt")
	sim.taunt_until = 0
	sim.focus_id = int(bystander.id)
	sim.focus_until = sim.tick + 80
	sim.golden = 9000
	_pay(sim, "taunt")
	if sim.taunt_id != int(bystander.id):
		fail("focus did not choose the taunt target")
	_pay_poor(sim, "body_block")
	var empty := _lab()
	var gold := empty.golden
	empty.submit("ability", {"name": "taunt"})
	empty.tick_once()
	if empty.golden != gold + Balance.golden_regen(0):
		fail("taunt spent elixir with no target")
	var dive := _lab()
	var elite := _mob(dive, "elite", dive._hero("michael").pos + Vector2i(700, 0), 400)
	elite.affixes = ["teleporter", "molten"]
	elite.blink = {"target": dive._hero("raphael").id, "until": 90, "pos": dive._hero("raphael").pos}
	_pay(dive, "taunt")
	if dive.taunt_id != int(elite.id):
		fail("taunt ignored the blinking elite")
	if not elite.blink.is_empty():
		fail("taunt left the blink armed")
	dive.tick_once()
	if not elite.blink.is_empty():
		fail("elite blinked again while taunted")
	if str(dive._mob_target(elite).subtype) != "michael":
		fail("taunted elite is not stuck to Michael")
	elite.pos = dive._hero("raphael").pos + Vector2i(150, 0)
	dive.taunt_until = dive.tick
	if int(dive._mob_target(elite).id) == int(dive._hero("michael").id):
		fail("taunt did not expire")


func test_raphael_kit() -> void:
	for ability in ["single_heal", "party_heal", "slow_revive"]:
		_assert_priced("raphael", ability)
	var regen := _lab()
	var raphael := regen._hero("raphael")
	raphael.hp = int(raphael.hp_max) - 20
	var idle := int(raphael.hp)
	for _i in Balance.RAPHAEL_REGEN_PERIOD:
		regen.tick_once()
	if int(raphael.hp) != idle + Balance.RAPHAEL_REGEN:
		fail("self-heal regen %d -> %d" % [idle, raphael.hp])
	var casting := _lab()
	var healer := casting._hero("raphael")
	healer.hp = int(healer.hp_max) - 20
	casting._hero("azrael").alive = false
	casting._hero("azrael").hp = 0
	var held := int(healer.hp)
	_pay(casting, "slow_revive")
	if str(healer.casting.get("ability", "")) != "slow_revive":
		fail("slow revive did not channel")
	for _j in Balance.RAPHAEL_REGEN_PERIOD:
		casting.tick_once()
	if int(healer.hp) != held:
		fail("regen ticked while casting %d -> %d" % [held, healer.hp])
	var gold := casting.golden
	casting._hurt(healer, 40, "single", 0, false)
	if not healer.casting.is_empty():
		fail("revive was not interrupted")
	if casting._hero("azrael").alive:
		fail("interrupted revive still landed")
	if casting.golden < gold + Balance.REVIVE_REFUND:
		fail("interrupt did not refund elixir")
	var done := _lab()
	var dead := done._hero("gabriel")
	dead.alive = false
	dead.hp = 0
	_pay(done, "slow_revive")
	var guard := 0
	while not done._hero("raphael").casting.is_empty() and guard < 80:
		done.tick_once()
		guard += 1
	if not dead.alive:
		fail("slow revive did not finish")
	var want := int(dead.hp_max) * Balance.REVIVE_PCT / 100
	if int(dead.hp) != want:
		fail("slow revive hp %d want %d" % [dead.hp, want])
	var heals := _lab()
	heals._hero("gabriel").hp = int(heals._hero("gabriel").hp_max) - 90
	var g0 := int(heals._hero("gabriel").hp)
	var r0 := int(heals._hero("raphael").hp)
	_pay(heals, "single_heal")
	if int(heals._hero("gabriel").hp) != g0 + Balance.HEAL_SINGLE:
		fail("single heal missed the lowest")
	if int(heals._hero("raphael").hp) != r0:
		fail("single heal splashed")
	_pay_blocked(heals, "single_heal")
	for a in heals._angels():
		a.hp = int(a.hp_max) - 50
	var before := {}
	for a2 in heals._angels():
		before[a2.subtype] = int(a2.hp)
	heals._hero("gabriel").alive = false
	heals._hero("gabriel").hp = 0
	_pay(heals, "party_heal")
	for a3 in heals._angels():
		if str(a3.subtype) == "gabriel":
			if int(a3.hp) != 0:
				fail("party heal raised the dead")
		elif int(a3.hp) != int(before[a3.subtype]) + Balance.HEAL_PARTY:
			fail("party heal missed %s" % a3.subtype)
	_pay_poor(heals, "party_heal")


func test_azrael_kit() -> void:
	for ability in ["burst", "disarm", "escape_dash"]:
		_assert_priced("azrael", ability)
	if Balance.cost("detect_pulse") <= 0:
		fail("detect pulse is free")
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 100
	var azrael := sim._hero("azrael")
	var near := _mob(sim, "imp", azrael.pos + Vector2i(400, 0), 250)
	var far := _mob(sim, "heavy", azrael.pos + Vector2i(5000, 0), 250)
	_pay(sim, "burst")
	if 250 - int(near.hp) != sim._out_damage(Balance.BURST_DMG):
		fail("burst damage %d" % (250 - int(near.hp)))
	if int(far.hp) != 250:
		fail("burst splashed")
	_pay_blocked(sim, "burst")
	for angel in sim._angels():
		angel.pos = azrael.pos
	sim.root_until = 5000
	var edge := _plant(sim, azrael.pos + Vector2i(Balance.DETECT_AURA, 0))
	var outside := _plant(sim, azrael.pos + Vector2i(Balance.DETECT_AURA + 1, 0))
	sim.tick_once()
	if not bool(edge.revealed):
		fail("detect aura missed the rim")
	if bool(outside.revealed):
		fail("detect aura reached past its radius")
	var way := _plant(sim, azrael.pos + Vector2i(Balance.DETECT_PULSE + 80, 0))
	_pay(sim, "detect_pulse")
	if not bool(outside.revealed):
		fail("detect pulse missed a trap inside its radius")
	if bool(way.revealed):
		fail("detect pulse revealed past its radius")
	var hidden := _plant(sim, azrael.pos + Vector2i(800, 0))
	hidden.revealed = false
	var out_of_reach := _plant(sim, azrael.pos + Vector2i(4000, 0))
	out_of_reach.revealed = true
	var gold := sim.golden
	sim.submit("ability", {"name": "disarm"})
	sim.tick_once()
	if not bool(hidden.armed):
		fail("disarm worked on a hidden trap")
	if sim.golden < gold:
		fail("hidden disarm spent elixir")
	hidden.revealed = true
	_pay(sim, "disarm")
	if bool(hidden.armed):
		fail("disarm left the revealed trap")
	if not bool(out_of_reach.armed):
		fail("disarm hit a trap out of range")
	var flee := _lab()
	var rogue := flee._hero("azrael")
	rogue.silence_until = 800
	var origin: Vector2i = rogue.pos
	flee._add_zone(origin, Balance.HELLFLAME_RADIUS, 80, 30, "hell", 0)
	flee.submit("ability", {"name": "burst"})
	flee.tick_once()
	if not _feed(flee).contains("silenced"):
		fail("silence did not block burst")
	var hp := int(rogue.hp)
	_pay(flee, "escape_dash")
	if Fixed.dist(rogue.pos, origin) <= Balance.HELLFLAME_RADIUS:
		fail("dash stayed in the flame, dist %d" % Fixed.dist(rogue.pos, origin))
	if int(rogue.untargetable_until) <= flee.tick:
		fail("dash did not make Azrael untargetable")
	for _k in 12:
		flee.tick_once()
	if int(rogue.hp) != hp:
		fail("dash did not keep Azrael out of the flame")


func test_uriel_kit() -> void:
	for ability in ["beam", "aoe_zone", "disengage"]:
		_assert_priced("uriel", ability)
	var sim := _lab()
	sim.root_until = 8000
	for a in sim._angels():
		a.atk_cd = 200
	var uriel := sim._hero("uriel")
	var locked := _mob(sim, "imp", uriel.pos + Vector2i(800, 0), 300)
	var side := _mob(sim, "heavy", uriel.pos + Vector2i(0, 1600), 300)
	_pay(sim, "beam")
	if str(uriel.casting.get("ability", "")) != "beam":
		fail("beam did not channel: %s" % _feed(sim))
	if bool(uriel.casting.get("steered", false)):
		fail("beam started steered")
	var guard := 0
	while int(uriel.casting.get("pulses", 0)) == Balance.BEAM_PULSES and guard < 30:
		sim.tick_once()
		guard += 1
	if int(locked.hp) == 300:
		fail("locked beam missed")
	if int(side.hp) != 300:
		fail("unsteered beam splashed")
	var lock_hp := int(locked.hp)
	var side_hp := int(side.hp)
	var left := int(uriel.casting.get("pulses", 0))
	sim.submit("steer", {"pos": uriel.pos + Vector2i(0, 2200)})
	guard = 0
	while int(uriel.casting.get("pulses", 0)) == left and guard < 30:
		sim.tick_once()
		guard += 1
	if int(side.hp) >= side_hp:
		fail("steered beam missed the line")
	if int(locked.hp) != lock_hp:
		fail("steered beam still hit the old target")
	var plain := _zone_damage(0)
	var boosted := _zone_damage(Balance.RADIANCE_CAP)
	if boosted <= plain:
		fail("radiance %d did not beat %d" % [boosted, plain])
	if plain != Balance.HOLY_ZONE_DMG * Balance.GABRIEL_AURA / 100:
		fail("holy zone base damage %d" % plain)
	var stacks := _lab()
	var mage := stacks._hero("uriel")
	mage.atk_cd = 1
	mage.radiance = Balance.RADIANCE_CAP - 1
	_mob(stacks, "imp", mage.pos + Vector2i(200, 0), 500)
	stacks.tick_once()
	if int(mage.radiance) != Balance.RADIANCE_CAP:
		fail("attack did not build Radiance")
	mage.atk_cd = 1
	stacks.tick_once()
	if int(mage.radiance) != Balance.RADIANCE_CAP:
		fail("Radiance exceeded the cap")
	var back := _lab()
	for b in back._angels():
		b.atk_cd = 200
	var old: Vector2i = back.anchor
	back._add_zone(old, Balance.HELLFLAME_RADIUS, 40, 25, "hell", 0)
	var hp := {}
	for c in back._angels():
		hp[c.subtype] = int(c.hp)
	_pay(back, "disengage")
	if not back.path.is_empty():
		fail("disengage left a path")
	if Fixed.dist(back.anchor, old) < 2000:
		fail("disengage only moved %d" % Fixed.dist(back.anchor, old))
	for d in back._angels():
		if d.alive and Fixed.dist(d.pos, old) <= Balance.HELLFLAME_RADIUS:
			fail("%s still standing in the flame" % d.subtype)
	for _n in 12:
		back.tick_once()
	for e in back._angels():
		if int(e.hp) < int(hp[e.subtype]):
			fail("%s took the flame after disengage" % e.subtype)


func test_gabriel_kit() -> void:
	for ability in ["cleanse", "self_shield", "emergency_res"]:
		_assert_priced("gabriel", ability)
	var aura := _lab()
	for a in aura._angels():
		a.atk_cd = 100
	var uriel := aura._hero("uriel")
	uriel.atk_cd = 1
	var mob := _mob(aura, "imp", uriel.pos + Vector2i(200, 0), 400)
	aura.tick_once()
	var buffed := 400 - int(mob.hp)
	aura._hero("gabriel").alive = false
	mob.hp = 400
	uriel.atk_cd = 1
	aura.tick_once()
	var bare := 400 - int(mob.hp)
	if buffed <= bare:
		fail("damage aura %d vs %d" % [buffed, bare])
	uriel.weaken_until = 500
	var weakened := aura._out_damage(100, uriel.id)
	if weakened != 100 * Balance.WEAKEN_DEALT / 100:
		fail("weaken outgoing %d" % weakened)
	var sim := _lab()
	var gabriel := sim._hero("gabriel")
	_pay(sim, "self_shield")
	if int(gabriel.shield) != Balance.SELF_SHIELD:
		fail("self shield %d" % gabriel.shield)
	if int(sim._hero("raphael").shield) != 0:
		fail("self shield splashed")
	var hp := int(gabriel.hp)
	sim._hurt(gabriel, 40, "single", 0, false)
	if int(gabriel.hp) != hp:
		fail("self shield did not absorb")
	if int(gabriel.shield) != Balance.SELF_SHIELD - 40:
		fail("shield remainder %d" % gabriel.shield)
	_pay_blocked(sim, "self_shield")
	sim._hero("raphael").mark_until = sim.tick + 100
	_pay(sim, "cleanse")
	if int(sim._hero("raphael").mark_until) > sim.tick:
		fail("cleanse did not remove mark")
	var rise := _lab()
	var dead := rise._hero("raphael")
	dead.alive = false
	dead.hp = 0
	_pay(rise, "emergency_res")
	if not dead.alive:
		fail("emergency res left them down")
	if not rise._hero("gabriel").casting.is_empty():
		fail("emergency res channeled")
	var pct := int(dead.hp_max) * Balance.EMERGENCY_PCT / 100
	if int(dead.hp) != pct:
		fail("emergency hp %d want %d" % [dead.hp, pct])
	_pay_blocked(rise, "emergency_res")
	_pay_poor(rise, "self_shield")


func test_command_bar_drives_kits() -> void:
	var wall := _lab()
	wall.submit("shield", {})
	wall.tick_once()
	if wall.shield_wall_until <= wall.tick:
		fail("shield bar did not raise the wall")
	wall._hero("raphael").mark_until = wall.tick + 80
	wall._hero("michael").cooldowns.erase("body_block")
	wall.golden = 9000
	wall.submit("shield", {})
	wall.tick_once()
	if int(wall._hero("michael").body_block_until) <= wall.tick:
		fail("marked shield bar did not body-block")
	var party := _lab()
	party._hero("michael").hp = int(party._hero("michael").hp_max) / 2
	party._hero("raphael").hp = int(party._hero("raphael").hp_max) / 2 - 5
	var m := int(party._hero("michael").hp)
	var r := int(party._hero("raphael").hp)
	party.submit("heal", {})
	party.tick_once()
	if int(party._hero("michael").hp) - m != Balance.HEAL_PARTY:
		fail("heal bar did not party-heal Michael")
	if int(party._hero("raphael").hp) - r != Balance.HEAL_PARTY:
		fail("heal bar did not party-heal Raphael")
	var slow := _lab()
	slow._hero("gabriel").alive = false
	slow._hero("gabriel").hp = 0
	slow.submit("heal", {})
	slow.tick_once()
	if str(slow._hero("raphael").casting.get("ability", "")) != "slow_revive":
		fail("heal bar did not start the slow revive: %s" % _feed(slow))
	var detect := _lab()
	var trap := _plant(detect, detect._hero("azrael").pos + Vector2i(250, 0))
	trap.revealed = true
	detect.submit("detect", {})
	detect.tick_once()
	if bool(trap.armed):
		fail("detect bar did not disarm")
	var burst := _lab()
	for a in burst._angels():
		a.atk_cd = 100
	var imp := _mob(burst, "imp", burst._hero("azrael").pos + Vector2i(300, 0), 300)
	burst.submit("burst", {})
	burst.tick_once()
	if int(imp.hp) == 300:
		fail("burst bar missed")
	if not _find_kind(burst, "zone").is_empty():
		fail("burst bar dropped a zone")
	var zone := _lab()
	for b in zone._angels():
		b.atk_cd = 100
	var mage := zone._hero("uriel")
	mage.radiance = 2
	for i in 3:
		_mob(zone, "imp", mage.pos + Vector2i(180 * i, 60), 200)
	zone.submit("burst", {})
	zone.tick_once()
	if int(mage.radiance) != 0:
		fail("burst bar did not spend Radiance on the zone")
	var holy := _find_kind(zone, "zone")
	if holy.is_empty() or str(holy.subtype) != "holy":
		fail("burst bar did not drop the holy zone")


func test_kit_commands_are_deterministic() -> void:
	var a := CombatSim.new()
	var b := CombatSim.new()
	a.director_enabled = false
	b.director_enabled = false
	for i in 40:
		if i == 2:
			a.submit("ability", {"name": "shield_wall"})
			b.submit("ability", {"name": "shield_wall"})
		if i == 5:
			a.submit("ability", {"name": "party_heal"})
			b.submit("ability", {"name": "party_heal"})
		if i == 8:
			a.submit("spawn", {"unit": "swarm", "node": "summoned:center"}, "demon", 1)
			b.submit("spawn", {"unit": "swarm", "node": "summoned:center"}, "demon", 1)
		if i == 14:
			a.submit("burst", {})
			b.submit("burst", {})
		a.tick_once()
		b.tick_once()
		if a.checksum() != b.checksum():
			fail("kit commands diverged at %d" % i)
			return


func _lab() -> CombatSim:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.stance = CombatSim.STANCE_SPREAD
	sim.golden = 9000
	return sim


func _assert_priced(owner: String, ability: String) -> void:
	if Balance.owner_of(ability) != owner:
		fail("%s owner is %s" % [ability, Balance.owner_of(ability)])
	if Balance.cost(ability) <= 0:
		fail("%s has no cost" % ability)
	if Balance.cooldown(ability) <= 0:
		fail("%s has no cooldown" % ability)


func _pay(sim: CombatSim, ability: String) -> void:
	var hero: Dictionary = sim._hero(Balance.owner_of(ability))
	hero.cooldowns.erase(ability)
	var before := sim.golden
	var bounty := 0
	if ability == "cleanse":
		bounty = Balance.CLEANSE_BOUNTY
	elif ability == "disarm":
		bounty = Balance.DISARM_BOUNTY
	sim.submit("ability", {"name": ability})
	sim.tick_once()
	var expect := before - Balance.cost(ability) + bounty + Balance.golden_regen(sim.stage_reached)
	if sim.golden != expect:
		fail("%s golden %d want %d (%s)" % [ability, sim.golden, expect, _feed(sim)])
	if int(hero.cooldowns.get(ability, 0)) <= sim.tick:
		fail("%s did not start a cooldown" % ability)


func _pay_blocked(sim: CombatSim, ability: String) -> void:
	var before := sim.golden
	sim.submit("ability", {"name": ability})
	sim.tick_once()
	var expect := before + Balance.golden_regen(sim.stage_reached)
	if sim.golden != expect:
		fail("%s ignored its cooldown (%d -> %d)" % [ability, before, sim.golden])


func _pay_poor(sim: CombatSim, ability: String) -> void:
	var hero: Dictionary = sim._hero(Balance.owner_of(ability))
	hero.cooldowns.erase(ability)
	sim.golden = Balance.cost(ability) - 1
	var before := sim.golden
	sim.submit("ability", {"name": ability})
	sim.tick_once()
	if sim.golden != before + Balance.golden_regen(sim.stage_reached):
		fail("%s cast without elixir" % ability)
	if not _feed(sim).contains("Not enough"):
		fail("%s poverty message missing: %s" % [ability, _feed(sim)])


func _mob(sim: CombatSim, subtype: String, pos: Vector2i, hp: int = 120) -> Dictionary:
	sim._make_mob(subtype, subtype, pos, hp, 6, 40, 1200, 0, [], "start:center")
	var mob: Dictionary = sim.entities[sim.next_id - 1]
	mob.active_at = 0
	mob.atk_cd = 100
	mob.speed = 0
	return mob


func _plant(sim: CombatSim, pos: Vector2i) -> Dictionary:
	var id := sim._alloc()
	sim.entities[id] = {
		"id": id,
		"team": "demon",
		"kind": "trap",
		"subtype": "spike",
		"name": "spike",
		"pos": pos,
		"hp": 1,
		"hp_max": 1,
		"alive": true,
		"armed": true,
		"revealed": false,
		"node": "start:center",
		"room": "start",
		"avoided": false,
		"radius": 0,
	}
	sim.order.append(id)
	sim.order.sort()
	return sim.entities[id]


func _zone_damage(stacks: int) -> int:
	var sim := _lab()
	sim.root_until = 5000
	for a in sim._angels():
		a.atk_cd = 200
	var uriel: Dictionary = sim._hero("uriel")
	uriel.radiance = stacks
	var inside := _mob(sim, "imp", uriel.pos + Vector2i(300, 0), 400)
	var outside := _mob(sim, "heavy", uriel.pos + Vector2i(7000, 0), 400)
	var angel := int(sim._hero("raphael").hp)
	_pay(sim, "aoe_zone")
	if int(uriel.radiance) != 0:
		fail("zone left Radiance %d" % uriel.radiance)
	if int(outside.hp) != 400:
		fail("zone hit a mob outside the radius")
	if int(sim._hero("raphael").hp) != angel:
		fail("holy zone damaged an angel")
	return 400 - int(inside.hp)


func _fresh_trap(kind: String, node: String) -> CombatSim:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 8000
	sim.submit("trap", {"kind": kind, "node": node}, "demon", 1)
	sim.tick_once()
	return sim


func _hell_hits(stance: int, spread: int) -> int:
	var sim := _fresh_trap("hellflame", "trapped:rear")
	sim.stance = stance
	var trap := _find_kind(sim, "trap")
	var pos: Vector2i = trap.pos
	var i := 0
	for a in sim._angels():
		a.pos = pos + Vector2i(0, i * spread)
		a.hp = int(a.hp_max)
		i += 1
	sim._spring_trap(trap)
	sim._zones_and_auras()
	var hits := 0
	for a2 in sim._angels():
		if int(a2.hp) < int(a2.hp_max):
			hits += 1
	return hits


func _descend_with_hp(pct: int, bank: int, early: bool) -> CombatSim:
	var sim := CombatSim.new()
	sim.director_enabled = false
	for a in sim._angels():
		a.hp = maxi(1, int(a.hp_max) * pct / 100)
	sim.dark = bank
	sim.traps_placed = 1
	sim.submit("descend", {"early": early}, "demon", 1)
	sim.tick_once()
	return sim


func _find_kind(sim, kind: String) -> Dictionary:
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == kind:
			return e
	return {}


func _find_subtype(sim, subtype: String) -> Dictionary:
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.subtype) == subtype and bool(e.alive):
			return e
	return {}


func _feed(sim) -> String:
	var s := ""
	for row in sim.feed:
		s += str(row.text) + " | "
	return s
