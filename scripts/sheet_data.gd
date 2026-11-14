class_name SheetData
extends RefCounted
## The endless bubble sheet: hex-packed rows (odd rows shifted half a bubble), split in square
## chunks of CHUNK x CHUNK bubbles. A chunk only exists once one of its bubbles is popped.

const CHUNK := 32
const SPACING := 1.0
const ROW_STEP := SPACING * 0.8660254
const BUBBLE_RADIUS := 0.42

## One byte per bubble, index row * CHUNK + column; 1 = popped.
var chunks: Dictionary[Vector2i, PackedByteArray] = {}


static func cell_position(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5 * (cell.y & 1)) * SPACING, cell.y * ROW_STEP)


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(CHUNK)), floori(cell.y / float(CHUNK)))


static func index_in_chunk(cell: Vector2i) -> int:
	return posmod(cell.y, CHUNK) * CHUNK + posmod(cell.x, CHUNK)


static func nearest_cell(point: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := INF
	var row := roundi(point.y / ROW_STEP)
	for r in range(row - 1, row + 2):
		var cell := Vector2i(roundi(point.x / SPACING - 0.5 * (r & 1)), r)
		var distance := cell_position(cell).distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


func is_popped(cell: Vector2i) -> bool:
	var bytes: PackedByteArray = chunks.get(chunk_of(cell), PackedByteArray())
	return not bytes.is_empty() and bytes[index_in_chunk(cell)] != 0


func popped_count() -> int:
	var total := 0
	for bytes in chunks.values():
		total += bytes.count(1)
	return total


func pop_nearest(point: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	_pop(nearest_cell(point), out)
	return out


## Pops every bubble whose center lies within radius of the segment a-b. Returns the newly popped cells.
func pop_capsule(a: Vector2, b: Vector2, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var radius_squared := radius * radius
	var low := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(radius, radius)
	var high := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(radius, radius)
	for r in range(ceili(low.y / ROW_STEP), floori(high.y / ROW_STEP) + 1):
		var shift := 0.5 * (r & 1)
		for c in range(ceili(low.x / SPACING - shift), floori(high.x / SPACING - shift) + 1):
			var cell := Vector2i(c, r)
			var center := cell_position(cell)
			if Geometry2D.get_closest_point_to_segment(center, a, b).distance_squared_to(center) <= radius_squared:
				_pop(cell, out)
	return out


func _pop(cell: Vector2i, out: Array[Vector2i]) -> void:
	var coord := chunk_of(cell)
	var bytes: PackedByteArray = chunks.get(coord, PackedByteArray())
	if bytes.is_empty():
		bytes.resize(CHUNK * CHUNK)
	var index := index_in_chunk(cell)
	if bytes[index] != 0:
		return
	bytes[index] = 1
	chunks[coord] = bytes
	out.append(cell)
