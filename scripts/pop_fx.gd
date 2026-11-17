class_name PopFx
extends Node3D
## Feedback for pops: plastic flecks, pop sounds, camera shake. Only for pops the camera can see.

const MAX_FLECKS := 900
const FLECKS_PER_POP := 3
const MAX_FX_POPS_PER_BURST := 60
const FLECK_LIFE := 0.4
const GRAVITY := 14.0
const SOUND_COUNT := 8
const VOICES := 20
## Sounds per second at most, so a rolling pin crackles instead of turning into noise.
const SOUND_RATE := 40.0
const MAX_SOUNDS_PER_BURST := 3
## The crackle loop fades in above this many visible pops per second and is full at CRACKLE_FULL_RATE.
const CRACKLE_MIN_RATE := 6.0
const CRACKLE_FULL_RATE := 80.0
const CRACKLE_MAX_DB := -7.0

var muted := false
var shake := 0.0
## Pops sound a little higher at each combo level.
var combo_level := 0

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _spins := PackedVector3Array()
var _ages := PackedFloat32Array()
var _multimesh: MultiMesh
var _streams: Array[AudioStream] = []
var _buy_stream: AudioStream
var _whoosh_up: AudioStream
var _whoosh_down: AudioStream
var _combo_stream: AudioStream
var _golden_stream: AudioStream
var _gold_material: StandardMaterial3D
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _sound_budget := 0.0
var _crackle: AudioStreamPlayer
var _crackle_level := 0.0
var _pending_pops := 0
## Visible pops per second, smoothed.
var pop_rate := 0.0


func _ready() -> void:
	var fleck := BoxMesh.new()
	fleck.size = Vector3(0.09, 0.015, 0.07)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.97, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.2
	fleck.material = material
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = fleck
	_multimesh.instance_count = MAX_FLECKS
	_multimesh.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Flecks follow the camera around, never cull them on a stale AABB.
	instance.extra_cull_margin = 16384.0
	add_child(instance)

	for i in SOUND_COUNT:
		_streams.append(load("res://assets/sounds/pop_%d.wav" % i))
	_buy_stream = load("res://assets/sounds/buy.wav")
	_whoosh_up = load("res://assets/sounds/whoosh_up.wav")
	_whoosh_down = load("res://assets/sounds/whoosh_down.wav")
	_combo_stream = load("res://assets/sounds/combo.wav")
	_golden_stream = load("res://assets/sounds/golden.wav")
	_gold_material = StandardMaterial3D.new()
	_gold_material.albedo_color = Color(1.0, 0.8, 0.25)
	_gold_material.metallic = 0.8
	_gold_material.roughness = 0.25
	_gold_material.emission_enabled = true
	_gold_material.emission = Color(1.0, 0.6, 0.1)
	_gold_material.emission_energy_multiplier = 1.5
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_crackle = AudioStreamPlayer.new()
	_crackle.stream = load("res://assets/sounds/crackle.wav")
	add_child(_crackle)


func burst(cells: Array[Vector2i], camera: Camera3D) -> void:
	var seen := 0
	for cell in cells:
		if seen >= MAX_FX_POPS_PER_BURST:
			break
		var p := SheetData.cell_position(cell)
		var world := Vector3(p.x, 0.1, p.y)
		if not camera.is_position_in_frustum(world):
			continue
		seen += 1
		for j in FLECKS_PER_POP:
			_spawn_fleck(world)
	if seen == 0:
		return
	_pending_pops += seen
	shake = minf(shake + 0.02 * seen, 0.35)
	var sounds := mini(mini(seen, MAX_SOUNDS_PER_BURST), floori(_sound_budget))
	for i in sounds:
		_sound_budget -= 1.0
		# Bigger bursts sound a bit lower and louder, like a fistful of bubbles.
		var pitch := randf_range(0.85, 1.25) - minf(seen, 30) * 0.006 + combo_level * 0.06
		_play(_streams.pick_random(), pitch, -6.0 + minf(seen, 20) * 0.2)


func play_buy() -> void:
	_play(_buy_stream, 1.0, -4.0)


func play_combo(level: int) -> void:
	_play(_combo_stream, 1.0 + 0.2 * level, -5.0)


