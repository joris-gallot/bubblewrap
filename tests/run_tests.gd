# Run: godot --headless --path . res://tests/run_tests.tscn
extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TEST_SAVE_PATH := "user://test_save.dat"
const TESTS: Array[StringName] = [
	&"test_nearest_cell_is_the_closest_center",
	&"test_chunks_handle_negative_cells",
	&"test_a_bubble_pops_only_once",
	&"test_capsule_pops_exactly_the_bubbles_in_reach",
	&"test_economy_prices_and_purchases",
	&"test_producers_cost_more_and_pop_over_time",
	&"test_counter_stops_at_the_world_total",
	&"test_shop_reveals_producers_one_tier_at_a_time",
	&"test_pacing_stays_in_target",
	&"test_first_producer_zooms_out_to_the_globe_and_back",
	&"test_a_click_skips_the_zoom_out",
	&"test_combo_heats_up_and_cools_down",
	&"test_combo_multiplies_every_pop",
	&"test_golden_bubble_pays_only_by_hand",
	&"test_click_pops_and_pays",
	&"test_press_squeezes_then_release_bursts",
	&"test_holding_bursts_on_its_own",
	&"test_rolling_pin_rolls_once_moved",
	&"test_steamroller_pops_while_driving",
	&"test_save_round_trip",
]

var _failures: Array[String] = []
var _current := ""


func _ready() -> void:
	for test in TESTS:
		_current = test
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
		var before := _failures.size()
		await call(test)
		print("%s %s" % ["FAIL" if _failures.size() > before else "ok  ", test])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("\n%d tests, %d failures" % [TESTS.size(), _failures.size()])
	for failure in _failures:
		print("  " + failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_current, message])


func _new_game() -> Game:
	var game: Game = MAIN_SCENE.instantiate()
	game.save_path = TEST_SAVE_PATH
	game.muted = true
	add_child(game)
	# process_frame fires before nodes process: wait two so the game ran a frame.
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func test_nearest_cell_is_the_closest_center() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		var p := Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
		var nearest := SheetData.nearest_cell(p)
		var best := SheetData.cell_position(nearest).distance_to(p)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var other := nearest + Vector2i(dx, dy)
				if SheetData.cell_position(other).distance_to(p) < best - 0.0001:
					check(false, "%s: %s is closer than %s" % [p, other, nearest])
					return


func test_chunks_handle_negative_cells() -> void:
	check(SheetData.chunk_of(Vector2i(-1, -1)) == Vector2i(-1, -1), "cell -1,-1 belongs to chunk -1,-1")
	check(SheetData.chunk_of(Vector2i(31, 0)) == Vector2i(0, 0), "cell 31,0 belongs to chunk 0,0")
	check(SheetData.index_in_chunk(Vector2i(-1, -1)) == SheetData.CHUNK * SheetData.CHUNK - 1, "cell -1,-1 is the last of its chunk")
	var data := SheetData.new()
	data.pop_nearest(SheetData.cell_position(Vector2i(-5, -7)))
	check(data.is_popped(Vector2i(-5, -7)), "negative cell popped")
	check(not data.is_popped(Vector2i(-5, -6)), "its neighbour is not")


func test_a_bubble_pops_only_once() -> void:
	var data := SheetData.new()
	check(data.pop_nearest(Vector2(3.1, 2.2)).size() == 1, "first click pops one")
	check(data.pop_nearest(Vector2(3.1, 2.2)).is_empty(), "second click on the same bubble pops none")
	var first := data.pop_capsule(Vector2.ZERO, Vector2(10, 0), 2.0).size()
	check(data.pop_capsule(Vector2.ZERO, Vector2(10, 0), 2.0).is_empty(), "same stroke twice pops nothing new")
	check(data.popped_count() == first + 1, "popped count matches")


func test_capsule_pops_exactly_the_bubbles_in_reach() -> void:
	var data := SheetData.new()
	var a := Vector2(-3.3, 1.7)
	var b := Vector2(8.2, -4.1)
	var radius := 2.4
	data.pop_capsule(a, b, radius)
	for y in range(-15, 15):
		for x in range(-15, 20):
			var cell := Vector2i(x, y)
			var p := SheetData.cell_position(cell)
			var inside := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= radius
			if data.is_popped(cell) != inside:
				check(false, "cell %s popped=%s, in reach=%s" % [cell, data.is_popped(cell), inside])
				return


