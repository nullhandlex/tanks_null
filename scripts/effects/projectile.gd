extends Node2D

## Travelling shot fired by an enemy.
##
## The node origin is the muzzle. Visuals are shifted forward along +X so the
## tail sits on the barrel instead of the whole sprite hanging past it.
## Damage is applied when the projectile reaches the target.

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _travel: float = 0.0
var _distance: float = 1.0
var _speed: float = 1600.0
var _params: Dictionary = {}
var _tint: Color = Color(1.0, 0.8, 0.3)
var _target: Node = null
var _damage: float = 0.0
var _explode_on_hit: bool = false
var _spent: bool = false

signal impacted

@onready var trail: Line2D = $Trail
@onready var core: Sprite2D = $Core
@onready var glow: Sprite2D = $Glow
@onready var smoke: CPUParticles2D = $Smoke
@onready var rocket_body: Sprite2D = $RocketBody
@onready var rocket_exhaust: Sprite2D = $RocketExhaust


func launch(
	from_global: Vector2,
	to_global: Vector2,
	style: int,
	tint: Color,
	target: Node,
	damage: float,
	explode_on_hit: bool = false,
) -> void:
	_from = from_global
	_to = to_global
	_tint = tint
	_target = target
	_damage = damage
	_explode_on_hit = explode_on_hit
	_params = CombatVfx.style_params(style)
	_speed = _params.get("speed", 1600.0)
	_distance = maxf(from_global.distance_to(to_global), 1.0)

	global_position = from_global
	rotation = (to_global - from_global).angle()
	_apply_style()


func set_flight_time(seconds: float) -> void:
	_speed = _distance / maxf(seconds, 0.05)


func _apply_style() -> void:
	var core_size: float = _params.get("core", 8.0)
	var trail_length: float = _params.get("trail", 80.0)
	var trail_width: float = _params.get("width", 5.0)
	var is_rocket: bool = _params.get("rocket", false)

	rocket_body.visible = is_rocket
	rocket_exhaust.visible = is_rocket
	core.visible = not is_rocket
	glow.visible = not is_rocket

	if is_rocket:
		_style_rocket(trail_length, trail_width)
	else:
		_style_shell(core_size, trail_length, trail_width)

	if _params.get("smoke", false):
		smoke.emitting = true
	else:
		smoke.emitting = false


func _style_shell(core_size: float, trail_length: float, trail_width: float) -> void:
	core.modulate = Color(1.0, 0.98, 0.85, 1.0)
	glow.modulate = Color(_tint.r, _tint.g * 0.85, _tint.b * 0.45, 0.55)
	if core.texture != null:
		var texture_width := maxf(core.texture.get_size().x, 1.0)
		var core_scale := core_size * 2.0 / texture_width
		core.scale = Vector2(core_scale * 1.7, core_scale)
		glow.scale = Vector2(core_scale * 2.4, core_scale * 1.8)
		# Centered sprites hang half their length past the muzzle; slide them
		# forward so the tail stays on the barrel.
		var half_len := core.texture.get_size().x * core.scale.x * 0.5
		core.position = Vector2(half_len, 0.0)
		glow.position = Vector2(half_len, 0.0)

	trail.width = trail_width
	trail.default_color = Color(_tint.r, _tint.g, _tint.b, 0.8)
	trail.points = PackedVector2Array([Vector2(-trail_length, 0.0), Vector2.ZERO])
	smoke.modulate = Color(0.75, 0.72, 0.68, 0.7)


func _style_rocket(trail_length: float, trail_width: float) -> void:
	# Art points +X. Scale so the missile reads as a small vehicle, not a blob.
	var body_len := 72.0
	if rocket_body.texture != null:
		var tex := rocket_body.texture.get_size()
		var s := body_len / maxf(tex.x, 1.0)
		rocket_body.scale = Vector2(s, s)
		rocket_body.position = Vector2(tex.x * s * 0.5, 0.0)
		rocket_body.modulate = Color(1, 1, 1, 1)

	if rocket_exhaust.texture != null:
		var etex := rocket_exhaust.texture.get_size()
		rocket_exhaust.scale = Vector2(36.0 / maxf(etex.x, 1.0), 20.0 / maxf(etex.y, 1.0))
		rocket_exhaust.position = Vector2(-10.0, 0.0)
		rocket_exhaust.modulate = Color(1.0, 0.85, 0.4, 1.0)

	trail.width = trail_width
	trail.default_color = Color(1.0, 0.55, 0.2, 0.55)
	trail.points = PackedVector2Array([Vector2(-trail_length, 0.0), Vector2.ZERO])

	smoke.modulate = Color(0.82, 0.78, 0.72, 0.9)
	smoke.amount = 48
	smoke.lifetime = 0.9
	smoke.position = Vector2(-4.0, 0.0)
	smoke.initial_velocity_min = 30.0
	smoke.initial_velocity_max = 90.0


func _process(delta: float) -> void:
	if _spent:
		return

	_travel += _speed * delta
	if _travel >= _distance:
		_impact()
		return

	global_position = _from.lerp(_to, _travel / _distance)

	var trail_length: float = minf(_params.get("trail", 80.0), _travel)
	trail.points = PackedVector2Array([Vector2(-trail_length, 0.0), Vector2.ZERO])

	if rocket_exhaust.visible:
		var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.04)
		rocket_exhaust.modulate.a = pulse


func _impact() -> void:
	_spent = true
	set_process(false)

	var hit_pos := _to
	# Follow a moving enemy. The base impact line is not the node origin, so
	# snapping there would pile every hit on the castle centre.
	if _target is Node2D and is_instance_valid(_target) and _target.is_in_group("enemies"):
		if not (_target.has_method("is_sleeping_in_pool") and _target.is_sleeping_in_pool()):
			hit_pos = _target.global_position
	global_position = hit_pos

	if _explode_on_hit:
		CombatVfx.spawn_explosion(hit_pos, get_parent(), _tint)
	else:
		CombatVfx.spawn_base_hit(hit_pos, get_parent(), _tint, _params.get("impact", 1.0))

	impacted.emit()

	if _target != null and is_instance_valid(_target) and _target.has_method("apply_damage"):
		# Amount only: Base ignores the missing impact arg, enemies treat a
		# Vector2 as `use_armor` and would apply the wrong reduction.
		_target.apply_damage(_damage)

	core.visible = false
	glow.visible = false
	trail.visible = false
	rocket_body.visible = false
	rocket_exhaust.visible = false
	smoke.emitting = false
	await get_tree().create_timer(0.7).timeout
	queue_free()
