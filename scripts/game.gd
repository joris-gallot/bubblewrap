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
var steamrollers: Array[Steamroller] = []

var _dragging := false
var _last_drag := Vector2.ZERO
var _autosave := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var view: SheetView = $SheetView
@onready var fx: PopFx = $PopFx
@onready var hud: Hud = $Hud
@onready var _steamroller_root: Node3D = $Steamrollers


func _ready() -> void:
	view.data = data
	fx.muted = muted
	hud.buy_requested.connect(buy)
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var ground := mouse_ground()
				pop_segment(ground, ground, economy.thumb_radius())
				_dragging = economy.rolling_pin
				_last_drag = ground
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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


func _process(delta: float) -> void:
	clock += delta
	RenderingServer.global_shader_parameter_set("pop_clock", clock)
	_update_camera(delta)
	view.update_visible(camera)

	var ground := mouse_ground()
	if _dragging:
		pop_segment(_last_drag, ground, maxf(economy.thumb_radius(), MIN_DRAG_RADIUS))
		_last_drag = ground
	var radius := economy.thumb_radius()
	var hover_center := SheetData.cell_position(SheetData.nearest_cell(ground)) if radius <= 0.0 else ground
	RenderingServer.global_shader_parameter_set("pop_hover", Vector3(hover_center.x, hover_center.y, maxf(radius, 0.1)))

	for steamroller in steamrollers:
		var swept := steamroller.advance(delta)
		pop_segment(swept[0], swept[1], steamroller.radius)

	hud.refresh(economy)
	_autosave += delta
	if _autosave >= AUTOSAVE_SECONDS:
		_autosave = 0.0
		save_game()


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
	return true


func mouse_ground() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if normal.y > -0.01:
		return focus
	var hit := origin + normal * (-origin.y / normal.y)
	return Vector2(hit.x, hit.z)


func _update_camera(delta: float) -> void:
	var move := Vector2(
		Input.get_axis(&"ui_left", &"ui_right") + float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		Input.get_axis(&"ui_up", &"ui_down") + float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	focus += move.limit_length(1.0) * PAN_SPEED * height * delta
	height = lerpf(height, target_height, 1.0 - exp(-12.0 * delta)) if delta > 0.0 else target_height
	camera.rotation = Vector3(-PITCH, 0.0, 0.0)
	camera.position = Vector3(focus.x, height, focus.y + height / tan(PITCH))
	camera.h_offset = randf_range(-1.0, 1.0) * fx.shake * 0.05 * height / START_HEIGHT
	camera.v_offset = randf_range(-1.0, 1.0) * fx.shake * 0.05 * height / START_HEIGHT


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


func reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	data.chunks.clear()
	economy = Economy.new()
	for steamroller in steamrollers:
		steamroller.queue_free()
	steamrollers.clear()
	focus = Vector2.ZERO
	target_height = START_HEIGHT
	view.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
