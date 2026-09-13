class_name UltWeapons
extends Node2D

## Player-triggered base weapon ultimates fed by the energy meter.
##
## Machine guns (50 energy): press and hold an MG tower, then drag to sweep the
## aim point across the field. Both MG towers fire at the finger until release
## or the duration timer runs out. Armour reduces damage taken.
## Cannon (100 energy): a single tap on the centre tower splits
## `cannon_total_damage` evenly across every enemy alive; armour is ignored,
## so it hits lone bosses the hardest.

@export var press_radius: float = 150.0
@export var mg_duration_sec: float = 5.0
@export var mg_tick_sec: float = 0.1
@export var mg_damage_per_tick: float = 6.0
@export var mg_aim_radius: float = 95.0
@export var cannon_total_damage: float = 500.0
@export var cannon_flight_sec: float = 0.42

const MG_TRACER_COLOR := Color(1.0, 0.85, 0.35, 1.0)
const CANNON_BLAST_COLOR := Color(1.0, 0.55, 0.2, 1.0)
const RETICLE_COLOR := Color(1.0, 0.85, 0.3, 0.9)

var _base: Node2D = null
var _effects: Node = null
var _mg_weapons: Array[Node2D] = []
var _cannon_weapon: Node2D = null

var _holding: bool = false
var _mg_active: bool = false
var _aim_position: Vector2 = Vector2.ZERO
var _mg_time_left: float = 0.0
var _tick_accum: float = 0.0
var _cannon_barrel_payloads: Array = []
var _cannon_blast_targets: Array[Node2D] = []
var _cannon_map_blast_pending: bool = false


func setup(base: Node2D, effects: Node) -> void:
	_base = base
	_effects = effects
	z_index = 60
	for mount_index in [0, 2]:
		var weapon := _weapon_at_mount(mount_index)
		if weapon != null:
			_mg_weapons.append(weapon)
	_cannon_weapon = _weapon_at_mount(1)
	if _cannon_weapon != null and _cannon_weapon.has_signal("barrel_fired"):
		_cannon_weapon.barrel_fired.connect(_on_cannon_barrel_fired)

	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.battle_state_changed.connect(_on_battle_state_changed)
	_on_energy_changed(GameManager.energy, GameManager.MAX_ENERGY)


func _weapon_at_mount(index: int) -> Node2D:
	if _base == null or not _base.has_method("get_weapon_mount"):
		return null
	var mount: Node2D = _base.get_weapon_mount(index)
	if mount == null or mount.get_child_count() == 0:
		return null
	return mount.get_child(0) as Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _handle_press(_to_world(event.position)):
				get_viewport().set_input_as_handled()
		else:
			_handle_release()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _handle_press(_to_world(event.position)):
				get_viewport().set_input_as_handled()
		else:
			_handle_release()
	elif event is InputEventScreenDrag:
		_handle_drag(_to_world(event.position))
	elif event is InputEventMouseMotion and _holding:
		_handle_drag(_to_world(event.position))


func _to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _handle_press(world_position: Vector2) -> bool:
	# Guards duplicated presses when the platform emulates mouse from touch.
	if _holding:
		return true
	if not GameManager.is_combat_active():
		return false

	if GameManager.energy >= GameManager.CANNON_ULT_COST and _is_near_weapon(_cannon_weapon, world_position):
		if _fire_cannon_ult():
			_holding = true
			return true
		return false

	if GameManager.energy >= GameManager.MG_ULT_COST:
		for weapon in _mg_weapons:
			if _is_near_weapon(weapon, world_position):
				if _start_mg_ult(world_position):
					_holding = true
					return true
				return false
	return false


func _handle_drag(world_position: Vector2) -> void:
	if _mg_active:
		_aim_position = world_position


func _handle_release() -> void:
	_holding = false
	if _mg_active:
		_end_mg_ult()


func _is_near_weapon(weapon: Node2D, world_position: Vector2) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	return weapon.global_position.distance_to(world_position) <= press_radius


func _start_mg_ult(aim_start: Vector2) -> bool:
	if _mg_active or _mg_weapons.is_empty():
		return false
	if not GameManager.try_consume_energy(GameManager.MG_ULT_COST):
		return false

	_mg_active = true
	_aim_position = aim_start
	_mg_time_left = mg_duration_sec
	# Full tick queued so the first burst leaves the barrels immediately.
	_tick_accum = mg_tick_sec
	for weapon in _mg_weapons:
		if not is_instance_valid(weapon):
			continue
		if weapon.has_method("set_aiming"):
			weapon.set_aiming(true)
		if weapon.has_method("aim_at"):
			weapon.aim_at(_aim_position)
		if weapon.has_method("play_shoot"):
			weapon.play_shoot(true)
	queue_redraw()
	return true


