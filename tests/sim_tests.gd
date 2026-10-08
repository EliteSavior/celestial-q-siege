extends RefCounted

var failures: Array = []
var host = null
var ran := 0
## Callbacks that must run after the next canvas flush. Headless does not
## invoke _draw inside notification(NOTIFICATION_DRAW); the redraw callback
## runs between frames.
var after_frame: Array = []

const POINT_COSTS := {
	"detect_pulse": 5,
	"single_heal": 6,
	"cleanse": 6,
	"taunt": 8,
	"body_block": 8,
	"disarm": 8,
	"escape_dash": 8,
	"disengage": 8,
	"self_shield": 8,
	"strike": 10,
	"shield_wall": 12,
	"burst": 12,
	"beam": 12,
	"sunstrike": 14,
	"party_heal": 15,
	"aoe_zone": 15,
	"slow_revive": 18,
	"emergency_res": 20,
	"scatter": 0,
	"phalanx": 0,
}


func run_all() -> int:
	var tests := [
		"test_map_connects",
		"test_elixir_compounds_by_stage",
		"test_opening_bank_funds_the_first_decision",
		"test_elixir_bar_is_zero_to_one_hundred",
		"test_ability_point_costs_are_spent",
		"test_golden_regen_over_ticks",
		"test_debuff_statuses_are_queryable",
		"test_skill_use_during_a_fight",
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
		"test_lucifer_transforms_before_buttons",
		"test_boss_buttons_are_telegraphed_and_answerable",
		"test_echo_reflects_run_history",
		"test_early_descent_is_a_weaker_echo",
		"test_director_takes_the_early_descent_gamble",
		"test_echo_one_wave_and_planted_traps_fire",
		"test_boss_commands_are_deterministic",
		"test_scene_lucifer_tells",
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
		"test_trap_cap_is_per_room",
		"test_commitment_telegraphs_before_it_lands",
		"test_director_tiers_follow_rooms_in_play",
		"test_director_reinforces_the_next_room",
		"test_director_elite_commit_is_telegraphed",
		"test_director_curse_shows_a_cast_bar",
		"test_director_defends_the_stake_first",
		"test_director_spends_dark_on_the_march",
		"test_competent_policy_can_win",
		"test_march_takes_minutes",
		"test_per_member_hp_downed_and_revive",
		"test_auto_attack_needs_no_order",
		"test_damage_shapes_single_and_aoe",
		"test_command_bar_routes_every_button",
		"test_elixir_spend_cap_and_interaction_income",
		"test_scene_touch_playable",
		"test_touch_reaches_the_board_and_forgiving_taps",
		"test_in_run_menu_restarts_or_returns_to_title",
		"test_guide_arrow_and_persistent_prompt",
		"test_opening_grace_before_the_player_acts",
		"test_iso_screen_tile_roundtrip",
		"test_threat_tells_are_distinct",
		"test_win_lose_restart_loop",
		"test_coach_hints_name_the_loop",
		"test_juice_stays_out_of_the_sim",
		"test_human_policy_can_win",
		"test_walking_past_the_kit_loses",
		"test_threat_orders_the_target",
		"test_taunt_snaps_threat",
		"test_dps_elixir_attacks",
		"test_tougher_mobs_take_seconds",
		"test_single_heal_targets_the_chosen_hero",
		"test_mobs_hold_until_aggro",
		"test_new_acts_are_touchable",
		"test_tank_holds_under_autos",
		"test_overheal_can_pull",
		"test_mob_pulse_hits_the_party",
		"test_director_casts_weaken",
		"test_shrine_disables_room_traps",
		"test_threat_meter_names_the_holder",
		"test_diagonal_path_cuts_the_corner",
		"test_elixir_abilities_have_no_cooldown",
		"test_team_heal_button_is_its_own_control",
		"test_doorway_fight_does_not_end_in_one_tick",
		"test_entrance_stays_calm_until_the_first_room",
		"test_golden_regen_is_slower_than_the_infinite_heal_tune",
		"test_threat_line_names_real_pressure",
		"test_cleanse_removes_each_curse",
		"test_portrait_tap_does_not_swap_the_bar",
		"test_zoom_buttons_change_the_camera",
		"test_status_icons",
		"test_threat_bars_relative_to_tank",
		"test_tank_headroom",
		"test_tank_opens_the_fight",
		"test_entrance_takes_no_damage",
	]
	ran = tests.size()
	for name in tests:
		_flush_queued_frees()
		call(name)
	return 0 if failures.is_empty() else 1


func fail(msg: String) -> void:
	failures.append(msg)
	print("  x ", msg)


## queue_free waits for idle, and the suite runs inside one frame.
## Drop those nodes now so a later scene test is the only control under the cursor.
func _flush_queued_frees() -> void:
	if host == null:
		return
	var pending: Array = []
	for child in host.root.get_children():
		if child.is_queued_for_deletion():
			pending.append(child)
	for child in pending:
		child.free()


func test_map_connects() -> void:
	var map := DungeonMap.new()
	var errors: Array = map.validate()
	var tiles := map.path_between("start", "throne").size()
	print("  throne path ", tiles, " tiles")
	if not errors.is_empty():
		fail("map: %s" % str(errors))


func test_opening_bank_funds_the_first_decision() -> void:
	var sim := CombatSim.new()
	# 1.0.4: 36 points. Taunt + Mend + Strike + Shield, not also Sunstrike.
	# 1.0.3 opened at 6500 internal (6.5 on the old 0–10 meter).
	if sim.golden != Balance.GOLDEN_START:
		fail("opening golden %d, want %d" % [sim.golden, Balance.GOLDEN_START])
		return
	if Balance.points_of(sim.golden) != 36:
		fail("opening is %d points, want 36" % Balance.points_of(sim.golden))
		return
	var opener := Balance.cost("taunt") + Balance.cost("single_heal") + Balance.cost("strike") + Balance.cost("shield_wall")
	if sim.golden != opener:
		fail("opening %d is not the four-cast opener %d" % [sim.golden, opener])
		return
	if sim.golden + Balance.golden_regen(0) >= opener + Balance.cost("sunstrike"):
		fail("the first tick also funds a sunstrike on top of the opener")


func test_elixir_bar_is_zero_to_one_hundred() -> void:
	if Balance.POINT != 100 or Balance.ELIXIR_MAX != 100 * Balance.POINT:
		fail("bar max %d is not 100 points" % Balance.ELIXIR_MAX)
		return
	if Balance.points_of(Balance.ELIXIR_MAX) != 100:
		fail("display max %d" % Balance.points_of(Balance.ELIXIR_MAX))
		return
	var sim := CombatSim.new()
	sim.director_enabled = false
	if sim.golden < 0 or sim.golden > Balance.ELIXIR_MAX:
		fail("opening golden %d outside 0–100" % sim.golden)
		return
	if sim.dark < 0 or sim.dark > Balance.ELIXIR_MAX:
		fail("opening dark %d outside 0–100" % sim.dark)
		return
	# v1.1.0 opens Dread full so the director can summon immediately.
	if Balance.points_of(Balance.DARK_START) != 100:
		fail("dark start is %d, want a full bar" % Balance.points_of(Balance.DARK_START))
		return
	if Balance.points_of(Balance.summon_cost("swarm")) != 16:
		fail("swarm cost rescaled")
		return
	if Balance.dark_regen(0) != 5:
		fail("dark regen changed")
		return
	sim.golden = Balance.ELIXIR_MAX
	sim.dark = Balance.ELIXIR_MAX
	sim.tick_once()
	if sim.golden != Balance.ELIXIR_MAX or sim.dark != Balance.ELIXIR_MAX:
		fail("bar left 0–100 golden %d dark %d" % [sim.golden, sim.dark])


func test_ability_point_costs_are_spent() -> void:
	for ability in POINT_COSTS.keys():
		var want: int = int(POINT_COSTS[ability])
		if Balance.point_cost(ability) != want:
			fail("%s costs %d points, want %d" % [ability, Balance.point_cost(ability), want])
			return
		if Balance.cost(ability) != want * Balance.POINT:
			fail("%s internal %d" % [ability, Balance.cost(ability)])
			return
		if want != 0 and (want < 5 or want > 20):
			fail("%s point cost %d is outside 5–20" % [ability, want])
			return
		if want == 0:
			continue
		var sim := _lab()
		if not _prime_cast(sim, ability):
			return
		var before := sim.golden
		sim.submit("ability", {"name": ability})
		sim.tick_once()
		var bounty := 0
		if ability == "cleanse":
			bounty = Balance.CLEANSE_BOUNTY
		elif ability == "disarm":
			bounty = Balance.DISARM_BOUNTY
		var expect := before - Balance.cost(ability) + Balance.golden_regen(sim.stage_reached) + bounty
		if sim.golden != expect:
			fail("%s spent to %d, want %d (%s)" % [ability, sim.golden, expect, _feed(sim)])
			return
		if sim.ability_casts != 1:
			fail("%s did not count a cast (%d)" % [ability, sim.ability_casts])
			return


func test_golden_regen_over_ticks() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	var n := 40
	var before := sim.golden
	for _i in n:
		sim.tick_once()
	var gain := sim.golden - before
	var want := Balance.golden_regen(0) * n
	if gain != want:
		fail("stage 0 regen %d over %d ticks, want %d" % [gain, n, want])
		return
	# 2 points/sec at 20 Hz, held exactly. 1.1.0 was 4 and heals felt free.
	if gain != 2 * Balance.POINT * n / Balance.TICK_HZ:
		fail("stage 0 is not 2 points/sec (%d)" % gain)
		return
	sim.stage_reached = 3
	before = sim.golden
	for _j in 10:
		sim.tick_once()
	if sim.golden - before != Balance.golden_regen(3) * 10:
		fail("stage 3 regen %d" % (sim.golden - before))
		return
	sim.golden = Balance.ELIXIR_MAX - 30
	sim.tick_once()
	if sim.golden != Balance.ELIXIR_MAX:
		fail("regen crossed the 100-point cap to %d" % sim.golden)


func test_debuff_statuses_are_queryable() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 9000
	sim.submit("curse", {"kind": "silence", "target": "raphael"}, "demon", 1)
	for _i in Balance.CURSE_CAST + 3:
		sim.tick_once()
	var raphael := sim._hero("raphael")
	raphael.rot_until = sim.tick + 40
	raphael.mark_until = sim.tick + 20
	raphael.weaken_until = sim.tick + 10
	raphael.shield = 55
	raphael.radiance = 3
	var rows: Array = sim.unit_statuses(raphael)
	for id in ["silence", "rot", "mark", "weaken"]:
		var row := _status_named(rows, id)
		if row.is_empty():
			fail("%s missing from the indicator query" % id)
			return
		if str(row.polarity) != "debuff":
			fail("%s is not a debuff" % id)
			return
		if int(row.left) <= 0:
			fail("%s has no timer" % id)
			return
	var sh := _status_named(rows, "shield")
	if sh.is_empty() or int(sh.stacks) != 55 or str(sh.polarity) != "buff":
		fail("shield badge %s" % str(sh))
		return
	if _status_named(rows, "radiance").is_empty() or int(_status_named(rows, "radiance").stacks) != 3:
		fail("damage buff missing")
		return
	var mob := _mob(sim, "imp", sim._hero("michael").pos + Vector2i(180, 0), 400)
	sim.golden = 8000
	sim._hero("michael").cooldowns.erase("taunt")
	sim._hero("michael").cooldowns.erase("shield_wall")
	sim.submit("ability", {"name": "taunt"})
	sim.submit("ability", {"name": "shield_wall"})
	sim.tick_once()
	if _status_named(sim.unit_statuses(sim._hero("michael")), "taunt").is_empty():
		fail("Michael is taunting with no badge")
		return
	if _status_named(sim.unit_statuses(mob), "taunt").is_empty():
		fail("taunted imp has no badge")
		return
	var walled := 0
	for angel in sim._angels():
		if bool(angel.alive) and not _status_named(sim.unit_statuses(angel), "wall").is_empty():
			walled += 1
	if walled != 5:
		fail("shield wall badges %d" % walled)
		return
	var snap := sim.build_snapshot()
	var published := false
	for a in snap.angels:
		if str(a.subtype) != "raphael":
			continue
		for st in a.get("statuses", []):
			if str(st.get("id", "")) == "silence" and int(st.get("left", 0)) > 0:
				published = true
	if not published:
		fail("snapshot hid silence from the indicator layer")


func test_skill_use_during_a_fight() -> void:
	# Autos still kill. Skills are extra casts the 1.0.3 bar could not fund.
	var imp := _skill_fight("imp", Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, true)
	var heavy := _skill_fight("heavy", Balance.HEAVY_HP, Balance.HEAVY_ATK, Balance.HEAVY_PERIOD, Balance.HEAVY_RANGE, true)
	var elite := _skill_fight("elite", Balance.ELITE_HP, Balance.ELITE_ATK, Balance.ELITE_PERIOD, Balance.ELITE_RANGE, true)
	print("  skill casts imp=%d heavy=%d elite=%d" % [int(imp.casts), int(heavy.casts), int(elite.casts)])
	if not bool(imp.dead) or not bool(imp.party):
		fail("imp fight was not winnable with skills dead=%s party=%s" % [imp.dead, imp.party])
		return
	if int(imp.casts) < 3:
		fail("imp fight only cast %d abilities" % int(imp.casts))
		return
	if not bool(heavy.dead) or int(heavy.casts) < 5:
		fail("heavy fight casts=%d dead=%s" % [int(heavy.casts), heavy.dead])
		return
	if not bool(elite.dead) or int(elite.casts) < 7:
		fail("elite fight casts=%d dead=%s" % [int(elite.casts), elite.dead])
		return
	var naked := _skill_fight("heavy", Balance.HEAVY_HP, Balance.HEAVY_ATK, Balance.HEAVY_PERIOD, Balance.HEAVY_RANGE, false)
	if int(naked.casts) != 0:
		fail("idle fight cast %d" % int(naked.casts))
		return
	if int(heavy.party_hp) <= int(naked.party_hp):
		fail("skills did not protect the party (%d vs %d)" % [int(heavy.party_hp), int(naked.party_hp)])


func test_elixir_compounds_by_stage() -> void:
	var prev := -1
	var prev_step := 0
	for s in 5:
		var g := Balance.golden_regen(s)
		if Balance.dark_regen(s) <= 0:
			fail("dark regen missing at %d" % s)
		if s == 0 and g <= 3:
			fail("opening golden regen %d was not raised from 1.0.3" % g)
		if s == 0 and g * Balance.TICK_HZ >= Balance.cost("single_heal") * 2:
			fail("opening regen %d funds two mends a second" % g)
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
	if not sim.build_snapshot().traps.is_empty():
		fail("standing near a trap rendered it")
		return
	sim.golden = 8000
	sim.submit("ability", {"name": "detect_pulse"})
	sim.tick_once()
	if sim.build_snapshot().traps.is_empty():
		fail("Detect did not reveal the spike")


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
	# The antechamber does not punish a fresh run. Camping a cleared fork does.
	_stand(idle, "fork")
	_stand(moving, "fork")
	idle.idle_ticks = 0
	idle.corruption = false
	moving.idle_ticks = 0
	moving.corruption = false
	for _i in Balance.OPENING_GRACE_TICKS + 420:
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


func test_lucifer_transforms_before_buttons() -> void:
	var sim := _descend_with_hp(100, 6000, false)
	if sim.phase != "lucifer":
		fail("descend did not open the lucifer phase")
		return
	if sim._boss().is_empty():
		fail("lucifer was not on the board during the rise")
		return
	var remain := sim.transform_until - sim.tick
	if remain < 55:
		fail("transformation tell is %d ticks" % remain)
	var hp_before := _party_hp(sim)
	sim.submit("boss", {"button": "judgment"}, "demon", 1)
	sim.tick_once()
	if not sim.telegraph.is_empty():
		fail("a boss button opened during the transformation")
	if sim.legal_boss("cleave") != "transform":
		fail("legal_boss during the rise: %s" % sim.legal_boss("cleave"))
	while sim.tick < sim.transform_until:
		sim.tick_once()
	if _party_hp(sim) != hp_before:
		fail("the rise dealt damage %d -> %d" % [hp_before, _party_hp(sim)])
	sim.submit("boss", {"button": "hell_rain"}, "demon", 1)
	sim.tick_once()
	if str(sim.telegraph.get("name", "")) != "hell_rain":
		fail("hell rain did not open after the rise")
		return
	var tell := int(sim.telegraph.until) - sim.tick
	if tell < Balance.BOSS_TELL - 1:
		fail("hell rain tell is %d ticks" % tell)
	var marked := _party_hp(sim)
	while sim.tick < int(sim.telegraph.until) - 1:
		sim.tick_once()
	if _party_hp(sim) != marked:
		fail("hell rain dealt damage before the tell ended")


