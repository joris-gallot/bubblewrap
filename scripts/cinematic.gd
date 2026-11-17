class_name Cinematic
extends RefCounted
## Zoom out from the sheet to the globe and back, when a new producer tier joins in. Game calls update() every frame.

const CLIMB := 1.4
const PULL := 1.6
const HOLD := 1.8
const DIVE := 0.9
const DESCEND := 1.2
const FLASH := 0.15
const SHEET_TOP := 260.0
const TOP_PITCH := PI / 2.0
const GLOBE_NEAR := Globe.RADIUS * 1.06
const GLOBE_FAR := Globe.RADIUS * 3.3
## New sparks appear this long after the globe does, so their intro is seen.
const SPARK_DELAY := 0.5

const GLOBE_START := CLIMB
const DESCEND_START := CLIMB + PULL + HOLD + DIVE
const TOTAL := DESCEND_START + DESCEND

var active := false
var time := 0.0
var caption := ""
var _game: Game
var _from_height := 0.0
var _in_globe := false


func _init(game: Game) -> void:
	_game = game


func play(text: String) -> void:
	active = true
	time = 0.0
	caption = text
	_from_height = _game.height
	_in_globe = false
	_game.fx.play_whoosh(true)


## A click ends the climb at once, or cuts from orbit to the descent.
func skip() -> void:
	if not active:
		return
	if time < GLOBE_START:
		time = TOTAL
	elif time < DESCEND_START:
		time = DESCEND_START


func in_globe() -> bool:
	return active and time >= GLOBE_START and time < DESCEND_START


## White flash over the cuts between the sheet and the globe, 0..1.
func flash() -> float:
	if not active:
		return 0.0
	return maxf(_pulse(GLOBE_START), _pulse(DESCEND_START))


func update(delta: float) -> void:
	if not active:
		return
	time += delta
	if time >= TOTAL:
		active = false
		_game.height = _from_height
		_game.pitch = Game.PITCH
		_set_globe(false)
		return
	if time < GLOBE_START:
		var k := smoothstep(0.0, 1.0, time / CLIMB)
		_game.height = _from_height * pow(SHEET_TOP / _from_height, k)
		_game.pitch = lerpf(Game.PITCH, TOP_PITCH, k)
	elif time < DESCEND_START:
		_game.height = SHEET_TOP
		_game.pitch = TOP_PITCH
		var t := time - GLOBE_START
		var distance := GLOBE_FAR
		if t < PULL:
			distance = lerpf(GLOBE_NEAR, GLOBE_FAR, 1.0 - pow(1.0 - t / PULL, 3.0))
		elif t > PULL + HOLD:
			distance = lerpf(GLOBE_FAR, GLOBE_NEAR, pow((t - PULL - HOLD) / DIVE, 3.0))
		_game.globe.look_from(distance)
		_game.globe.set_popped_fraction(float(_game.economy.popped) / Economy.WORLD_BUBBLES)
		if not _in_globe:
			_set_globe(true)
			_game.globe.set_producers(_game.economy, _game.clock + SPARK_DELAY)
			_game.hud.show_caption(caption, PULL + HOLD)
	else:
		if _in_globe:
			_set_globe(false)
			_game.fx.play_whoosh(false)
		var k := 1.0 - pow(1.0 - (time - DESCEND_START) / DESCEND, 3.0)
		_game.height = SHEET_TOP * pow(_from_height / SHEET_TOP, k)
		_game.pitch = lerpf(TOP_PITCH, Game.PITCH, k)


func _set_globe(on: bool) -> void:
	_in_globe = on
	_game.globe.visible = on
	_game.set_space(on)
	if not on:
		_game.hud.show_caption("", 0.0)
	if on:
		_game.globe.camera.make_current()
	else:
		_game.camera.make_current()


func _pulse(at: float) -> float:
	return clampf(1.0 - absf(time - at) / FLASH, 0.0, 1.0)
