class_name SheetView
extends Node3D
## Draws the chunks of the sheet the camera sees, one MultiMesh per chunk, recycled as the view moves.

const MAX_BUILDS_PER_FRAME := 10
const FLOATS_PER_INSTANCE := 16 # 12 transform + 4 custom data
const BUBBLE_MATERIAL := preload("res://shaders/bubble.gdshader")
const CHUNK_SIZE := Vector2(SheetData.CHUNK * SheetData.SPACING, SheetData.CHUNK * SheetData.ROW_STEP)

var data: SheetData
var _loaded: Dictionary[Vector2i, MultiMeshInstance3D] = {}
var _pool: Array[MultiMeshInstance3D] = []
var _template := PackedFloat32Array()
var _mesh: SphereMesh
var _material: ShaderMaterial
var _floor: MeshInstance3D


func _ready() -> void:
	_mesh = SphereMesh.new()
	_mesh.radius = SheetData.BUBBLE_RADIUS
	# Full sphere: the lower half sits under the opaque floor and is hidden by the depth test.
	_mesh.height = SheetData.BUBBLE_RADIUS * 1.1
	_mesh.radial_segments = 14
	_mesh.rings = 6
	_material = ShaderMaterial.new()
	_material.shader = BUBBLE_MATERIAL
	_mesh.material = _material

	var count := SheetData.CHUNK * SheetData.CHUNK
	_template.resize(count * FLOATS_PER_INSTANCE)
	for i in count:
		var row := i / SheetData.CHUNK
		var cell_position := SheetData.cell_position(Vector2i(i % SheetData.CHUNK, row))
		var o := i * FLOATS_PER_INSTANCE
		_template[o] = 1.0
		_template[o + 3] = cell_position.x
		_template[o + 5] = 1.0
		_template[o + 10] = 1.0
		_template[o + 11] = cell_position.y

	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var floor_material := StandardMaterial3D.new()
	# Cardboard under the sheet: transparent bubbles need a warm, darker backdrop to read.
	floor_material.albedo_color = Color(0.55, 0.38, 0.22)
	floor_material.roughness = 0.9
	plane.material = floor_material
	_floor.mesh = plane
	add_child(_floor)


func update_visible(camera: Camera3D) -> void:
	var view := ground_rect(camera).grow(2.0)
	_floor.position = Vector3(view.get_center().x, 0.0, view.get_center().y)
	_floor.scale = Vector3(view.size.x, 1.0, view.size.y)

	var first := Vector2i(floori(view.position.x / CHUNK_SIZE.x) - 1, floori(view.position.y / CHUNK_SIZE.y))
	var last := Vector2i(floori(view.end.x / CHUNK_SIZE.x), floori(view.end.y / CHUNK_SIZE.y))
	var wanted: Array[Vector2i] = []
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			wanted.append(Vector2i(x, y))

	for coord in _loaded.keys():
		if coord.x < first.x or coord.x > last.x or coord.y < first.y or coord.y > last.y:
			var instance: MultiMeshInstance3D = _loaded[coord]
			_loaded.erase(coord)
			instance.visible = false
			_pool.append(instance)

	var center := view.get_center()
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_center(a).distance_squared_to(center) < _chunk_center(b).distance_squared_to(center))
	var builds := 0
	for coord in wanted:
		if _loaded.has(coord):
			continue
		_build(coord)
		builds += 1
		if builds >= MAX_BUILDS_PER_FRAME:
			break


func mark_popped(cells: Array[Vector2i], clock: float) -> void:
	for cell in cells:
		var instance: MultiMeshInstance3D = _loaded.get(SheetData.chunk_of(cell))
		if instance:
			instance.multimesh.set_instance_custom_data(SheetData.index_in_chunk(cell), Color(1.0, clock, 0.0, 0.0))


func clear() -> void:
	for coord in _loaded.keys():
		_loaded[coord].visible = false
		_pool.append(_loaded[coord])
	_loaded.clear()


func is_loaded(coord: Vector2i) -> bool:
	return _loaded.has(coord)


## Ground area seen by the camera, from the rays through the viewport corners.
static func ground_rect(camera: Camera3D) -> Rect2:
	var size := camera.get_viewport().get_visible_rect().size
	var rect := Rect2()
	var first := true
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var origin := camera.project_ray_origin(corner)
		var normal := camera.project_ray_normal(corner)
		var distance := -origin.y / normal.y if normal.y < -0.05 else camera.far
		var hit := origin + normal * minf(distance, camera.far)
		var point := Vector2(hit.x, hit.z)
		if first:
			rect = Rect2(point, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(point)
	return rect


func _chunk_center(coord: Vector2i) -> Vector2:
	return (Vector2(coord) + Vector2(0.5, 0.5)) * CHUNK_SIZE


func _build(coord: Vector2i) -> void:
	var instance: MultiMeshInstance3D
	if _pool.is_empty():
		instance = MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = _mesh
		multimesh.instance_count = SheetData.CHUNK * SheetData.CHUNK
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	else:
		instance = _pool.pop_back()
		instance.visible = true

	var buffer := _template
	var bytes: PackedByteArray = data.chunks.get(coord, PackedByteArray())
	if not bytes.is_empty():
		buffer = _template.duplicate()
		for i in bytes.size():
			if bytes[i] != 0:
				# Popped long ago: already flat.
				buffer[i * FLOATS_PER_INSTANCE + 12] = 1.0
				buffer[i * FLOATS_PER_INSTANCE + 13] = -1000.0
	instance.multimesh.buffer = buffer
	instance.position = Vector3(coord.x * CHUNK_SIZE.x, 0.0, coord.y * CHUNK_SIZE.y)
	_loaded[coord] = instance