func test_boss_buttons_are_telegraphed_and_answerable() -> void:
	# Hell rain: the marked tile is the hit. Stepping out is the answer.
	var rain := _descend_with_hp(100, 4000, false)
	_wait_boss_ready(rain)
	rain.submit("boss", {"button": "hell_rain"}, "demon", 1)
	rain.tick_once()
	if str(rain.telegraph.get("name", "")) != "hell_rain" or rain.hell_rain_marks.size() < 5:
		fail("hell rain did not mark the party")
		return
	rain.root_until = rain.tick + 200
	var stayer: Dictionary = rain._hero("gabriel")
	var mover: Dictionary = rain._hero("uriel")
	var stay_hp := int(stayer.hp)
	var move_hp := int(mover.hp)
	for mark in rain.hell_rain_marks:
		if int(mark.id) == int(mover.id):
			mover.pos = mark.pos + Vector2i(4000, 0)
	while not rain.telegraph.is_empty():
		rain.tick_once()
	if int(stayer.hp) >= stay_hp:
		fail("hell rain missed the angel who stayed in the mark")
	if int(mover.hp) < move_hp:
		fail("hell rain hit the angel who left the mark")
	if not stayer.alive:
		fail("hell rain killed from full health")
	# Scatter Roll is the same answer without a manual reposition.
	var rolled := _descend_with_hp(100, 4000, false)
	_wait_boss_ready(rolled)
	rolled.submit("boss", {"button": "hell_rain"}, "demon", 1)
	rolled.tick_once()
	var taken := int(rolled.stats.damage_taken)
	rolled.submit("scatter", {})
	rolled.tick_once()
	while not rolled.telegraph.is_empty():
		rolled.tick_once()
	if int(rolled.stats.damage_taken) > taken:
		fail("scatter did not clear hell rain")
	# Cleave: the lane is locked when the tell opens.
	var cleave := _descend_with_hp(100, 4000, false)
	_wait_boss_ready(cleave)
	cleave.submit("boss", {"button": "cleave"}, "demon", 1)
	cleave.tick_once()
	if int(cleave.telegraph.until) - cleave.tick < Balance.BOSS_TELL - 1:
		fail("cleave tell is short")
	var origin: Vector2i = cleave.telegraph.from
	var end: Vector2i = cleave.telegraph.end
	var mid := Vector2i((origin.x + end.x) / 2, (origin.y + end.y) / 2)
	cleave.root_until = cleave.tick + 200
	var on_lane: Dictionary = cleave._hero("michael")
	var off_lane: Dictionary = cleave._hero("gabriel")
	on_lane.pos = mid
	off_lane.pos = mid + Vector2i(0, 4000)
	var on_hp := int(on_lane.hp)
	var off_hp := int(off_lane.hp)
	while not cleave.telegraph.is_empty():
		cleave.tick_once()
	if int(on_lane.hp) >= on_hp:
		fail("cleave missed the angel in the lane")
	if int(off_lane.hp) < off_hp:
		fail("cleave hit the angel who left the lane")
	if not on_lane.alive:
		fail("cleave killed from full health")
	# Judgment: single target, body-block answers it, full health survives.
	var judge := _descend_with_hp(100, 4000, false)
	_wait_boss_ready(judge)
	var gabriel: Dictionary = judge._hero("gabriel")
	gabriel.hp = 90
	judge.submit("boss", {"button": "judgment"}, "demon", 1)
	judge.tick_once()
	if int(judge.telegraph.get("target", 0)) != int(gabriel.id):
		fail("judgment did not mark the lowest angel")
	judge.golden = 8000
	judge.submit("ability", {"name": "body_block"})
	judge.tick_once()
	var g_hp := int(gabriel.hp)
	var m_hp := int(judge._hero("michael").hp)
	while not judge.telegraph.is_empty():
		judge.tick_once()
	if int(gabriel.hp) != g_hp:
		fail("body-block did not catch judgment")
	if int(judge._hero("michael").hp) >= m_hp:
		fail("michael did not take the blocked judgment")
	if not judge._hero("michael").alive:
		fail("judgment killed through michael")
	var naked := _descend_with_hp(100, 4000, false)
	_wait_boss_ready(naked)
	naked.submit("boss", {"button": "judgment"}, "demon", 1)
	naked.tick_once()
	var victim := naked._ent(int(naked.telegraph.get("target", 0)))
	while not naked.telegraph.is_empty():
		naked.tick_once()
	if victim.is_empty() or not victim.alive:
		fail("judgment deleted a full-health angel")
	# Grasp: Phalanx refuses the pull and keeps more health.
	var pulled := _descend_with_hp(100, 4000, false)
	var held := _descend_with_hp(100, 4000, false)
	_wait_boss_ready(pulled)
	_wait_boss_ready(held)
	pulled.submit("boss", {"button": "grasp"}, "demon", 1)
	held.submit("boss", {"button": "grasp"}, "demon", 1)
	pulled.tick_once()
	held.tick_once()
	pulled.root_until = pulled.tick + 200
	held.root_until = held.tick + 200
	held.submit("phalanx", {})
	held.tick_once()
	var p0 := int(Fixed.dist(pulled._hero("gabriel").pos, pulled._boss().pos))
	var h0 := int(Fixed.dist(held._hero("gabriel").pos, held._boss().pos))
	var p_taken := int(pulled.stats.damage_taken)
	var h_taken := int(held.stats.damage_taken)
	while not pulled.telegraph.is_empty():
		pulled.tick_once()
	while not held.telegraph.is_empty():
		held.tick_once()
	var p1 := int(Fixed.dist(pulled._hero("gabriel").pos, pulled._boss().pos))
	var h1 := int(Fixed.dist(held._hero("gabriel").pos, held._boss().pos))
	if p0 - p1 < 800:
		fail("grasp pull was %d" % (p0 - p1))
	if h0 - h1 > 400:
		fail("phalanx was pulled %d" % (h0 - h1))
	if int(held.stats.damage_taken) - h_taken >= int(pulled.stats.damage_taken) - p_taken:
		fail("phalanx did not soften grasp")


func test_echo_reflects_run_history() -> void:
	var trap := _history_descend(16, 2, 2, 8000, 100, false)
	var summon := _history_descend(2, 15, 2, 8000, 100, false)
	var curse := _history_descend(2, 2, 12, 8000, 100, false)
	var early := _history_descend(2, 15, 2, 8000, 100, true)
	if trap.echo_style != "traps" or summon.echo_style != "summons" or curse.echo_style != "curses":
		fail("styles trap=%s summon=%s curse=%s" % [trap.echo_style, summon.echo_style, curse.echo_style])
	if summon.echo_units.size() <= trap.echo_units.size():
		fail("summon wave %s was not bigger than trap wave %s" % [str(summon.echo_units), str(trap.echo_units)])
	if trap.echo_traps <= summon.echo_traps:
		fail("trap echo laid %d traps, summon laid %d" % [trap.echo_traps, summon.echo_traps])
	if trap.trap_cap <= summon.trap_cap:
		fail("trap cap %d was not higher than summon cap %d" % [trap.trap_cap, summon.trap_cap])
	if summon.trap_cap != Balance.ECHO_TRAP_CAP:
		fail("summon echo did not cut the trap cap")
	if _pattern_count(curse.lucifer_pattern, "judgment") <= _pattern_count(summon.lucifer_pattern, "judgment"):
		fail("curse pattern %s was not more judgment than %s" % [str(curse.lucifer_pattern), str(summon.lucifer_pattern)])
	if curse.echo_traps != 0:
		fail("curse echo laid traps")
	if early.echo_units.size() >= summon.echo_units.size():
		fail("early summon wave %s was not weaker than %s" % [str(early.echo_units), str(summon.echo_units)])
	if int(early._boss().hp_max) >= int(summon._boss().hp_max):
		fail("early lucifer was not weaker")
	if early.echo_spent >= summon.echo_spent:
		fail("early descent spent %d vs %d" % [early.echo_spent, summon.echo_spent])
	if summon.echo_units.size() > Balance.MOB_CAP:
		fail("summon echo was the uncapped wave %s" % str(summon.echo_units))
	print("  echoes trap=%s traps=%d | summon=%s | curse=%s | early=%s spent %d/%d" % [
		str(trap.echo_units), trap.echo_traps, str(summon.echo_units), str(curse.lucifer_pattern),
		str(early.echo_units), early.echo_spent, summon.echo_spent,
	])
	# Same planted set: a trap siege keeps a trappier field than a summon siege.
	var planted_trap := _plant_four()
	planted_trap.traps_placed = 16
	planted_trap.spawns_placed = 2
	planted_trap.curses_cast = 2
	planted_trap.dark = 8000
	planted_trap.submit("descend", {"early": false}, "demon", 1)
	var planted_summon := _plant_four()
	planted_summon.traps_placed = 2
	planted_summon.spawns_placed = 15
	planted_summon.curses_cast = 2
	planted_summon.dark = 8000
	planted_summon.submit("descend", {"early": false}, "demon", 1)
	for _i in 220:
		planted_trap.tick_once()
		planted_summon.tick_once()
	var trap_armed := _armed_count(planted_trap)
	var summon_armed := _armed_count(planted_summon)
	if trap_armed <= summon_armed:
		fail("planted field trap %d was not trappier than summon %d" % [trap_armed, summon_armed])


func test_early_descent_is_a_weaker_echo() -> void:
	var late := _history_descend(16, 2, 2, 8000, 100, false)
	var early := _history_descend(16, 2, 2, 8000, 100, true)
	if int(early._boss().hp_max) != Balance.LUCIFER_HP_EARLY:
		fail("early hp %s" % str(early._boss().get("hp_max", 0)))
	if int(late._boss().hp_max) != Balance.LUCIFER_HP:
		fail("late hp %s" % str(late._boss().get("hp_max", 0)))
	if early.echo_units.size() >= late.echo_units.size() and early.echo_traps >= late.echo_traps:
		fail("early echo was not weaker units %s/%s traps %d/%d" % [
			str(early.echo_units), str(late.echo_units), early.echo_traps, late.echo_traps,
		])
	if early.echo_spent >= late.echo_spent:
		fail("early spent %d late spent %d" % [early.echo_spent, late.echo_spent])
	print("  early-descent units %s traps %d spent %d | late units %s traps %d spent %d" % [
		str(early.echo_units), early.echo_traps, early.echo_spent,
		str(late.echo_units), late.echo_traps, late.echo_spent,
	])


func test_director_takes_the_early_descent_gamble() -> void:
	var sim := CombatSim.new()
	_stand(sim, "gallery3")
	sim.stage_reached = 2
	sim.rooms_cleared = Balance.ELITE_ROOMS
	sim.altar_done = false
	sim.seal_done = true
	sim.font_done = true
	sim.dark = 5000
	sim.golden = 9000
	for a in sim._angels():
		a.hp = maxi(1, int(a.hp_max) * 40 / 100)
	_ready_director(sim)
	var ticks := 0
	while sim.phase != "lucifer" and ticks < 40:
		sim.tick_once()
		ticks += 1
	if not sim.early_descend:
		fail("wounded sanctum party did not draw an early descent: %s" % sim.debug_string())
		return
	if int(sim._boss().hp_max) != Balance.LUCIFER_HP_EARLY:
		fail("early gamble spawned a full lucifer")
	var late := CombatSim.new()
	late.director_enabled = false
	late.dark = 5000
	late.traps_placed = sim.traps_placed
	late.spawns_placed = sim.spawns_placed
	late.curses_cast = sim.curses_cast
	for b in late._angels():
		b.hp = maxi(1, int(b.hp_max) * 40 / 100)
	late.submit("descend", {"early": false}, "demon", 1)
	late.tick_once()
	if sim.echo_spent >= late.echo_spent:
		fail("gamble spent %d vs a prepared %d" % [sim.echo_spent, late.echo_spent])
	if sim.echo_units.size() > late.echo_units.size():
		fail("gamble wave %s beat the prepared wave %s" % [str(sim.echo_units), str(late.echo_units)])


func test_echo_one_wave_and_planted_traps_fire() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 9000
	sim.submit("trap", {"kind": "spike", "node": "trapped:choke"}, "demon", 1)
	sim.tick_once()
	var spike := _find_kind(sim, "trap")
	if spike.is_empty():
		fail("spike was not planted")
		return
	sim.dark = 8000
	for a in sim._angels():
		a.atk = 0
	sim.submit("descend", {"early": false}, "demon", 1)
	sim.tick_once()
	if not bool(spike.get("armed", false)):
		fail("the planted spike was removed by the descent")
	var scheduled := 0
	for c in sim.queue:
		if str(c.type) == "spawn":
			scheduled += 1
	if scheduled != sim.echo_units.size() or scheduled < 1:
		fail("wave scheduled %d units from %s" % [scheduled, str(sim.echo_units)])
	var guard := 0
	while sim._command_pending("spawn") and guard < 400:
		sim.tick_once()
		guard += 1
	if sim.mob_count() != scheduled:
		fail("one wave produced %d mobs from %d spawns" % [sim.mob_count(), scheduled])
	var mobs := sim.mob_count()
	for _i in 30:
		sim.tick_once()
	if sim.mob_count() != mobs:
		fail("a second wave arrived")
	if sim._command_pending("spawn"):
		fail("spawn commands remained after the one wave")
	sim.submit("curse", {"kind": "silence", "target": "raphael"}, "demon", 1)
	sim.tick_once()
	if int(sim._hero("raphael").silence_until) > sim.tick:
		fail("the echo accepted a new curse")
	sim.root_until = sim.tick + 10
	sim.anchor = spike.pos
	for angel in sim._angels():
		angel.pos = spike.pos
	var tripped := int(sim.stats.traps_triggered)
	sim.tick_once()
	if int(sim.stats.traps_triggered) <= tripped:
		fail("planted spike did not fire during the echo")


func test_boss_commands_are_deterministic() -> void:
	var a := _history_descend(9, 6, 3, 7000, 90, false)
	var b := _history_descend(9, 6, 3, 7000, 90, false)
	_wait_boss_ready(a)
	_wait_boss_ready(b)
	for button in ["hell_rain", "cleave", "judgment", "grasp"]:
		a.submit("boss", {"button": button}, "demon", 1)
		b.submit("boss", {"button": button}, "demon", 1)
		for _i in Balance.BOSS_TELL + Balance.BOSS_GAP + 2:
			a.tick_once()
			b.tick_once()
			if a.checksum() != b.checksum():
				fail("boss commands diverged on %s" % button)
				return


func test_scene_lucifer_tells() -> void:
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
	game.paused = true
	game.sim.director_enabled = false
	game.hud._brief.visible = false
	game.hud._brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.sim.dark = 8000
	game.sim.traps_placed = 16
	game.sim.spawns_placed = 2
	game.sim.curses_cast = 2
	game.sim.submit("descend", {"early": false}, "demon", 1)
	game.sim.tick_once()
	game._process(0.0)
	game.board._process(0.0)
	if not game.hud._boss.visible:
		fail("boss hp bar hidden during the transformation")
		game.queue_free()
		return
	if int(game.hud._boss.max_value) != int(game.board.snap.boss_hp_max) or int(game.hud._boss.value) != int(game.board.snap.boss_hp):
		fail("boss bar does not match the sim")
		game.queue_free()
		return
	if not str(game.hud._boss_l.text).contains("Transforms"):
		fail("transform tell read %s" % game.hud._boss_l.text)
		game.queue_free()
		return
	game.board.notification(CanvasItem.NOTIFICATION_DRAW)
	while game.sim.tick < game.sim.transform_until:
		game.sim.tick_once()
	game.sim.submit("boss", {"button": "cleave"}, "demon", 1)
	game.sim.tick_once()
	game._process(0.0)
	game.board._process(0.0)
	game.board.notification(CanvasItem.NOTIFICATION_DRAW)
	if str(game.board.snap.telegraph.get("name", "")) != "cleave":
		fail("cleave tell was not on the snapshot")
		game.queue_free()
		return
	if not str(game.hud._boss_l.text).contains("cleave"):
		fail("hud tell read %s" % game.hud._boss_l.text)
		game.queue_free()
		return
	var guard := 0
	while game.sim.count_subtype("heavy") + game.sim.count_subtype("imp") < 1 and guard < 400:
		game.sim.tick_once()
		guard += 1
	game._process(0.0)
	game.board._process(0.0)
	game.board.notification(CanvasItem.NOTIFICATION_DRAW)
	var echo_seen := false
	for foe in game.board.snap.foes:
		if str(foe.subtype) == "heavy" or str(foe.subtype) == "imp":
			echo_seen = true
	if not echo_seen:
		fail("echo wave was not on the board")
		game.queue_free()
		return
	var lucifer := {}
	for foe2 in game.board.snap.foes:
		if str(foe2.subtype) == "lucifer":
			lucifer = foe2
	if lucifer.is_empty():
		fail("lucifer left the board")
		game.queue_free()
		return
	game._tap_frame = -1
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = game.board._milli_screen(lucifer.pos)
	var queued := game.sim.queue.size()
	game._unhandled_input(touch)
	if game.sim.queue.size() <= queued or str(game.sim.queue.back().type) != "focus":
		fail("tap did not focus lucifer")
		game.queue_free()
		return
	game.sim.golden = 8000
	game.hud._bar.shield.pressed.emit()
	game.sim.tick_once()
	if game.sim.shield_wall_until <= game.sim.tick:
		fail("shield did not answer during the lucifer phase")
	game.queue_free()


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


func test_trap_cap_is_per_room() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 10000
	sim.submit("trap", {"kind": "spike", "node": "trapped:choke"}, "demon", 1)
	sim.submit("trap", {"kind": "snare", "node": "trapped:center"}, "demon", 1)
	sim.tick_once()
	sim.tick_once()
	var why := sim.legal_trap("hellflame", "trapped:flank")
	if why != "room":
		fail("third trap in one room was allowed (%s)" % why)


