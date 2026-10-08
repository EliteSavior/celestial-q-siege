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
