class_name Globe
extends Node3D
## The Earth wrapped in bubble wrap, seen when the camera zooms out. Each producer unit is a spark on it.

## Far below the sheet, out of reach of both cameras' far planes.
const ORIGIN := Vector3(0, -100_000, 0)
const RADIUS := 100.0
const SPARKS_PER_UNIT := 25
const MAX_SPARKS := 6000
const SPIN_SPEED := 0.1
const FLOATS_PER_SPARK := 16

var camera: Camera3D
var _planet: MeshInstance3D
var _material: ShaderMaterial
var _sparks: MultiMesh
## Birth time of each spark, keyed by tier * MAX_SPARKS + index, so old sparks do not replay their intro.
var _born: Dictionary[int, float] = {}


func _ready() -> void:
	position = ORIGIN
	visible = false
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 128
	sphere.rings = 64
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/globe.gdshader")
	sphere.material = _material
	_planet = MeshInstance3D.new()
	_planet.mesh = sphere
	_planet.rotation.x = deg_to_rad(18.0)
	add_child(_planet)

	var spark := SphereMesh.new()
	spark.radius = 1.0
	spark.height = 2.0
	spark.radial_segments = 8
	spark.rings = 4
	var spark_material := ShaderMaterial.new()
	spark_material.shader = preload("res://shaders/globe_spark.gdshader")
	spark.material = spark_material
	_sparks = MultiMesh.new()
	_sparks.transform_format = MultiMesh.TRANSFORM_3D
	_sparks.use_custom_data = true
	_sparks.mesh = spark
	_sparks.instance_count = MAX_SPARKS
	_sparks.visible_instance_count = 0
	var sparks := MultiMeshInstance3D.new()
	sparks.multimesh = _sparks
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_planet.add_child(sparks)

	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.5
	camera.far = RADIUS * 20.0
	add_child(camera)
	look_from(RADIUS * 3.0)


func _process(delta: float) -> void:
	if visible:
		_planet.rotate_y(SPIN_SPEED * delta)


## Puts the camera at this distance from the center, looking at the globe.
func look_from(distance: float) -> void:
	camera.position = Vector3(0.0, 0.0, distance)
	camera.look_at(global_position)


func set_popped_fraction(fraction: float) -> void:
	_material.set_shader_parameter("popped", fraction)


## One spark per unit owned, at a fixed random spot per (tier, index). New ones are born at clock.
func set_producers(economy: Economy, clock: float) -> void:
	var buffer := PackedFloat32Array()
	var count := 0
	for tier in Economy.PRODUCERS.size():
		var wanted := economy.producer_count(Economy.PRODUCERS[tier]["id"]) * SPARKS_PER_UNIT
		for i in wanted:
			if count >= MAX_SPARKS:
				break
			var key := tier * MAX_SPARKS + i
			if not _born.has(key):
				_born[key] = clock
			var rng := RandomNumberGenerator.new()
			rng.seed = key
			var normal := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var size := RADIUS * 0.018 * (1.0 + tier * 0.25)
			var basis := Basis.IDENTITY.scaled(Vector3.ONE * size)
			var origin := normal * RADIUS * 1.003
			buffer.append_array([
				basis.x.x, basis.y.x, basis.z.x, origin.x,
				basis.x.y, basis.y.y, basis.z.y, origin.y,
				basis.x.z, basis.y.z, basis.z.z, origin.z,
				float(tier), rng.randf(), _born[key], 0.0,
			])
			count += 1
	buffer.resize(MAX_SPARKS * FLOATS_PER_SPARK)
	_sparks.buffer = buffer
	_sparks.visible_instance_count = count


func spark_count() -> int:
	return _sparks.visible_instance_count
