class_name GoldenBubble
extends Node3D
## A golden bubble that shows up now and then on the sheet. Popping it by hand pays out; Game decides how.

const MIN_DELAY := 50.0
const MAX_DELAY := 110.0
const LIFETIME := 12.0
## Blinks during its last seconds so the player knows it is leaving.
const BLINK_TIME := 2.5
## Nothing golden before the player has popped this much: the first minute is about learning to pop.
const FIRST_AFTER_POPS := 200

var cell := Vector2i.ZERO
var active := false
var _left := 0.0
var _wait := 0.0
var _age := 0.0
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = SheetData.BUBBLE_RADIUS * 1.15
	sphere.height = SheetData.BUBBLE_RADIUS * 1.3
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.78, 0.22)
	_material.metallic = 0.85
	_material.roughness = 0.18
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.65, 0.1)
	sphere.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false
	_wait = randf_range(MIN_DELAY, MAX_DELAY)


## Counts down to the next appearance; true once it is time to show one.
func wants_to_spawn(delta: float) -> bool:
	if active:
		return false
	_wait -= delta
	return _wait <= 0.0


func show_at(at: Vector2i) -> void:
	cell = at
	active = true
	_left = LIFETIME
	_age = 0.0
	var p := SheetData.cell_position(at)
	position = Vector3(p.x, 0.02, p.y)
	visible = true


func leave() -> void:
	active = false
	visible = false
	_wait = randf_range(MIN_DELAY, MAX_DELAY)


func _process(delta: float) -> void:
	if not active:
		return
	_age += delta
	_left -= delta
	if _left <= 0.0:
		leave()
		return
	var pulse := 1.0 + 0.1 * sin(_age * 7.0)
	var intro := minf(_age / 0.25, 1.0)
	_mesh.scale = Vector3.ONE * pulse * (1.0 + 0.6 * sin(intro * PI)) * intro
	_material.emission_energy_multiplier = 0.8 + 0.6 * sin(_age * 7.0)
	_mesh.visible = _left > BLINK_TIME or fmod(_left, 0.3) > 0.12