func test_commitment_telegraphs_before_it_lands() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 9000
	_stand(sim, "fork")
	var before := sim.dark
	sim.submit("commit", {
		"plan": "trap_cluster",
		"pieces": [
			{"kind": "spike", "node": "trapped:choke"},
			{"kind": "hellflame", "node": "trapped:center"},
		],
	}, "demon", 1)
	sim.tick_once()
	if sim.dark >= before:
		fail("cluster did not spend Dark on commit (%d -> %d)" % [before, sim.dark])
	if not _find_kind(sim, "trap").is_empty():
		fail("traps existed during the cluster cast")
	var commits: Array = sim.build_snapshot().get("commitments", [])
	if commits.is_empty():
		fail("trap cluster had no cast the angels could read")
		return
	var land := int(commits[0].land)
	if land - sim.tick < 60:
		fail("cluster cast shorter than 3s (%d)" % (land - sim.tick))
	while sim.tick < land - 1:
		sim.tick_once()
		if not _find_kind(sim, "trap").is_empty():
			fail("trap armed before the cluster cast finished")
			return
	sim.tick_once()
	var armed := 0
	var revealed := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)):
			armed += 1
			if bool(e.get("revealed", false)):
				revealed += 1
	if armed != 2:
		fail("cluster armed %d traps" % armed)
		return
	if revealed != 0:
		fail("cluster rendered without Detect (%d revealed)" % revealed)
		return
	sim.golden = 8000
	var hidden_trap := {}
	for id_h in sim.order:
		var eh: Dictionary = sim.entities[id_h]
		if str(eh.kind) == "trap" and bool(eh.get("armed", false)):
			hidden_trap = eh
			break
	# Stand inside the pulse and outside the spring, or the reveal tick
	# consumes the trap and the room is no longer at its cap.
	sim._hero("azrael").pos = hidden_trap.pos + Vector2i(800, 0)
	sim.submit("ability", {"name": "detect_pulse"})
	sim.tick_once()
	if not bool(hidden_trap.get("revealed", false)):
		fail("Detect did not reveal the committed trap")
		return
	sim.dark = 5000
	sim.submit("trap", {"kind": "snare", "node": "cursed:rear"}, "demon", 1)
	sim.tick_once()
	var snare := {}
	for id2 in sim.order:
		var e2: Dictionary = sim.entities[id2]
		if str(e2.kind) == "trap" and str(e2.subtype) == "snare":
			snare = e2
	if snare.is_empty():
		fail("quiet snare was not placed ahead")
		return
	if bool(snare.get("revealed", false)):
		fail("quiet snare was revealed without Detect")
		return
	if sim.legal_trap("snare", "trapped:flank") != "room":
		fail("room cap after the cluster: %s" % sim.legal_trap("snare", "trapped:flank"))
		return
	sim.golden = 8000
	var trap := {}
	for id3 in sim.order:
		var e3: Dictionary = sim.entities[id3]
		if str(e3.kind) == "trap" and bool(e3.get("armed", false)) and bool(e3.get("revealed", false)):
			trap = e3
			break
	sim._hero("azrael").pos = trap.pos
	sim.submit("ability", {"name": "disarm"})
	sim.tick_once()
	if bool(trap.get("armed", true)):
		fail("disarm did not answer the committed trap")


func test_director_tiers_follow_rooms_in_play() -> void:
	var early := CombatSim.new()
	_stand(early, "seal")
	early.rooms_cleared = 0
	early.dark = 10000
	early.visited["fork"] = true
	early.director.fortified = {}
	_ready_director(early)
	for _i in 30:
		early.tick_once()
	if early.count_subtype("heavy") > 0 or early.count_subtype("elite") > 0:
		fail("high tier defended the seal before any rooms were cleared")
	var mid := CombatSim.new()
	_stand(mid, "font")
	mid.rooms_cleared = Balance.HEAVY_ROOMS
	mid.stage_reached = 1
	mid.seal_done = true
	mid.visited["fork"] = true
	mid.dark = 10000
	_ready_director(mid)
	var heavy := false
	for _j in 40:
		mid.tick_once()
		if mid.count_subtype("elite") > 0:
			fail("elite defended the font at the heavy gate")
			return
		if mid.count_subtype("heavy") > 0:
			heavy = true
	if not heavy:
		fail("director did not bring a heavy to the font once %d rooms were clear" % Balance.HEAVY_ROOMS)


func test_director_reinforces_the_next_room() -> void:
	var sim := CombatSim.new()
	_stand(sim, "summoned")
	sim.stage_reached = 1
	sim.rooms_cleared = Balance.HEAVY_ROOMS
	sim.seal_done = true
	sim.font_done = true
	sim.altar_done = true
	sim.dark = 9500
	sim.director.fortified = {"seal": true, "font": true, "altar": true}
	sim.director.committed["summoned"] = 1
	sim.director.resolved["summoned"] = true
	sim._hero("raphael").silence_until = 9000
	_ready_director(sim)
	sim.submit("spawn", {"unit": "heavy", "node": "summoned:flank"}, "demon", 1)
	sim.tick_once()
	var ahead := str(sim.director._next_content_room())
	var fought := str(sim.party_room())
	if ahead == "" or ahead == fought:
		fail("ahead=%s party=%s" % [ahead, fought])
		return
	for _i in 12:
		sim.director.next_decision = 0
		sim.tick_once()
	var heavies_in_fight := 0
	var heavies_ahead := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.subtype) != "heavy":
			continue
		if str(e.get("home", "")) == fought:
			heavies_in_fight += 1
		if str(e.get("home", "")) == ahead:
			heavies_ahead += 1
	if heavies_in_fight > 1:
		fail("another heavy joined the room being fought (%s)" % fought)
	if heavies_ahead < 1:
		fail("heavy did not reinforce the next room %s" % ahead)


func test_director_elite_commit_is_telegraphed() -> void:
	var early := CombatSim.new()
	_stand(early, "cross3")
	early.rooms_cleared = Balance.ELITE_ROOMS - 1
	early.stage_reached = 2
	early.seal_done = true
	early.font_done = true
	early.visited["fork"] = true
	early.dark = 10000
	_ready_director(early)
	for _i in 40:
		early.tick_once()
		if early.count_subtype("elite") > 0:
			fail("elite spawned at %d rooms" % early.rooms_cleared)
			return
		for c in early.build_snapshot().get("commitments", []):
			if str(c.get("plan", "")) == "elite":
				fail("elite commitment before %d rooms" % Balance.ELITE_ROOMS)
				return
	var sim := CombatSim.new()
	_stand(sim, "cross3")
	sim.rooms_cleared = Balance.ELITE_ROOMS
	sim.stage_reached = 2
	sim.seal_done = true
	sim.font_done = true
	sim.visited["fork"] = true
	sim.dark = 10000
	_ready_director(sim)
	var saw := false
	for _j in 120:
		sim.tick_once()
		if sim.count_subtype("elite") > 0 and not saw:
			fail("elite appeared before its commitment cast")
			return
		for c2 in sim.build_snapshot().get("commitments", []):
			if str(c2.get("plan", "")) != "elite":
				continue
			if not saw and int(c2.land) - sim.tick < 50:
				fail("elite cast was %d ticks" % (int(c2.land) - sim.tick))
				return
			saw = true
		if saw and sim.count_subtype("elite") > 0:
			break
	if not saw:
		fail("director never committed the altar elite")
		return
	var guard := 0
	while sim.count_subtype("elite") == 0 and guard < 90:
		sim.tick_once()
		guard += 1
	var elite := _find_subtype(sim, "elite")
	if elite.is_empty():
		fail("committed elite never arrived")
		return
	var aff: Array = elite.affixes
	if aff.size() != 2 or not aff.has("teleporter") or not aff.has("molten"):
		fail("elite affixes %s" % str(aff))
	if int(elite.get("active_at", 0)) <= sim.tick:
		fail("elite could act before its spawn telegraph")


func test_director_curse_shows_a_cast_bar() -> void:
	var sim := CombatSim.new()
	_stand(sim, "gallery1")
	sim.stage_reached = 1
	sim.rooms_cleared = 2
	sim.seal_done = true
	sim.font_done = true
	sim.altar_done = true
	sim.dark = 9000
	sim.stance = CombatSim.STANCE_SPREAD
	sim.director.fortified = {"seal": true, "font": true, "altar": true}
	sim.director.committed["gallery1"] = 1
	sim.director.resolved["gallery1"] = true
	_ready_director(sim)
	var saw := false
	for _i in 80:
		sim.tick_once()
		var curses: Array = sim.build_snapshot().curses
		if curses.is_empty():
			continue
		saw = true
		var curse: Dictionary = curses[0]
		if int(curse.land) - sim.tick < 40:
			fail("director curse cast too short")
			return
		var hero := sim._ent(int(curse.target))
		if int(hero.get("mark_until", 0)) > sim.tick or int(hero.get("silence_until", 0)) > sim.tick or int(hero.get("rot_until", 0)) > sim.tick:
			fail("curse debuff was active during the cast bar")
			return
		break
	if not saw:
		fail("director never telegraphed a curse")


func test_director_defends_the_stake_first() -> void:
	var sim := CombatSim.new()
	_stand(sim, "seal")
	sim.visited["fork"] = true
	sim.dark = 10000
	sim.stance = CombatSim.STANCE_SPREAD
	_ready_director(sim)
	for _i in 6:
		sim.tick_once()
		if sim.mob_count() > 0:
			break
	var at_stake := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "mob" and bool(e.alive) and str(e.get("home", "")) == "seal":
			at_stake += 1
	if at_stake < 1:
		fail("seal was threatened and the director did not defend it")
	if not _find_kind(sim, "curse").is_empty():
		fail("a curse landed before the stake defender")


func test_director_spends_dark_on_the_march() -> void:
	var sim := CombatSim.new()
	_stand_corridor(sim, "m3a_0")
	sim.stage_reached = 3
	sim.rooms_cleared = 6
	sim.seal_done = true
	sim.font_done = true
	sim.altar_done = true
	sim.dark = Balance.ELIXIR_MAX
	sim.golden = 9000
	sim.director.fortified = {"seal": true, "font": true, "altar": true}
	sim.director.committed["gallery3"] = 1
	sim.director.resolved["gallery3"] = true
	_ready_director(sim)
	var before := sim.traps_placed + sim.spawns_placed + sim.curses_cast
	var late_max := 0
	for i in 900:
		if sim.outcome != "":
			fail("march wiped the party: %s" % sim.debug_string())
			return
		if sim.lowest_angel_hp_pct() < 65:
			sim.golden = maxi(sim.golden, 8000)
			sim.submit("heal", {})
		if sim.tick % 25 == 0:
			var tile := Fixed.tile_of(sim.anchor) + Vector2i(3, 0)
			if sim.map.at(tile) < 0:
				tile = Fixed.tile_of(sim.anchor) + Vector2i(-3, 0)
			if sim.map.at(tile) >= 0:
				sim.submit("move_tile", {"tile": tile})
		sim.tick_once()
		if i >= 500 and sim.dark > late_max:
			late_max = sim.dark
	var spent := sim.traps_placed + sim.spawns_placed + sim.curses_cast - before
	if spent < 3:
		fail("director spent %d actions on the march" % spent)
	if late_max >= Balance.ELIXIR_MAX - 200:
		fail("late march Dark climbed back to the cap (%d) after %d spends" % [late_max, spent])


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
			print("  lucifer ", sim.debug_string(), " echo=", sim.echo_units, " style=", sim.echo_style, " traps=", sim.traps_placed, " spawns=", sim.spawns_placed, " curses=", sim.curses_cast)
			if sim.echo_units.size() >= 6:
				fail("healthy siege still paid the capped echo %s" % str(sim.echo_units))
		if sim.tick % 2000 == 0:
			print("  ", sim.debug_string())
	var crawl_s := float(lucifer_tick) / 20.0
	var total_s := float(sim.tick) / 20.0
	var boss_s := total_s - crawl_s if lucifer_tick >= 0 else -1.0
	print("  pacing crawl=%0.1fs boss=%0.1fs total=%0.1fs outcome=%s casts=%d" % [crawl_s, boss_s, total_s, sim.outcome, sim.ability_casts])
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
	if boss_s < 90.0 or boss_s > 130.0:
		fail("boss %0.1fs is outside the 1.5–2 min climax" % boss_s)
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
	if int(sim.taunt_id) == int(bystander.id):
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
	if dive.threat_boost_until <= dive.tick:
		fail("taunt boost ended with the force window")
	if str(dive._mob_target(elite).subtype) != "michael":
		fail("stored taunt threat dropped Michael")


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
	if bool(edge.revealed) or bool(outside.revealed):
		fail("a trap rendered without Detect")
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


func _prime_cast(sim: CombatSim, ability: String) -> bool:
	var owner_name := Balance.owner_of(ability)
	if owner_name == "":
		fail("%s has no owner" % ability)
		return false
	var owner: Dictionary = sim._hero(owner_name)
	owner.cooldowns.erase(ability)
	sim.golden = 8000
	if ability in ["taunt", "strike", "burst", "sunstrike", "beam", "aoe_zone"]:
		_mob(sim, "imp", owner.pos + Vector2i(220, 0), 900)
	if ability == "disarm":
		var trap := _plant(sim, owner.pos + Vector2i(200, 0))
		trap.revealed = true
		trap.armed = true
	if ability == "cleanse":
		sim._hero("michael").silence_until = sim.tick + 80
	if ability == "slow_revive":
		var down: Dictionary = sim._hero("azrael")
		down.alive = false
		down.hp = 0
		down.final_death = false
	if ability == "emergency_res":
		var fallen: Dictionary = sim._hero("uriel")
		fallen.alive = false
		fallen.hp = 0
		fallen.final_death = false
	return true


