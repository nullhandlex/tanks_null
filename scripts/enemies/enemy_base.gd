@tool
extends CharacterBody2D

enum State {
	SPAWNING,
	MOVING,
	ATTACKING,
	DEAD,
}

@export var enemy_display_name: String = "Medium"
@export var clicks_to_destroy: int = 3
@export var move_speed: float = 220.0
@export var stop_tolerance: float = 36.0
@export var use_avoidance: bool = true
@export var avoidance_neighbor_distance: float = 160.0
@export var avoidance_max_neighbors: int = 10
@export var damage_per_shot: float = 5.0
@export var attack_rate: float = 1.0
@export var reward: int = 1
## Real hit points. Each click still removes `max_hp / clicks_to_destroy`,
## so click balance is unchanged; ults remove raw HP instead.
@export var max_hp: float = 30.0
## 0 = unarmoured. Only scales down machine-gun ult damage; clicks and the
## cannon ult ignore armour by design.
@export_range(0.0, 0.95, 0.05) var armor: float = 0.0
## Energy added to the player's ult meter when this unit dies.
@export var energy_reward: float = 5.0
@export var shot_color: Color = Color(1.0, 0.75, 0.2, 1.0)
@export var explosion_tint: Color = Color(1.0, 0.45, 0.15, 1.0)
@export var death_style: UnitDeathVfx.Style = UnitDeathVfx.Style.TANK
@export_range(0.25, 3.0, 0.05) var death_effect_scale: float = 1.0
## Ground mark left on death: blood for infantry, scorch/debris for vehicles.
@export var crater_scale: float = 1.1
## Ground-decal appearance is independent from the weapon/projectile style.
@export var crater_style: GroundCrater.Style = GroundCrater.Style.TANK

@export_group("Weapon")
## Picks the muzzle flash, projectile look and impact size for this unit.
@export var shot_style: CombatVfx.ShotStyle = CombatVfx.ShotStyle.RIFLE
## Muzzle positions as fractions of the sprite frame measured from its centre,
## so they follow the art through scaling and the facing tilt. Multiple entries
## are cycled, which is how twin-barrel units alternate.
@export var muzzle_offsets: Array[Vector2] = [Vector2(0.0, 0.30)]
## Where inside one attack cycle the art actually discharges; the shot is held
## back by this fraction of `attack_rate` so VFX and animation line up.
@export_range(0.0, 0.9, 0.01) var fire_frame_ratio: float = 0.15
## Absolute shoot-animation frame to fire on. When >= 0 this wins over
## `fire_frame_ratio` and is converted through the animation FPS, so slowing
## the sprite keeps the shot on the recoil pose.
@export var fire_frame: int = -1
## Rounds per attack cycle. `damage_per_shot` is split across the burst, so
## raising this changes the look and not the damage output.
@export var shots_per_burst: int = 1
@export var burst_interval: float = 0.08

@export_group("Presentation")
## On-screen height of the unit in pixels; the sprite scale is derived from it.
@export var display_height: float = 140.0:
	set(value):
		display_height = value
		_refresh_presentation()
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"shoot"
## Source art is rendered facing down-screen, so straight-down movement needs no turn.
@export var sprite_angle_offset: float = -PI / 2.0
## Applied before the facing clamp. Used when the source art does not already
## face down-screen (TOS launchers point up in the PNG).
@export var sprite_rest_rotation: float = 0.0
## Pre-rendered art breaks down at steep angles, so facing is clamped instead of free.
@export var max_facing_angle: float = deg_to_rad(4.0)
@export var facing_turn_speed: float = 7.0
## Fraction of the sprite width used as the avoidance body; keeps units from
## driving through each other when a wave bunches up.
@export var body_radius_ratio: float = 0.52
@export var click_radius_ratio: float = 0.46
@export_subgroup("Shadow")
@export_range(0.4, 3.0, 0.05, "or_greater") var shadow_width_ratio: float = 1.55:
	set(value):
		shadow_width_ratio = value
		_refresh_presentation()
@export_range(0.2, 2.0, 0.05, "or_greater") var shadow_height_ratio: float = 0.85:
	set(value):
		shadow_height_ratio = value
		_refresh_presentation()
