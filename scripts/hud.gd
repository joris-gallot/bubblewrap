class_name Hud
extends CanvasLayer
## World counter at the top, shop on the right, controls reminder at the bottom.

signal buy_requested(id: StringName)

const NAMES := {
	Economy.THUMB: "Bigger thumb",
	Economy.ROLLING_PIN: "Rolling pin",
	Economy.STEAMROLLER: "Steamroller",
	Economy.STEAMROLLER_WIDTH: "Wider drums",
	&"elephants": "Elephant herd",
	&"monster_trucks": "Monster truck rally",
	&"anvil_airdrop": "Anvil airdrop",
	&"hydraulic_press": "Hydraulic megapress",
	&"pop_day": "National Pop Day",
	&"tectonic_plates": "Tectonic plates",
	&"moon": "Pull the Moon closer",
}
const DESCRIPTIONS := {
	Economy.THUMB: "Pop more bubbles per click",
	Economy.ROLLING_PIN: "Hold and drag to pop",
	Economy.STEAMROLLER: "Pops on its own, forever",
	Economy.STEAMROLLER_WIDTH: "Every steamroller pops wider",
	&"elephants": "They stomp bubble wrap in the savanna",
	&"monster_trucks": "Sold out stadiums, every night",
	&"anvil_airdrop": "Cargo planes, cartoon physics",
	&"hydraulic_press": "A factory that only squeezes",
	&"pop_day": "A whole country stops working",
	&"tectonic_plates": "Continents squeeze it flat",
	&"moon": "The tides do the rest",
}
## Seconds of history behind the pops per second display.
const RATE_WINDOW := 1.0

var _popped_label: Label
var _left_label: Label
var _wallet_label: Label
var _rate_label: Label
var _hint_label: Label
var _buttons: Dictionary[StringName, Button] = {}
var _punch: Tween
var _shown_popped := -1
var _rate_popped := -1
var _rate := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var counter := VBoxContainer.new()
	counter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	counter.offset_top = 18
	counter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_theme_constant_override("separation", -4)
	root.add_child(counter)
	_popped_label = _label(64, counter)
	_label(20, counter).text = "BUBBLES POPPED"
	_left_label = _label(18, counter)
	_left_label.modulate = Color(1, 1, 1, 0.75)

	var shop := VBoxContainer.new()
	shop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shop.offset_left = -380
	shop.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	shop.offset_right = -20
	shop.offset_top = 20
	shop.add_theme_constant_override("separation", 6)
	shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shop)
	_wallet_label = _label(26, shop)
	_rate_label = _label(17, shop)
	_rate_label.modulate = Color(1, 1, 1, 0.8)
	for id in Economy.UPGRADES:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(360, 58)
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(func() -> void: buy_requested.emit(id))
		shop.add_child(button)
		_buttons[id] = button

	_hint_label = _label(16, root)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.offset_left = 20
	_hint_label.offset_top = -40
	_hint_label.modulate = Color(1, 1, 1, 0.8)


func refresh(economy: Economy, delta: float) -> void:
	if _rate_popped >= 0 and delta > 0.0:
		_rate = lerpf(_rate, (economy.popped - _rate_popped) / delta, 1.0 - exp(-delta / RATE_WINDOW))
	_rate_popped = economy.popped
	_rate_label.text = "%s pops per second" % Economy.format_count(roundi(_rate))
	if economy.popped != _shown_popped:
		if _shown_popped >= 0 and economy.popped > _shown_popped:
			_punch_counter()
		_shown_popped = economy.popped
		_popped_label.text = Economy.format_count(economy.popped)
		var left := economy.bubbles_left()
		_left_label.text = "%s left on Earth" % Economy.format_count(left) if left > 0 else "No bubble wrap left on Earth"
	_wallet_label.text = "%s pops to spend" % Economy.format_count(economy.wallet)
	for id in Economy.UPGRADES:
		var button := _buttons[id]
		var price := economy.cost(id)
		var level := _level_text(economy, id)
		button.visible = economy.is_listed(id)
		if price < 0:
			button.text = "%s%s\nDone" % [NAMES[id], level]
			button.disabled = true
		else:
			var description: String = DESCRIPTIONS[id]
			var p := Economy.producer(id)
			if not p.is_empty():
				description += " (+%s/s)" % Economy.format_count(p["rate"])
			button.text = "%s%s - %s pops\n%s" % [NAMES[id], level, Economy.format_count(price), description]
			button.disabled = economy.wallet < price
	_hint_label.text = "%s  |  Right-drag or WASD: move  |  Wheel: zoom%s" % [
		"Hold and drag: pop" if economy.rolling_pin else "Click: pop",
		"  |  TIME x%d (F10)" % Engine.time_scale if Engine.time_scale != 1.0 else ""]


func _level_text(economy: Economy, id: StringName) -> String:
	match id:
		Economy.THUMB:
			return " %d/%d" % [economy.thumb, Economy.THUMB_COSTS.size()]
		Economy.STEAMROLLER:
			return " x%d" % economy.steamrollers if economy.steamrollers > 0 else ""
		Economy.STEAMROLLER_WIDTH:
			return " %d/%d" % [economy.steamroller_width, Economy.STEAMROLLER_WIDTH_COSTS.size()]
	var count := economy.producer_count(id)
	return " x%d" % count if count > 0 else ""


func _punch_counter() -> void:
	if _punch and _punch.is_running():
		return
	_popped_label.pivot_offset = _popped_label.size / 2.0
	_popped_label.scale = Vector2.ONE * 1.12
	_punch = create_tween()
	_punch.tween_property(_popped_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _label(font_size: int, parent: Control) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.2))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