func _status_named(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if str(row.get("id", "")) == id:
			return row
	return {}


func _skill_fight(subtype: String, hp: int, atk: int, period: int, mob_range: int, spend: bool) -> Dictionary:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.stance = CombatSim.STANCE_TIGHT
	var michael := sim._hero("michael")
	sim._make_mob(subtype, subtype, michael.pos + Vector2i(280, 0), hp, atk, period, mob_range, 0, [], "start:center")
	var mob: Dictionary = sim.entities[sim.next_id - 1]
	mob.active_at = 0
	mob.pulled = true
	var guard := 0
	while bool(mob.alive) and sim.outcome == "" and guard < 20 * 40:
		if spend:
			_mash_skills(sim)
		sim.tick_once()
		guard += 1
	var party := 0
	var alive := false
	for a in sim._angels():
		if bool(a.alive):
			alive = true
			party += int(a.hp)
	return {
		"casts": sim.ability_casts,
		"dead": not bool(mob.alive),
		"party": alive and sim.outcome != "demons",
		"party_hp": party,
		"hp_left": int(mob.hp),
	}


func _mash_skills(sim: CombatSim) -> void:
	if sim.tick % 5 != 0:
		return
	var foe := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "mob" and bool(e.alive):
			foe = int(e.id)
			break
	if foe != 0 and sim.focus_id != foe:
		sim.submit("focus", {"id": foe})
	if sim.lowest_angel_hp_pct() < 90:
		sim.submit("ability", {"name": "single_heal"})
	if foe != 0:
		sim.submit("ability", {"name": "taunt"})
		sim.submit("ability", {"name": "strike"})
		sim.submit("ability", {"name": "shield_wall"})
		sim.submit("ability", {"name": "sunstrike"})


func _assert_priced(owner: String, ability: String) -> void:
	if Balance.owner_of(ability) != owner:
		fail("%s owner is %s" % [ability, Balance.owner_of(ability)])
	if Balance.cost(ability) <= 0:
		fail("%s has no cost" % ability)
	if Balance.cooldown(ability) > 0:
		fail("%s still has a cooldown" % ability)


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
	if Balance.cooldown(ability) > 0 and int(hero.cooldowns.get(ability, 0)) <= sim.tick:
		fail("%s did not start a cooldown" % ability)


func _pay_blocked(sim: CombatSim, ability: String) -> void:
	var before := sim.golden
	sim.submit("ability", {"name": ability})
	sim.tick_once()
	if Balance.cooldown(ability) <= 0:
		if _feed(sim).contains("not ready"):
			fail("%s was cooling after cooldowns were removed" % ability)
		return
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


func test_threat_tells_are_distinct() -> void:
	var board = load("res://game/board_view.gd")
	var colors: Dictionary = board.TELL_COLOR
	var labels: Dictionary = board.TELL_LABEL
	var groups := [
		["silence", "rot", "mark"],
		["spike", "snare", "hellflame"],
		["hell_rain", "cleave", "judgment", "grasp"],
		["commit", "echo", "transform"],
	]
	for group in groups:
		var seen := {}
		for name in group:
			if not colors.has(name):
				fail("missing tell color %s" % name)
				return
			var c: Color = colors[name]
			var key := "%d,%d,%d" % [int(c.r * 20.0), int(c.g * 20.0), int(c.b * 20.0)]
			if seen.has(key):
				fail("%s shares a color with another tell in %s" % [name, str(group)])
				return
			seen[key] = true
			if str(labels.get(name, "")) == "":
				fail("missing tell label %s" % name)
				return
	var hints: Dictionary = board.HINT_COLOR
	for hint in ["Still air", "Skittering", "Whispers"]:
		if not hints.has(hint):
			fail("door hint %s has no color" % hint)
			return


func test_win_lose_restart_loop() -> void:
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
	game.hud._layout_bottom()
	game.sim.director_enabled = false
	if not game.briefing or not game.hud._brief.visible:
		fail("start screen was not up")
		game.queue_free()
		return
	var held := game.sim.tick
	game._process(1.0)
	if game.sim.tick != held:
		fail("start screen advanced the clock")
		game.queue_free()
		return
	var queued := game.sim.queue.size()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(640, 360)
	game._unhandled_input(touch)
	if game.sim.queue.size() != queued:
		fail("start screen accepted a march")
		game.queue_free()
		return
	var begin: Button = game.hud._begin
	var begin_r := begin.get_rect()
	if begin_r.size.x < 64.0 or begin_r.size.y < 64.0 or begin_r.position.y + begin_r.size.y > 720.0:
		fail("begin target %s" % begin_r)
		game.queue_free()
		return
	begin.pressed.emit()
	if game.briefing:
		fail("begin did not start")
		game.queue_free()
		return
	game._process(0.2)
	if game.sim.tick <= 0:
		fail("the run never ticked")
		game.queue_free()
		return
	for angel in game.sim._angels():
		game.sim._hurt(angel, 99999, "single", 0, false)
	for _i in 80:
		if game.sim.outcome != "":
			break
		game.sim.tick_once()
	game._process(0.0)
	if game.sim.outcome != "demon":
		fail("wipe was not a defeat: %s" % game.sim.debug_string())
		game.queue_free()
		return
	if not game.hud._end.visible or not game.hud._defeat_mark.visible or game.hud._victory_mark.visible:
		fail("defeat screen did not replace the board")
		game.queue_free()
		return
	if str(game.hud._defeat_mark.text) != "DEFEAT" or str(game.hud._again.text) != "Try again":
		fail("defeat copy %s / %s" % [game.hud._defeat_mark.text, game.hud._again.text])
		game.queue_free()
		return
	if not str(game.hud._end_label.text).contains("extinguished"):
		fail("defeat body %s" % game.hud._end_label.text)
		game.queue_free()
		return
	var defeat_color: Color = game.hud._end.color
	var again_r: Rect2 = game.hud._again.get_rect()
	if again_r.size.x < 64.0 or again_r.size.y < 64.0 or again_r.position.y + again_r.size.y > 720.0:
		fail("try-again target %s" % again_r)
		game.queue_free()
		return
	var q_end := game.sim.queue.size()
	game.command("shield")
	if game.sim.queue.size() != q_end:
		fail("defeat still accepted commands")
		game.queue_free()
		return
	game.hud._again.pressed.emit()
	if game.briefing or game.sim.outcome != "" or game.sim.tick != 0:
		fail("restart did not open a fresh run: %s" % game.sim.debug_string())
		game.queue_free()
		return
	game.sim.director_enabled = false
	game.sim.golden = 8000
	game.command("shield")
	game.sim.tick_once()
	game._process(0.0)
	if game.sim.shield_wall_until <= game.sim.tick:
		fail("restarted run ignored shield")
		game.queue_free()
		return
	var fill := game.hud._bar.shield.get_node_or_null("CdFill") as ColorRect
	if fill != null and fill.visible:
		fail("shield drew a cooldown veil; elixir is the only gate")
		game.queue_free()
		return
	game.sim.dark = 8000
	game.sim.submit("descend", {"early": false}, "demon", 1)
	game.sim.tick_once()
	var boss: Dictionary = game.sim._boss()
	if boss.is_empty():
		fail("descend did not bring lucifer")
		game.queue_free()
		return
	boss.hp = 1
	game.sim._hurt(boss, 50, "single", 1, false)
	game.sim.tick_once()
	game._process(0.0)
	if game.sim.outcome != "angels":
		fail("killing lucifer was not a win")
		game.queue_free()
		return
	if not game.hud._victory_mark.visible or game.hud._defeat_mark.visible:
		fail("victory screen missing")
		game.queue_free()
		return
	if str(game.hud._victory_mark.text) != "VICTORY" or str(game.hud._again.text) != "Siege again":
		fail("victory copy %s / %s" % [game.hud._victory_mark.text, game.hud._again.text])
		game.queue_free()
		return
	if game.hud._end.color == defeat_color:
		fail("victory and defeat share a panel")
		game.queue_free()
		return
	var title_r: Rect2 = game.hud._to_title.get_rect()
	if title_r.size.y < 48.0 or title_r.position.y + title_r.size.y > 720.0:
		fail("title button %s" % title_r)
		game.queue_free()
		return
	game.hud._to_title.pressed.emit()
	if not game.briefing or not game.hud._brief.visible or game.sim.tick != 0 or game.sim.outcome != "":
		fail("title did not return to the start screen")
		game.queue_free()
		return
	game._process(0.5)
	if game.sim.tick != 0:
		fail("title screen ticked")
		game.queue_free()
		return
	game.hud.size = Vector2(1280, 800)
	game.hud._layout_bottom()
	var shield: Button = game.hud._bar.shield
	var shield_r := shield.get_rect()
	if shield_r.size.x < 64.0 or shield_r.size.y < 64.0:
		fail("shield target on a tall screen %s" % shield_r)
		game.queue_free()
		return
	if shield_r.position.y < 640.0 or shield_r.position.y + shield_r.size.y > 800.0:
		fail("command bar left the bottom of an 800-tall screen %s" % shield_r)
		game.queue_free()
		return
	game.queue_free()


func test_coach_hints_name_the_loop() -> void:
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
	game.hud._brief.visible = false
	game.hud._brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.sim.director_enabled = false
	game._process(0.0)
	var line := str(game.hud._coach.text)
	if not line.contains("squad") and not line.contains("Tap"):
		fail("opening hint was %s" % line)
		game.queue_free()
		return
	var tile: Vector2i = game.sim.map.center_tile("fork")
	game.sim.anchor = Fixed.tile_center(tile)
	for angel in game.sim._angels():
		angel.pos = game.sim.anchor
	game.sim.path = []
	game.sim.tick_once()
	game._process(0.0)
	line = str(game.hud._coach.text)
	if not line.contains("Still air") or not line.contains("3"):
		fail("fork hint was %s" % line)
		game.queue_free()
		return
	game.sim.dark = 9000
	game.sim.submit("curse", {"kind": "rot", "target": "raphael"}, "demon", 1)
	game.sim.tick_once()
	game._process(0.0)
	game.board.notification(CanvasItem.NOTIFICATION_DRAW)
	line = str(game.hud._coach.text)
	if not line.contains("Rot") or not line.contains("Cleanse"):
		fail("curse hint was %s" % line)
		game.queue_free()
		return
	for _i in 90:
		game.sim.tick_once()
	game.sim.dark = 8000
	game.sim.submit("descend", {"early": false}, "demon", 1)
	game.sim.tick_once()
	game._process(0.0)
	line = str(game.hud._coach.text)
	if not line.contains("Lucifer"):
		fail("rise hint was %s" % line)
		game.queue_free()
		return
	while game.sim.tick < game.sim.transform_until:
		game.sim.tick_once()
	game.sim.submit("boss", {"button": "hell_rain"}, "demon", 1)
	game.sim.tick_once()
	game._process(0.0)
	game.board.notification(CanvasItem.NOTIFICATION_DRAW)
	line = str(game.hud._coach.text)
	if not line.contains("Hell rain") or not line.contains("Scatter"):
		fail("hell rain hint was %s" % line)
		game.queue_free()
		return
	game.hud._hide.pressed.emit()
	game._process(0.0)
	if game.hud._coach.visible:
		fail("hints stayed up after hide")
	game.queue_free()


func test_juice_stays_out_of_the_sim() -> void:
	if host == null:
		fail("scene test has no tree")
		return
	var bare := CombatSim.new()
	bare.director_enabled = false
	var game := GameRoot.new()
	game.boot()
	_pin_screen(game)
	host.root.add_child(game)
	_pin_screen(game)
	game.briefing = false
	game.sim.director_enabled = false
	game.hud._brief.visible = false
	bare.submit("stance", {"stance": CombatSim.STANCE_SPREAD})
	game.sim.submit("stance", {"stance": CombatSim.STANCE_SPREAD})
	bare.tick_once()
	game.sim.tick_once()
	bare._hurt(bare._hero("gabriel"), 30, "single", 0, false)
	game.sim._hurt(game.sim._hero("gabriel"), 30, "single", 0, false)
	game.juice.follow(game.sim.build_snapshot())
	game.juice._process(0.05)
	if game.sim.checksum() != bare.checksum():
		fail("view juice diverged the sim")
		game.queue_free()
		return
	if game.juice.sfx == null or game.juice.sfx._clips.is_empty():
		fail("sfx clips were not built")
		game.queue_free()
		return
	if game.juice.sfx.played.find("hit") < 0:
		fail("a hit did not hook a sound %s" % str(game.juice.sfx.played))
		game.queue_free()
		return
	var q := game.sim.queue.size()
	game.juice.follow(game.sim.build_snapshot())
	if game.sim.queue.size() != q:
		fail("juice submitted a command")
		game.queue_free()
		return
	game.hud._bar.heal.pressed.emit()
	if game.juice.sfx.played.find("ui") < 0:
		fail("a button press did not hook ui")
		game.queue_free()
		return
	if game.sim.checksum() != bare.checksum():
		fail("the ui hook wrote into the sim before the command was ticked")
	game.queue_free()


func test_human_policy_can_win() -> void:
	var run: Dictionary = _drive(preload("res://tests/human_policy.gd").new(), 20 * 60 * 16)
	var sim = run.sim
	var lucifer_tick := int(run.lucifer)
	var total_s := float(sim.tick) / 20.0
	var crawl_s := float(lucifer_tick) / 20.0 if lucifer_tick >= 0 else -1.0
	var boss_s := total_s - crawl_s if lucifer_tick >= 0 else -1.0
	print("  human crawl=%0.1fs boss=%0.1fs total=%0.1fs outcome=%s casts=%d seal=%s font=%s altar=%s" % [
		crawl_s, boss_s, total_s, sim.outcome, sim.ability_casts, sim.seal_done, sim.font_done, sim.altar_done
	])
	if sim.outcome != "angels":
		fail("a slower player did not win: %s" % sim.debug_string())
		print(_feed(sim))
		return
	if not sim.seal_done or not sim.font_done or not sim.altar_done:
		fail("human skipped a stake seal=%s font=%s altar=%s" % [sim.seal_done, sim.font_done, sim.altar_done])
	if total_s < 8.0 * 60.0 or total_s > 14.0 * 60.0:
		fail("human run %0.1fs is outside 8–14 min" % total_s)
	if boss_s < 60.0 or boss_s > 180.0:
		fail("human boss %0.1fs is not a climax" % boss_s)


func test_walking_past_the_kit_loses() -> void:
	var run: Dictionary = _drive(preload("res://tests/passive_policy.gd").new(), 20 * 60 * 16)
	var sim = run.sim
	var total_s := float(sim.tick) / 20.0
	print("  passive total=%0.1fs outcome=%s room=%s altar=%s" % [total_s, sim.outcome, sim.party_room_id, sim.altar_done])
	if sim.outcome == "angels":
		fail("marching without the kit still won")
		return
	if sim.outcome != "demon":
		fail("passive run soft-locked: %s" % sim.debug_string())
		return
	if sim.altar_done:
		fail("passive run banked the altar")


func test_touch_reaches_the_board_and_forgiving_taps() -> void:
	if host == null:
		fail("scene test has no tree")
		return
	var mounted: Array = _mount_main()
	var main: Control = mounted[0]
	var game = mounted[1]
	game.briefing = false
	game.paused = true
	game.sim.director_enabled = false
	game.hud._brief.visible = false
	game.hud._brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._process(0.0)
	game.board._process(0.0)
	if main.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		fail("root control still captures pointers (%s)" % main.mouse_filter)
		main.queue_free()
		return
	if game.board.mouse_filter != Control.MOUSE_FILTER_STOP:
		fail("play field does not claim taps")
		main.queue_free()
		return
	if game.hud.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		fail("hud root captures the play area")
		main.queue_free()
		return
	var tile: Vector2i = Fixed.tile_of(game.sim.anchor) + Vector2i(2, 0)
	if game.sim.map.at(tile) < 0:
		tile = Fixed.tile_of(game.sim.anchor) + Vector2i(0, 1)
	var pos: Vector2 = game.board._milli_screen(Fixed.tile_center(tile))
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	game.get_viewport().push_input(motion, true)
	var hovered: Control = game.get_viewport().gui_get_hovered_control()
	if hovered == main or hovered == game.hud:
		fail("map hover hit %s instead of the play field" % hovered)
		main.queue_free()
		return
	game._tap_frame = -1
	var queued: int = game.sim.queue.size()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = pos
	game.get_viewport().push_input(touch, true)
	if game.sim.queue.size() <= queued:
		fail("InputEventScreenTouch did not reach the board at %s" % pos)
		main.queue_free()
		return
	var moved: Dictionary = game.sim.queue.back()
	if str(moved.type) != "move_tile" and str(moved.type) != "move_room":
		fail("walkable touch submitted %s" % moved.type)
		main.queue_free()
		return
	var anchor_tile: Vector2i = Fixed.tile_of(game.sim.anchor)
	var void_tile := Vector2i(-1, -1)
	var void_pos := Vector2.ZERO
	for dist in range(1, 14):
		for d in [Vector2i(dist, 0), Vector2i(-dist, 0), Vector2i(0, dist), Vector2i(0, -dist)]:
			var t: Vector2i = anchor_tile + d
			if game.sim.map.at(t) >= 0:
				continue
			var screen: Vector2 = game.board._milli_screen(Fixed.tile_center(t))
			if screen.x < 210.0 or screen.y < 120.0 or screen.y > game.board.size.y - 250.0:
				continue
			void_tile = t
			void_pos = screen
			break
		if void_tile.x >= 0:
			break
	if void_tile.x < 0:
		fail("no void tile inside the play field")
		main.queue_free()
		return
	game._tap_frame = -1
	queued = game.sim.queue.size()
	var void_touch := InputEventScreenTouch.new()
	void_touch.pressed = true
	void_touch.index = 1
	void_touch.position = void_pos
	game.get_viewport().push_input(void_touch, true)
	if game.sim.queue.size() <= queued:
		fail("void tap at %s still no-opped" % void_pos)
		main.queue_free()
		return
	var void_cmd: Dictionary = game.sim.queue.back()
	if str(void_cmd.type) != "move_tile" and str(void_cmd.type) != "move_room":
		fail("void tap submitted %s" % void_cmd.type)
		main.queue_free()
		return
	game.sim._make_mob("imp", "Imp", game.sim.anchor + Vector2i(700, 0), 80, 1, 50, 100, 0, [], "start:center")
	for id in game.sim.order:
		var foe: Dictionary = game.sim.entities[id]
		if str(foe.subtype) == "imp":
			foe.active_at = 0
	game._process(0.0)
	game.board._process(0.0)
	var foe_pos := Vector2.ZERO
	for row in game.board.snap.foes:
		if str(row.subtype) == "imp":
			foe_pos = game.board._milli_screen(row.pos)
	game._tap_frame = -1
	queued = game.sim.queue.size()
	var focus := InputEventScreenTouch.new()
	focus.pressed = true
	focus.index = 2
	focus.position = foe_pos
	game.get_viewport().push_input(focus, true)
	if game.sim.queue.size() <= queued or str(game.sim.queue.back().type) != "focus":
		fail("foe touch did not focus, got %s" % (game.sim.queue.back() if game.sim.queue.size() > queued else {}))
		main.queue_free()
		return
	var shield: Button = game.hud._bar.shield
	var shield_at: Vector2 = shield.get_global_rect().get_center()
	game.sim.golden = 8000
	game._tap_frame = -1
	queued = game.sim.queue.size()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = shield_at
	down.global_position = shield_at
	game.get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = shield_at
	up.global_position = shield_at
	game.get_viewport().push_input(up, true)
	if game.sim.queue.size() <= queued or str(game.sim.queue.back().type) != "shield":
		fail("command bar touch was stolen, last %s" % (game.sim.queue.back() if game.sim.queue.size() > queued else {}))
		main.queue_free()
		return
	main.queue_free()


func test_in_run_menu_restarts_or_returns_to_title() -> void:
	if host == null:
		fail("scene test has no tree")
		return
	var mounted: Array = _mount_main()
	var main: Control = mounted[0]
	var game = mounted[1]
	game.sim.director_enabled = false
	game.hud._begin.pressed.emit()
	game._process(0.0)
	if game.briefing or game.hud._menu == null or not game.hud._menu.visible:
		fail("menu hidden during the run")
		main.queue_free()
		return
	if str(game.hud._menu.text) != "Menu":
		fail("menu label %s" % game.hud._menu.text)
		main.queue_free()
		return
	var menu_r: Rect2 = game.hud._menu.get_rect()
	if menu_r.size.x < 64.0 or menu_r.size.y < 64.0:
		fail("menu touch target %s" % menu_r)
		main.queue_free()
		return
	if menu_r.position.x < 0.0 or menu_r.position.y < 0.0 or menu_r.end.x > 1280.0 or menu_r.end.y > 720.0:
		fail("menu sits outside 1280x720 %s" % menu_r)
		main.queue_free()
		return
	var bar: Array = []
	for cmd in ["shield", "heal", "cleanse", "detect", "burst"]:
		bar.append(game.hud._bar[cmd])
	for key in game.hud._stances.keys():
		bar.append(game.hud._stances[key])
	bar.append(game.hud._scatter)
	bar.append(game.hud._phalanx)
	for btn in bar:
		var br: Rect2 = btn.get_rect()
		if menu_r.intersects(br):
			fail("menu overlaps %s at %s" % [btn.text, br])
			main.queue_free()
			return
		if menu_r.position.y + menu_r.size.y > br.position.y:
			fail("menu reaches the command bar %s vs %s" % [menu_r, br])
			main.queue_free()
			return
	var center: Vector2 = game.hud._menu.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	game.get_viewport().push_input(motion, true)
	var hovered: Control = game.get_viewport().gui_get_hovered_control()
	if hovered != game.hud._menu:
		fail("menu button is not the touch target, hit %s" % hovered)
		main.queue_free()
		return
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	game.get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	game.get_viewport().push_input(up, true)
	if not game.hud._menu_dim.visible or not game.paused:
		fail("menu press did not open the pause panel")
		main.queue_free()
		return
	var held: int = game.sim.tick
	game._process(1.0)
	if game.sim.tick != held:
		fail("open menu let the sim tick")
		main.queue_free()
		return
	if game.hud._menu_restart.get_rect().size.y < 64.0 or game.hud._menu_title.get_rect().size.y < 48.0:
		fail("menu actions are too small")
		main.queue_free()
		return
	game.sim.tick = 40
	game.hud._menu_restart.pressed.emit()
	if game.briefing or game.sim.outcome != "" or game.sim.tick != 0 or game.hud._menu_dim.visible:
		fail("restart from the menu did not open a fresh run: %s" % game.sim.debug_string())
		main.queue_free()
		return
	game.sim.director_enabled = false
	game.sim.tick = 12
	game._process(0.0)
	game.hud._menu.pressed.emit()
	game.hud._menu_title.pressed.emit()
	if not game.briefing or not game.hud._brief.visible or game.sim.tick != 0:
		fail("title from the menu did not return to the start screen")
		main.queue_free()
		return
	game._process(0.5)
	if game.sim.tick != 0:
		fail("title screen ticked after the menu")
		main.queue_free()
		return
	if game.hud._menu.visible:
		fail("menu stayed up on the title")
	main.queue_free()


func test_guide_arrow_and_persistent_prompt() -> void:
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
	game.hud._brief.visible = false
	game.hud._brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.sim.director_enabled = false
	game._process(0.0)
	game.board._process(0.0)
	var g: Dictionary = game.board.guide(game.board.snap)
	if not str(g.line).contains("Tap") or not str(g.line).contains("door"):
		fail("opening prompt %s" % g.line)
		game.queue_free()
		return
	if g.at == Vector2i.ZERO or str(g.kind) != "move":
		fail("opening objective %s" % g)
		game.queue_free()
		return
	game.board.queue_redraw()
	var board = game.board
	after_frame.append(func():
		if not is_instance_valid(board) or not board.guide_drawn:
			fail("objective arrow was not drawn")
		if is_instance_valid(game):
			game.queue_free()
	)
	if not game.hud._coach.visible or str(game.hud._coach.text) == "":
		fail("coach hidden at the start")
		game.queue_free()
		return
	for _i in 1000:
		game.sim.tick_once()
	game._process(0.0)
	if not game.hud._coach.visible or str(game.hud._coach.text) == "":
		fail("coach went blank after the old 45s cutoff: %s" % game.hud._coach.text)
		game.queue_free()
		return
	game.sim._make_mob("imp", "Imp", game.sim.anchor + Vector2i(600, 0), 80, 1, 50, 100, 0, [], "start:center")
	for id in game.sim.order:
		var foe: Dictionary = game.sim.entities[id]
		if str(foe.subtype) == "imp":
			foe.active_at = 0
	game._process(0.0)
	var clear: Dictionary = game.board.guide(game.board.snap)
	if not str(clear.line).contains("Clear the room"):
		fail("clear prompt %s" % clear.line)
		game.queue_free()
		return
	for id2 in game.sim.order:
		var foe2: Dictionary = game.sim.entities[id2]
		if str(foe2.subtype) == "imp":
			foe2.alive = false
			foe2.hp = 0
	_stand(game.sim, "seal")
	game.sim.director_enabled = false
	game._process(0.0)
	var stake: Dictionary = game.board.guide(game.board.snap)
	if not str(stake.line).contains("Claim the stake"):
		fail("stake prompt %s" % stake.line)
		game.queue_free()
		return
	_stand(game.sim, "start")
	game.sim._hero("raphael").hp = game.sim._hero("raphael").hp_max / 2
	game.sim.golden = 8000
	game._process(0.0)
	var spend: Dictionary = game.board.guide(game.board.snap)
	if not str(spend.line).contains("Spend elixir"):
		fail("spend prompt %s" % spend.line)
		return


func test_opening_grace_before_the_player_acts() -> void:
	var sim := CombatSim.new()
	if sim.golden != Balance.GOLDEN_START or sim.dark != Balance.DARK_START:
		fail("banks golden %d dark %d" % [sim.golden, sim.dark])
		return
	var dark0 := sim.dark
	var gold0 := sim.golden
	for _i in Balance.OPENING_GRACE_TICKS:
		sim.tick_once()
	if sim.golden <= gold0:
		fail("golden did not tick during grace")
		return
	if sim.corruption or sim.idle_ticks > 0:
		fail("turtle ran during grace idle=%d" % sim.idle_ticks)
		return
	# The director may spend the opening bank. Regen must not raise it.
	if sim.dark > dark0:
		fail("dark snowballed during grace %d -> %d" % [dark0, sim.dark])
		return
	var held := sim.dark
	sim.director_enabled = false
	sim.tick_once()
	if sim.dark != held + Balance.dark_regen(0):
		fail("dark did not resume after grace (%d -> %d)" % [held, sim.dark])
		return
	var fast := CombatSim.new()
	fast.director_enabled = false
	fast.submit("move_tile", {"tile": Fixed.tile_of(fast.anchor)})
	var before := fast.dark
	fast.tick_once()
	if fast.opening_grace():
		fail("grace stuck after the player moved")
		return
	var want := before + Balance.dark_regen(0)
	if before >= Balance.ELIXIR_MAX:
		want = Balance.ELIXIR_MAX
	if fast.dark != want:
		fail("acted run dark %d want %d" % [fast.dark, want])


func _mount_main() -> Array:
	var main := (load("res://Main.tscn") as PackedScene).instantiate()
	main.boot_host()
	_pin_screen(main)
	host.root.add_child(main)
	_pin_screen(main)
	var game = main.get_child(main.get_child_count() - 1)
	_pin_screen(game)
	_pin_screen(game.board)
	_pin_screen(game.hud)
	if game.juice:
		_pin_screen(game.juice)
	game.hud._layout_bottom()
	return [main, game]


func test_iso_screen_tile_roundtrip() -> void:
	# 2:1 dimetric: tile (col, row) -> ((col - row) * w/2, (col + row) * h/2), w = 2h.
	var east: Vector2 = BoardView.iso_of_tile(1.0, 0.0) - BoardView.iso_of_tile(0.0, 0.0)
	var south: Vector2 = BoardView.iso_of_tile(0.0, 1.0) - BoardView.iso_of_tile(0.0, 0.0)
	if absf(BoardView.TILE_W - BoardView.TILE_H * 2.0) > 0.001:
		fail("tile ratio %s:%s is not 2:1" % [BoardView.TILE_W, BoardView.TILE_H])
		return
	if absf(absf(east.x) - 2.0 * absf(east.y)) > 0.001 or east.x <= 0.0 or east.y <= 0.0:
		fail("east step is not down-right 2:1 %s" % east)
		return
	if absf(absf(south.x) - 2.0 * absf(south.y)) > 0.001 or south.x >= 0.0 or south.y <= 0.0:
		fail("south step is not down-left 2:1 %s" % south)
		return
	if absf(BoardView.iso_of_tile(1.0, 1.0).x - BoardView.iso_of_tile(0.0, 0.0).x) > 0.001:
		fail("a diagonal step should stay on a vertical screen column")
		return
	if BoardView.iso_depth(1.0, 0.0) >= BoardView.iso_depth(2.0, 2.0):
		fail("nearer tiles must sort after farther ones")
		return
	var sample := Vector2(40.5, 12.25)
	var back: Vector2 = BoardView.tile_of_iso(BoardView.iso_of_tile(sample.x, sample.y))
	if absf(back.x - sample.x) > 0.0001 or absf(back.y - sample.y) > 0.0001:
		fail("iso inverse drifted to %s" % back)
		return
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
	# South of the squad. The room center is the anchor, so a tap there hits Raphael.
	var tile := Vector2i(24, 50)
	var milli := Fixed.tile_center(tile)
	var screen: Vector2 = game.board._milli_screen(milli)
	if not game.board.playfield_rect().has_point(screen):
		fail("projected tile %s fell outside the playfield at %s" % [tile, screen])
		game.queue_free()
		return
	var back_m: Vector2i = game.board._screen_to_milli(screen)
	if Fixed.tile_of(back_m) != tile:
		fail("screen %s of %s came back as %s (%s)" % [screen, tile, Fixed.tile_of(back_m), back_m])
		game.queue_free()
		return
	var far: Vector2 = game.board._tile_center_screen(10, 40)
	var near: Vector2 = game.board._tile_center_screen(10, 50)
	if near.y <= far.y:
		fail("southern tile should sit lower on screen (%s vs %s)" % [near, far])
		game.queue_free()
		return
	game._tap_frame = -1
	var queued := game.sim.queue.size()
	game.note_tap(screen)
	if game.sim.queue.size() <= queued:
		fail("iso tap at %s did not submit" % screen)
		game.queue_free()
		return
	var cmd: Dictionary = game.sim.queue.back()
	if str(cmd.type) != "move_tile" or cmd.args.tile != tile:
		fail("iso tap submitted %s" % cmd)
		game.queue_free()
		return
	var forced := Vector2i(10, 44)
	var forced_milli := Fixed.tile_center(forced)
	var iso: Vector2 = BoardView.iso_of_tile(float(forced_milli.x) / 1000.0, float(forced_milli.y) / 1000.0)
	var view: Vector2 = game.board._view_size()
	game.board.zoom = 1.0
	game.board.cam = iso - view * 0.5
	var known: Vector2 = game.board._view_origin() + view * 0.5
	var got: Vector2i = game.board._screen_to_milli(known)
	if Fixed.tile_of(got) != forced:
		fail("playfield center mapped to %s (%s), want %s" % [Fixed.tile_of(got), got, forced])
		game.queue_free()
		return
	var again: Vector2 = game.board._milli_screen(forced_milli)
	if again.distance_to(known) > 0.75:
		fail("round trip screen %s vs %s" % [again, known])
		game.queue_free()
		return
	var outside := Vector2i(16, 48)
	var out_milli := Fixed.tile_center(outside)
	var out_iso: Vector2 = BoardView.iso_of_tile(float(out_milli.x) / 1000.0, float(out_milli.y) / 1000.0)
	game.board.zoom = 1.0
	game.board.cam = out_iso - view * 0.5
	game._tap_frame = -1
	queued = game.sim.queue.size()
	game.note_tap(game.board._milli_screen(out_milli))
	if game.sim.queue.size() <= queued:
		fail("void tap within 16 tiles did not snap")
		game.queue_free()
		return
	var snapped: Dictionary = game.sim.queue.back()
	if str(snapped.type) != "move_tile" and str(snapped.type) != "move_room":
		fail("void tap submitted %s" % snapped.type)
		game.queue_free()
		return
	if str(snapped.type) == "move_tile":
		var dest: Vector2i = snapped.args.tile
		if game.sim.map.at(dest) < 0 or Fixed.dist(out_milli, Fixed.tile_center(dest)) > 16000:
			fail("snap %s is not a walkable tile within 16" % dest)
			game.queue_free()
			return
	var dir_east: Vector2 = game.board._iso_screen_delta(forced_milli, Fixed.tile_center(forced + Vector2i(4, 0)))
	var dir_south: Vector2 = game.board._iso_screen_delta(forced_milli, Fixed.tile_center(forced + Vector2i(0, 4)))
	if dir_east.x <= 0.0 or dir_east.y <= 0.0:
		fail("gold-arrow east is not down-right in iso %s" % dir_east)
		game.queue_free()
		return
	if dir_south.x >= 0.0 or dir_south.y <= 0.0:
		fail("gold-arrow south is not down-left in iso %s" % dir_south)
		game.queue_free()
		return
	game.hud.size = Vector2(1080, 2400)
	game.board.size = Vector2(1080, 2400)
	game.hud._layout_bottom()
	var play: Rect2 = game.board.playfield_rect()
	for cmd_name in ["shield", "heal", "cleanse", "detect", "burst"]:
		var r: Rect2 = game.hud._bar[cmd_name].get_rect()
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > 1080.0 or r.end.y > 2400.0:
			fail("portrait %s outside the phone %s" % [cmd_name, r])
			game.queue_free()
			return
		if r.intersects(play):
			fail("portrait %s overlaps the playfield %s vs %s" % [cmd_name, r, play])
			game.queue_free()
			return
	var menu_r: Rect2 = game.hud._menu.get_rect()
	if menu_r.end.x > 1080.0 or menu_r.position.x < 800.0 or menu_r.position.y > 80.0 or menu_r.size.y < 64.0:
		fail("menu is not top-right on a portrait phone %s" % menu_r)
		game.queue_free()
		return
	if menu_r.intersects(play):
		fail("menu overlaps the playfield %s vs %s" % [menu_r, play])
		game.queue_free()
		return
	var coach_r: Rect2 = game.hud._coach_bg.get_rect()
	var shield_r: Rect2 = game.hud._bar.shield.get_rect()
	if coach_r.intersects(play) or coach_r.end.y > shield_r.position.y:
		fail("coach overlaps playfield or the command bar %s shield %s play %s" % [coach_r, shield_r, play])
		game.queue_free()
		return
	game.queue_free()


func test_threat_orders_the_target() -> void:
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 9999
	var az := sim._hero("azrael")
	var michael := sim._hero("michael")
	var raphael := sim._hero("raphael")
	var mob := _mob(sim, "imp", michael.pos + Vector2i(200, 0), 800)
	mob.pulled = true
	sim._hurt(mob, 50, "single", int(az.id), false)
	if int(mob.threat.get(str(az.id), 0)) != 50:
		fail("damage threat %s" % str(mob.threat))
		return
	if str(sim._mob_target(mob).subtype) != "azrael":
		fail("highest threat was not the target")
		return
	sim._hurt(mob, 20, "single", int(michael.id), false)
	var mike := int(mob.threat.get(str(michael.id), 0))
	if mike != 20 * Balance.TANK_THREAT_MULT / 100:
		fail("tank threat %d" % mike)
		return
	if str(sim._mob_target(mob).subtype) != "michael":
		fail("tank multiplier did not take aggro")
		return
	sim._hurt(mob, 280, "single", int(az.id), false)
	if str(sim._mob_target(mob).subtype) != "azrael":
		fail("over-damage did not pull aggro")
		return
	var idle := _mob(sim, "heavy", michael.pos + Vector2i(4000, 0), 800)
	idle.pulled = false
	var second := _mob(sim, "heavy", michael.pos + Vector2i(300, 0), 800)
	second.pulled = true
	raphael.hp = int(raphael.hp_max) - 40
	sim._heal(raphael, 40, int(raphael.id))
	var pool := 40 * Balance.HEAL_THREAT_PCT / 100
	var lo: Dictionary = mob if int(mob.id) < int(second.id) else second
	var hi: Dictionary = second if int(lo.id) == int(mob.id) else mob
	var each := pool / 2
	var rem := pool - each * 2
	if int(lo.threat.get(str(raphael.id), 0)) != each + rem:
		fail("heal threat on the lower id %s" % str(lo.threat))
		return
	if int(hi.threat.get(str(raphael.id), 0)) != each:
		fail("heal threat on the higher id %s" % str(hi.threat))
		return
	if int(idle.threat.get(str(raphael.id), 0)) != 0:
		fail("heal threat hit a mob that was holding")


func test_taunt_snaps_threat() -> void:
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 9999
	var michael := sim._hero("michael")
	var az := sim._hero("azrael")
	var mob := _mob(sim, "imp", sim._hero("raphael").pos + Vector2i(200, 0), 900)
	mob.pulled = true
	mob.threat = {str(az.id): 500, str(michael.id): 10}
	if str(sim._mob_target(mob).subtype) != "azrael":
		fail("setup did not give Azrael aggro")
		return
	_pay(sim, "taunt")
	if sim.taunt_id != int(mob.id):
		fail("taunt missed the mob on Raphael")
		return
	if str(sim._mob_target(mob).subtype) != "michael":
		fail("taunt did not force Michael")
		return
	var snapped := sim.threat_of(int(mob.id), int(michael.id))
	var az_t := sim.threat_of(int(mob.id), int(az.id))
	if snapped <= az_t:
		fail("snap %d did not clear %d" % [snapped, az_t])
		return
	if int(mob.threat.get(str(michael.id), 0)) <= 10:
		fail("snap was not stored %s" % str(mob.threat))
		return
	if sim.threat_boost_until <= sim.tick + Balance.TAUNT_TICKS:
		fail("threat boost is only the taunt window")
		return
	sim.taunt_until = sim.tick
	if str(sim._mob_target(mob).subtype) != "michael":
		fail("stored snap dropped when the force window ended")
		return
	var before := int(mob.threat.get(str(michael.id), 0))
	sim._hurt(mob, 10, "single", int(michael.id), false)
	var gained := int(mob.threat.get(str(michael.id), 0)) - before
	var boosted := 10 * Balance.TANK_THREAT_MULT / 100 * (100 + Balance.TAUNT_BOOST_PCT) / 100
	if gained != boosted:
		fail("boosted threat %d want %d" % [gained, boosted])


func test_dps_elixir_attacks() -> void:
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 9999
	var az := sim._hero("azrael")
	var uri := sim._hero("uriel")
	var near := _mob(sim, "imp", az.pos + Vector2i(400, 0), 500)
	var splash := _mob(sim, "imp", near.pos + Vector2i(Balance.SUNSTRIKE_RADIUS - 50, 0), 500)
	var far := _mob(sim, "heavy", az.pos + Vector2i(6000, 0), 500)
	_pay(sim, "strike")
	var strike := sim._out_damage(Balance.STRIKE_DMG, int(az.id))
	if 500 - int(near.hp) != strike:
		fail("strike damage %d want %d" % [500 - int(near.hp), strike])
		return
	if int(splash.hp) != 500 or int(far.hp) != 500:
		fail("strike was not single target")
		return
	near.hp = 500
	near.pos = uri.pos + Vector2i(800, 0)
	splash.pos = near.pos + Vector2i(Balance.SUNSTRIKE_RADIUS - 40, 0)
	far.pos = uri.pos + Vector2i(8000, 0)
	var gold := sim.golden
	uri.cooldowns.erase("sunstrike")
	sim.submit("ability", {"name": "sunstrike"})
	sim.tick_once()
	var expect := gold - Balance.cost("sunstrike") + Balance.golden_regen(sim.stage_reached)
	if sim.golden != expect:
		fail("sunstrike golden %d want %d (%s)" % [sim.golden, expect, _feed(sim)])
		return
	var primary := sim._out_damage(Balance.SUNSTRIKE_DMG, int(uri.id))
	var splash_d := sim._out_damage(Balance.SUNSTRIKE_SPLASH, int(uri.id))
	if 500 - int(near.hp) != primary:
		fail("sunstrike primary %d want %d" % [500 - int(near.hp), primary])
		return
	if 500 - int(splash.hp) != splash_d:
		fail("sunstrike splash %d want %d" % [500 - int(splash.hp), splash_d])
		return
	if int(far.hp) != 500:
		fail("sunstrike reached a mob outside the splash")


func test_tougher_mobs_take_seconds() -> void:
	# 1.0.2 bodies: imp 34, heavy 260, elite 420. A focused party erased an imp
	# in under a second. 1.0.3 wants a basic mob to last several seconds.
	if Balance.IMP_HP < 34 * 4 or Balance.HEAVY_HP <= 260 or Balance.ELITE_HP <= 420:
		fail("mob hp was not raised from 1.0.2 (imp %d heavy %d elite %d)" % [Balance.IMP_HP, Balance.HEAVY_HP, Balance.ELITE_HP])
		return
	var imp_ticks := _ttk("imp", Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE)
	var heavy_ticks := _ttk("heavy", Balance.HEAVY_HP, Balance.HEAVY_ATK, Balance.HEAVY_PERIOD, Balance.HEAVY_RANGE)
	var elite_ticks := _ttk("elite", Balance.ELITE_HP, Balance.ELITE_ATK, Balance.ELITE_PERIOD, Balance.ELITE_RANGE)
	print("  ttk imp=%0.2fs heavy=%0.2fs elite=%0.2fs" % [float(imp_ticks) / 20.0, float(heavy_ticks) / 20.0, float(elite_ticks) / 20.0])
	if imp_ticks < 20 * 4 or imp_ticks > 20 * 8:
		fail("imp time to kill %0.2fs is outside 4–8s" % (float(imp_ticks) / 20.0))
		return
	if heavy_ticks <= imp_ticks:
		fail("heavy %0.2fs was not slower than an imp %0.2fs" % [float(heavy_ticks) / 20.0, float(imp_ticks) / 20.0])
		return
	if elite_ticks <= heavy_ticks:
		fail("elite %0.2fs was not slower than a heavy %0.2fs" % [float(elite_ticks) / 20.0, float(heavy_ticks) / 20.0])


func test_single_heal_targets_the_chosen_hero() -> void:
	var sim := _lab()
	var gabriel := sim._hero("gabriel")
	var uriel := sim._hero("uriel")
	gabriel.hp = int(gabriel.hp_max) - 80
	uriel.hp = int(uriel.hp_max) - 70
	var g0 := int(gabriel.hp)
	var u0 := int(uriel.hp)
	var others := {}
	for a in sim._angels():
		if str(a.subtype) == "uriel":
			continue
		others[str(a.subtype)] = int(a.hp)
	sim.submit("ally", {"target": "uriel"})
	sim.tick_once()
	if sim.ally_target != "uriel":
		fail("tap did not mark Uriel for Mend")
		return
	sim._hero("raphael").cooldowns.erase("single_heal")
	sim.golden = 9000
	sim.submit("ability", {"name": "single_heal"})
	sim.tick_once()
	if int(uriel.hp) != u0 + Balance.HEAL_SINGLE:
		fail("chosen heal landed %d want %d" % [int(uriel.hp) - u0, Balance.HEAL_SINGLE])
		return
	if int(gabriel.hp) != g0:
		fail("single heal hit Gabriel, who was lower")
		return
	for a2 in sim._angels():
		if str(a2.subtype) == "uriel":
			continue
		if int(a2.hp) != int(others[str(a2.subtype)]):
			fail("single heal changed %s" % a2.subtype)
			return


func test_mobs_hold_until_aggro() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	var pos := Fixed.tile_center(sim.map.node_tile("summoned:center"))
	sim._make_mob("imp", "Imp", pos, Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, Balance.IMP_SPEED, [], "summoned:center")
	var imp: Dictionary = sim.entities[sim.next_id - 1]
	imp.active_at = 0
	var origin: Vector2i = imp.pos
	for _i in 30:
		sim.tick_once()
	if imp.pos != origin or bool(imp.get("pulled", false)):
		fail("imp chased from another room %s pulled=%s" % [imp.pos - origin, imp.get("pulled", false)])
		return
	sim.root_until = 99999
	var uriel := sim._hero("uriel")
	uriel.pos = imp.pos + Vector2i(Balance.AGGRO_RANGE + 600, 0)
	uriel.atk_cd = 1
	for a in sim._angels():
		if str(a.subtype) != "uriel":
			a.atk_cd = 99999
	var hp := int(imp.hp)
	sim.tick_once()
	sim.tick_once()
	if int(imp.hp) >= hp:
		fail("Uriel did not shoot past aggro range")
		return
	if not bool(imp.get("pulled", false)):
		fail("damage did not pull the imp")
		return
	if imp.pos == origin:
		fail("pulled imp held still")


func test_new_acts_are_touchable() -> void:
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
	game.hud._layout_bottom()
	game._process(0.0)
	var names := ["taunt", "mend", "strike", "sunstrike"]
	for key in names:
		if not game.hud._acts.has(key):
			fail("command bar missing %s" % key)
			game.queue_free()
			return
		var btn: Button = game.hud._acts[key]
		var r: Rect2 = btn.get_rect()
		if r.size.x < 64.0 or r.size.y < 64.0:
			fail("%s touch target %s" % [key, r.size])
			game.queue_free()
			return
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > 1280.0 or r.end.y > 720.0:
			fail("%s sits outside 1280x720 %s" % [key, r])
			game.queue_free()
			return
		if r.intersects(game.board.playfield_rect()):
			fail("%s overlaps the playfield %s" % [key, r])
			game.queue_free()
			return
	game.hud.size = Vector2(1080, 2400)
	game.board.size = Vector2(1080, 2400)
	game.hud._layout_bottom()
	var play: Rect2 = game.board.playfield_rect()
	for key2 in names:
		var r2: Rect2 = game.hud._acts[key2].get_rect()
		if r2.position.x < 0.0 or r2.position.y < 0.0 or r2.end.x > 1080.0 or r2.end.y > 2400.0:
			fail("%s outside the phone %s" % [key2, r2])
			game.queue_free()
			return
		if r2.intersects(play):
			fail("%s overlaps the phone playfield %s vs %s" % [key2, r2, play])
			game.queue_free()
			return
		if r2.size.y < 64.0:
			fail("%s phone target %s" % [key2, r2.size])
			game.queue_free()
			return
	game.hud.size = Vector2(1280, 720)
	game.board.size = Vector2(1280, 720)
	game.hud._layout_bottom()
	var mob := _mob(game.sim, "imp", game.sim._hero("azrael").pos + Vector2i(300, 0), 500)
	game.sim.golden = 9000
	var queued := game.sim.queue.size()
	game.hud._acts.strike.pressed.emit()
	if game.sim.queue.size() != queued:
		fail("strike armed by casting immediately")
		game.queue_free()
		return
	if game.armed != "strike":
		fail("strike tap did not arm")
		game.queue_free()
		return
	game.cast_armed({"id": int(mob.id)})
	game.sim.tick_once()
	if int(mob.hp) == 500:
		fail("armed strike did no damage")
		game.queue_free()
		return
	game.sim.golden = 9000
	game.hud._acts.taunt.pressed.emit()
	if game.armed != "taunt":
		fail("taunt tap did not arm")
		game.queue_free()
		return
	game.cast_armed({"id": int(mob.id)})
	game.sim.tick_once()
	if game.sim.taunt_until <= game.sim.tick:
		fail("armed taunt did not force a target")
	game.queue_free()


func _ttk(subtype: String, hp: int, atk: int, period: int, mob_range: int) -> int:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.stance = CombatSim.STANCE_TIGHT
	var michael := sim._hero("michael")
	sim._make_mob(subtype, subtype, michael.pos, hp, atk, period, mob_range, 0, [], "start:center")
	var mob: Dictionary = sim.entities[sim.next_id - 1]
	mob.active_at = 0
	mob.atk_cd = 99999
	mob.pulled = true
	var guard := 0
	while bool(mob.alive) and guard < 20 * 40:
		sim.tick_once()
		guard += 1
	return guard


func _drive(policy, limit: int) -> Dictionary:
	var sim := CombatSim.new()
	var lucifer_tick := -1
	for _i in limit:
		if sim.outcome != "":
			break
		policy.act(sim)
		sim.tick_once()
		if sim.phase == "lucifer" and lucifer_tick < 0:
			lucifer_tick = sim.tick
			print("  arrived ", sim.debug_string())
	return {"sim": sim, "lucifer": lucifer_tick}


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



func _stand(sim: CombatSim, room: String) -> void:
	sim.director_enabled = false
	var tile := sim.map.center_tile(room)
	if tile == Vector2i.ZERO:
		var keys: Array = sim.map.node_keys(room)
		if not keys.is_empty():
			tile = sim.map.node_tile(str(keys[0]))
	sim.anchor = Fixed.tile_center(tile)
	for a in sim._angels():
		a.pos = sim.anchor
	sim.path = []
	sim.tick_once()


func _stand_corridor(sim: CombatSim, room: String) -> void:
	var idx := -1
	for i in sim.map.rooms.size():
		if str(sim.map.rooms[i].id) == room:
			idx = i
			break
	var tile := Vector2i.ZERO
	var w := sim.map.width
	for i in sim.map.room_of.size():
		if int(sim.map.room_of[i]) == idx:
			tile = Vector2i(i % w, int(i / w))
			break
	sim.director_enabled = false
	sim.anchor = Fixed.tile_center(tile)
	for a in sim._angels():
		a.pos = sim.anchor
	sim.path = []
	sim.tick_once()


func _ready_director(sim: CombatSim) -> void:
	sim.director.opening_abandoned = true
	sim.director.next_decision = 0
	sim.director.pressure_lock = 0
	sim.director_enabled = true


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


func _history_descend(traps: int, spawns: int, curses: int, bank: int, pct: int, early: bool) -> CombatSim:
	var sim := CombatSim.new()
	sim.director_enabled = false
	for a in sim._angels():
		a.hp = maxi(1, int(a.hp_max) * pct / 100)
	sim.dark = bank
	sim.traps_placed = traps
	sim.spawns_placed = spawns
	sim.curses_cast = curses
	sim.submit("descend", {"early": early}, "demon", 1)
	sim.tick_once()
	return sim


func _wait_boss_ready(sim: CombatSim) -> void:
	var guard := 0
	while guard < 400:
		if sim.tick >= sim.transform_until and sim.tick >= sim.lucifer_next and sim.telegraph.is_empty() and not sim._command_pending("boss"):
			return
		sim.tick_once()
		guard += 1


func _party_hp(sim: CombatSim) -> int:
	var hp := 0
	for a in sim._angels():
		hp += int(a.hp)
	return hp


func _pattern_count(pattern: Array, name: String) -> int:
	var n := 0
	for step in pattern:
		if str(step) == name:
			n += 1
	return n


func _plant_four() -> CombatSim:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 10000
	for a in sim._angels():
		a.atk = 0
	var nodes := ["trapped:choke", "trapped:center", "summoned:choke", "summoned:center"]
	var kinds := ["spike", "snare", "spike", "hellflame"]
	for i in nodes.size():
		sim.submit("trap", {"kind": kinds[i], "node": nodes[i]}, "demon", 1)
		sim.tick_once()
	return sim


func _armed_count(sim: CombatSim) -> int:
	var n := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "trap" and bool(e.get("armed", false)):
			n += 1
	return n


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


func test_tank_holds_under_autos() -> void:
	var sim := _lab()
	var michael := sim._hero("michael")
	var mob := _mob(sim, "imp", michael.pos + Vector2i(700, 0), 5000)
	mob.pulled = true
	mob.active_at = 0
	mob.atk_cd = 99999
	var held := 0
	for _i in 80:
		sim.tick_once()
		if str(sim._mob_target(mob).subtype) == "michael":
			held += 1
	if held < 60:
		fail("Michael held aggro on %d of 80 ticks" % held)
		return
	var meter: Dictionary = sim.build_snapshot().threat
	if str(meter.get("holder", "")) != "michael":
		fail("meter holder %s" % str(meter.get("holder", "")))


func test_overheal_can_pull() -> void:
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 9999
	var michael := sim._hero("michael")
	var raphael := sim._hero("raphael")
	var mob := _mob(sim, "imp", michael.pos + Vector2i(200, 0), 900)
	mob.pulled = true
	sim._hurt(mob, 8, "single", int(michael.id), false)
	var lead := int(mob.threat.get(str(michael.id), 0))
	if str(sim._mob_target(mob).subtype) != "michael":
		fail("tank did not open with aggro")
		return
	raphael.hp = int(raphael.hp_max)
	var casts := 0
	while str(sim._mob_target(mob).subtype) == "michael" and casts < 40:
		sim._heal(raphael, Balance.HEAL_PARTY, int(raphael.id))
		casts += 1
	if str(sim._mob_target(mob).subtype) != "raphael":
		fail("overheal did not pull (lead %d casts %d threat %s)" % [lead, casts, str(mob.threat)])
		return
	if int(mob.threat.get(str(raphael.id), 0)) <= lead:
		fail("overheal threat did not pass the tank")


func test_mob_pulse_hits_the_party() -> void:
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 9999
		a.pos = sim._hero("michael").pos
	var michael := sim._hero("michael")
	var mob := _mob(sim, "imp", michael.pos + Vector2i(400, 0), 900)
	mob.pulled = true
	mob.active_at = 0
	mob.atk_cd = 1
	mob.swing = Balance.MOB_AOE_EVERY - 1
	var before := {}
	for a in sim._angels():
		before[str(a.subtype)] = int(a.hp)
	sim.tick_once()
	var hit := 0
	for a2 in sim._angels():
		if int(a2.hp) < int(before[str(a2.subtype)]):
			hit += 1
	if hit < 5:
		fail("pulse hit %d of 5" % hit)


func test_director_casts_weaken() -> void:
	var sim := CombatSim.new()
	_stand_corridor(sim, "m1a_0")
	sim.stage_reached = 1
	sim.rooms_cleared = 3
	sim.seal_done = true
	sim.font_done = true
	sim.altar_done = true
	sim.dark = 10000
	# Spawn and trap counts sit above the curse count, so the next spend
	# is the curse the director owes: every fourth curse leads with Weaken.
	sim.spawns_placed = 8
	sim.traps_placed = 8
	sim.curses_cast = 3
	sim.director.fortified = {"seal": true, "font": true, "altar": true}
	_ready_director(sim)
	var saw := false
	for _i in 80:
		sim.tick_once()
		if int(sim._hero("azrael").get("weaken_until", 0)) > sim.tick or int(sim._hero("uriel").get("weaken_until", 0)) > sim.tick:
			saw = true
			break
		for id in sim.order:
			var e: Dictionary = sim.entities[id]
			if str(e.kind) == "curse" and str(e.subtype) == "weaken":
				saw = true
				break
		if saw:
			break
	if not saw:
		fail("director never cast weaken (%s)" % sim.debug_string())


func test_shrine_disables_room_traps() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	sim.dark = 8000
	sim.submit("trap", {"kind": "spike", "node": "trapped:choke"}, "demon", 1)
	sim.submit("trap", {"kind": "snare", "node": "trapped:flank"}, "demon", 1)
	sim.tick_once()
	var shrine: Vector2i = sim.map.node_tile("trapped:shrine")
	if shrine.x < 0:
		fail("trapped room has no shrine")
		return
	if not sim.build_snapshot().traps.is_empty():
		fail("traps rendered before Detect")
		return
	sim.anchor = Fixed.tile_center(shrine)
	sim.party_room_id = "trapped"
	for a in sim._angels():
		a.pos = sim.anchor
	sim.submit("channel_shrine")
	for _i in Balance.SHRINE_CHANNEL:
		sim.tick_once()
	if not bool(sim.shrines_done.get("trapped", false)):
		fail("shrine did not finish (progress %d)" % sim.shrine_progress)
		return
	if sim.traps_in_room("trapped") != 0:
		fail("shrine left %d armed traps" % sim.traps_in_room("trapped"))
		return
	if not sim.build_snapshot().traps.is_empty():
		fail("disabled traps still rendered")


func test_threat_meter_names_the_holder() -> void:
	var sim := _lab()
	for a in sim._angels():
		a.atk_cd = 9999
	var michael := sim._hero("michael")
	var az := sim._hero("azrael")
	var mob := _mob(sim, "heavy", michael.pos + Vector2i(200, 0), 900)
	mob.pulled = true
	sim._hurt(mob, 40, "single", int(michael.id), false)
	var meter: Dictionary = sim.build_snapshot().threat
	if str(meter.get("holder", "")) != "michael":
		fail("holder %s" % str(meter.holder))
		return
	var pulling := false
	sim._hurt(mob, 560, "single", int(az.id), false)
	meter = sim.build_snapshot().threat
	for row in meter.rows:
		if str(row.subtype) == "azrael" and (bool(row.aggro) or bool(row.pulling)):
			pulling = true
	if str(meter.get("holder", "")) == "michael" and not pulling and str(meter.get("pulling", "")) == "":
		fail("meter did not show Azrael taking or threatening aggro %s" % str(meter))


func test_diagonal_path_cuts_the_corner() -> void:
	var map := DungeonMap.new()
	var start := Vector2i(4, 4)
	var goal := Vector2i(8, 8)
	for y in range(2, 12):
		for x in range(2, 12):
			map.walk[y * map.width + x] = 1
	var path: Array = Pathing.find(map.walk, map.width, map.height, start, goal, {})
	if path.is_empty():
		fail("diagonal path missing")
		return
	if path.size() > 6:
		fail("path stayed orthogonal, length %d" % path.size())
		return
	var blocked := map.walk.duplicate()
	blocked[4 * map.width + 5] = 0
	blocked[5 * map.width + 4] = 0
	var cut: Array = Pathing.find(blocked, map.width, map.height, start, Vector2i(5, 5), {})
	if cut.size() == 2:
		fail("path cut a closed corner")


func test_elixir_abilities_have_no_cooldown() -> void:
	for ability in ["taunt", "single_heal", "strike", "sunstrike", "burst", "shield_wall", "cleanse"]:
		if Balance.cooldown(ability) != 0:
			fail("%s cooldown %d" % [ability, Balance.cooldown(ability)])
			return
	if Balance.cooldown("scatter") <= 0 or Balance.cooldown("phalanx") <= 0:
		fail("maneuvers lost the lockout that keeps them from being free")
		return
	var sim := _lab()
	var michael := sim._hero("michael")
	_mob(sim, "imp", michael.pos + Vector2i(200, 0), 900)
	sim.golden = 9000
	sim.submit("ability", {"name": "taunt"})
	sim.tick_once()
	sim.golden = 9000
	sim.submit("ability", {"name": "taunt"})
	sim.tick_once()
	if _feed(sim).contains("not ready"):
		fail("taunt cooled down")
	if sim.ability_casts < 2:
		fail("second taunt did not cast (%s)" % _feed(sim))


func test_team_heal_button_is_its_own_control() -> void:
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
	game.hud._layout_bottom()
	if not game.hud._acts.has("team") or not game.hud._acts.has("mend"):
		fail("team heal is not its own button next to single heal")
		game.queue_free()
		return
	var team: Button = game.hud._acts.team
	var mend: Button = game.hud._acts.mend
	var team_r: Rect2 = team.get_rect()
	var mend_r: Rect2 = mend.get_rect()
	if team_r.size.x < 64.0 or team_r.size.y < 64.0:
		fail("team heal target %s" % team_r.size)
		game.queue_free()
		return
	if absf(team_r.position.y - mend_r.position.y) > 1.0:
		fail("team heal is not on the single-heal row %s vs %s" % [team_r, mend_r])
		game.queue_free()
		return
	var gap := team_r.position.x - mend_r.end.x
	if gap < -1.0 or gap > 24.0:
		fail("team heal is not beside single heal, gap %s" % gap)
		game.queue_free()
		return
	var zoom_out: Button = game.hud._zoom_out
	var zoom_in: Button = game.hud._zoom_in
	var zout: Rect2 = zoom_out.get_rect()
	var zin: Rect2 = zoom_in.get_rect()
	if zout.size.y < 64.0 or zin.size.y < 64.0 or zout.end.y > 720.0 or zin.end.x > 196.0:
		fail("zoom controls are not a visible pair under the portrait column %s %s" % [zout, zin])
		game.queue_free()
		return
	if str(game.hud._zoom_l.text) != "ZOOM":
		fail("zoom has no label")
		game.queue_free()
		return
	var last_portrait_end := 0.0
	for subtype in game.hud._portraits.keys():
		var pr: Rect2 = game.hud._portraits[subtype].get_rect()
		if pr.intersects(zout) or pr.intersects(zin):
			fail("portrait covers zoom %s" % pr)
			game.queue_free()
			return
		last_portrait_end = maxf(last_portrait_end, pr.end.y)
	if zout.position.y < last_portrait_end:
		fail("zoom sits under the portraits at %s, portraits end %s" % [zout, last_portrait_end])
		game.queue_free()
		return
	# The real press-and-measure check lives in test_zoom_buttons_change_the_camera.
	if not game.board.has_method("nudge_zoom"):
		fail("board has no zoom")
		game.queue_free()
		return
	var queued := game.sim.queue.size()
	mend.pressed.emit()
	if game.sim.queue.size() != queued:
		fail("single heal cast instead of arming")
		game.queue_free()
		return
	if game.armed != "single_heal":
		fail("single heal did not arm")
		game.queue_free()
		return
	for angel in game.sim._angels():
		angel.hp = int(angel.hp_max) - 40
	var before := {}
	for angel2 in game.sim._angels():
		before[int(angel2.id)] = int(angel2.hp)
	game.sim.golden = 9000
	team.pressed.emit()
	if game.armed != "":
		fail("team heal armed a target instead of casting")
		game.queue_free()
		return
	if game.sim.queue.size() != queued + 1:
		fail("team heal did not submit")
		game.queue_free()
		return
	game.sim.tick_once()
	for angel3 in game.sim._angels():
		var gained: int = int(angel3.hp) - int(before[int(angel3.id)])
		if gained != Balance.HEAL_PARTY:
			fail("team heal moved %s by %d" % [angel3.subtype, gained])
			game.queue_free()
			return
	game.queue_free()


func test_doorway_fight_does_not_end_in_one_tick() -> void:
	var sim := CombatSim.new()
	sim.director_enabled = false
	var center: Vector2i = sim.map.node_tile("summoned:center")
	var imp_pos := Fixed.tile_center(center)
	sim._make_mob("imp", "Imp", imp_pos, Balance.IMP_HP, Balance.IMP_ATK, Balance.IMP_PERIOD, Balance.IMP_RANGE, Balance.IMP_SPEED, [], "summoned:center")
	var imp: Dictionary = sim.entities[sim.next_id - 1]
	imp.active_at = 0
	var door := _west_door(sim, "summoned")
	if door.is_empty():
		fail("summoned has no west door")
		return
	var threshold: Vector2i = door.door
	var outside: Vector2i = door.out
	var dist := Fixed.dist(Fixed.tile_center(threshold), imp.pos)
	if sim.map.id_at_tile(threshold) != "summoned" or sim.map.id_at_tile(outside) == "summoned":
		fail("threshold %s / %s is not the room edge" % [threshold, outside])
		return
	if dist <= Balance.LEASH_RANGE:
		fail("doorway dist %d is inside leash; the phantom fight is a far threshold" % dist)
		return
	_place_party(sim, threshold)
	sim.tick_once()
	if bool(imp.pulled):
		fail("stepping onto the doorway pulled a garrison %d past leash" % dist)
		return
	_place_party(sim, outside)
	sim.tick_once()
	if bool(imp.pulled):
		fail("stepping back out of the doorway started a fight")
		return
	_place_party(sim, center)
	sim.tick_once()
	if not bool(imp.pulled):
		fail("closing inside the room did not start the fight")
		return
	var hp := int(imp.hp)
	for _i in 40:
		sim.path = []
		sim.tick_once()
		if not bool(imp.pulled):
			fail("in-range fight dropped on tick %d" % sim.tick)
			return
	if int(imp.hp) >= hp:
		fail("the held fight dealt no damage")


func test_entrance_stays_calm_until_the_first_room() -> void:
	var sim := CombatSim.new()
	if str(sim.map.by_id["start"].kind) != "start":
		fail("antechamber is not a start room")
		return
	var hp := {}
	for angel in sim._angels():
		hp[int(angel.id)] = int(angel.hp)
	for _i in 80:
		sim.tick_once()
	if sim.party_room() != "start":
		fail("the opening walked out of the antechamber into %s" % sim.party_room())
		return
	if _pulled_count(sim) != 0 or _mob_homed(sim, "start") != 0:
		fail("the antechamber started a fight pulls=%d home=%d" % [_pulled_count(sim), _mob_homed(sim, "start")])
		return
	for angel2 in sim._angels():
		if int(angel2.hp) < int(hp[int(angel2.id)]):
			fail("the antechamber dealt damage")
			return
	var fork: Vector2i = sim.map.center_tile("fork")
	if not _walk_to(sim, fork, 20 * 30):
		fail("could not reach the fork from the antechamber")
		return
	for _j in 40:
		sim.tick_once()
	if _pulled_count(sim) != 0:
		fail("the fork pulled a fight before a real room")
		return
	var goal: Vector2i = sim.map.node_tile("summoned:center")
	sim.submit("move_tile", {"tile": goal})
	var fought := ""
	for _k in 20 * 120:
		sim.tick_once()
		if _pulled_count(sim) > 0:
			fought = sim.party_room()
			break
	if fought == "":
		fail("walking into the first room never started a fight %s" % sim.debug_string())
		return
	var kind := str(sim.map.by_id.get(fought, {}).get("kind", ""))
	if kind not in ["summoned", "trapped", "cursed"]:
		fail("first fight started in %s (%s), not a real room" % [fought, kind])
		return
	sim.path = []
	var held := _first_pulled(sim)
	if held.is_empty():
		fail("pull vanished as the hold started")
		return
	for _n in 40:
		sim.path = []
		sim.tick_once()
		if not bool(held.alive) or not bool(held.pulled):
			fail("first fight ended during the hold room=%s" % sim.party_room())
			return


func test_golden_regen_is_slower_than_the_infinite_heal_tune() -> void:
	var curve := [10, 22, 48, 110, 260]
	var rates := [2.0, 4.4, 9.6, 22.0, 52.0]
	for i in 5:
		var g := Balance.golden_regen(i)
		if g != curve[i]:
			fail("golden curve %d is %d, want %d" % [i, g, curve[i]])
			return
		var pts := float(g) * float(Balance.TICK_HZ) / float(Balance.POINT)
		if absf(pts - rates[i]) > 0.05:
			fail("stage %d regens %0.2f points/sec" % [i, pts])
			return
	var g0 := Balance.golden_regen(0)
	if g0 <= 3:
		fail("descent %d fell back to the 1.0.3 starvation floor" % g0)
		return
	if g0 >= 20:
		fail("descent %d is still the 1.1.0 infinite-heal tune" % g0)
		return
	var rate := float(g0) * float(Balance.TICK_HZ) / float(Balance.POINT)
	var mend := float(Balance.points_of(Balance.cost("single_heal")))
	var party := float(Balance.points_of(Balance.cost("party_heal")))
	if mend / rate <= 2.0:
		fail("a mend refunds in %0.2fs" % (mend / rate))
		return
	if rate * 5.0 >= party:
		fail("5s of descent regen pays a party heal")


func _west_door(sim: CombatSim, room_id: String) -> Dictionary:
	var room: Dictionary = sim.map.by_id.get(room_id, {})
	if room.is_empty():
		return {}
	var best_x := 9999
	var door := Vector2i.ZERO
	var outside := Vector2i.ZERO
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for ex in room.exits:
		var tile: Vector2i = ex.tile
		if tile.x > best_x:
			continue
		for d in dirs:
			var n: Vector2i = tile + d
			var id := sim.map.id_at_tile(n)
			if id != "" and id != room_id:
				best_x = tile.x
				door = tile
				outside = n
				break
	if best_x == 9999:
		return {}
	return {"door": door, "out": outside}


func _place_party(sim: CombatSim, tile: Vector2i) -> void:
	sim.path = []
	sim.anchor = Fixed.tile_center(tile)
	for angel in sim._angels():
		angel.pos = sim.anchor
	sim.party_room_id = sim.map.id_at_tile(tile)


func _walk_to(sim: CombatSim, tile: Vector2i, limit: int) -> bool:
	sim.submit("move_tile", {"tile": tile})
	for _i in limit:
		sim.tick_once()
		if sim.outcome != "":
			return false
		if sim.path.is_empty() and Fixed.tile_of(sim.anchor) == tile:
			return true
	return Fixed.tile_of(sim.anchor) == tile


func _pulled_count(sim: CombatSim) -> int:
	var n := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "mob" and bool(e.alive) and bool(e.get("pulled", false)):
			n += 1
	return n


func _tap_control(ctrl: Control) -> Control:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion, true)
	var hovered: Control = vp.gui_get_hovered_control()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up, true)
	return hovered


