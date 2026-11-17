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
## Combo text color per level: cool when idle, hotter as it climbs.
const COMBO_COLORS: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.92, 0.45), Color(1.0, 0.62, 0.2), Color(1.0, 0.3, 0.2)]
const FRENZY_COLOR := Color(1.0, 0.82, 0.25)
## Seconds of history behind the pops per second display.
const RATE_WINDOW := 1.0

var _popped_label: Label
var _left_label: Label
var _wallet_label: Label
var _rate_label: Label
var _hint_label: Label
var _caption_label: Label
var _caption_tween: Tween
var _flash: ColorRect
var _combo_box: Control
var _combo_label: Label
var _combo_bar: ProgressBar
var _combo_fill: StyleBoxFlat
var _combo_punch: Tween
var _shown_multiplier := 1
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

	# Kept in the layout at zero alpha, so the counter does not jump when a combo starts.
	_combo_box = VBoxContainer.new()
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.modulate.a = 0.0
	counter.add_child(_combo_box)
	_combo_label = _label(38, _combo_box)
	var bar_holder := CenterContainer.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.add_child(bar_holder)
	_combo_bar = ProgressBar.new()
	_combo_bar.custom_minimum_size = Vector2(200, 8)
	_combo_bar.show_percentage = false
	_combo_bar.max_value = 1.0
	_combo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.08, 0.12, 0.2, 0.6)
	bar_background.set_corner_radius_all(4)
	_combo_fill = StyleBoxFlat.new()
	_combo_fill.set_corner_radius_all(4)
	_combo_bar.add_theme_stylebox_override("background", bar_background)
	_combo_bar.add_theme_stylebox_override("fill", _combo_fill)
	bar_holder.add_child(_combo_bar)

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

	_caption_label = _label(44, root)
	_caption_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption_label.offset_top = -150
	_caption_label.offset_bottom = -90
	_caption_label.modulate.a = 0.0

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)


## Big line under the globe; an empty text hides it at once.
func show_caption(text: String, duration: float) -> void:
	if _caption_tween:
		_caption_tween.kill()
	_caption_label.text = text
	if text.is_empty():
		_caption_label.modulate.a = 0.0
		return
	_caption_label.modulate.a = 0.0
	_caption_label.pivot_offset = _caption_label.size / 2.0
	_caption_label.scale = Vector2.ONE * 0.7
	_caption_tween = create_tween().set_parallel()
	_caption_tween.tween_property(_caption_label, "modulate:a", 1.0, 0.25)
	_caption_tween.tween_property(_caption_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_caption_tween.chain().tween_property(_caption_label, "modulate:a", 0.0, 0.3).set_delay(maxf(duration - 0.55, 0.0))


func set_flash(alpha: float) -> void:
	_flash.color.a = alpha


func refresh(economy: Economy, delta: float, combo: Combo = null) -> void:
	if combo:
		_refresh_combo(combo)
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


func _refresh_combo(combo: Combo) -> void:
	var multiplier := combo.multiplier()
	var frenzy := combo.frenzy_left > 0.0
	var color := FRENZY_COLOR if frenzy else COMBO_COLORS[combo.level()]
	_combo_label.text = "x%d FRENZY %ds" % [multiplier, ceili(combo.frenzy_left)] if frenzy else "x%d COMBO" % multiplier
	_combo_label.add_theme_color_override("font_color", color)
	_combo_bar.value = combo.meter
	_combo_fill.bg_color = color
	var target := 1.0 if frenzy or combo.meter > 0.02 else 0.0
	_combo_box.modulate.a = move_toward(_combo_box.modulate.a, target, 0.08)
	if multiplier > _shown_multiplier:
		if _combo_punch:
			_combo_punch.kill()
		_combo_label.pivot_offset = _combo_label.size / 2.0
		_combo_label.scale = Vector2.ONE * 1.35
		_combo_punch = create_tween()
		_combo_punch.tween_property(_combo_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shown_multiplier = multiplier


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
