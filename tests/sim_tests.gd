extends RefCounted

var failures: Array = []
var host = null


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
		"test_per_member_hp_downed_and_revive",
		"test_auto_attack_needs_no_order",
		"test_damage_shapes_single_and_aoe",
		"test_command_bar_routes_every_button",
		"test_elixir_spend_cap_and_interaction_income",
		"test_scene_touch_playable",
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


func test_per_member_hp_downed_and_revive() -> void:
	if Balance.DOWNED_TICKS != Balance.TICK_HZ * 3:
		fail("downed window is not 3 seconds")
		return
	var sim := CombatSim.new()
	sim.director_enabled = false
	var michael := sim._hero("michael")
	var raphael := sim._hero("raphael")
	var before_r := int(raphael.hp)
	sim._hurt(michael, 50, "single", 0, false)
	if int(michael.hp) >= int(michael.hp_max):
		fail("michael took no damage")
		return
	if int(raphael.hp) != before_r:
		fail("single hit splashed onto raphael")
		return
	sim._hurt(michael, 99999, "single", 0, false)
	if michael.alive or bool(michael.final_death):
		fail("lethal hit was not a downed telegraph")
		return
	if int(michael.downed_until) - sim.tick != Balance.DOWNED_TICKS:
		fail("window %d" % (int(michael.downed_until) - sim.tick))
		return
	if sim.outcome == "demon":
		fail("one downed angel wiped the party")
		return
	var snap := sim.build_snapshot()
	if snap.heroes.size() != 5 or not bool(snap.heroes.michael.downed):
		fail("snapshot did not mark michael downed")
		return
	sim.golden = 9000
	sim.submit("ability", {"name": "emergency_res"})
	sim.tick_once()
	if not michael.alive or int(michael.hp) <= 0:
		fail("emergency revive missed the window: %s" % _feed(sim))
		return
	var az := sim._hero("azrael")
	sim._hurt(az, 99999, "single", 0, false)
	az.downed_until = sim.tick + 3
	sim.golden = 9000
	sim.submit("ability", {"name": "slow_revive"})
	for _i in 70:
		sim.tick_once()
		if az.alive:
			break
	if not az.alive or bool(az.final_death):
		fail("slow revive did not hold the window: %s" % _feed(sim))
		return
	sim._hurt(michael, 99999, "single", 0, false)
	for _j in Balance.DOWNED_TICKS:
		sim.tick_once()
	if not bool(michael.final_death) or michael.alive:
		fail("death did not become final, left %d" % (int(michael.downed_until) - sim.tick))
		return
	sim.golden = 9000
	sim._hero("gabriel").cooldowns.erase("emergency_res")
	sim.submit("ability", {"name": "emergency_res"})
	sim.tick_once()
	if michael.alive:
		fail("emergency revived a final death")
		return
	if sim.golden != 9000 + Balance.golden_regen(0):
		fail("final death still spent golden (%d)" % sim.golden)
		return
	var wipe := CombatSim.new()
	wipe.director_enabled = false
	for a in wipe._angels():
		wipe._hurt(a, 99999, "single", 0, false)
	if wipe.outcome == "demon":
		fail("wipe fired inside the downed window")
		return
	for _k in Balance.DOWNED_TICKS - 1:
		wipe.tick_once()
	if wipe.outcome == "demon":
		fail("wipe fired before 3 seconds")
		return
	wipe.tick_once()
	if wipe.outcome != "demon":
		fail("wipe did not resolve when every window closed")


func test_auto_attack_needs_no_order() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	var michael := sim._hero("michael")
	sim._make_mob("imp", "Imp", michael.pos, 400, 8, 10, 2000, 0, [], "start:center")
	var imp := _find_subtype(sim, "imp")
	imp.active_at = 0
	imp.atk_cd = 1
	for a in sim._angels():
		a.atk_cd = 1
	var hp_m := int(michael.hp)
	var hp_i := int(imp.hp)
	for _i in 30:
		sim.tick_once()
	if sim.queue.size() != 0:
		fail("auto-attack queued a player command")
	if int(michael.hp) >= hp_m:
		fail("imp did not auto-attack")
	if int(imp.hp) >= hp_i:
		fail("angels did not auto-attack")
	if int(sim.stats.damage_dealt) <= 0 or int(sim.stats.damage_taken) <= 0:
		fail("auto-attack did not record damage")


