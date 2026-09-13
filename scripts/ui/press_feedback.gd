class_name PressFeedback
extends RefCounted

## Press-in for TextureButtons so they feel mechanical: shrink, dim, drop.

const PRESS_SCALE := 0.93
const PRESS_MODULATE := Color(0.82, 0.82, 0.82, 1.0)
const PRESS_Y := 8.0
const DOWN_SEC := 0.07
const UP_SEC := 0.14


static func bind(button: BaseButton, visual: Control = null) -> void:
	var target: Control = visual if visual != null else button
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_update_pivot(target)
	if not target.resized.is_connected(_update_pivot):
		target.resized.connect(_update_pivot.bind(target))

	button.button_down.connect(func () -> void:
		if button.disabled:
			return
		target.set_meta("press_rest_mod", target.modulate)
		target.set_meta("press_rest_top", target.offset_top)
		target.set_meta("press_rest_bottom", target.offset_bottom)
		_animate(target, true)
	)
	button.button_up.connect(func () -> void:
		_animate(target, false)
	)


static func _update_pivot(target: Control) -> void:
	target.pivot_offset = target.size * 0.5


static func _animate(target: Control, pressed: bool) -> void:
	if target.has_meta("press_tw"):
		var old: Tween = target.get_meta("press_tw")
		if old != null and is_instance_valid(old):
			old.kill()

	var rest_mod: Color = target.get_meta("press_rest_mod", target.modulate)
	var rest_top: float = target.get_meta("press_rest_top", target.offset_top)
	var rest_bottom: float = target.get_meta("press_rest_bottom", target.offset_bottom)
	var dy := PRESS_Y if pressed else 0.0
	var dur := DOWN_SEC if pressed else UP_SEC

	var tw := target.create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD if pressed else Tween.TRANS_BACK)
	tw.tween_property(target, "scale", Vector2.ONE * (PRESS_SCALE if pressed else 1.0), dur)
	tw.tween_property(target, "modulate", PRESS_MODULATE if pressed else rest_mod, dur)
	tw.tween_property(target, "offset_top", rest_top + dy, dur)
	tw.tween_property(target, "offset_bottom", rest_bottom + dy, dur)
	target.set_meta("press_tw", tw)
