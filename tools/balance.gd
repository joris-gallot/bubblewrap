# Pacing check: a greedy player buys whatever pays back soonest, until Earth is out of bubble wrap.
#
#   godot --headless --path . res://tools/balance.tscn
#
# Prints when each upgrade is first bought and the total time. Hand pops are modelled, not played.
class_name Balance
extends Node

const CLICKS_PER_SECOND := 3.0
## Ground units per second swept while dragging the rolling pin.
const DRAG_SPEED := 8.0
const BUBBLES_PER_AREA := 1.0 / (SheetData.SPACING * SheetData.ROW_STEP)


func _ready() -> void:
	var result := simulate()
	for line: String in result["log"]:
		print(line)
	print("Earth emptied in %.2f h" % (result["seconds"] / 3600.0))
	get_tree().quit()


## Returns {"seconds": time to pop the whole world, "first": {id: seconds}, "log": [lines]}.
static func simulate() -> Dictionary:
	var economy := Economy.new()
	var seconds := 0.0
	var first: Dictionary[StringName, float] = {}
	var lines: Array[String] = []
	while economy.bubbles_left() > 0:
		var rate := model_rate(economy)
		var best_id := &""
		var best_score := INF
		for id in Economy.UPGRADES:
			var price := economy.cost(id)
			if price < 0:
				continue
			var gain := model_rate(_after_buying(economy, id)) - rate
			if gain <= 0.0:
				continue
			var score := maxf(price - economy.wallet, 0.0) / rate + price / gain
			if score < best_score:
				best_score = score
				best_id = id
		var wait := maxf(economy.cost(best_id) - economy.wallet, 0.0) / rate
		if best_id.is_empty() or wait * rate >= economy.bubbles_left():
			seconds += economy.bubbles_left() / rate
			break
		seconds += wait
		economy.add_pops(ceili(wait * rate))
		economy.buy(best_id)
		if not first.has(best_id):
			first[best_id] = seconds
			lines.append("%7.1f min  %-18s %s pops/s" % [seconds / 60.0, best_id, Economy.format_count(roundi(model_rate(economy)))])
	return {"seconds": seconds, "first": first, "log": lines}


## Expected pops per second: an active player, steamrollers on fresh wrap, and producers.
static func model_rate(economy: Economy) -> float:
	var radius := economy.thumb_radius()
	var click := CLICKS_PER_SECOND * maxf(1.0, PI * radius * radius * BUBBLES_PER_AREA)
	var drag := DRAG_SPEED * 2.0 * maxf(radius, Game.MIN_DRAG_RADIUS) * BUBBLES_PER_AREA if economy.rolling_pin else 0.0
	var rollers := economy.steamrollers * Steamroller.SPEED * 2.0 * economy.steamroller_radius() * BUBBLES_PER_AREA
	return maxf(click, drag) + rollers + economy.production_rate()


static func _after_buying(economy: Economy, id: StringName) -> Economy:
	var copy := Economy.new()
	copy.from_dict(economy.to_dict())
	copy.wallet = copy.cost(id)
	copy.buy(id)
	return copy