func test_damage_shapes_single_and_aoe() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	for a in sim._angels():
		a.atk_cd = 500
	var az := sim._hero("azrael")
	sim._make_mob("imp", "A", az.pos, 300, 1, 99, 100, 0, [], "start:center")
	sim._make_mob("imp", "B", az.pos + Vector2i(400, 0), 300, 1, 99, 100, 0, [], "start:center")
	var imps: Array = []
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.subtype) == "imp":
			e.active_at = 0
			e.atk_cd = 999
			imps.append(e)
	sim.focus_id = int(imps[0].id)
	sim.focus_until = 9999
	sim.golden = 9000
	var hp0 := int(imps[0].hp)
	var hp1 := int(imps[1].hp)
	sim.submit("ability", {"name": "burst"})
	sim.tick_once()
	if int(imps[0].hp) >= hp0:
		fail("burst missed the focus")
		return
	if int(imps[1].hp) != hp1:
		fail("single-target burst splashed")
		return
	var after0 := int(imps[0].hp)
	var after1 := int(imps[1].hp)
	sim.golden = 9000
	sim.submit("ability", {"name": "aoe_zone"})
	sim.tick_once()
	if int(imps[0].hp) >= after0 or int(imps[1].hp) >= after1:
		fail("holy zone did not hit both imps (%d, %d)" % [int(imps[0].hp), int(imps[1].hp)])
		return
	var heal := CombatSim.new()
	heal.director_enabled = false
	var gabriel := heal._hero("gabriel")
	gabriel.hp = 40
	var untouched := {}
	for a2 in heal._angels():
		if str(a2.subtype) != "gabriel":
			untouched[a2.subtype] = int(a2.hp)
	heal.golden = 9000
	heal.submit("ability", {"name": "single_heal"})
	heal.tick_once()
	if int(gabriel.hp) <= 40:
		fail("single heal missed gabriel")
		return
	for subtype in untouched.keys():
		if int(heal._hero(str(subtype)).hp) != int(untouched[subtype]):
			fail("single heal hit %s" % subtype)
			return
	for a3 in heal._angels():
		a3.hp = int(a3.hp_max) - 40
		a3.alive = true
		a3.final_death = false
	var before := {}
	for a4 in heal._angels():
		before[a4.subtype] = int(a4.hp)
	heal.golden = 9000
	heal._hero("raphael").cooldowns.erase("party_heal")
	heal.submit("ability", {"name": "party_heal"})
	heal.tick_once()
	for a5 in heal._angels():
		var gain := int(a5.hp) - int(before[a5.subtype])
		if str(a5.subtype) == "raphael":
			if gain < 32:
				fail("party heal raphael %+d" % gain)
				return
		elif gain != 32:
			fail("party heal %s %+d" % [a5.subtype, gain])
			return
	heal._hurt(heal._hero("azrael"), 99999, "single", 0, false)
	heal.golden = 9000
	heal._hero("raphael").cooldowns.erase("party_heal")
	heal.submit("ability", {"name": "party_heal"})
	heal.tick_once()
	if heal._hero("azrael").alive:
		fail("party heal raised a downed angel")
		return
	var molten := CombatSim.new()
	molten.director_enabled = false
	molten._make_mob("elite", "Elite", molten.anchor, 900, 1, 999, 100, 0, ["molten"], "start:center")
	var elite := _find_subtype(molten, "elite")
	elite.active_at = 0
	elite.atk_cd = 999
	for a6 in molten._angels():
		a6.atk_cd = 999
	var hp_before := {}
	for a7 in molten._angels():
		hp_before[a7.subtype] = int(a7.hp)
	for _i in 20:
		molten.tick_once()
	var hit := 0
	for a8 in molten._angels():
		if int(a8.hp) < int(hp_before[a8.subtype]):
			hit += 1
	if hit < 3:
		fail("molten aoe hit %d angels" % hit)


func test_command_bar_routes_every_button() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	var snap := sim.build_snapshot()
	var expect := {
		"shield": "michael",
		"heal": "raphael",
		"cleanse": "gabriel",
		"detect": "azrael",
		"burst": "uriel",
	}
	for cmd in expect.keys():
		if not snap.bar.has(cmd):
			fail("bar missing %s" % cmd)
			return
		if str(snap.bar[cmd].owner) != str(expect[cmd]):
			fail("%s routed to %s" % [cmd, snap.bar[cmd].owner])
			return
		if str(snap.bar[cmd].ability) == "":
			fail("%s routed nowhere" % cmd)
			return
	if not _spend_ok(sim, "shield", "shield_wall"):
		return
	if sim.shield_wall_until <= sim.tick:
		fail("shield did not cast")
		return
	sim._hero("raphael").hp = 120
	sim.golden = 8000
	if not _spend_ok(sim, "heal", "single_heal"):
		return
	if int(sim._hero("raphael").hp) <= 120:
		fail("heal button did not mend raphael")
		return
	sim._hero("raphael").silence_until = sim.tick + 80
	sim.golden = 8000
	sim._hero("gabriel").cooldowns.erase("cleanse")
	if not _spend_ok(sim, "cleanse", "cleanse", Balance.CLEANSE_BOUNTY):
		return
	if int(sim._hero("raphael").silence_until) > sim.tick:
		fail("cleanse button did not route")
		return
	sim.golden = 8000
	sim._hero("azrael").cooldowns.erase("detect_pulse")
	if not _spend_ok(sim, "detect", "detect_pulse"):
		return
	sim._make_mob("heavy", "Heavy", sim._hero("azrael").pos, 400, 1, 99, 100, 0, [], "start:center")
	var heavy := _find_subtype(sim, "heavy")
	heavy.active_at = 0
	sim.focus_id = int(heavy.id)
	sim.focus_until = sim.tick + 100
	sim.golden = 8000
	sim._hero("azrael").cooldowns.erase("burst")
	var routed := str(sim.preview("burst").ability)
	if routed != "burst" or str(sim.preview("burst").owner) != "azrael":
		fail("burst in range routed to %s" % routed)
		return
	if not _spend_ok(sim, "burst", "burst"):
		return
	sim._hurt(sim._hero("azrael"), 99999, "single", 0, false)
	var beam := str(sim.preview("burst").ability)
	if beam != "beam" or str(sim.preview("burst").owner) != "uriel":
		fail("burst with azrael down routed to %s" % beam)