func _end_mg_ult() -> void:
	if not _mg_active:
		return
	_mg_active = false
	for weapon in _mg_weapons:
		if not is_instance_valid(weapon):
			continue
		if weapon.has_method("set_aiming"):
			weapon.set_aiming(false)
		if weapon.has_method("play_idle"):
			weapon.play_idle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _mg_active:
		return
	if not GameManager.is_combat_active():
		_end_mg_ult()
		return

	_mg_time_left -= delta
	if _mg_time_left <= 0.0:
		_end_mg_ult()
		return

	_tick_accum += delta
	for weapon in _mg_weapons:
		if is_instance_valid(weapon) and weapon.has_method("aim_at"):
			weapon.aim_at(_aim_position)
	while _tick_accum >= mg_tick_sec:
		_tick_accum -= mg_tick_sec
		_mg_tick()
	queue_redraw()


func _mg_tick() -> void:
	var jitter := Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))

	for weapon in _mg_weapons:
		if not is_instance_valid(weapon):
			continue
		var impact := _aim_position + jitter
		if weapon.has_method("aim_at"):
			impact = weapon.aim_at(_aim_position) + jitter
		var muzzle: Vector2 = weapon.global_position
		if weapon.has_method("get_muzzle_global_position"):
			muzzle = weapon.get_muzzle_global_position()
		var shot_dir := muzzle.direction_to(impact)
		CombatVfx.spawn_muzzle_flash(
			muzzle,
			shot_dir,
			CombatVfx.ShotStyle.MACHINE_GUN,
			_effects,
			MG_TRACER_COLOR,
		)
		# Cosmetic tracer; HP is applied by the aim-radius check below.
		CombatVfx.spawn_projectile(
			muzzle,
			impact,
			CombatVfx.ShotStyle.MACHINE_GUN,
			_effects,
			MG_TRACER_COLOR,
			null,
			0.0,
		)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_hittable(enemy):
			continue
		if enemy.global_position.distance_to(_aim_position) > mg_aim_radius:
			continue
		CombatVfx.spawn_click_hit(enemy.global_position, _effects)
		enemy.apply_damage(mg_damage_per_tick, true)


func _fire_cannon_ult() -> bool:
	if not GameManager.try_consume_energy(GameManager.CANNON_ULT_COST):
		return false

	var targets: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _is_hittable(enemy):
			targets.append(enemy)

	_prepare_cannon_payloads(targets)
	if _cannon_weapon != null and is_instance_valid(_cannon_weapon):
		if _cannon_weapon.has_method("play_shoot"):
			_cannon_weapon.play_shoot(false)
	return true


func _cannon_barrel_count() -> int:
	if _cannon_weapon != null and is_instance_valid(_cannon_weapon):
		var frames: Variant = _cannon_weapon.get("fire_frames")
		if frames is Array and (frames as Array).size() > 0:
			return (frames as Array).size()
		var offsets: Variant = _cannon_weapon.get("muzzle_offsets")
		if offsets is Array and (offsets as Array).size() > 0:
			return (offsets as Array).size()
	return 1


func _prepare_cannon_payloads(targets: Array[Node2D]) -> void:
	var barrel_count := maxi(_cannon_barrel_count(), 1)
	_cannon_barrel_payloads.clear()
	_cannon_blast_targets.clear()
	_cannon_map_blast_pending = false
	for _i in barrel_count:
		_cannon_barrel_payloads.append([])
	if targets.is_empty():
		return

	_cannon_map_blast_pending = true
	_cannon_blast_targets = targets.duplicate()
	var damage_each := cannon_total_damage / float(targets.size())
	for i in targets.size():
		var barrel: int = i % barrel_count
		_cannon_barrel_payloads[barrel].append({
			"target": targets[i],
			"damage": damage_each,
		})
	for barrel in barrel_count:
		if not (_cannon_barrel_payloads[barrel] as Array).is_empty():
			continue
		var reuse: Node2D = targets[barrel % targets.size()]
		_cannon_barrel_payloads[barrel].append({
			"target": reuse,
			"damage": 0.0,
		})


