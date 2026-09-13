class_name CombatVfx
extends Node

const CLICK_HIT_VFX_SCENE: PackedScene = preload("res://scenes/effects/ClickHitVfx.tscn")
const EXPLOSION_VFX_SCENE: PackedScene = preload("res://scenes/effects/ExplosionVfx.tscn")
const BASE_HIT_VFX_SCENE: PackedScene = preload("res://scenes/effects/BaseHitVfx.tscn")
const MUZZLE_FLASH_VFX_SCENE: PackedScene = preload("res://scenes/effects/MuzzleFlashVfx.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/Projectile.tscn")
const CRATER_DECAL_SCENE: PackedScene = preload("res://scenes/effects/CraterDecal.tscn")
const MAX_GROUND_CRATERS := 80
const MAX_DEATH_EFFECTS := 32

## Weapon archetypes. Each enemy picks one, which drives the muzzle flash, the
## projectile look and travel speed, and how big the impact reads.
enum ShotStyle {
	RIFLE,
	MACHINE_GUN,
	CANNON,
	ROCKET,
	HEAVY_CANNON,
}

const STYLE_TABLE := {
	ShotStyle.RIFLE: {
		"speed": 2100.0, "core": 5.5, "trail": 48.0, "width": 3.0,
		"smoke": false, "impact": 1.1, "muzzle": 0.7, "muzzle_smoke": false,
	},
	ShotStyle.MACHINE_GUN: {
		"speed": 1850.0, "core": 7.0, "trail": 72.0, "width": 4.0,
		"smoke": false, "impact": 1.35, "muzzle": 0.95, "muzzle_smoke": false,
	},
	ShotStyle.CANNON: {
		"speed": 1300.0, "core": 9.0, "trail": 88.0, "width": 5.5,
		"smoke": true, "impact": 2.2, "muzzle": 1.15, "muzzle_smoke": true,
	},
	ShotStyle.ROCKET: {
		"speed": 420.0, "core": 8.0, "trail": 90.0, "width": 5.0,
		"smoke": true, "impact": 2.6, "muzzle": 0.9, "muzzle_smoke": true,
		"rocket": true,
	},
	ShotStyle.HEAVY_CANNON: {
		"speed": 1000.0, "core": 13.0, "trail": 130.0, "width": 7.5,
		"smoke": true, "impact": 3.4, "muzzle": 1.55, "muzzle_smoke": true,
	},
}


static func style_params(style: int) -> Dictionary:
	return STYLE_TABLE.get(style, STYLE_TABLE[ShotStyle.RIFLE])


static func spawn_click_hit(world_position: Vector2, parent: Node) -> void:
	if parent == null:
		return
	var vfx: Node2D = CLICK_HIT_VFX_SCENE.instantiate() as Node2D
	if vfx == null:
		return
	_add_at(vfx, parent, world_position)


static func spawn_explosion(
	world_position: Vector2,
	parent: Node,
	tint: Color = Color(1.0, 0.45, 0.15),
	death_style: int = UnitDeathVfx.Style.GENERIC,
	effect_scale: float = 1.0,
) -> void:
	if parent == null:
		return
	var vfx: Node2D = EXPLOSION_VFX_SCENE.instantiate() as Node2D
	if vfx == null:
		return
	vfx.set("tint", tint)
	vfx.set("style", death_style)
	vfx.set("effect_scale", effect_scale)
	_add_at(vfx, parent, world_position)
	var live: Array[Node] = []
	for effect in parent.get_tree().get_nodes_in_group("unit_death_vfx"):
		if not effect.is_queued_for_deletion():
			live.append(effect)
	for index in maxi(0, live.size() - MAX_DEATH_EFFECTS):
		live[index].queue_free()


## Ground death mark. Size is per unit. Parent should be the Craters layer (z -10),
## so marks sit on the landscape and never cover units or props.
static func spawn_crater(
	world_position: Vector2,
	size_scale: float,
	parent: Node,
	style: int = GroundCrater.Style.TANK,
) -> void:
	if parent == null or size_scale <= 0.0:
		return
	var crater: Node2D = CRATER_DECAL_SCENE.instantiate() as Node2D
	if crater == null:
		return
	crater.add_to_group("ground_craters")
	_add_at(crater, parent, world_position)
	if crater.has_method("setup"):
		crater.setup(size_scale, style)
	_trim_ground_craters(parent)


static func _trim_ground_craters(parent: Node) -> void:
	var tree := parent.get_tree()
	if tree == null:
		return
	var living: Array[Node] = []
	# Exclude pending frees: several deaths can arrive before the next frame.
	for mark in tree.get_nodes_in_group("ground_craters"):
		if not mark.is_queued_for_deletion():
			living.append(mark)
	var overflow := living.size() - MAX_GROUND_CRATERS
	if overflow <= 0:
		return
	for i in overflow:
		var old: Node = living[i]
		if is_instance_valid(old):
			old.queue_free()


static func spawn_muzzle_flash(
	world_position: Vector2,
	direction: Vector2,
	style: int,
	parent: Node,
	tint: Color = Color(1.0, 0.85, 0.4),
) -> void:
	if parent == null:
		return
	var vfx: Node2D = MUZZLE_FLASH_VFX_SCENE.instantiate() as Node2D
	if vfx == null:
		return
	var params := style_params(style)
	vfx.setup(direction, tint, params.get("muzzle", 1.0), params.get("muzzle_smoke", false))
	_add_at(vfx, parent, world_position)


## Fires a shot that travels to `to_global` and only then damages `target`.
static func spawn_projectile(
	from_global: Vector2,
	to_global: Vector2,
	style: int,
	parent: Node,
	tint: Color,
	target: Node,
	damage: float,
	explode_on_hit: bool = false,
	flight_time: float = 0.0,
) -> Node2D:
	if parent == null:
		return null
	var projectile: Node2D = PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return null
	_add_at(projectile, parent, from_global)
	projectile.launch(from_global, to_global, style, tint, target, damage, explode_on_hit)
	if flight_time > 0.0 and projectile.has_method("set_flight_time"):
		projectile.set_flight_time(flight_time)
	return projectile


static func spawn_base_hit(
	world_position: Vector2,
	parent: Node,
	tint: Color = Color(1.0, 0.55, 0.2),
	power: float = 1.0,
) -> void:
	if parent == null:
		return
	var vfx: Node2D = BASE_HIT_VFX_SCENE.instantiate() as Node2D
	if vfx == null:
		return
	vfx.set("tint", tint)
	vfx.set("power", power)
	_add_at(vfx, parent, world_position)


## Position first, then enter the tree. `_ready` (and one-shot particles) would
## otherwise fire at (0, 0), which is the top-left of the camera.
static func _add_at(vfx: Node2D, parent: Node, world_position: Vector2) -> void:
	if parent is Node2D:
		vfx.position = (parent as Node2D).to_local(world_position)
	else:
		vfx.position = world_position
	parent.add_child(vfx)
	vfx.global_position = world_position