func test_elixir_spend_cap_and_interaction_income() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	var broke := Balance.cost("shield_wall") - 1
	sim.golden = broke
	sim.submit("shield", {})
	sim.tick_once()
	if sim.shield_wall_until > sim.tick:
		fail("shield cast without elixir")
		return
	if sim.golden != broke + Balance.golden_regen(0):
		fail("poor cast changed golden to %d" % sim.golden)
		return
	sim.golden = Balance.ELIXIR_MAX
	sim.tick_once()
	if sim.golden > Balance.ELIXIR_MAX:
		fail("regen overflowed the cap")
		return
	var snap := sim.build_snapshot()
	if int(snap.golden_regen) != Balance.golden_regen(0) or int(snap.dark_regen) != Balance.dark_regen(0):
		fail("snapshot regen does not match the stage curve")
		return
	var room := sim.party_room()
	var guard := 0
	while int(sim.dark_income_room.get(room, 0)) < Balance.ROOM_DARK_DMG_CAP and guard < 80:
		var raphael := sim._hero("raphael")
		if not raphael.alive or int(raphael.hp) < 80:
			raphael.alive = true
			raphael.final_death = false
			raphael.downed_until = 0
			raphael.hp = raphael.hp_max
		sim._hurt(raphael, 40, "single", 0, false)
		guard += 1
	if int(sim.dark_income_room.get(room, 0)) != Balance.ROOM_DARK_DMG_CAP:
		fail("angel chip dark income %s" % str(sim.dark_income_room.get(room, 0)))
		return
	var dark_before := sim.dark
	sim._hero("raphael").alive = true
	sim._hero("raphael").hp = sim._hero("raphael").hp_max
	sim._hurt(sim._hero("raphael"), 40, "single", 0, false)
	if sim.dark != dark_before:
		fail("dark income exceeded the room cap")
		return
	for _i in 20:
		sim._grant_golden(Balance.AVOID_BOUNTY, "start")
	if int(sim.golden_income_room.get("start", 0)) != Balance.ROOM_GOLDEN_CAP:
		fail("golden bounty did not cap at %s" % str(sim.golden_income_room.get("start", 0)))
		return
	var id := sim._alloc()
	var pos := sim.anchor + Vector2i(1600, 0)
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
		"revealed": true,
		"avoided": false,
		"node": "fork:center",
		"room": "fork",
	}
	sim.order.append(id)
	sim.order.sort()
	sim.tick_once()
	if int(sim.golden_income_room.get("fork", 0)) != Balance.AVOID_BOUNTY:
		fail("avoided trap paid %s" % str(sim.golden_income_room.get("fork", 0)))
		return
	sim.tick_once()
	if int(sim.golden_income_room.get("fork", 0)) != Balance.AVOID_BOUNTY:
		fail("avoided trap paid twice")


