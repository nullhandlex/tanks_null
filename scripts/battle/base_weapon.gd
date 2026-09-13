extends Node2D

## Animated weapon mounted on one of the base platforms.
##
## Placement and firing logic are still open; for now the scene only owns its
## own presentation so it can be dropped onto a mount marker.
## Idle (`instant`) is a one-shot fidget, not a loop. Shoot stays a separate loop.

@export var display_height: float = 180.0:
	set(value):
		display_height = value
		_apply_layout()

@export var idle_animation: StringName = &"instant"
@export var shoot_animation: StringName = &"shoot"

## Lifts the sprite so its carriage rests on the platform instead of straddling it.
@export var ground_offset_ratio: float = 0.22:
	set(value):
		ground_offset_ratio = value
		_apply_layout()

@export_group("Idle fidget")
@export var fidget_enabled: bool = true
@export_range(1.0, 30.0, 0.5) var fidget_interval_min: float = 5.0
@export_range(1.0, 30.0, 0.5) var fidget_interval_max: float = 10.0

@export_group("Aim")
## Machine guns yaw toward the ult aim point; the mortar stays fixed.
@export var can_aim: bool = false
@export var rest_direction: Vector2 = Vector2.UP
## Half-angle from rest. ~55° covers the lane ahead without letting one
## MG sweep across the wall into the other.
@export_range(10.0, 90.0, 1.0) var max_yaw_degrees: float = 55.0
@export var aim_turn_speed: float = 12.0

@export_group("Muzzles")
## Fractions of the sprite frame from its visual centre, same convention as
## enemies (`ratio * frame_size`). Empty keeps the single top-centre muzzle.
@export var muzzle_offsets: Array[Vector2] = []
## Shoot-animation frame index that discharges each barrel. Empty means no
## `barrel_fired` sync (machine guns keep their current tick-driven shots).
@export var fire_frames: Array[int] = []
## Optional unit directions for muzzle flash, in sprite space (UP-ish, fanned).
@export var muzzle_dirs: Array[Vector2] = []

signal barrel_fired(barrel_index: int, muzzle_global: Vector2, fire_dir: Vector2)

## Pulse colour while enough ult energy is banked for this weapon.
const READY_GLOW_COLOR := Color(2.21, 1.95, 1.11, 1.0)

@onready var weapon_sprite: AnimatedSprite2D = $WeaponSprite

var _fidget_timer: Timer
var _glow_tween: Tween
var _ready_glow: bool = false
var _aiming: bool = false
var _aim_rotation: float = 0.0
var _barrels_fired: Array[bool] = []
var _barrel_sync_enabled: bool = false


