class_name Combo
extends RefCounted
## Popping by hand heats a meter that multiplies every pop. A golden bubble frenzy multiplies on top.

## Meter thresholds of each level and their multipliers.
const LEVELS: Array[float] = [0.0, 0.25, 0.55, 0.9]
const MULTIPLIERS: Array[int] = [1, 2, 3, 5]
## About 4 clicks a second climb to the top in a few seconds; rolling gets there much faster.
const CLICK_FILL := 0.07
const DRAG_FILL_PER_SECOND := 0.6
const DRAIN_PER_SECOND := 0.15
## Stop popping this long and the meter drains fast.
const IDLE_AFTER := 1.0
const IDLE_DRAIN_PER_SECOND := 0.5
const FRENZY_MULTIPLIER := 5
const FRENZY_SECONDS := 12.0

var meter := 0.0
var frenzy_left := 0.0
var _idle := 0.0


func feed(amount: float) -> void:
	meter = minf(meter + amount, 1.0)
	_idle = 0.0


func update(delta: float) -> void:
	_idle += delta
	meter = maxf(meter - delta * (IDLE_DRAIN_PER_SECOND if _idle > IDLE_AFTER else DRAIN_PER_SECOND), 0.0)
	frenzy_left = maxf(frenzy_left - delta, 0.0)


func level() -> int:
	var out := 0
	for i in LEVELS.size():
		if meter >= LEVELS[i]:
			out = i
	return out


func multiplier() -> int:
	return MULTIPLIERS[level()] * (FRENZY_MULTIPLIER if frenzy_left > 0.0 else 1)


func start_frenzy() -> void:
	frenzy_left = FRENZY_SECONDS