func _on_cannon_barrel_fired(barrel_index: int, muzzle_global: Vector2, fire_dir: Vector2) -> void:
	var flash_dir := fire_dir
	if flash_dir.length_squared() < 0.0001:
		flash_dir = Vector2.UP
	CombatVfx.spawn_muzzle_flash(
		muzzle_global,
		flash_dir,
		CombatVfx.ShotStyle.HEAVY_CANNON,
		_effects,
		CANNON_BLAST_COLOR,
	)

	if barrel_index < 0 or barrel_index >= _cannon_barrel_payloads.size():
		return
	var shots: Array = _cannon_barrel_payloads[barrel_index]
	for shot in shots:
		_launch_cannon_shell(muzzle_global, flash_dir, shot)


func _launch_cannon_shell(muzzle: Vector2, fire_dir: Vector2, shot: Variant) -> void:
	var damage := 0.0
	var listed: Node = null
	if shot is Dictionary:
		damage = float((shot as Dictionary).get("damage", 0.0))
		listed = (shot as Dictionary).get("target") as Node

	var live: Node = null
	var aim := _cannon_fallback_aim(muzzle, fire_dir)
	if listed != null and is_instance_valid(listed) and listed is Node2D:
		aim = (listed as Node2D).global_position
		if damage > 0.0 and _is_hittable(listed):
			live = listed

	# Shared landing: earlier barrels fly longer so the volley hits together.
	var shell: Node2D = CombatVfx.spawn_projectile(
		muzzle,
		aim,
		CombatVfx.ShotStyle.HEAVY_CANNON,
		_effects,
		CANNON_BLAST_COLOR,
		live,
		damage,
		false,
		_cannon_flight_for_current_barrel(),
	)
	if shell != null and shell.has_signal("impacted"):
		if not shell.impacted.is_connected(_play_cannon_map_blast):
			shell.impacted.connect(_play_cannon_map_blast)


func _cannon_flight_for_current_barrel() -> float:
	var frames: Array = []
	if _cannon_weapon != null and is_instance_valid(_cannon_weapon):
		var listed: Variant = _cannon_weapon.get("fire_frames")
		if listed is Array:
			frames = listed as Array
	if frames.is_empty() or _cannon_weapon == null:
		return cannon_flight_sec
	var current := 0
	var sprite: AnimatedSprite2D = _cannon_weapon.get_node_or_null("WeaponSprite") as AnimatedSprite2D
	if sprite != null:
		current = sprite.frame
	var last := int(frames[0])
	for frame in frames:
		last = maxi(last, int(frame))
	var fps := 24.0
	if sprite != null and sprite.sprite_frames != null:
		var speed := sprite.sprite_frames.get_animation_speed(&"shoot")
		if speed > 0.0:
			fps = speed
	return cannon_flight_sec + float(maxi(last - current, 0)) / fps


func _play_cannon_map_blast() -> void:
	if not _cannon_map_blast_pending:
		return
	_cannon_map_blast_pending = false
	for enemy in _cannon_blast_targets:
		if not is_instance_valid(enemy):
			continue
		CombatVfx.spawn_explosion(enemy.global_position, _effects, CANNON_BLAST_COLOR)
	_cannon_blast_targets.clear()


func _cannon_fallback_aim(muzzle: Vector2, fire_dir: Vector2) -> Vector2:
	var dir := fire_dir
	if dir.length_squared() < 0.0001:
		dir = Vector2.UP
	return muzzle + dir.normalized() * 520.0


func _is_hittable(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or not (enemy is Node2D):
		return false
	if enemy.has_method("is_sleeping_in_pool") and enemy.is_sleeping_in_pool():
		return false
	return enemy.has_method("apply_damage")


func _on_energy_changed(current: float, _max_energy: float) -> void:
	var mg_ready := current >= GameManager.MG_ULT_COST
	var cannon_ready := current >= GameManager.CANNON_ULT_COST
	for weapon in _mg_weapons:
		if is_instance_valid(weapon) and weapon.has_method("set_ready_glow"):
			weapon.set_ready_glow(mg_ready)
	if _cannon_weapon != null and is_instance_valid(_cannon_weapon):
		if _cannon_weapon.has_method("set_ready_glow"):
			_cannon_weapon.set_ready_glow(cannon_ready)


func _on_battle_state_changed(state: GameManager.BattleState) -> void:
	if _mg_active and state != GameManager.BattleState.WAVE_ACTIVE:
		_end_mg_ult()


func _draw() -> void:
	if not _mg_active:
		return
	var local_aim := to_local(_aim_position)
	draw_arc(local_aim, mg_aim_radius, 0.0, TAU, 40, RETICLE_COLOR, 4.0)
	draw_circle(local_aim, 7.0, RETICLE_COLOR)
