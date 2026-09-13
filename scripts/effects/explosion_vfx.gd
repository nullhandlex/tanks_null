class_name UnitDeathVfx
extends Node2D

## Independent from weapon impacts and ground-decal tuning.
## GENERIC keeps existing projectile/ultimate callers on a non-organic effect.
enum Style {
	SOLDIER, CAR, GATLING, MINIGUN, MINE,
	TANK, HEAVY_TANK, TOS, DORA, ANIGIL, GENERIC,
}

const PUFF: Texture2D = preload("res://assets/effects/death_smoke.svg")
const SHARD: Texture2D = preload("res://assets/effects/death_shard.svg")
const DROP: Texture2D = preload("res://assets/effects/blood_drop.svg")

## Radius, flame/smoke/debris counts, smoke duration and secondary detonations.
const PROFILES := [
	{"radius": 48.0, "fire": 0, "smoke": 0, "debris": 0, "life": 0.65, "secondary": 0},
	{"radius": 75.0, "fire": 17, "smoke": 10, "debris": 8, "life": 1.35, "secondary": 0},
	{"radius": 61.0, "fire": 10, "smoke": 6, "debris": 17, "life": 0.95, "secondary": 0},
	{"radius": 66.0, "fire": 12, "smoke": 7, "debris": 22, "life": 1.05, "secondary": 0},
	{"radius": 83.0, "fire": 5, "smoke": 5, "debris": 21, "life": 0.85, "secondary": 0},
	{"radius": 92.0, "fire": 20, "smoke": 11, "debris": 13, "life": 1.50, "secondary": 0},
	{"radius": 111.0, "fire": 24, "smoke": 14, "debris": 17, "life": 1.75, "secondary": 0},
	{"radius": 89.0, "fire": 16, "smoke": 10, "debris": 12, "life": 1.45, "secondary": 3},
	{"radius": 129.0, "fire": 28, "smoke": 17, "debris": 22, "life": 1.95, "secondary": 1},
	{"radius": 143.0, "fire": 25, "smoke": 18, "debris": 24, "life": 2.05, "secondary": 4},
	{"radius": 66.0, "fire": 14, "smoke": 6, "debris": 5, "life": 0.85, "secondary": 0},
]

@export var style: Style = Style.GENERIC
@export var effect_scale: float = 1.0
@export var tint: Color = Color(1.0, 0.45, 0.15, 1.0)

@onready var burst_particles: CPUParticles2D = $BurstParticles
@onready var smoke_particles: CPUParticles2D = $SmokeParticles
@onready var debris_particles: CPUParticles2D = $DebrisParticles
@onready var dust_particles: CPUParticles2D = $DustParticles
@onready var flash: Sprite2D = $Flash
@onready var shockwave: Sprite2D = $Shockwave


func _ready() -> void:
	add_to_group("unit_death_vfx")
	scale = Vector2.ONE * clampf(effect_scale, 0.25, 3.0)
	if style == Style.SOLDIER:
		_start_blood()
		_expire_after(0.95)
		return
	_start_vehicle(PROFILES[clampi(style, 0, Style.GENERIC)])


func _start_blood() -> void:
	flash.hide()
	shockwave.hide()
	# Wet droplets follow short arcs. Dark red mist replaces fire and smoke.
	_emit(burst_particles, DROP, 23, 0.46, 75.0, 180.0, 0.14, 0.33,
		[Color(0.72, 0.06, 0.085, 1), Color(0.43, 0.025, 0.045, 0.9), Color(0.25, 0.015, 0.025, 0)], Vector2(0, 200))
	burst_particles.direction = Vector2(0, -1)
	burst_particles.spread = 115.0
	_emit(debris_particles, DROP, 10, 0.62, 40.0, 115.0, 0.23, 0.46,
		[Color(0.56, 0.025, 0.04, 1), Color(0.37, 0.016, 0.025, 1), Color(0.24, 0.01, 0.016, 0)], Vector2(0, 145))
	_emit(dust_particles, PUFF, 7, 0.35, 12.0, 42.0, 0.23, 0.52,
		[Color(0.54, 0.025, 0.045, 0.32), Color(0.34, 0.015, 0.03, 0.20), Color(0.25, 0.01, 0.02, 0)], Vector2(0, 18))


