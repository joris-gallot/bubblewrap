class_name Economy
extends RefCounted
## Pops earned and spent, and the upgrades they buy. Every popped bubble is worth one pop.

const WORLD_BUBBLES := 10_000_000_000_000

const THUMB := &"thumb"
const ROLLING_PIN := &"rolling_pin"
const STEAMROLLER := &"steamroller"
const STEAMROLLER_WIDTH := &"steamroller_width"
const UPGRADES: Array[StringName] = [THUMB, ROLLING_PIN, STEAMROLLER, STEAMROLLER_WIDTH]

## Pop radius per thumb level; 0 pops only the bubble under the cursor.
const THUMB_RADII: Array[float] = [0.0, 0.9, 1.4, 2.0, 2.8, 3.8, 5.0]
const THUMB_COSTS: Array[int] = [40, 150, 600, 2500, 9000, 30000]
const ROLLING_PIN_COST := 250
const STEAMROLLER_BASE_COST := 500
const STEAMROLLER_COST_GROWTH := 1.5
const STEAMROLLER_RADII: Array[float] = [1.5, 2.2, 3.0, 4.0, 5.5]
const STEAMROLLER_WIDTH_COSTS: Array[int] = [2000, 8000, 30000, 100000]

var wallet := 0
var popped := 0
var thumb := 0
var rolling_pin := false
var steamrollers := 0
var steamroller_width := 0


func add_pops(count: int) -> void:
	wallet += count
	popped += count


func thumb_radius() -> float:
	return THUMB_RADII[thumb]


func steamroller_radius() -> float:
	return STEAMROLLER_RADII[steamroller_width]


func bubbles_left() -> int:
	return WORLD_BUBBLES - popped


## Price of the next level, or -1 once maxed out.
func cost(id: StringName) -> int:
	match id:
		THUMB:
			return THUMB_COSTS[thumb] if thumb < THUMB_COSTS.size() else -1
		ROLLING_PIN:
			return -1 if rolling_pin else ROLLING_PIN_COST
		STEAMROLLER:
			return roundi(STEAMROLLER_BASE_COST * pow(STEAMROLLER_COST_GROWTH, steamrollers))
		STEAMROLLER_WIDTH:
			if steamrollers == 0 or steamroller_width >= STEAMROLLER_WIDTH_COSTS.size():
				return -1
			return STEAMROLLER_WIDTH_COSTS[steamroller_width]
	return -1


func can_buy(id: StringName) -> bool:
	var price := cost(id)
	return price >= 0 and wallet >= price


func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	wallet -= cost(id)
	match id:
		THUMB:
			thumb += 1
		ROLLING_PIN:
			rolling_pin = true
		STEAMROLLER:
			steamrollers += 1
		STEAMROLLER_WIDTH:
			steamroller_width += 1
	return true


func to_dict() -> Dictionary:
	return {
		"wallet": wallet, "popped": popped, "thumb": thumb, "rolling_pin": rolling_pin,
		"steamrollers": steamrollers, "steamroller_width": steamroller_width,
	}


func from_dict(d: Dictionary) -> void:
	wallet = d.get("wallet", 0)
	popped = d.get("popped", 0)
	thumb = d.get("thumb", 0)
	rolling_pin = d.get("rolling_pin", false)
	steamrollers = d.get("steamrollers", 0)
	steamroller_width = d.get("steamroller_width", 0)


static func format_count(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out
