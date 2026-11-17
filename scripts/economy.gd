class_name Economy
extends RefCounted
## Pops earned and spent, and the upgrades they buy. Every popped bubble is worth one pop.

const WORLD_BUBBLES := 10_000_000_000_000

const THUMB := &"thumb"
const ROLLING_PIN := &"rolling_pin"
const STEAMROLLER := &"steamroller"
const STEAMROLLER_WIDTH := &"steamroller_width"

## Producers pop bubble wrap elsewhere on Earth: they add to the counter without touching the sheet.
## Each tier makes about 12x the previous one and takes 30% longer to pay back (see tools/balance.gd).
const PRODUCERS: Array[Dictionary] = [
	{"id": &"elephants", "cost": 12_000, "rate": 120},
	{"id": &"monster_trucks", "cost": 190_000, "rate": 1_500},
	{"id": &"anvil_airdrop", "cost": 2_900_000, "rate": 17_000},
	{"id": &"hydraulic_press", "cost": 45_000_000, "rate": 210_000},
	{"id": &"pop_day", "cost": 700_000_000, "rate": 2_500_000},
	{"id": &"tectonic_plates", "cost": 11_000_000_000, "rate": 30_000_000},
	{"id": &"moon", "cost": 170_000_000_000, "rate": 360_000_000},
]
const PRODUCER_COST_GROWTH := 1.15

const UPGRADES: Array[StringName] = [
	THUMB, ROLLING_PIN, STEAMROLLER, STEAMROLLER_WIDTH,
	&"elephants", &"monster_trucks", &"anvil_airdrop", &"hydraulic_press", &"pop_day", &"tectonic_plates", &"moon",
]

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
var producers: Dictionary[StringName, int] = {}
var _production_carry := 0.0


## Adds pops, never past the bubbles left on Earth. Returns how many counted.
func add_pops(count: int) -> int:
	count = mini(count, bubbles_left())
	wallet += count
	popped += count
	return count


## Producer output over delta seconds; fractions carry over to the next call.
func produce(delta: float, multiplier := 1) -> int:
	_production_carry += production_rate() * multiplier * delta
	var whole := floori(_production_carry)
	_production_carry -= whole
	return add_pops(whole)


func production_rate() -> float:
	var total := 0.0
	for producer in PRODUCERS:
		total += producers.get(producer["id"], 0) * producer["rate"]
	return total


func producer_count(id: StringName) -> int:
	return producers.get(id, 0)


static func producer(id: StringName) -> Dictionary:
	for p in PRODUCERS:
		if p["id"] == id:
			return p
	return {}


## Shop rows worth showing: maxed one-offs are hidden, and producers appear one tier at a time.
func is_listed(id: StringName) -> bool:
	if id == STEAMROLLER_WIDTH:
		return steamrollers > 0 and cost(id) >= 0
	if id == THUMB or id == ROLLING_PIN:
		return cost(id) >= 0
	var tier := PRODUCERS.find(producer(id))
	if tier < 0:
		return true
	if tier == 0:
		return steamrollers > 0
	return producer_count(PRODUCERS[tier - 1]["id"]) > 0


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
	var p := producer(id)
	if not p.is_empty():
		return roundi(p["cost"] * pow(PRODUCER_COST_GROWTH, producer_count(id)))
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
		_:
			producers[id] = producer_count(id) + 1
	return true


func to_dict() -> Dictionary:
	return {
		"wallet": wallet, "popped": popped, "thumb": thumb, "rolling_pin": rolling_pin,
		"steamrollers": steamrollers, "steamroller_width": steamroller_width, "producers": producers.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	wallet = d.get("wallet", 0)
	popped = d.get("popped", 0)
	thumb = d.get("thumb", 0)
	rolling_pin = d.get("rolling_pin", false)
	steamrollers = d.get("steamrollers", 0)
	steamroller_width = d.get("steamroller_width", 0)
	producers.assign(d.get("producers", {}))


static func format_count(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out