@export_range(0.05, 1.0, 0.01) var shadow_alpha: float = 0.5:
	set(value):
		shadow_alpha = value
		_refresh_presentation()
@export_range(-0.6, 0.6, 0.01) var shadow_x_ratio: float = 0.0:
	set(value):
		shadow_x_ratio = value
		_refresh_presentation()
@export_range(-0.4, 0.6, 0.01) var shadow_y_ratio: float = 0.08:
	set(value):
		shadow_y_ratio = value
		_refresh_presentation()

signal defeated(reward_amount: int)

var state: State = State.SPAWNING
var _hp: float = 0.0
var _click_block_until_msec: int = 0
var _attack_target: Node2D = null
var _hold_position: Vector2 = Vector2.ZERO
var _navigation_ready: bool = false
var _base_visual_scale: Vector2 = Vector2.ONE
var _frame_size: Vector2 = Vector2(120.0, 120.0)
var _visual_scale: float = 1.0
var _target_facing: float = 0.0
var avoidance_radius: float = 22.0
var _muzzle_index: int = 0
var _burst_remaining: int = 0
var _fire_delay_timer: Timer = null
var _idle_in_pool: bool = false

@onready var visual_root: Node2D = $VisualRoot
@onready var shadow_sprite: Sprite2D = $ShadowSprite
@onready var unit_sprite: AnimatedSprite2D = $VisualRoot/UnitSprite
@onready var type_badge: Label = $VisualRoot/TypeBadge
@onready var hp_label: Label = $VisualRoot/HpLabel
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var attack_timer: Timer = $AttackTimer
@onready var click_area: Area2D = $ClickArea
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var click_shape: CollisionShape2D = $ClickArea/CollisionShape2D


func _ready() -> void:
	_setup_visuals()
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(true)
		return

	set_process(false)
	add_to_group("enemies")
	attack_timer.wait_time = attack_rate
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	_setup_fire_delay_timer()
	click_area.input_event.connect(_on_click_area_input_event)
	navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)
	type_badge.text = enemy_display_name
	navigation_agent.target_desired_distance = stop_tolerance
	unit_sprite.rotation = sprite_rest_rotation
	state = State.MOVING
	_play_animation(move_animation)
	call_deferred("_init_click_health")
	call_deferred("_prepare_navigation")


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		call_deferred("_setup_visuals")


func _refresh_presentation() -> void:
	if Engine.is_editor_hint():
		if is_inside_tree():
			call_deferred("_setup_visuals")
		return
	if is_inside_tree():
		_setup_visuals()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_setup_visuals()
		return


## Owned by the enemy rather than awaited inline, so a unit destroyed mid-cycle
## takes its pending shot down with it.
func _setup_fire_delay_timer() -> void:
	_fire_delay_timer = Timer.new()
	_fire_delay_timer.one_shot = true
	_fire_delay_timer.timeout.connect(_fire_shot)
	add_child(_fire_delay_timer)


## Derives sprite scale, hitboxes and label placement from the animation frame,
## so a new enemy type only needs `display_height` instead of hand-tuned nodes.
func _setup_visuals() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot")
	if shadow_sprite == null:
		shadow_sprite = get_node_or_null("ShadowSprite")
	if unit_sprite == null:
		unit_sprite = get_node_or_null("VisualRoot/UnitSprite")
	if body_shape == null:
		body_shape = get_node_or_null("CollisionShape2D")
	if click_shape == null:
		click_shape = get_node_or_null("ClickArea/CollisionShape2D")
	if type_badge == null:
		type_badge = get_node_or_null("VisualRoot/TypeBadge")
	if hp_label == null:
		hp_label = get_node_or_null("VisualRoot/HpLabel")
	if visual_root == null or unit_sprite == null:
		return
	_frame_size = _measure_frame_size()
	_visual_scale = display_height / maxf(_frame_size.y, 1.0)
	visual_root.scale = Vector2(_visual_scale, _visual_scale)

	var world_width := _frame_size.x * _visual_scale
	var world_height := _frame_size.y * _visual_scale

	avoidance_radius = world_width * body_radius_ratio
	if not Engine.is_editor_hint() and body_shape != null:
		var body_circle := body_shape.shape as CircleShape2D
		if body_circle == null:
			body_circle = CircleShape2D.new()
			body_shape.shape = body_circle
		body_circle.radius = avoidance_radius

	if not Engine.is_editor_hint() and click_shape != null:
		var click_circle := click_shape.shape as CircleShape2D
		if click_circle == null:
			click_circle = CircleShape2D.new()
			click_shape.shape = click_circle
		click_circle.radius = maxf(world_width, world_height) * click_radius_ratio

	_setup_shadow(world_width, world_height)
	if not Engine.is_editor_hint():
		_setup_labels()


