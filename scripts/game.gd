class_name Game
extends Node3D
## Main scene: input, camera, steamrollers, save. Pops go through pop_segment.

const SAVE_VERSION := 1
const PITCH := deg_to_rad(62.0)
const MIN_HEIGHT := 6.0
const MAX_HEIGHT := 80.0
const START_HEIGHT := 12.0
const PAN_SPEED := 1.2 # camera heights per second
const ZOOM_STEP := 1.15
const AUTOSAVE_SECONDS := 15.0
## Rolling pin reach when the thumb is still tiny, so a drag pops a continuous line.
const MIN_DRAG_RADIUS := 0.45
## A press squeezes, the release bursts; holding this long bursts on its own.
const PRESS_MAX := 0.35
## Share of the squeeze reached almost at once, the rest builds up until PRESS_MAX.
const PRESS_DENT := 0.6
const PRESS_DENT_TIME := 0.06
## With the rolling pin, moving this far while pressed starts rolling.
const ROLL_START_DISTANCE := 0.35
## Golden angle: consecutive steamrollers leave in well spread directions.
const STEAMROLLER_ANGLE := 2.399963

@export var save_path := "user://save.dat"
@export var muted := false

var data := SheetData.new()
var economy := Economy.new()
var clock := 0.0
var focus := Vector2.ZERO
var height := START_HEIGHT
var target_height := START_HEIGHT
var pitch := PITCH
var steamrollers: Array[Steamroller] = []

var _pressing := false
var _press_point := Vector2.ZERO
var _press_time := 0.0
var _dragging := false
var _last_drag := Vector2.ZERO
var _autosave := 0.0
var _environment: Environment

@onready var camera: Camera3D = $Camera3D
@onready var view: SheetView = $SheetView
@onready var fx: PopFx = $PopFx
@onready var hud: Hud = $Hud
@onready var _steamroller_root: Node3D = $Steamrollers
var globe: Globe
var cinematic: Cinematic


func _ready() -> void:
	view.data = data
	fx.muted = muted
	hud.buy_requested.connect(buy)
	globe = Globe.new()
	add_child(globe)
	cinematic = Cinematic.new(self)
	_build_lighting()
	load_game()
	_update_camera(0.0)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	# Lit from the far side so the bubble highlights face the camera.
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(200.0), 0.0)
	sun.light_energy = 1.3
	add_child(sun)
	var environment := Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.38, 0.22)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_hdr_threshold = 1.1
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


## Dark sky behind the globe, cardboard behind the sheet.
func set_space(on: bool) -> void:
	_environment.background_color = Color(0.02, 0.03, 0.07) if on else Color(0.55, 0.38, 0.22)


