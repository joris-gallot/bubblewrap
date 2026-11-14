class_name Steamroller
extends Node3D
## Drives straight ahead forever, flattening a stripe as wide as its drum.

const SPEED := 3.0
const DRUM_OFFSET := 1.6
const DRUM_RADIUS := 0.55

var heading := Vector2(0, -1)
var radius := 1.5
var _drum: MeshInstance3D


func setup(start: Vector2, direction: Vector2, drum_half_width: float) -> void:
	position = Vector3(start.x, 0.0, start.y)
	heading = direction.normalized()
	basis = Basis.looking_at(Vector3(heading.x, 0.0, heading.y))
	set_radius(drum_half_width)


func _ready() -> void:
	var yellow := _material(Color(1.0, 0.74, 0.1))
	var dark := _material(Color(0.2, 0.21, 0.23))
	_add_box(Vector3(1.7, 0.9, 2.2), Vector3(0, 0.75, 0.5), yellow)
	_add_box(Vector3(1.3, 0.9, 1.1), Vector3(0, 1.65, 0.9), yellow)
	_add_box(Vector3(1.4, 0.12, 1.3), Vector3(0, 2.15, 0.9), dark)
	for side in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 0.35
		cylinder.material = dark
		wheel.mesh = cylinder
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(side * 0.95, 0.5, 1.1)
		add_child(wheel)
	_drum = MeshInstance3D.new()
	_drum.rotation.z = PI / 2.0
	_drum.position = Vector3(0, DRUM_RADIUS, -DRUM_OFFSET)
	add_child(_drum)
	set_radius(radius)


func set_radius(value: float) -> void:
	radius = value
	if _drum == null:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = DRUM_RADIUS
	cylinder.bottom_radius = DRUM_RADIUS
	cylinder.height = radius * 2.0
	cylinder.material = _material(Color(0.55, 0.57, 0.6))
	_drum.mesh = cylinder


func drum_point() -> Vector2:
	return Vector2(position.x, position.z) + heading * DRUM_OFFSET


## Moves forward and returns the segment the drum swept: [from, to].
func advance(delta: float) -> PackedVector2Array:
	var from := drum_point()
	position += Vector3(heading.x, 0.0, heading.y) * SPEED * delta
	if _drum:
		_drum.rotate_object_local(Vector3.UP, -SPEED * delta / DRUM_RADIUS)
	return PackedVector2Array([from, drum_point()])


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material


func _add_box(size: Vector3, at: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	box.mesh = mesh
	box.position = at
	add_child(box)
