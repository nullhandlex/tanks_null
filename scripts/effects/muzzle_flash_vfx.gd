extends Node2D

## Discharge flash placed at a unit's muzzle and oriented along the firing line.
##
## `setup` only touches plain state so it can be called before the node enters
## the tree; everything that needs child nodes happens in `_ready`.

var _tint: Color = Color(1.0, 0.85, 0.4)
var _size: float = 1.0
var _with_smoke: bool = false


func setup(direction: Vector2, tint: Color, size: float, with_smoke: bool) -> void:
	if direction.length_squared() > 0.0:
		rotation = direction.angle()
	_tint = tint
	_size = maxf(size, 0.1)
	_with_smoke = with_smoke


func _ready() -> void:
	var flash: Sprite2D = $Flash
	var ring: Sprite2D = $Ring
	var sparks: CPUParticles2D = $Sparks
	var smoke: CPUParticles2D = $Smoke

	var bright := Color(1.0, 0.95, 0.7, 1.0)
	flash.modulate = bright
	ring.modulate = Color(_tint.r, _tint.g, _tint.b * 0.55, 0.9)

	# Keep the cone on the muzzle instead of pushing it down the firing line.
	flash.scale = Vector2(0.42 * _size, 0.26 * _size)
	flash.position = Vector2(2.0 * _size, 0.0)
	ring.scale = Vector2(0.18 * _size, 0.18 * _size)
	ring.position = Vector2.ZERO

	sparks.color = bright
	sparks.scale_amount_min = 0.08 * _size
	sparks.scale_amount_max = 0.16 * _size
	sparks.initial_velocity_min = 140.0 * _size
	sparks.initial_velocity_max = 320.0 * _size
	sparks.emitting = true

	if _with_smoke:
		smoke.scale_amount_min = 0.12 * _size
		smoke.scale_amount_max = 0.26 * _size
		smoke.initial_velocity_min = 40.0 * _size
		smoke.initial_velocity_max = 120.0 * _size
		smoke.emitting = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(0.78 * _size, 0.4 * _size), 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_property(ring, "scale", Vector2(0.65 * _size, 0.65 * _size), 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.16)

	await get_tree().create_timer(0.7).timeout
	queue_free()