func _play_game() -> Array:
	var mounted := _mount_main()
	var game = mounted[1]
	game.briefing = false
	game.paused = true
	game.sim.director_enabled = false
	game.hud._brief.visible = false
	game.hud._brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud._layout_bottom()
	game._process(0.0)
	game.board._process(0.0)
	return mounted


func _util_signature(hud) -> String:
	var parts: PackedStringArray = []
	for cmd in ["shield", "heal", "cleanse", "detect", "burst"]:
		parts.append(str(hud._bar[cmd].text))
	return "|".join(parts)


func _meter_row(meter: Dictionary, subtype: String) -> Dictionary:
	for row in meter.get("rows", []):
		if str(row.get("subtype", "")) == subtype:
			return row
	return {}


func _mob_homed(sim: CombatSim, room_id: String) -> int:
	var n := 0
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "mob" and str(e.get("home", "")) == room_id:
			n += 1
	return n


func _first_pulled(sim: CombatSim) -> Dictionary:
	for id in sim.order:
		var e: Dictionary = sim.entities[id]
		if str(e.kind) == "mob" and bool(e.alive) and bool(e.get("pulled", false)):
			return e
	return {}


func test_threat_line_names_real_pressure() -> void:
	var sim := _lab()
	for angel in sim._angels():
		angel.atk_cd = 99999
	var michael := sim._hero("michael")
	var before := int(michael.hp)
	var mob := _mob(sim, "imp", michael.pos + Vector2i(300, 0), 900)
	mob.pulled = true
	mob.atk_cd = 1
	mob.speed = 0
	mob.range = 2000
	sim.tick_once()
	if int(michael.hp) >= before:
		fail("a pulled mob did not hit the party")
		return
	var meter: Dictionary = sim.build_snapshot().threat
	if int(meter.get("engaged", 0)) <= 0 or str(meter.get("holder", "")) == "":
		fail("a live fight reported %s" % str(meter))
		return
	if str(meter.get("reason", "")) != "mobs":
		fail("fight reason %s" % str(meter.get("reason", "")))
		return
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _play_game()
	var main: Control = mounted[0]
	var game = mounted[1]
	game.sim = sim
	game._process(0.0)
	var line := str(game.hud._aggro.text)
	if line.contains("no one is fighting"):
		fail("fight line said nobody is fighting: %s" % line)
		main.queue_free()
		return
	if not line.contains("holds") and not line.contains("pull"):
		fail("fight line did not name a holder: %s" % line)
		main.queue_free()
		return
	var calm := _lab()
	calm.corruption = true
	var curse_sim := _lab()
	curse_sim._hero("azrael").silence_until = curse_sim.tick + 80
	var boss := _lab()
	boss.director_enabled = false
	boss._cmd_descend(false)
	boss.transform_until = boss.tick
	game.sim = calm
	game._process(0.0)
	if not str(game.hud._aggro.text).contains("Corruption"):
		fail("corruption line %s" % game.hud._aggro.text)
		main.queue_free()
		return
	if str(game.hud._aggro.text).contains("no one is fighting"):
		fail("corruption still said nobody is fighting")
		main.queue_free()
		return
	game.sim = curse_sim
	game._process(0.0)
	var curse_line := str(game.hud._aggro.text)
	if not curse_line.contains("Silence") or not curse_line.contains("Azrael"):
		fail("curse line %s" % curse_line)
		main.queue_free()
		return
	if curse_line.contains("no one is fighting"):
		fail("a curse still said nobody is fighting")
		main.queue_free()
		return
	var boss_meter: Dictionary = boss.build_snapshot().threat
	if str(boss_meter.get("reason", "")) != "boss":
		fail("lucifer reason %s" % str(boss_meter))
		main.queue_free()
		return
	game.sim = boss
	game._process(0.0)
	if not str(game.hud._aggro.text).contains("Lucifer"):
		fail("boss line %s" % game.hud._aggro.text)
	main.queue_free()