## Gold confetti, a chime and a kick of shake when a golden bubble is claimed.
func golden_burst(at: Vector3) -> void:
	_play(_golden_stream, 1.0, -3.0)
	shake = minf(shake + 0.3, 0.6)
	var particles := CPUParticles3D.new()
	var fleck := BoxMesh.new()
	fleck.size = Vector3(0.1, 0.02, 0.1)
	fleck.material = _gold_material
	particles.mesh = fleck
	particles.one_shot = true
	particles.amount = 90
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 65.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 7.5
	particles.gravity = Vector3(0, -12, 0)
	particles.angular_velocity_min = -720.0
	particles.angular_velocity_max = 720.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.position = at
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func play_whoosh(up: bool) -> void:
	_play(_whoosh_up if up else _whoosh_down, 1.0, -6.0)


func _process(delta: float) -> void:
	_sound_budget = minf(_sound_budget + SOUND_RATE * delta, MAX_SOUNDS_PER_BURST * 2.0)
	shake = move_toward(shake, 0.0, delta * 1.5)
	_update_crackle(delta)
	var i := 0
	while i < _ages.size():
		_ages[i] += delta
		if _ages[i] >= FLECK_LIFE or _positions[i].y < 0.0:
			_remove_fleck(i)
			continue
		_velocities[i].y -= GRAVITY * delta
		_positions[i] += _velocities[i] * delta
		i += 1
	var buffer := PackedFloat32Array()
	buffer.resize(MAX_FLECKS * 12)
	for f in _ages.size():
		var basis := Basis.from_euler(_spins[f] * _ages[f]).scaled(Vector3.ONE * (1.0 - _ages[f] / FLECK_LIFE * 0.6))
		var o := f * 12
		buffer[o] = basis.x.x
		buffer[o + 1] = basis.y.x
		buffer[o + 2] = basis.z.x
		buffer[o + 3] = _positions[f].x
		buffer[o + 4] = basis.x.y
		buffer[o + 5] = basis.y.y
		buffer[o + 6] = basis.z.y
		buffer[o + 7] = _positions[f].y
		buffer[o + 8] = basis.x.z
		buffer[o + 9] = basis.y.z
		buffer[o + 10] = basis.z.z
		buffer[o + 11] = _positions[f].z
	_multimesh.buffer = buffer
	_multimesh.visible_instance_count = _ages.size()


func _update_crackle(delta: float) -> void:
	if delta <= 0.0:
		return
	pop_rate = lerpf(pop_rate, _pending_pops / delta, 1.0 - exp(-6.0 * delta))
	_pending_pops = 0
	var target := clampf((pop_rate - CRACKLE_MIN_RATE) / (CRACKLE_FULL_RATE - CRACKLE_MIN_RATE), 0.0, 1.0)
	# Quick to rise so a drag crackles at once, slower to fade so it does not stutter.
	_crackle_level = move_toward(_crackle_level, target, delta * (8.0 if target > _crackle_level else 3.0))
	if muted or _crackle_level <= 0.01:
		if _crackle.playing:
			_crackle.stop()
		return
	if not _crackle.playing:
		_crackle.play(randf() * _crackle.stream.get_length())
	_crackle.volume_db = CRACKLE_MAX_DB + linear_to_db(_crackle_level)
	_crackle.pitch_scale = 0.95 + 0.2 * _crackle_level


func _spawn_fleck(at: Vector3) -> void:
	if _ages.size() >= MAX_FLECKS:
		return
	var angle := randf() * TAU
	var outward := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.6, 1.8)
	_positions.append(at)
	_velocities.append(outward + Vector3.UP * randf_range(2.5, 4.5))
	_spins.append(Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20)))
	_ages.append(0.0)


func _remove_fleck(i: int) -> void:
	var last := _ages.size() - 1
	_positions[i] = _positions[last]
	_velocities[i] = _velocities[last]
	_spins[i] = _spins[last]
	_ages[i] = _ages[last]
	_positions.resize(last)
	_velocities.resize(last)
	_spins.resize(last)
	_ages.resize(last)


func _play(stream: AudioStream, pitch: float, volume_db: float) -> void:
	if muted:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = volume_db
	voice.play()