func _ready() -> void:
	_apply_layout()
	_set_anim_loop(idle_animation, false)
	weapon_sprite.animation_finished.connect(_on_animation_finished)
	weapon_sprite.frame_changed.connect(_on_frame_changed)
	_hold_idle()
	if Engine.is_editor_hint():
		return
	_fidget_timer = Timer.new()
	_fidget_timer.one_shot = true
	_fidget_timer.timeout.connect(_on_fidget_timeout)
	add_child(_fidget_timer)
	_schedule_fidget(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not can_aim:
		return
	var target := _aim_rotation if _aiming else 0.0
	var weight := 1.0 - exp(-aim_turn_speed * delta)
	rotation = lerp_angle(rotation, target, clampf(weight, 0.0, 1.0))


func play_idle() -> void:
	_hold_idle()
	_schedule_fidget()


func play_shoot(loop: bool = true) -> void:
	if _fidget_timer != null:
		_fidget_timer.stop()
	_reset_barrel_fires()
	_barrel_sync_enabled = false
	_set_anim_loop(shoot_animation, loop)
	_play(shoot_animation)
	_barrel_sync_enabled = true
	# Catch a fire frame that is already showing; `frame_changed` skips it.
	_emit_due_barrels()


func set_aiming(enabled: bool) -> void:
	_aiming = enabled
	if not enabled:
		_aim_rotation = 0.0


## Yaw toward `world_position`, clamped to `max_yaw_degrees` around rest.
## Returns the point the barrel actually fires at.
func aim_at(world_position: Vector2) -> Vector2:
	if not can_aim:
		return world_position
	var origin := global_position
	var to_target := world_position - origin
	var dist := maxf(to_target.length(), 40.0)
	var dir := _clamped_aim_dir(to_target)
	_aim_rotation = dir.angle() - rest_direction.angle()
	return origin + dir * dist


func _clamped_aim_dir(to_target: Vector2) -> Vector2:
	var rest := rest_direction.normalized()
	if rest == Vector2.ZERO:
		rest = Vector2.UP
	if to_target.length_squared() < 1.0:
		return rest
	var yaw := rest.angle_to(to_target.normalized())
	var limit := deg_to_rad(max_yaw_degrees)
	return rest.rotated(clampf(yaw, -limit, limit))


## World position of a barrel tip. Empty `muzzle_offsets` keeps the old
## single-muzzle fallback (sprite top-centre). `barrel_index` < 0 uses barrel 0
## when offsets exist.
func get_muzzle_global_position(barrel_index: int = -1) -> Vector2:
	if weapon_sprite == null:
		return global_position
	var frame := _frame_size()
	var origin := weapon_sprite.offset
	if muzzle_offsets.is_empty():
		return weapon_sprite.to_global(origin + Vector2(0.0, -frame.y * 0.5))
	var idx := barrel_index if barrel_index >= 0 else 0
	var ratio: Vector2 = muzzle_offsets[idx % muzzle_offsets.size()]
	return weapon_sprite.to_global(origin + Vector2(ratio.x * frame.x, ratio.y * frame.y))


func get_barrel_fire_dir(barrel_index: int = -1) -> Vector2:
	var local := Vector2.UP
	if barrel_index >= 0 and barrel_index < muzzle_dirs.size():
		var listed := muzzle_dirs[barrel_index]
		if listed != Vector2.ZERO:
			local = listed
	if weapon_sprite == null:
		return local.normalized()
	var global_dir := weapon_sprite.to_global(local) - weapon_sprite.to_global(Vector2.ZERO)
	if global_dir.length_squared() < 0.0001:
		return Vector2.UP
	return global_dir.normalized()


## UI cue that this weapon's ult can be fired (MG at 50 energy, cannon at 100).
func set_ready_glow(enabled: bool) -> void:
	if _ready_glow == enabled:
		return
	_ready_glow = enabled
	if _glow_tween != null:
		_glow_tween.kill()
		_glow_tween = null
	if weapon_sprite == null:
		return
	if not enabled:
		weapon_sprite.modulate = Color.WHITE
		return
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(weapon_sprite, "modulate", READY_GLOW_COLOR, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(weapon_sprite, "modulate", Color.WHITE, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play(anim: StringName) -> void:
	var frames := weapon_sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	weapon_sprite.stop()
	weapon_sprite.animation = anim
	weapon_sprite.frame = 0
	weapon_sprite.play(anim)


func _hold_idle() -> void:
	_barrel_sync_enabled = false
	var frames := weapon_sprite.sprite_frames
	if frames == null or not frames.has_animation(idle_animation):
		return
	weapon_sprite.stop()
	weapon_sprite.animation = idle_animation
	weapon_sprite.frame = 0


func _on_fidget_timeout() -> void:
	if weapon_sprite.animation == shoot_animation and weapon_sprite.is_playing():
		_schedule_fidget()
		return
	_set_anim_loop(idle_animation, false)
	_play(idle_animation)


func _on_frame_changed() -> void:
	_emit_due_barrels()


func _reset_barrel_fires() -> void:
	_barrels_fired.clear()
	_barrels_fired.resize(fire_frames.size())
	_barrels_fired.fill(false)


func _emit_due_barrels() -> void:
	if not _barrel_sync_enabled:
		return
	if weapon_sprite == null or fire_frames.is_empty():
		return
	if weapon_sprite.animation != shoot_animation:
		return
	var current := weapon_sprite.frame
	for i in fire_frames.size():
		if i < _barrels_fired.size() and _barrels_fired[i]:
			continue
		if fire_frames[i] > current:
			continue
		if i >= _barrels_fired.size():
			_barrels_fired.resize(i + 1)
		_barrels_fired[i] = true
		barrel_fired.emit(i, get_muzzle_global_position(i), get_barrel_fire_dir(i))


func _on_animation_finished() -> void:
	if weapon_sprite.animation == shoot_animation:
		_emit_due_barrels()
		_hold_idle()
		_schedule_fidget()
		return
	if weapon_sprite.animation == idle_animation:
		_hold_idle()
		_schedule_fidget()


func _schedule_fidget(initial: bool = false) -> void:
	if not fidget_enabled or _fidget_timer == null:
		return
	var wait := randf_range(
		minf(fidget_interval_min, fidget_interval_max),
		maxf(fidget_interval_min, fidget_interval_max),
	)
	if initial:
		wait *= randf_range(0.05, 1.0)
	_fidget_timer.start(maxf(wait, 0.1))


func _set_anim_loop(anim: StringName, looping: bool) -> void:
	var frames := weapon_sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	frames.set_animation_loop(anim, looping)


func _apply_layout() -> void:
	if not is_node_ready():
		return
	var frame_size := _frame_size()
	var sprite_scale := display_height / maxf(frame_size.y, 1.0)
	weapon_sprite.scale = Vector2(sprite_scale, sprite_scale)
	weapon_sprite.offset = Vector2(0.0, -frame_size.y * ground_offset_ratio)


func _frame_size() -> Vector2:
	var frames := weapon_sprite.sprite_frames
	if frames == null:
		return Vector2(180.0, 180.0)
	var names := frames.get_animation_names()
	if names.is_empty():
		return Vector2(180.0, 180.0)
	var anim := idle_animation if frames.has_animation(idle_animation) else StringName(names[0])
	if frames.get_frame_count(anim) <= 0:
		return Vector2(180.0, 180.0)
	var texture := frames.get_frame_texture(anim, 0)
	if texture == null:
		return Vector2(180.0, 180.0)
	return texture.get_size()