func test_economy_prices_and_purchases() -> void:
	var economy := Economy.new()
	check(not economy.buy(Economy.THUMB), "cannot buy without pops")
	check(economy.cost(Economy.STEAMROLLER_WIDTH) == -1, "wider drums need a steamroller first")
	economy.add_pops(10_000)
	check(economy.buy(Economy.THUMB), "buys a thumb level")
	check(economy.wallet == 10_000 - Economy.THUMB_COSTS[0], "thumb paid")
	check(economy.popped == 10_000, "spending does not unpop bubbles")
	check(economy.buy(Economy.ROLLING_PIN) and not economy.can_buy(Economy.ROLLING_PIN), "rolling pin is bought once")
	var first := economy.cost(Economy.STEAMROLLER)
	economy.buy(Economy.STEAMROLLER)
	check(economy.cost(Economy.STEAMROLLER) > first, "each steamroller costs more")
	check(Economy.format_count(1234567) == "1,234,567", "thousands separators")
	check(Economy.format_count(Economy.WORLD_BUBBLES) == "10,000,000,000,000", "world count fits an int")


func test_producers_cost_more_and_pop_over_time() -> void:
	var economy := Economy.new()
	for producer in Economy.PRODUCERS:
		check(Economy.UPGRADES.has(producer["id"]), "%s is sold in the shop" % producer["id"])
		check(Hud.NAMES.has(producer["id"]) and Hud.DESCRIPTIONS.has(producer["id"]), "%s has a name and description" % producer["id"])
	var first := economy.cost(&"elephants")
	economy.add_pops(first * 3)
	check(economy.buy(&"elephants"), "elephants bought")
	check(economy.cost(&"elephants") > first, "the second herd costs more")
	var before := economy.popped
	var total := 0
	# 1/160 s steps are exact in binary and each makes 0.75 pop, so fractions must carry.
	for i in 160:
		total += economy.produce(1.0 / 160.0)
	check(total == 120 and economy.popped == before + 120, "one herd pops 120 in a second, fractions carried (%d)" % total)
	var saved := Economy.new()
	saved.from_dict(economy.to_dict())
	check(saved.producer_count(&"elephants") == 1, "producers survive a save")


func test_counter_stops_at_the_world_total() -> void:
	var economy := Economy.new()
	economy.add_pops(Economy.WORLD_BUBBLES - 5)
	check(economy.add_pops(10) == 5, "only the last 5 bubbles count")
	check(economy.bubbles_left() == 0 and economy.popped == Economy.WORLD_BUBBLES, "Earth is out of bubble wrap")
	economy.producers[&"moon"] = 3
	check(economy.produce(1.0) == 0 and economy.popped == Economy.WORLD_BUBBLES, "producers stop at the world total")


func test_shop_reveals_producers_one_tier_at_a_time() -> void:
	var economy := Economy.new()
	check(not economy.is_listed(&"elephants"), "no producer before a steamroller")
	economy.steamrollers = 1
	check(economy.is_listed(&"elephants") and not economy.is_listed(&"monster_trucks"), "first tier after a steamroller")
	economy.producers[&"elephants"] = 1
	check(economy.is_listed(&"monster_trucks") and not economy.is_listed(&"anvil_airdrop"), "next tier once the previous is owned")
	economy.thumb = Economy.THUMB_COSTS.size()
	check(not economy.is_listed(Economy.THUMB), "a maxed thumb leaves the shop")


func test_pacing_stays_in_target() -> void:
	# Target from the design: first steamroller within a few minutes, Earth emptied in a couple of hours.
	var result := Balance.simulate()
	var hours: float = result["seconds"] / 3600.0
	check(hours > 1.5 and hours < 4.0, "Earth emptied in %.2f h" % hours)
	check(result["first"].get(Economy.STEAMROLLER, INF) < 5 * 60.0, "first steamroller within 5 min")
	for producer in Economy.PRODUCERS:
		check(result["first"].has(producer["id"]), "%s gets bought" % producer["id"])


func _run_cinematic(game: Game, seconds: float) -> void:
	var step := 1.0 / 30.0
	var elapsed := 0.0
	while elapsed < seconds:
		game.cinematic.update(step)
		elapsed += step


