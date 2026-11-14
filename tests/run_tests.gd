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
	&"test_click_pops_and_pays",
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


func test_click_pops_and_pays() -> void:
	var game := await _new_game()
	check(game.pop_segment(Vector2(2, 2), Vector2(2, 2), 0.0) == 1, "a finger click pops one bubble")
	check(game.economy.wallet == 1 and game.economy.popped == 1, "one pop earned")
	var cell := SheetData.nearest_cell(Vector2(2, 2))
	var instance: MultiMeshInstance3D = game.view._loaded.get(SheetData.chunk_of(cell))
	# The headless renderer keeps no MultiMesh data: check the bubble look with tools/capture.tscn.
	check(instance != null, "the chunk under the camera is drawn")
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