func _measure_frame_size() -> Vector2:
	var frames := unit_sprite.sprite_frames
	if frames == null:
		return Vector2(120.0, 120.0)

	var anim := move_animation
	if not frames.has_animation(anim):
		var names := frames.get_animation_names()
		if names.is_empty():
			return Vector2(120.0, 120.0)
		anim = StringName(names[0])

	if frames.get_frame_count(anim) <= 0:
		return Vector2(120.0, 120.0)

	var texture := frames.get_frame_texture(anim, 0)
	if texture == null:
		return Vector2(120.0, 120.0)
	return texture.get_size()


func _setup_shadow(world_width: float, world_height: float) -> void:
	if shadow_sprite == null:
		return
	# Keep z_index at 0. A negative value draws behind the landscape, so the
	# shadow disappears on BattleLevel even though it looks fine in the unit scene.
	shadow_sprite.visible = true
	shadow_sprite.z_index = 0
	shadow_sprite.z_as_relative = true
	shadow_sprite.show_behind_parent = true
	shadow_sprite.centered = true
	shadow_sprite.rotation = 0.0
	shadow_sprite.modulate = Color(0.0, 0.0, 0.0, shadow_alpha)

	var texture_size := (
		shadow_sprite.texture.get_size()
		if shadow_sprite.texture != null
		else Vector2(256.0, 96.0)
	)
	var target_width := maxf(world_width * shadow_width_ratio, 48.0)
	var target_height := maxf(world_height * shadow_height_ratio, 28.0)
	shadow_sprite.scale = Vector2(
		target_width / maxf(texture_size.x, 1.0),
		target_height / maxf(texture_size.y, 1.0),
	)
	shadow_sprite.position = Vector2(
		world_width * shadow_x_ratio,
		world_height * shadow_y_ratio,
	)


func _setup_labels() -> void:
	if type_badge == null or hp_label == null:
		return
	type_badge.visible = false
	hp_label.visible = true
	# Labels live under VisualRoot, so undo its scale to keep text size constant.
	var inverse := 1.0 / maxf(_visual_scale, 0.001)
	var top := -(_frame_size.y * 0.5) - 8.0 * inverse
	hp_label.scale = Vector2(inverse, inverse)
	hp_label.position = Vector2(-48.0 * inverse, top)


func _play_animation(anim: StringName, restart: bool = false) -> void:
	var frames := unit_sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return
	if unit_sprite.animation == anim and unit_sprite.is_playing() and not restart:
		return
	unit_sprite.play(anim)
	if restart:
		unit_sprite.set_frame_and_progress(0, 0.0)


func _init_click_health() -> void:
	_hp = maxf(max_hp, 1.0)
	_base_visual_scale = visual_root.scale
	_update_hp_display()


func _prepare_navigation() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or _idle_in_pool or state == State.DEAD:
		return
	_configure_avoidance()
	_navigation_ready = true
	_sync_navigation_target()
	call_deferred("_enable_avoidance")


func _configure_avoidance() -> void:
	navigation_agent.avoidance_enabled = false
	navigation_agent.max_speed = move_speed
	navigation_agent.radius = avoidance_radius
	navigation_agent.neighbor_distance = maxf(avoidance_neighbor_distance, avoidance_radius * 3.5)
	navigation_agent.max_neighbors = avoidance_max_neighbors
	navigation_agent.time_horizon_agents = 0.7
	navigation_agent.avoidance_layers = 1
	navigation_agent.avoidance_mask = 1


func _enable_avoidance() -> void:
	if _idle_in_pool or state == State.DEAD or not use_avoidance:
		return
	navigation_agent.avoidance_enabled = true