func test_first_producer_zooms_out_to_the_globe_and_back() -> void:
	var game := await _new_game()
	var start_height := game.height
	game.economy.steamrollers = 1
	game.economy.add_pops(Economy.PRODUCERS[0]["cost"] * 3)
	check(game.buy(&"elephants") and game.cinematic.active, "the first herd starts the zoom out")
	_run_cinematic(game, Cinematic.GLOBE_START * 0.5)
	check(game.height > start_height * 2.0 and game.camera.current, "climbing above the sheet")
	_run_cinematic(game, Cinematic.GLOBE_START * 0.5 + 0.5)
	check(game.cinematic.in_globe() and game.globe.visible and game.globe.camera.current, "the globe is on screen")
	check(game.globe.spark_count() == Globe.SPARKS_PER_UNIT, "one herd of sparks (%d)" % game.globe.spark_count())
	_run_cinematic(game, Cinematic.TOTAL)
	check(not game.cinematic.active and not game.globe.visible and game.camera.current, "back on the sheet")
	check(is_equal_approx(game.height, start_height) and game.pitch == Game.PITCH, "camera back where it was")
	game.buy(&"elephants")
	check(not game.cinematic.active, "a second herd does not zoom out again")
	check(game.globe.spark_count() == 2 * Globe.SPARKS_PER_UNIT, "but adds its sparks")
	game.queue_free()


func test_a_click_skips_the_zoom_out() -> void:
	var game := await _new_game()
	game.economy.producers[&"elephants"] = 1
	game.play_zoom_out(&"elephants")
	_run_cinematic(game, 0.2)
	game.cinematic.skip()
	_run_cinematic(game, 0.1)
	check(not game.cinematic.active and game.camera.current, "a click during the climb ends it")
	game.play_zoom_out(&"elephants")
	_run_cinematic(game, Cinematic.GLOBE_START + 0.3)
	game.cinematic.skip()
	_run_cinematic(game, 0.1)
	check(game.cinematic.active and not game.globe.visible and game.camera.current, "a click in orbit cuts to the descent")
	_run_cinematic(game, Cinematic.DESCEND)
	check(not game.cinematic.active, "and lands")
	game.queue_free()


func test_combo_heats_up_and_cools_down() -> void:
	var combo := Combo.new()
	check(combo.multiplier() == 1, "no combo at rest")
	# Four clicks a second.
	for i in 40:
		combo.feed(Combo.CLICK_FILL)
		combo.update(0.25)
	check(combo.multiplier() == Combo.MULTIPLIERS[-1], "steady clicking reaches the top (x%d)" % combo.multiplier())
	combo.update(Combo.IDLE_AFTER + 3.0)
	check(combo.multiplier() == 1, "stopping cools it down")
	for i in 30:
		combo.feed(Combo.DRAG_FILL_PER_SECOND * 0.1)
		combo.update(0.1)
	check(combo.multiplier() == Combo.MULTIPLIERS[-1], "three seconds of rolling reach the top")
	combo.start_frenzy()
	check(combo.multiplier() == Combo.MULTIPLIERS[-1] * Combo.FRENZY_MULTIPLIER, "frenzy multiplies the combo")
	combo.meter = 0.0
	combo.update(Combo.FRENZY_SECONDS)
	check(combo.multiplier() == 1, "frenzy runs out")


func test_combo_multiplies_every_pop() -> void:
	var game := await _new_game()
	game.combo.meter = 1.0
	var popped := game.pop_segment(Vector2(5, 5), Vector2(5, 5), 0.0)
	check(popped == 1 and game.economy.popped == Combo.MULTIPLIERS[-1], "one bubble at x5 counts five (%d)" % game.economy.popped)
	game.economy.producers[&"elephants"] = 1
	var before := game.economy.popped
	game.economy.produce(1.0, game.combo.multiplier())
	check(game.economy.popped - before == 120 * Combo.MULTIPLIERS[-1], "producers get the multiplier too")
	game.combo.meter = 0.0
	game.press_begin(Vector2(9, 9))
	game.press_end()
	check(is_equal_approx(game.combo.meter, Combo.CLICK_FILL), "a click feeds the combo")
	game.queue_free()


func test_golden_bubble_pays_only_by_hand() -> void:
	var game := await _new_game()
	var cell := SheetData.nearest_cell(Vector2(3, -3))
	game.golden.show_at(cell)
	game.pop_segment(Vector2(3, -3), Vector2(3, -3), 1.5)
	check(not game.golden.active and game.economy.popped < GoldenBubble.FIRST_AFTER_POPS, "a steamroller crushes it for nothing")
	cell = SheetData.nearest_cell(Vector2(-6, 2))
	game.golden.show_at(cell)
	var before := game.economy.popped
	game.press_begin(SheetData.cell_position(cell))
	game.press_end()
	check(not game.golden.active, "clicking it claims it")
	check(game.economy.popped - before > Game.LUCKY_MIN / 2 or game.combo.frenzy_left > 0.0, "and pays out")
	game.golden.show_at(SheetData.nearest_cell(Vector2(8, 8)))
	game.claim_golden(&"frenzy")
	check(game.combo.frenzy_left == Combo.FRENZY_SECONDS, "frenzy reward")
	before = game.economy.popped
	game.golden.show_at(SheetData.nearest_cell(Vector2(-8, 8)))
	game.claim_golden(&"lucky")
	check(game.economy.popped - before >= Game.LUCKY_MIN, "lucky reward pays at least the minimum")
	game.queue_free()


