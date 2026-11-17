# Screenshots of the game for visual checks without the editor (opens a window briefly).
#
#   godot --path . res://tools/capture.tscn -- --pops 40 --radius 2 --out /tmp/bubblewrap.png
#
# Options: --out PATH, --size WxH, --time S (wait before the shot, default 0.6),
#   --height H (camera height), --pops N (random strokes near the center), --radius R (stroke radius),
#   --steamrollers N, --wallet N, --thumb LEVEL, --mid-pop (shot taken 0.03 s after a big stroke).
#   --press S (shot taken S seconds into a press at the center, below Game.PRESS_MAX).
#   --producers N (owns one of each of the first N producer tiers).
#   --zoom-out S (shot taken S seconds into the zoom out to the globe, see Cinematic for the timeline).
# Uses its own save file and mutes sound.
extends Node

const SAVE_PATH := "user://capture_save.dat"

var _options: Dictionary[String, String] = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key := args[i].trim_prefix("--")
		var value := "1"
		if i + 1 < args.size() and not args[i + 1].begins_with("--"):
			value = args[i + 1]
			i += 1
		_options[key] = value
		i += 1
	var size: PackedStringArray = _options.get("size", "1600x900").split("x")
	get_window().size = Vector2i(int(size[0]), int(size[1]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	var game: Game = load("res://scenes/main.tscn").instantiate()
	game.save_path = SAVE_PATH
	game.muted = true
	add_child(game)
	if _options.has("height"):
		game.target_height = float(_options["height"])
		game.height = game.target_height
	game.economy.thumb = int(_options.get("thumb", "0"))
	game.economy.add_pops(int(_options.get("wallet", "0")))
	for n in int(_options.get("steamrollers", "0")):
		game.economy.add_pops(game.economy.cost(Economy.STEAMROLLER))
		game.buy(Economy.STEAMROLLER)
	for n in int(_options.get("producers", "0")):
		game.economy.producers[Economy.PRODUCERS[n]["id"]] = 1
	await get_tree().process_frame
	await get_tree().process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var radius := float(_options.get("radius", "1.5"))
	for n in int(_options.get("pops", "0")):
		var a := Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 4))
		game.pop_segment(a, a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0, 6), radius)
	await get_tree().create_timer(float(_options.get("time", "0.6"))).timeout
	if _options.has("press"):
		game.press_begin(Vector2(0, -2))
		var hold := float(_options["press"])
		while game._press_time < hold:
			await get_tree().process_frame
	if _options.has("zoom-out"):
		game.play_zoom_out(game._latest_producer())
		await get_tree().create_timer(float(_options["zoom-out"])).timeout
	if _options.has("mid-pop"):
		game.pop_segment(Vector2(-4, -2), Vector2(4, -2), 1.6)
		await get_tree().create_timer(0.03).timeout
	await RenderingServer.frame_post_draw
	var out: String = _options.get("out", "/tmp/bubblewrap_capture.png")
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().quit()