func test_cleanse_removes_each_curse() -> void:
	var fields := {
		"silence": "silence_until",
		"rot": "rot_until",
		"mark": "mark_until",
		"weaken": "weaken_until",
	}
	for kind in ["silence", "rot", "mark", "weaken"]:
		var sim := _lab()
		var hero := sim._hero("raphael")
		hero[fields[kind]] = sim.tick + 120
		sim.submit("cleanse", {})
		sim.tick_once()
		if int(hero[fields[kind]]) > sim.tick:
			fail("cleanse left %s on Raphael" % kind)
			return
	var both := _lab()
	both.corruption = true
	both.idle_ticks = 400
	both._hero("raphael").silence_until = 500
	both.submit("cleanse", {})
	both.tick_once()
	if both.corruption:
		fail("cleanse left corruption in place")
		return
	if int(both._hero("raphael").silence_until) <= both.tick:
		fail("corruption cleanse also removed silence")
		return
	if both.idle_ticks > 5:
		fail("corruption cleanse left the idle clock at %d" % both.idle_ticks)
		return
	var camp := _lab()
	_stand(camp, "fork")
	camp.corruption = true
	camp.corruption_warned = true
	camp.idle_ticks = 500
	camp.turtle_clock = 4
	camp.golden = 8000
	camp.submit("cleanse", {})
	camp.tick_once()
	camp.tick_once()
	if camp.corruption or camp.idle_ticks >= Balance.TURTLE_TICKS:
		fail("corruption returned immediately idle=%d" % camp.idle_ticks)
		return
	var rooted := _lab()
	rooted.root_total = 40
	rooted.root_until = rooted.tick + 40
	rooted.submit("cleanse", {})
	rooted.tick_once()
	if rooted.tick >= rooted.root_until:
		fail("cleanse broke a snare")
		return
	var snare := _status_named(rooted.unit_statuses(rooted._hero("michael")), "snare")
	if snare.is_empty() or bool(snare.get("cleansable", true)) or not str(snare.get("note", "")).contains("not cleansable"):
		fail("snare row %s" % str(snare))
		return
	if not _feed(rooted).contains("Nothing to cleanse."):
		fail("snare cleanse feed %s" % _feed(rooted))
		return
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _play_game()
	var main: Control = mounted[0]
	var game = mounted[1]
	game.sim.root_total = 40
	game.sim.root_until = game.sim.tick + 40
	game._process(0.0)
	if not str(game.hud._room.text).contains("not cleansable"):
		fail("snare was not labeled on screen: %s" % game.hud._room.text)
	main.queue_free()