func test_click_pops_and_pays() -> void:
	var game := await _new_game()
	check(game.pop_segment(Vector2(2, 2), Vector2(2, 2), 0.0) == 1, "a finger click pops one bubble")
	check(game.economy.wallet == 1 and game.economy.popped == 1, "one pop earned")
	var cell := SheetData.nearest_cell(Vector2(2, 2))
	var instance: MultiMeshInstance3D = game.view._loaded.get(SheetData.chunk_of(cell))
	# The headless renderer keeps no MultiMesh data: check the bubble look with tools/capture.tscn.
	check(instance != null, "the chunk under the camera is drawn")
	game.queue_free()


func test_press_squeezes_then_release_bursts() -> void:
	var game := await _new_game()
	game.press_begin(Vector2(2, 2))
	game.press_update(Vector2(2, 2), 0.05)
	check(game.economy.popped == 0, "a held press does not pop yet")
	check(game.press_amount() > 0.0 and game.press_amount() < 1.0, "the bubble is being squeezed (%f)" % game.press_amount())
	game.press_end()
	check(game.economy.popped == 1, "release bursts the pressed bubble")
	check(game.press_amount() == 0.0, "nothing squeezed after release")
	game.press_end()
	check(game.economy.popped == 1, "a second release pops nothing")
	game.queue_free()


func test_holding_bursts_on_its_own() -> void:
	var game := await _new_game()
	game.press_begin(Vector2(2, 2))
	game.press_update(Vector2(2, 2), Game.PRESS_MAX)
	check(game.economy.popped == 1, "holding long enough bursts")
	game.press_end()
	check(game.economy.popped == 1, "the release after it pops nothing more")
	game.queue_free()


func test_rolling_pin_rolls_once_moved() -> void:
	var game := await _new_game()
	game.economy.rolling_pin = true
	game.press_begin(Vector2(0, 0))
	game.press_update(Vector2(0.1, 0), 0.01)
	check(game.economy.popped == 0, "a tiny wobble still squeezes")
	game.press_update(Vector2(6, 0), 0.01)
	check(game.economy.popped >= 6, "moving rolls a line (%d)" % game.economy.popped)
	game.press_update(Vector2(12, 0), 0.01)
	var rolled := game.economy.popped
	check(rolled >= 12, "keeps rolling (%d)" % rolled)
	game.press_end()
	game.press_update(Vector2(20, 0), 0.01)
	check(game.economy.popped == rolled, "release stops rolling")
	game.queue_free()


func test_steamroller_pops_while_driving() -> void:
	var game := await _new_game()
	game.economy.add_pops(Economy.STEAMROLLER_BASE_COST)
	check(game.buy(Economy.STEAMROLLER), "steamroller bought")
	var before := game.economy.popped
	var start := game.clock
	while game.clock - start < 1.0:
		await get_tree().process_frame
	check(game.economy.popped > before + 10, "steamroller earned pops (%d)" % (game.economy.popped - before))
	game.queue_free()


func test_save_round_trip() -> void:
	var game := await _new_game()
	game.economy.add_pops(Economy.STEAMROLLER_BASE_COST)
	game.buy(Economy.STEAMROLLER)
	game.pop_segment(Vector2(-40, 30), Vector2(-40, 30), 3.0)
	game.save_game()
	var popped := game.data.popped_count()
	var economy_popped := game.economy.popped
	game.queue_free()
	await get_tree().process_frame
	var loaded := await _new_game()
	check(loaded.data.popped_count() >= popped, "popped bubbles survive a reload")
	check(loaded.data.is_popped(SheetData.nearest_cell(Vector2(-40, 30))), "the far bubble is still popped")
	check(loaded.economy.popped >= economy_popped, "counter survives")
	check(loaded.steamrollers.size() == 1, "steamroller survives")
	loaded.queue_free()
