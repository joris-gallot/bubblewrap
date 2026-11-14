class_name Hud
extends CanvasLayer
## World counter at the top, shop on the right, controls reminder at the bottom.

signal buy_requested(id: StringName)

const NAMES := {
	Economy.THUMB: "Bigger thumb",
	Economy.ROLLING_PIN: "Rolling pin",
	Economy.STEAMROLLER: "Steamroller",
	Economy.STEAMROLLER_WIDTH: "Wider drums",
}
const DESCRIPTIONS := {
	Economy.THUMB: "Pop more bubbles per click",
	Economy.ROLLING_PIN: "Hold and drag to pop",
	Economy.STEAMROLLER: "Pops on its own, forever",
	Economy.STEAMROLLER_WIDTH: "Every steamroller pops wider",
}

var _popped_label: Label
var _left_label: Label
var _wallet_label: Label
var _hint_label: Label
var _buttons: Dictionary[StringName, Button] = {}
var _punch: Tween
var _shown_popped := -1


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
	shop.offset_left = -300
	shop.offset_right = -20
	shop.offset_top = 20
	shop.add_theme_constant_override("separation", 8)
	shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shop)
	_wallet_label = _label(26, shop)
	for id in Economy.UPGRADES:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(280, 74)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func() -> void: buy_requested.emit(id))
		shop.add_child(button)
		_buttons[id] = button

	_hint_label = _label(16, root)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.offset_left = 20
	_hint_label.offset_top = -40
	_hint_label.modulate = Color(1, 1, 1, 0.8)


func refresh(economy: Economy) -> void:
	if economy.popped != _shown_popped:
		if _shown_popped >= 0 and economy.popped > _shown_popped:
			_punch_counter()
		_shown_popped = economy.popped
		_popped_label.text = Economy.format_count(economy.popped)
		_left_label.text = "%s left on Earth" % Economy.format_count(economy.bubbles_left())
	_wallet_label.text = "%s pops to spend" % Economy.format_count(economy.wallet)
	for id in Economy.UPGRADES:
		var button := _buttons[id]
		var price := economy.cost(id)
		var level := _level_text(economy, id)
		button.visible = id != Economy.STEAMROLLER_WIDTH or economy.steamrollers > 0
		if price < 0:
			button.text = "%s%s\nDone" % [NAMES[id], level]
			button.disabled = true
		else:
			button.text = "%s%s - %s pops\n%s" % [NAMES[id], level, Economy.format_count(price), DESCRIPTIONS[id]]
			button.disabled = economy.wallet < price
	_hint_label.text = "%s  |  Right-drag or WASD: move  |  Wheel: zoom" % (
		"Hold and drag: pop" if economy.rolling_pin else "Click: pop")


func _level_text(economy: Economy, id: StringName) -> String:
	match id:
		Economy.THUMB:
			return " %d/%d" % [economy.thumb, Economy.THUMB_COSTS.size()]
		Economy.STEAMROLLER:
			return " x%d" % economy.steamrollers if economy.steamrollers > 0 else ""
		Economy.STEAMROLLER_WIDTH:
			return " %d/%d" % [economy.steamroller_width, Economy.STEAMROLLER_WIDTH_COSTS.size()]
	return ""


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