func set_attack_target(target: Node2D) -> void:
	_attack_target = target
	if _attack_target != null and _attack_target.has_method("assign_attack_slot"):
		_hold_position = _attack_target.assign_attack_slot(self)
	elif _attack_target != null:
		_hold_position = _attack_target.global_position

	if is_node_ready() and _navigation_ready:
		_sync_navigation_target()
	elif is_node_ready():
		call_deferred("_prepare_navigation")


func stop_combat() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	attack_timer.stop()
	if _fire_delay_timer != null:
		_fire_delay_timer.stop()
	unit_sprite.stop()
	set_process(false)
	set_physics_process(false)
	click_area.input_pickable = false


func apply_click_damage() -> void:
	if state == State.DEAD or not GameManager.is_combat_active():
		return

	CombatVfx.spawn_click_hit(global_position, _get_effects_layer())
	apply_damage(max_hp / float(maxi(clicks_to_destroy, 1)))


## Real-HP damage entry point shared by clicks and base ultimates.
## `use_armor` lets the machine-gun ult chew light targets faster than
## armoured ones; clicks and the cannon ult pass raw damage.
func apply_damage(amount: float, use_armor: bool = false) -> void:
	if state == State.DEAD or not GameManager.is_combat_active():
		return

	var final_damage := amount
	if use_armor:
		final_damage *= 1.0 - clampf(armor, 0.0, 0.95)
	_hp = maxf(_hp - final_damage, 0.0)
	_play_hit_feedback()
	_update_hp_display()

	if _hp <= 0.0:
		defeat()


func _play_hit_feedback() -> void:
	if visual_root == null:
		return
	var tween := create_tween()
	visual_root.scale = _base_visual_scale * 1.18
	unit_sprite.modulate = Color(1.4, 1.4, 1.4, 1.0)
	tween.tween_property(visual_root, "scale", _base_visual_scale, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(unit_sprite, "modulate", Color.WHITE, 0.12)


func _update_hp_display() -> void:
	if hp_label == null:
		return
	# Dots still read as "clicks left" even though damage is HP-based now.
	var click_damage := max_hp / float(maxi(clicks_to_destroy, 1))
	var remaining := int(ceilf(_hp / maxf(click_damage, 0.001)))
	var filled := "●".repeat(clampi(remaining, 0, clicks_to_destroy))
	var empty := "○".repeat(clampi(clicks_to_destroy - remaining, 0, clicks_to_destroy))
	hp_label.text = "%s%s  (%d)" % [filled, empty, int(ceilf(_hp))]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_advance_facing(delta)

	if state == State.ATTACKING:
		velocity = Vector2.ZERO
		navigation_agent.set_velocity(Vector2.ZERO)
		_face_target(_get_shot_impact_position())
		return

	if state != State.MOVING or not GameManager.is_combat_active():
		velocity = Vector2.ZERO
		navigation_agent.set_velocity(Vector2.ZERO)
		return

	if _is_at_hold_position():
		_try_start_attack()
		return

	if not _navigation_ready:
		return

	if navigation_agent.is_navigation_finished():
		_try_start_attack()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_path_position)
	if direction.length_squared() < 0.0001:
		direction = global_position.direction_to(_get_move_target_position())

	var desired_velocity := direction * move_speed
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity
		move_and_slide()
		_update_facing_from_velocity(desired_velocity)


func _on_navigation_velocity_computed(safe_velocity: Vector2) -> void:
	if state != State.MOVING or not GameManager.is_combat_active():
		return

	velocity = safe_velocity
	move_and_slide()
	_update_facing_from_velocity(safe_velocity)


func _update_facing_from_velocity(facing_velocity: Vector2) -> void:
	if facing_velocity.length_squared() > 0.0:
		_set_target_facing(facing_velocity.angle())


func _set_target_facing(world_angle: float) -> void:
	var relative := wrapf(world_angle + sprite_angle_offset, -PI, PI)
	_target_facing = clampf(relative, -max_facing_angle, max_facing_angle)


func _advance_facing(delta: float) -> void:
	if unit_sprite == null:
		return
	var weight := clampf(facing_turn_speed * delta, 0.0, 1.0)
	unit_sprite.rotation = lerp_angle(
		unit_sprite.rotation,
		sprite_rest_rotation + _target_facing,
		weight,
	)
	shadow_sprite.rotation = 0.0