func test_portrait_tap_does_not_swap_the_bar() -> void:
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _play_game()
	var main: Control = mounted[0]
	var game = mounted[1]
	var hud = game.hud
	for key in ["block", "revive", "dash", "beam", "zone", "retreat", "aegis", "rescue"]:
		if not hud._acts.has(key):
			fail("bar is missing %s" % key)
			main.queue_free()
			return
	var before := _util_signature(hud)
	if before.contains("Back"):
		fail("bar opened on a kit: %s" % before)
		main.queue_free()
		return
	var portrait: Button = hud._portraits["azrael"]
	var hovered := _tap_control(portrait)
	if hovered != portrait:
		fail("portrait tap hit %s" % hovered)
		main.queue_free()
		return
	game._process(0.0)
	var after := _util_signature(hud)
	if after != before or after.contains("Back"):
		fail("portrait tap changed the bar\n%s\n%s" % [before, after])
		main.queue_free()
		return
	if str(hud._highlight) != "azrael":
		fail("portrait tap did not highlight Azrael (%s)" % str(hud._highlight))
		main.queue_free()
		return
	for cmd in hud._bar.keys():
		if not bool(hud._bar[cmd].visible):
			fail("%s was hidden by a portrait tap" % cmd)
			main.queue_free()
			return
	var az: Dictionary = game.sim._hero("azrael")
	var az_pos: Vector2i = az.pos
	game.sim.golden = 9000
	var dash: Button = hud._acts["dash"]
	var dash_hit := _tap_control(dash)
	if dash_hit != dash:
		fail("dash tap hit %s" % dash_hit)
		main.queue_free()
		return
	game.sim.tick_once()
	game._process(0.0)
	if int(az.untargetable_until) <= game.sim.tick and az.pos == az_pos:
		fail("dash press did not cast")
		main.queue_free()
		return
	if _util_signature(hud).contains("Back"):
		fail("dash press swapped the bar %s" % _util_signature(hud))
		main.queue_free()
		return
	var raphael: Dictionary = game.sim._hero("raphael")
	raphael.hp = int(raphael.hp_max) - 40
	var hurt := int(raphael.hp)
	game.sim.golden = 9000
	game._process(0.0)
	var mend: Button = hud._acts["mend"]
	if _tap_control(mend) != mend:
		fail("mend tap missed the button")
		main.queue_free()
		return
	if game.armed != "single_heal":
		fail("mend did not arm, armed=%s" % game.armed)
		main.queue_free()
		return
	var ally: Button = hud._portraits["raphael"]
	if _tap_control(ally) != ally:
		fail("armed portrait tap missed Raphael")
		main.queue_free()
		return
	game.sim.tick_once()
	game._process(0.0)
	if int(raphael.hp) <= hurt:
		fail("armed portrait tap did not heal Raphael")
		main.queue_free()
		return
	if _util_signature(hud).contains("Back"):
		fail("a targeted heal swapped the bar")
	main.queue_free()