func test_scene_touch_playable() -> void:
	if host == null:
		fail("scene test has no tree")
		return
	var game := GameRoot.new()
	game.boot()
	_pin_screen(game)
	_pin_screen(game.board)
	_pin_screen(game.hud)
	host.root.add_child(game)
	_pin_screen(game)
	_pin_screen(game.board)
	_pin_screen(game.hud)
	game.briefing = false
	game.sim.director_enabled = false
	game.hud._brief.visible = false
	game.hud._brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._process(0.0)
	game.board._process(0.0)
	if game.hud._hp.size() != 5:
		fail("expected 5 hp bars, got %d" % game.hud._hp.size())
		game.queue_free()
		return
	var snap: Dictionary = game.board.snap
	for subtype in ["michael", "raphael", "azrael", "uriel", "gabriel"]:
		var bar: ProgressBar = game.hud._hp[subtype]
		var hs: Dictionary = snap.heroes[subtype]
		if int(bar.max_value) != int(hs.hp_max) or int(bar.value) != int(hs.hp):
			fail("hp bar %s shows %s/%s want %s/%s" % [subtype, bar.value, bar.max_value, hs.hp, hs.hp_max])
			game.queue_free()
			return
		var rect: Rect2 = game.hud._portraits[subtype].get_rect()
		if rect.size.y < 64 or rect.position.y + rect.size.y > 720:
			fail("portrait %s is not a touch target %s" % [subtype, rect])
			game.queue_free()
			return
	if int(game.hud._golden.value) != int(snap.golden) or int(game.hud._dark.value) != int(snap.dark):
		fail("elixir bars do not match the sim")
		game.queue_free()
		return
	if not str(game.hud._golden_l.text).contains("+") or not str(game.hud._dark_l.text).contains("Dark"):
		fail("elixir labels missing regen")
		game.queue_free()
		return
	for cmd in ["shield", "heal", "cleanse", "detect", "burst"]:
		var btn: Button = game.hud._bar[cmd]
		var r: Rect2 = btn.get_rect()
		if r.size.x < 64 or r.size.y < 64:
			fail("%s touch target %s" % [cmd, r.size])
			game.queue_free()
			return
		if r.position.x < 0 or r.position.y < 0 or r.position.x + r.size.x > 1280 or r.position.y + r.size.y > 720:
			fail("%s sits outside 1280x720 %s" % [cmd, r])
			game.queue_free()
			return
	game.sim.golden = 8000
	game.hud._bar.shield.pressed.emit()
	game.sim.tick_once()
	if game.sim.shield_wall_until <= game.sim.tick or game.sim.golden >= 8000:
		fail("shield tap did not spend golden in the sim")
		game.queue_free()
		return
	game.sim._make_mob("imp", "Imp", game.sim.anchor + Vector2i(700, 0), 80, 1, 50, 100, 0, [], "start:center")
	for id in game.sim.order:
		var foe: Dictionary = game.sim.entities[id]
		if str(foe.subtype) == "imp":
			foe.active_at = 0
	game._process(0.0)
	game.board._process(0.0)
	var foe_snap: Dictionary = {}
	for row in game.board.snap.foes:
		if str(row.subtype) == "imp":
			foe_snap = row
	if foe_snap.is_empty():
		fail("spawned imp was not on the board")
		game.queue_free()
		return
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = game.board._milli_screen(foe_snap.pos)
	var queued := game.sim.queue.size()
	game._unhandled_input(touch)
	if game.sim.queue.size() <= queued or str(game.sim.queue.back().type) != "focus":
		fail("tap-to-focus did not submit at %s board %s" % [touch.position, game.board.size])
		game.queue_free()
		return
	game._tap_frame = -1
	var tile := Fixed.tile_of(game.sim.anchor) + Vector2i(3, 0)
	if game.sim.map.at(tile) < 0:
		tile = Fixed.tile_of(game.sim.anchor) + Vector2i(0, 2)
	var move := InputEventScreenTouch.new()
	move.pressed = true
	move.index = 1
	move.position = game.board._milli_screen(Fixed.tile_center(tile))
	queued = game.sim.queue.size()
	game._unhandled_input(move)
	if game.sim.queue.size() <= queued:
		fail("tap-to-move did not submit")
		game.queue_free()
		return
	var moved: Dictionary = game.sim.queue.back()
	if str(moved.type) != "move_tile" and str(moved.type) != "move_room":
		fail("ground tap submitted %s" % moved.type)
		game.queue_free()
		return
	game.sim._hurt(game.sim._hero("azrael"), 99999, "single", 0, false)
	game._process(0.0)
	game.board._process(0.0)
	if not str(game.hud._portraits.azrael.text).contains("DOWN"):
		fail("downed portrait read %s" % game.hud._portraits.azrael.text)
		game.queue_free()
		return
	if str(game.hud._portraits.michael.text).contains("DOWN"):
		fail("michael portrait showed the wrong angel down")
	game.queue_free()


func _pin_screen(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = Vector2.ZERO
	node.size = Vector2(1280, 720)


func _spend_ok(sim: CombatSim, cmd: String, ability: String, bounty: int = 0) -> bool:
	var before := sim.golden
	var regen := Balance.golden_regen(0)
	sim.submit(cmd, {})
	sim.tick_once()
	var expect := before - Balance.cost(ability) + regen + bounty
	if sim.golden != expect:
		fail("%s spent to %d, want %d" % [cmd, sim.golden, expect])
		return false
	return true


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