func _unhandled_input(event: InputEvent) -> void:
	if cinematic.active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cinematic.skip()
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				press_begin(mouse_ground())
			MOUSE_BUTTON_WHEEL_UP:
				target_height = maxf(target_height / ZOOM_STEP, MIN_HEIGHT)
			MOUSE_BUTTON_WHEEL_DOWN:
				target_height = minf(target_height * ZOOM_STEP, MAX_HEIGHT)
	elif event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		var focus_distance := height / sin(PITCH)
		var world_per_pixel := 2.0 * focus_distance * tan(deg_to_rad(camera.fov) / 2.0) / get_viewport().get_visible_rect().size.y
		focus -= Vector2(event.relative.x, event.relative.y / sin(PITCH)) * world_per_pixel
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		reset()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		# Dev: fast-forward to test the progression.
		Engine.time_scale = {1.0: 10.0, 10.0: 100.0}.get(Engine.time_scale, 1.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		# Dev: replay the zoom out, for clips.
		play_zoom_out(_latest_producer())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		press_end()


func _process(delta: float) -> void:
	clock += delta
	RenderingServer.global_shader_parameter_set("pop_clock", clock)
	cinematic.update(delta)
	_update_camera(delta)
	view.update_visible(camera)
	hud.set_flash(cinematic.flash())

	if cinematic.active:
		_pressing = false
		_dragging = false
		RenderingServer.global_shader_parameter_set("pop_hover", Vector3(0.0, 0.0, -1.0))
		RenderingServer.global_shader_parameter_set("pop_press", 0.0)
	else:
		var ground := mouse_ground()
		press_update(ground, delta)
		var radius := economy.thumb_radius()
		var tool_point := _press_point if _pressing else ground
		var hover_center := SheetData.cell_position(SheetData.nearest_cell(tool_point)) if radius <= 0.0 else tool_point
		RenderingServer.global_shader_parameter_set("pop_hover", Vector3(hover_center.x, hover_center.y, maxf(radius, 0.1)))
		RenderingServer.global_shader_parameter_set("pop_press", press_amount())

	for steamroller in steamrollers:
		var swept := steamroller.advance(delta)
		pop_segment(swept[0], swept[1], steamroller.radius)
	economy.produce(delta)

	hud.refresh(economy, delta)
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		_autosave = 0.0
		save_game()


func press_begin(ground: Vector2) -> void:
	_pressing = true
	_press_point = ground
	_press_time = 0.0


func press_update(ground: Vector2, delta: float) -> void:
	if _dragging:
		pop_segment(_last_drag, ground, maxf(economy.thumb_radius(), MIN_DRAG_RADIUS))
		_last_drag = ground
		return
	if not _pressing:
		return
	_press_time += delta
	var rolled := economy.rolling_pin and ground.distance_to(_press_point) > ROLL_START_DISTANCE
	if not rolled and _press_time < PRESS_MAX:
		return
	_burst_press()
	if economy.rolling_pin:
		_dragging = true
		_last_drag = _press_point
		press_update(ground, 0.0)


func press_end() -> void:
	if _pressing:
		_burst_press()
	_dragging = false


## Squeeze of the pressed bubbles, 0 when nothing is held.
func press_amount() -> float:
	if not _pressing:
		return 0.0
	var dent := minf(_press_time / PRESS_DENT_TIME, 1.0) * PRESS_DENT
	return dent + (1.0 - PRESS_DENT) * minf(_press_time / PRESS_MAX, 1.0)


func _burst_press() -> void:
	_pressing = false
	pop_segment(_press_point, _press_point, economy.thumb_radius())


## Pops around a segment (a point when a == b); radius 0 pops the single nearest bubble.
func pop_segment(a: Vector2, b: Vector2, radius: float) -> int:
	var cells := data.pop_nearest(a) if radius <= 0.0 else data.pop_capsule(a, b, radius)
	if cells.is_empty():
		return 0
	view.mark_popped(cells, clock)
	fx.burst(cells, camera)
	economy.add_pops(cells.size())
	return cells.size()


func buy(id: StringName) -> bool:
	if not economy.buy(id):
		return false
	fx.play_buy()
	match id:
		Economy.STEAMROLLER:
			var direction := Vector2.from_angle(-PI / 2.0 + (economy.steamrollers - 1) * STEAMROLLER_ANGLE)
			_spawn_steamroller(focus, direction)
		Economy.STEAMROLLER_WIDTH:
			for steamroller in steamrollers:
				steamroller.set_radius(economy.steamroller_radius())
		_:
			if economy.producer_count(id) == 1:
				play_zoom_out(id)
			else:
				globe.set_producers(economy, clock)
	return true


## Zooms out to the globe to show a producer tier at work.
func play_zoom_out(id: StringName) -> void:
	if cinematic.active:
		return
	cinematic.play("%s joined in" % Hud.NAMES[id] if Hud.NAMES.has(id) else "")


func _latest_producer() -> StringName:
	var latest := &""
	for producer in Economy.PRODUCERS:
		if economy.producer_count(producer["id"]) > 0:
			latest = producer["id"]
	return latest


func mouse_ground() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if normal.y > -0.01:
		return focus
	var hit := origin + normal * (-origin.y / normal.y)
	return Vector2(hit.x, hit.z)


func _update_camera(delta: float) -> void:
	if not cinematic.active:
		_player_camera(delta)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.position = Vector3(focus.x, height, focus.y + height / tan(pitch))
	camera.h_offset = randf_range(-1.0, 1.0) * fx.shake * 0.05 * height / START_HEIGHT
	camera.v_offset = randf_range(-1.0, 1.0) * fx.shake * 0.05 * height / START_HEIGHT


func _player_camera(delta: float) -> void:
	var move := Vector2(
		Input.get_axis(&"ui_left", &"ui_right") + float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		Input.get_axis(&"ui_up", &"ui_down") + float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	focus += move.limit_length(1.0) * PAN_SPEED * height * delta
	height = lerpf(height, target_height, 1.0 - exp(-12.0 * delta)) if delta > 0.0 else target_height


func _spawn_steamroller(start: Vector2, direction: Vector2) -> Steamroller:
	var steamroller := Steamroller.new()
	steamroller.setup(start, direction, economy.steamroller_radius())
	_steamroller_root.add_child(steamroller)
	steamrollers.append(steamroller)
	return steamroller


func save_game() -> void:
	var rollers: Array = []
	for steamroller in steamrollers:
		rollers.append([Vector2(steamroller.position.x, steamroller.position.z), steamroller.heading])
	var file := FileAccess.open_compressed(save_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_error("Cannot write save %s" % save_path)
		return
	file.store_var({
		"version": SAVE_VERSION, "economy": economy.to_dict(), "chunks": data.chunks,
		"steamrollers": rollers, "focus": focus, "height": target_height,
	})


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open_compressed(save_path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var save = file.get_var() if file else null
	if not save is Dictionary or save.get("version") != SAVE_VERSION:
		return
	economy.from_dict(save["economy"])
	data.chunks.assign(save["chunks"])
	focus = save["focus"]
	target_height = save["height"]
	height = target_height
	for roller in save["steamrollers"]:
		_spawn_steamroller(roller[0], roller[1])
	view.clear()
	# Born long ago: loaded sparks skip their intro.
	globe.set_producers(economy, -1000.0)


func reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	data.chunks.clear()
	economy = Economy.new()
	for steamroller in steamrollers:
		steamroller.queue_free()
	steamrollers.clear()
	focus = Vector2.ZERO
	_pressing = false
	_dragging = false
	target_height = START_HEIGHT
	view.clear()
	globe.set_producers(economy, clock)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