func test_zoom_buttons_change_the_camera() -> void:
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _play_game()
	var main: Control = mounted[0]
	var game = mounted[1]
	var board = game.board
	if board.has_method("apply_pinch_factor"):
		fail("pinch zoom is still wired")
		main.queue_free()
		return
	var before := float(board.zoom)
	var step := int(board.zoom_step)
	if before <= 0.2:
		fail("camera zoom did not compute (%s)" % before)
		main.queue_free()
		return
	var plus: Button = game.hud._zoom_in
	var hovered := _tap_control(plus)
	if hovered != plus:
		fail("zoom + tap hit %s" % hovered)
		main.queue_free()
		return
	board._process(0.0)
	if int(board.zoom_step) != step + 1:
		fail("zoom + did not step (%d -> %d)" % [step, int(board.zoom_step)])
		main.queue_free()
		return
	if float(board.zoom) < before * 1.2:
		fail("zoom + left the camera at %s from %s" % [board.zoom, before])
		main.queue_free()
		return
	var minus: Button = game.hud._zoom_out
	if _tap_control(minus) != minus:
		fail("zoom − tap missed the button")
		main.queue_free()
		return
	board._process(0.0)
	if int(board.zoom_step) != step or absf(float(board.zoom) - before) > 0.001:
		fail("zoom − did not restore %s step %d" % [board.zoom, int(board.zoom_step)])
		main.queue_free()
		return
	var held_step := int(board.zoom_step)
	var held_zoom := float(board.zoom)
	var mag := InputEventMagnifyGesture.new()
	mag.factor = 1.8
	mag.position = Vector2(640, 360)
	game.get_viewport().push_input(mag, true)
	var a := InputEventScreenTouch.new()
	a.pressed = true
	a.index = 0
	a.position = Vector2(560, 300)
	var b := InputEventScreenTouch.new()
	b.pressed = true
	b.index = 1
	b.position = Vector2(760, 300)
	game.get_viewport().push_input(a, true)
	game.get_viewport().push_input(b, true)
	board._process(0.0)
	if int(board.zoom_step) != held_step or absf(float(board.zoom) - held_zoom) > 0.001:
		fail("pinch changed the camera to step %d zoom %s" % [int(board.zoom_step), board.zoom])
	main.queue_free()


func test_status_icons() -> void:
	var sim := _lab()
	var raphael := sim._hero("raphael")
	raphael.silence_until = sim.tick + Balance.SILENCE_TICKS
	raphael.shield = 40
	raphael.radiance = 2
	sim.corruption = true
	var rows: Array = sim.unit_statuses(raphael)
	for id in ["silence", "corruption", "shield", "radiance"]:
		var row := _status_named(rows, id)
		if row.is_empty():
			fail("%s icon row missing" % id)
			return
		if str(row.get("symbol", "")) == "" or not row.has("left") or not row.has("total") or not row.has("cleansable"):
			fail("%s row is incomplete %s" % [id, str(row)])
			return
	var silence := _status_named(rows, "silence")
	if str(silence.polarity) != "debuff" or int(silence.total) < int(silence.left):
		fail("silence icon %s" % str(silence))
		return
	if str(_status_named(rows, "shield").polarity) != "buff":
		fail("shield is not a buff")
		return
	if str(_status_named(rows, "radiance").polarity) != "buff":
		fail("radiance is not a buff")
		return
	sim.root_total = 30
	sim.root_until = sim.tick + 30
	var snare := _status_named(sim.unit_statuses(sim._hero("michael")), "snare")
	if snare.is_empty() or bool(snare.cleansable):
		fail("snare icon is cleansable %s" % str(snare))
		return
	var mob := _mob(sim, "imp", sim._hero("michael").pos + Vector2i(200, 0), 400)
	sim.golden = 8000
	sim.submit("ability", {"name": "taunt", "id": int(mob.id)})
	sim.tick_once()
	var foe_badge := {}
	for foe in sim.build_snapshot().foes:
		if int(foe.get("id", 0)) == int(mob.id):
			foe_badge = _status_named(foe.get("statuses", []), "taunt")
	if foe_badge.is_empty() or str(foe_badge.get("polarity", "")) != "debuff":
		fail("enemy taunt icon %s" % str(foe_badge))
		return
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _play_game()
	var main: Control = mounted[0]
	var game = mounted[1]
	game.sim = sim
	game._process(0.0)
	var icons: StatusRow = game.hud._icons["raphael"]
	if not icons.visible or icons.rows.is_empty():
		fail("portrait icons were not shown")
		main.queue_free()
		return
	var shown := false
	for st in icons.rows:
		if str(st.get("id", "")) == "silence" and str(st.get("polarity", "")) == "debuff":
			shown = true
	if not shown:
		fail("portrait icons hid silence %s" % str(icons.rows))
		main.queue_free()
		return
	var drawn_at := StatusRow.draws
	icons.queue_redraw()
	game.board.queue_redraw()
	var board = game.board
	after_frame.append(func():
		if not is_instance_valid(icons) or not is_instance_valid(board):
			fail("status icons were freed before they drew")
			return
		if StatusRow.draws <= drawn_at:
			fail("buff icons were never drawn")
		if is_instance_valid(main):
			main.queue_free()
	)


func test_threat_bars_relative_to_tank() -> void:
	var sim := _lab()
	for angel in sim._angels():
		angel.atk_cd = 99999
	var michael := sim._hero("michael")
	var az := sim._hero("azrael")
	var mob := _mob(sim, "imp", michael.pos + Vector2i(200, 0), 900)
	mob.pulled = true
	mob.threat = {str(michael.id): 1000, str(az.id): 400}
	var safe: Dictionary = _meter_row(sim.build_snapshot().threat, "azrael")
	if int(safe.get("of_tank", -1)) != 40 or str(safe.get("heat", "")) != "safe":
		fail("moderate threat painted %s" % str(safe))
		return
	var tank: Dictionary = _meter_row(sim.build_snapshot().threat, "michael")
	if int(tank.get("of_tank", 0)) != 100 or str(tank.get("heat", "")) != "hold":
		fail("tank bar %s" % str(tank))
		return
	mob.threat[str(az.id)] = 700
	var warn: Dictionary = _meter_row(sim.build_snapshot().threat, "azrael")
	if int(warn.of_tank) != 70 or str(warn.heat) != "warn":
		fail("near-pull bar %s" % str(warn))
		return
	mob.threat[str(az.id)] = 920
	var hot: Dictionary = _meter_row(sim.build_snapshot().threat, "azrael")
	if int(hot.of_tank) != 92 or str(hot.heat) != "pull":
		fail("about-to-pull bar %s" % str(hot))
		return
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _play_game()
	var main: Control = mounted[0]
	var game = mounted[1]
	game.sim = sim
	game._process(0.0)
	var bar: ProgressBar = game.hud._threat["azrael"]
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if int(bar.value) != 92:
		fail("hud threat bar shows %s" % bar.value)
		main.queue_free()
		return
	if fill == null or fill.bg_color.r < 0.8 or fill.bg_color.g > 0.45:
		fail("about-to-pull bar was not red %s" % (fill.bg_color if fill else "none"))
		main.queue_free()
		return
	var tank_bar: ProgressBar = game.hud._threat["michael"]
	var tank_fill := tank_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if int(tank_bar.value) != 100 or tank_fill == null or tank_fill.bg_color.r < 0.8 or tank_fill.bg_color.g < 0.5:
		fail("tank bar looked like a pull %s value %s" % [tank_fill.bg_color if tank_fill else "none", tank_bar.value])
	main.queue_free()


func test_tank_headroom() -> void:
	if Balance.TANK_THREAT_MULT != 1600 or Balance.HEAL_THREAT_PCT != 35 or Balance.OPENER_THREAT != 480:
		fail("threat tune drifted %d / %d / %d" % [Balance.TANK_THREAT_MULT, Balance.HEAL_THREAT_PCT, Balance.OPENER_THREAT])
		return
	if Balance.THREAT_WARN_PCT != 70 or Balance.THREAT_DANGER_PCT != 92 or Balance.THREAT_PULL_PCT != 85:
		fail("threat colors drifted")
		return
	var auto_threat := 8 * Balance.TANK_THREAT_MULT / 100
	var heal_threat := Balance.HEAL_PARTY * Balance.HEAL_THREAT_PCT / 100
	if auto_threat != 128 or heal_threat != 11:
		fail("documented auto threat %d heal threat %d" % [auto_threat, heal_threat])
		return
	if heal_threat * 11 > auto_threat or heal_threat * 12 <= auto_threat:
		fail("twelve party heals should be what passes one tank auto")
		return
	var sim := _lab()
	for angel in sim._angels():
		angel.atk_cd = 99999
	var michael := sim._hero("michael")
	var raphael := sim._hero("raphael")
	raphael.hp = int(raphael.hp_max)
	var mob := _mob(sim, "imp", michael.pos + Vector2i(400, 0), 900)
	mob.atk_cd = 99999
	mob.speed = 0
	sim.tick_once()
	if not bool(mob.pulled):
		fail("headroom mob never pulled")
		return
	var lead := int(mob.threat.get(str(michael.id), 0))
	if lead < Balance.OPENER_THREAT:
		fail("opener threat %d" % lead)
		return
	for _i in 10:
		sim._heal(raphael, Balance.HEAL_PARTY, int(raphael.id))
	if str(sim._mob_target(mob).get("subtype", "")) != "michael":
		fail("ten party heals pulled off the opener %s" % str(mob.threat))
		return
	var casts := 10
	while str(sim._mob_target(mob).get("subtype", "")) == "michael" and casts < 80:
		sim._heal(raphael, Balance.HEAL_PARTY, int(raphael.id))
		casts += 1
	if str(sim._mob_target(mob).get("subtype", "")) != "raphael":
		fail("heals never pulled, casts %d threat %s" % [casts, str(mob.threat)])
		return
	if casts < 40 or casts > 50:
		fail("opener headroom was %d party heals, want about 44" % casts)


func test_tank_opens_the_fight() -> void:
	var sim := _lab()
	sim.stance = CombatSim.STANCE_TIGHT
	for angel in sim._angels():
		angel.atk_cd = 99999
	var names := ["michael", "raphael", "azrael", "uriel", "gabriel"]
	var offsets: Array[Vector2i] = [Vector2i(280, 0), Vector2i(0, -260), Vector2i(0, 260), Vector2i(-260, -140), Vector2i(-300, 160)]
	for i in names.size():
		sim._hero(names[i]).pos = sim.anchor + offsets[i]
	var michael := sim._hero("michael")
	var raphael := sim._hero("raphael")
	var mob := _mob(sim, "imp", raphael.pos + Vector2i(160, 0), 900)
	mob.range = 2500
	mob.atk = 12
	mob.atk_cd = 1
	mob.period = 100
	mob.speed = 0
	if Fixed.dist(mob.pos, raphael.pos) >= Fixed.dist(mob.pos, michael.pos):
		fail("setup did not put Raphael closer")
		return
	var before := {}
	for hero in sim._angels():
		before[str(hero.subtype)] = int(hero.hp)
	sim.tick_once()
	if int(michael.hp) >= int(before["michael"]):
		fail("Michael was not hit first (hp %d target %s threat %s)" % [int(michael.hp), str(sim._mob_target(mob).get("subtype", "")), str(mob.threat)])
		return
	for subtype in before.keys():
		if str(subtype) == "michael":
			continue
		if int(sim._hero(str(subtype)).hp) != int(before[subtype]):
			fail("%s took the opening hit" % subtype)
			return


func test_entrance_takes_no_damage() -> void:
	var sim := CombatSim.new()
	if not sim.director_enabled:
		fail("entrance check ran with the director off")
		return
	var hp := {}
	for angel in sim._angels():
		hp[str(angel.subtype)] = int(angel.hp)
	for _i in 600:
		sim.tick_once()
		if sim.party_room() != "start":
			fail("the fresh run left the entrance for %s" % sim.party_room())
			return
	if int(sim.stats.damage_taken) != 0 or sim.corruption:
		fail("entrance took %d and corruption=%s (%s)" % [int(sim.stats.damage_taken), sim.corruption, _feed(sim)])
		return
	for angel2 in sim._angels():
		if int(angel2.hp) != int(hp[str(angel2.subtype)]):
			fail("%s hp changed in the entrance" % angel2.subtype)
			return
	if _feed(sim).contains("Rot"):
		fail("rot landed in the entrance: %s" % _feed(sim))
		return
	if host == null:
		fail("scene test has no tree")
		return
	var mounted := _mount_main()
	var main: Control = mounted[0]
	var game = mounted[1]
	var begin: Button = game.hud._begin
	var hovered := _tap_control(begin)
	if hovered != begin:
		fail("Begin tap hit %s" % hovered)
		main.queue_free()
		return
	if game.briefing:
		fail("Begin did not start the run")
		main.queue_free()
		return
	var hp2 := {}
	for angel3 in game.sim._angels():
		hp2[str(angel3.subtype)] = int(angel3.hp)
	for _j in 400:
		game.sim.tick_once()
	if int(game.sim.stats.damage_taken) != 0 or game.sim.corruption:
		fail("a begun run took damage in the entrance: %s" % _feed(game.sim))
		main.queue_free()
		return
	for angel4 in game.sim._angels():
		if int(angel4.hp) != int(hp2[str(angel4.subtype)]):
			fail("begun run hurt %s in the entrance" % angel4.subtype)
			main.queue_free()
			return
	main.queue_free()