func _is_at_hold_position() -> bool:
	if _hold_position == Vector2.ZERO:
		return false
	return global_position.distance_to(_hold_position) <= stop_tolerance


func _get_move_target_position() -> Vector2:
	if _hold_position != Vector2.ZERO:
		return _hold_position
	return _get_shot_impact_position()


func _sync_navigation_target() -> void:
	if _hold_position != Vector2.ZERO:
		navigation_agent.target_position = _hold_position
	elif _attack_target != null and is_instance_valid(_attack_target):
		if _attack_target.has_method("get_attack_target_position"):
			navigation_agent.target_position = _attack_target.get_attack_target_position()
		else:
			navigation_agent.target_position = _attack_target.global_position


func _get_shot_impact_position() -> Vector2:
	if _attack_target != null and is_instance_valid(_attack_target):
		if _attack_target.has_method("get_shot_impact_position_for"):
			return _attack_target.get_shot_impact_position_for(self)
		if _attack_target.has_method("get_shot_impact_position"):
			return _attack_target.get_shot_impact_position()
		if _attack_target.has_method("get_attack_target_position"):
			return _attack_target.get_attack_target_position()
		return _attack_target.global_position
	if _hold_position != Vector2.ZERO:
		return _hold_position
	return global_position


func _try_start_attack() -> void:
	if state != State.MOVING or not GameManager.is_combat_active():
		return
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	if not _is_at_hold_position() and not navigation_agent.is_navigation_finished():
		return

	state = State.ATTACKING
	velocity = Vector2.ZERO
	navigation_agent.set_velocity(Vector2.ZERO)
	_face_target(_get_shot_impact_position())
	_play_animation(attack_animation)
	if attack_timer.is_stopped():
		_on_attack_timer_timeout()
		attack_timer.start()


func _face_target(target_position: Vector2) -> void:
	var direction := global_position.direction_to(target_position)
	if direction.length_squared() > 0.0:
		_set_target_facing(direction.angle())


## Delay from the start of the shoot loop to the discharge pose.
func _shot_sync_delay() -> float:
	var frames := unit_sprite.sprite_frames
	if frames != null and frames.has_animation(attack_animation):
		var fps := maxf(frames.get_animation_speed(attack_animation), 0.01)
		var count := frames.get_frame_count(attack_animation)
		if fire_frame >= 0:
			return clampf(float(fire_frame) / fps, 0.0, attack_rate * 0.92)
		if count > 0:
			return clampf(fire_frame_ratio * float(count) / fps, 0.0, attack_rate * 0.92)
	return attack_rate * fire_frame_ratio


## World position of the barrel tip, following the sprite's scale and tilt.
func _get_muzzle_global_position() -> Vector2:
	if unit_sprite == null or muzzle_offsets.is_empty():
		return global_position
	var ratio: Vector2 = muzzle_offsets[_muzzle_index % muzzle_offsets.size()]
	return unit_sprite.to_global(Vector2(ratio.x * _frame_size.x, ratio.y * _frame_size.y))


func _on_attack_timer_timeout() -> void:
	if state != State.ATTACKING or not GameManager.is_combat_active():
		return
	if _attack_target == null or not is_instance_valid(_attack_target):
		return

	_face_target(_get_shot_impact_position())
	# Restart the loop so its discharge frame lands on the delayed shot below.
	_play_animation(attack_animation, true)

	_burst_remaining = maxi(shots_per_burst, 1)
	var delay := _shot_sync_delay()
	if delay <= 0.01:
		_fire_shot()
	else:
		_fire_delay_timer.start(delay)

	if attack_timer.is_stopped():
		attack_timer.start()


func _fire_shot() -> void:
	if state != State.ATTACKING or not GameManager.is_combat_active():
		return
	if _attack_target == null or not is_instance_valid(_attack_target):
		return

	var impact_position := _get_shot_impact_position()
	var muzzle_position := _get_muzzle_global_position()
	var effects_layer := _get_effects_layer()
	var rounds := maxi(shots_per_burst, 1)

	CombatVfx.spawn_muzzle_flash(
		muzzle_position,
		muzzle_position.direction_to(impact_position),
		shot_style,
		effects_layer,
		shot_color,
	)
	CombatVfx.spawn_projectile(
		muzzle_position,
		impact_position,
		shot_style,
		effects_layer,
		shot_color,
		_attack_target,
		damage_per_shot / float(rounds),
	)

	_muzzle_index += 1
	_burst_remaining -= 1
	if _burst_remaining > 0:
		_fire_delay_timer.start(maxf(burst_interval, 0.02))


