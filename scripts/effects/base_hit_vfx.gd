extends Node2D

## Impact burst played where a shot actually lands.
##
## `tint` and `power` are set before the node enters the tree, so `_ready` is
## where the whole burst is assembled.

var tint: Color = Color(1.0, 0.55, 0.2)
var power: float = 1.0


func _ready() -> void:
	var flash: Sprite2D = $Flash
	var ring: Sprite2D = $Ring
	var sparks: CPUParticles2D = $Sparks
	var debris: CPUParticles2D = $Debris
	var smoke: CPUParticles2D = $Smoke

	var scaled: float = maxf(power, 0.2)
	var core := Color(1.0, 0.95, 0.7, 1.0)

	flash.modulate = core
	flash.scale = Vector2(0.7 * scaled, 0.7 * scaled)
	ring.modulate = Color(tint.r, tint.g, tint.b * 0.5, 0.95)
	ring.scale = Vector2(0.4 * scaled, 0.4 * scaled)

	sparks.color = core
	sparks.amount = int(18 * scaled) + 10
	sparks.initial_velocity_min = 180.0 * scaled
	sparks.initial_velocity_max = 520.0 * scaled
	sparks.scale_amount_min = 0.1 * scaled
	sparks.scale_amount_max = 0.22 * scaled
	sparks.emitting = true

	debris.amount = int(10 * scaled) + 6
	debris.initial_velocity_min = 110.0 * scaled
	debris.initial_velocity_max = 300.0 * scaled
	debris.scale_amount_min = 0.1 * scaled
	debris.scale_amount_max = 0.2 * scaled
	debris.emitting = true

	smoke.amount = int(12 * scaled) + 6
	smoke.initial_velocity_min = 40.0 * scaled
	smoke.initial_velocity_max = 140.0 * scaled
	smoke.scale_amount_min = 0.22 * scaled
	smoke.scale_amount_max = 0.48 * scaled
	smoke.emitting = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.8 * scaled, 1.8 * scaled), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_property(ring, "scale", Vector2(2.2 * scaled, 2.2 * scaled), 0.32)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.32)

	await get_tree().create_timer(1.1).timeout
	queue_free()