func _start_vehicle(profile: Dictionary) -> void:
	var radius: float = profile.radius * randf_range(0.93, 1.06)
	var smoke_life: float = profile.life
	var flame := Color(1.0, 0.36, 0.055, 0.95)
	var smoke := Color(0.24, 0.225, 0.205, 0.60)
	var debris := Color(0.36, 0.37, 0.32, 1.0)
	var debris_speed := radius * 2.2
	var dust_count := 9
	if style == Style.CAR:
		flame = Color(1, 0.48, 0.08, 0.95)
		smoke = Color(0.13, 0.135, 0.125, 0.68)
	elif style == Style.GATLING or style == Style.MINIGUN:
		debris = Color(0.68, 0.49, 0.20, 1)
		debris_speed *= 1.3
	elif style == Style.MINE:
		dust_count = 23
		debris = Color(0.43, 0.32, 0.20, 1)
		debris_speed *= 1.3
		smoke = Color(0.44, 0.36, 0.24, 0.55)
	elif style == Style.HEAVY_TANK or style == Style.DORA:
		dust_count = 16
	elif style == Style.TOS or style == Style.ANIGIL:
		flame = Color(1, 0.25, 0.035, 0.96)
	elif style == Style.GENERIC:
		flame = tint

	_play_flash(flash, radius, Color(1, 0.88, 0.56, 0.90))
	_emit(burst_particles, PUFF, int(profile.fire), 0.46, radius * 0.45, radius * 1.6, 0.20, radius / 105.0,
		[Color(1, 0.91, 0.55, 0.98), flame, Color(0.19, 0.12, 0.075, 0)], Vector2(0, -48))
	_emit(smoke_particles, PUFF, int(profile.smoke), smoke_life, radius * 0.15, radius * 0.53, 0.35, radius / 80.0,
		[Color(smoke, 0.10), smoke, Color(0.28, 0.27, 0.24, 0)], Vector2(0, -30))
	smoke_particles.direction = Vector2(0, -1)
	smoke_particles.spread = 72.0
	smoke_particles.scale_amount_curve = _growth_curve()
	_emit(debris_particles, SHARD, int(profile.debris), 0.82, radius * 0.85, debris_speed, 0.17, 0.45,
		[Color(1, 0.68, 0.24, 1), debris, Color(debris, 0)], Vector2(0, 185))
	debris_particles.direction = Vector2(0, -1)
	debris_particles.spread = 140.0
	_emit(dust_particles, PUFF, dust_count, 0.74, radius * 0.7, radius * 1.3, 0.30, radius / 105.0,
		[Color(0.59, 0.49, 0.31, 0.30), Color(0.48, 0.41, 0.30, 0.24), Color(0.44, 0.39, 0.29, 0)], Vector2.ZERO)
	dust_particles.scale = Vector2(1, 0.52)
	dust_particles.scale_amount_curve = _growth_curve()

	if style == Style.MINE or style == Style.HEAVY_TANK or style == Style.DORA or style == Style.ANIGIL:
		shockwave.show()
		shockwave.modulate = Color(0.76, 0.65, 0.42, 0.36)
		shockwave.scale = Vector2.ONE * radius / 200.0
		var wave := create_tween().set_parallel(true)
		wave.tween_property(shockwave, "scale", Vector2.ONE * radius / 60.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wave.tween_property(shockwave, "modulate:a", 0.0, 0.38)
	else:
		shockwave.hide()

	for i in int(profile.secondary):
		var delay := 0.13 + i * 0.13
		var offset := Vector2(randf_range(-0.48, 0.48) * radius, randf_range(-0.32, 0.12) * radius)
		var sequence := create_tween()
		sequence.tween_interval(delay)
		sequence.tween_callback(_secondary_burst.bind(offset, radius * 0.57))
	_expire_after(maxf(smoke_life, 0.13 * float(profile.secondary) + 0.65) + 0.30)


func _emit(
	emitter: CPUParticles2D, particle_texture: Texture2D, count: int,
	lifetime: float, speed_min: float, speed_max: float,
	size_min: float, size_max: float, colors: Array[Color], gravity: Vector2,
) -> void:
	emitter.emitting = false
	emitter.amount = maxi(count, 1)
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.lifetime = lifetime
	emitter.lifetime_randomness = 0.20
	emitter.texture = particle_texture
	emitter.direction = Vector2(0, -1)
	emitter.spread = 180.0
	emitter.gravity = gravity
	emitter.initial_velocity_min = speed_min
	emitter.initial_velocity_max = speed_max
	emitter.angular_velocity_min = -180.0
	emitter.angular_velocity_max = 180.0
	emitter.scale_amount_min = size_min
	emitter.scale_amount_max = size_max
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	gradient.colors = PackedColorArray(colors)
	emitter.color_ramp = gradient
	emitter.emitting = count > 0
	if count > 0:
		emitter.restart()


func _growth_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.40))
	curve.add_point(Vector2(0.35, 0.75))
	curve.add_point(Vector2(1, 1))
	return curve


func _play_flash(sprite: Sprite2D, radius: float, color: Color) -> void:
	sprite.modulate = color
	sprite.scale = Vector2.ONE * radius / 160.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ONE * radius / 48.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _secondary_burst(offset: Vector2, radius: float) -> void:
	var flare := Sprite2D.new()
	flare.texture = flash.texture
	flare.material = flash.material
	flare.position = offset
	add_child(flare)
	_play_flash(flare, radius, Color(1, 0.72, 0.30, 0.85))
	var sparks := CPUParticles2D.new()
	sparks.position = offset
	add_child(sparks)
	_emit(sparks, PUFF, 7, 0.40, 35.0, radius * 1.5, 0.23, 0.65,
		[Color(1, 0.81, 0.36, 0.98), Color(1, 0.28, 0.035, 0.9), Color(0.19, 0.12, 0.08, 0)], Vector2(0, -35))


func _expire_after(seconds: float) -> void:
	# Bound to this node: pauses correctly and is cancelled on scene teardown.
	var lifetime := create_tween()
	lifetime.tween_interval(seconds)
	lifetime.tween_callback(queue_free)