func _on_click_area_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int,
) -> void:
	if state == State.DEAD or not GameManager.is_combat_active():
		return
	if not _is_click_press_event(event):
		return

	var now_msec := Time.get_ticks_msec()
	if now_msec < _click_block_until_msec:
		return
	_click_block_until_msec = now_msec + 150

	apply_click_damage()
	get_viewport().set_input_as_handled()


func _is_click_press_event(event: InputEvent) -> bool:
	if OS.has_feature("mobile"):
		return event is InputEventScreenTouch and event.pressed
	return event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT


func defeat() -> void:
	if state == State.DEAD:
		return

	if _attack_target != null and is_instance_valid(_attack_target):
		if _attack_target.has_method("release_attack_slot"):
			_attack_target.release_attack_slot(self)

	var defeat_position := global_position
	state = State.DEAD
	velocity = Vector2.ZERO
	navigation_agent.set_velocity(Vector2.ZERO)
	attack_timer.stop()
	click_area.input_pickable = false
	set_process(false)
	set_physics_process(false)

	CombatVfx.spawn_explosion(
		defeat_position, _get_effects_layer(), explosion_tint, death_style, death_effect_scale,
	)
	if crater_scale > 0.0:
		CombatVfx.spawn_crater(
			_get_ground_position(), crater_scale, _get_ground_layer(), crater_style,
		)
	defeated.emit(reward)
	GameManager.add_energy(energy_reward)
	GameManager.register_enemy_defeated()
	var pool = get_meta("enemy_pool", null)
	if pool != null and pool.has_method("put_back"):
		pool.put_back(self)
	else:
		queue_free()


func is_sleeping_in_pool() -> bool:
	return _idle_in_pool


func wake_from_pool() -> void:
	_idle_in_pool = false
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	state = State.MOVING
	velocity = Vector2.ZERO
	_hold_position = Vector2.ZERO
	_attack_target = null
	_muzzle_index = 0
	_burst_remaining = 0
	_click_block_until_msec = 0
	set_process(true)
	set_physics_process(true)
	click_area.input_pickable = true
	if not is_in_group("enemies"):
		add_to_group("enemies")
	if visual_root != null:
		visual_root.scale = _base_visual_scale
	if unit_sprite != null:
		unit_sprite.modulate = Color.WHITE
	_init_click_health()
	_play_animation(move_animation, true)
	_navigation_ready = true
	_configure_avoidance()
	call_deferred("_enable_avoidance")


func sleep_in_pool() -> void:
	_idle_in_pool = true
	if _attack_target != null and is_instance_valid(_attack_target):
		if _attack_target.has_method("release_attack_slot"):
			_attack_target.release_attack_slot(self)
	_attack_target = null
	_hold_position = Vector2.ZERO
	state = State.DEAD
	velocity = Vector2.ZERO
	if _fire_delay_timer != null:
		_fire_delay_timer.stop()
	attack_timer.stop()
	if navigation_agent != null:
		navigation_agent.avoidance_enabled = false
		navigation_agent.set_velocity(Vector2.ZERO)
	if is_in_group("enemies"):
		remove_from_group("enemies")
	click_area.input_pickable = false
	set_process(false)
	set_physics_process(false)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _get_effects_layer() -> Node:
	var battle := get_tree().current_scene
	if battle != null and battle.has_node("Effects"):
		return battle.get_node("Effects")
	return get_tree().current_scene


func _get_ground_layer() -> Node:
	var battle := get_tree().current_scene
	if battle == null:
		return _get_effects_layer()
	var craters := battle.get_node_or_null("Craters")
	if craters != null:
		return craters
	# Above the landscape (z -20), below units/props in World (z 0).
	craters = Node2D.new()
	craters.name = "Craters"
	craters.z_index = -10
	battle.add_child(craters)
	return craters


func _get_ground_position() -> Vector2:
	if shadow_sprite != null and is_instance_valid(shadow_sprite):
		return shadow_sprite.global_position
	return global_position
