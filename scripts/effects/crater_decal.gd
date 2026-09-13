class_name GroundCrater
extends Sprite2D

## Shared imported atlas; one sprite and one bound tween per mark. No runtime
## texture generation, extra physics bodies, or per-frame script processing.
enum Style {
	INFANTRY, CAR, GATLING, MINIGUN, MINE,
	TANK, HEAVY_TANK, ROCKET, SIEGE_BOSS, HEAVY_BOSS,
}

const ATLAS_COLUMNS := 5
const ATLAS_ROWS := 6
const VARIANTS_PER_STYLE := 3
const ATLAS_PIXEL_SCALE := 0.5

## Seconds at full visibility; randomized slightly so adjacent marks do not
## disappear in unison. Timings follow game time and pause with the battle.
@export_range(0.0, 60.0, 0.5) var hold_seconds: float = 14.0
@export_range(0.1, 30.0, 0.5) var fade_seconds: float = 7.0

var _lifetime_tween: Tween


func setup(size_scale: float, style: int = Style.TANK) -> void:
	if _lifetime_tween != null and _lifetime_tween.is_valid():
		_lifetime_tween.kill()
	centered = true
	z_index = 0
	z_as_relative = true
	show_behind_parent = true
	hframes = ATLAS_COLUMNS
	vframes = ATLAS_ROWS
	var style_index := clampi(style, Style.INFANTRY, Style.HEAVY_BOSS)
	frame = style_index * VARIANTS_PER_STYLE + randi_range(0, VARIANTS_PER_STYLE - 1)
	rotation = randf_range(-0.12, 0.12)
	var visual_scale := maxf(size_scale, 0.01) * ATLAS_PIXEL_SCALE * randf_range(0.94, 1.06)
	scale = Vector2(visual_scale, visual_scale * randf_range(0.94, 1.02))
	var shade := randf_range(0.93, 1.0)
	modulate = Color(shade, shade, shade, 0.0)
	var opacity := randf_range(0.88, 1.0)
	_lifetime_tween = create_tween()
	_lifetime_tween.tween_property(self, "modulate:a", opacity, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lifetime_tween.tween_interval(maxf(hold_seconds, 0.0) * randf_range(0.85, 1.15))
	_lifetime_tween.tween_property(self, "modulate:a", 0.0, maxf(fade_seconds, 0.1))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lifetime_tween.tween_callback(queue_free)
