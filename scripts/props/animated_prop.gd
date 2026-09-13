@tool
extends Node2D

## Ambient animated decoration (trees, bushes, wrecks).
##
## The sprite is anchored at the bottom of its frame so the node position marks
## where the prop touches the ground, which is also what Y sorting compares.
## When `blocks_movement` is on, the prop gets both a static body and a
## navigation obstacle so enemies steer around it instead of driving through.

@export var display_height: float = 160.0:
	set(value):
		display_height = value
		_refresh_layout()

@export var flip_horizontal: bool = false:
	set(value):
		flip_horizontal = value
		_refresh_layout()

@export_group("Blocking")
@export var blocks_movement: bool = true:
	set(value):
		blocks_movement = value
		_refresh_layout()

## Obstacle radius in pixels. Zero derives it from `display_height`.
@export var collider_radius: float = 0.0:
	set(value):
		collider_radius = value
		_refresh_layout()

@export var collider_height_ratio: float = 0.28:
	set(value):
		collider_height_ratio = value
		_refresh_layout()

@export_group("Shadow")
@export_range(0.2, 2.5, 0.05, "or_greater") var shadow_width_ratio: float = 0.9:
	set(value):
		shadow_width_ratio = value
		_refresh_layout()
@export_range(0.08, 1.2, 0.01, "or_greater") var shadow_height_ratio: float = 0.22:
	set(value):
		shadow_height_ratio = value
		_refresh_layout()
@export_range(0.05, 1.0, 0.01) var shadow_alpha: float = 0.45:
	set(value):
		shadow_alpha = value
		_refresh_layout()
@export_range(-1.0, 1.0, 0.01) var shadow_x_ratio: float = 0.0:
	set(value):
		shadow_x_ratio = value
		_refresh_layout()
@export_range(-0.5, 0.8, 0.01) var shadow_y_ratio: float = 0.0:
	set(value):
		shadow_y_ratio = value
		_refresh_layout()

## Offsets the loop start so a group of identical props does not sway in unison.
@export var randomize_phase: bool = true

const SHADOW_TEXTURE: Texture2D = preload("res://assets/shadows/ground_shadow.png")

@onready var shadow_sprite: Sprite2D = get_node_or_null("ShadowSprite")
@onready var prop_sprite: AnimatedSprite2D = $PropSprite
@onready var blocker_shape: CollisionShape2D = $Blocker/CollisionShape2D
@onready var navigation_obstacle: NavigationObstacle2D = $NavigationObstacle2D


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		call_deferred("_apply_visuals")


func _ready() -> void:
	_apply_layout()
	if Engine.is_editor_hint():
		set_process(true)
		return
	if randomize_phase:
		_offset_animation_phase()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_visuals()


func _refresh_layout() -> void:
	if Engine.is_editor_hint():
		if is_inside_tree():
			call_deferred("_apply_visuals")
		return
	if is_inside_tree():
		_apply_layout()


func _apply_layout() -> void:
	_apply_visuals()
	_apply_blocking()


func _apply_visuals() -> void:
	_ensure_nodes()
	if prop_sprite == null:
		return

	var frame_size := _frame_size()
	var sprite_scale := display_height / maxf(frame_size.y, 1.0)
	prop_sprite.scale = Vector2(sprite_scale, sprite_scale)
	prop_sprite.offset = Vector2(0.0, -frame_size.y * 0.5)
	prop_sprite.flip_h = flip_horizontal

	var world_width := frame_size.x * sprite_scale
	var world_height := frame_size.y * sprite_scale
	_setup_shadow(world_width, world_height)


func _setup_shadow(world_width: float, world_height: float) -> void:
	if shadow_sprite == null:
		return
	# Keep z_index at 0. A negative value draws behind the landscape.
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
	var target_width := maxf(world_width * shadow_width_ratio, 36.0)
	var target_height := maxf(world_height * shadow_height_ratio, 16.0)
	shadow_sprite.scale = Vector2(
		target_width / maxf(texture_size.x, 1.0),
		target_height / maxf(texture_size.y, 1.0),
	)
	var facing := -1.0 if flip_horizontal else 1.0
	shadow_sprite.position = Vector2(
		prop_sprite.position.x + world_width * shadow_x_ratio * facing,
		prop_sprite.position.y + world_height * shadow_y_ratio,
	)


func _apply_blocking() -> void:
	_ensure_nodes()
	if blocker_shape == null or navigation_obstacle == null:
		return

	var radius := collider_radius
	if radius <= 0.0:
		radius = display_height * collider_height_ratio

	# Built per instance: a shared sub-resource would resize every other prop too.
	var circle := blocker_shape.shape as CircleShape2D
	if circle == null or not circle.resource_local_to_scene:
		circle = CircleShape2D.new()
		circle.resource_local_to_scene = true
		blocker_shape.shape = circle
	circle.radius = radius
	blocker_shape.disabled = not blocks_movement

	navigation_obstacle.radius = radius
	navigation_obstacle.avoidance_enabled = blocks_movement


func _ensure_nodes() -> void:
	if shadow_sprite == null:
		shadow_sprite = get_node_or_null("ShadowSprite")
	if shadow_sprite == null:
		_create_shadow_sprite()
	elif shadow_sprite.texture == null:
		shadow_sprite.texture = SHADOW_TEXTURE
	if prop_sprite == null:
		prop_sprite = get_node_or_null("PropSprite")
	if blocker_shape == null:
		blocker_shape = get_node_or_null("Blocker/CollisionShape2D")
	if navigation_obstacle == null:
		navigation_obstacle = get_node_or_null("NavigationObstacle2D")


func _create_shadow_sprite() -> void:
	shadow_sprite = Sprite2D.new()
	shadow_sprite.name = "ShadowSprite"
	shadow_sprite.texture = SHADOW_TEXTURE
	shadow_sprite.show_behind_parent = true
	shadow_sprite.centered = true
	shadow_sprite.z_index = 0
	add_child(shadow_sprite)
	move_child(shadow_sprite, 0)
	if Engine.is_editor_hint() and get_tree() != null:
		var edited := get_tree().edited_scene_root
		shadow_sprite.owner = edited if edited != null else self


func _frame_size() -> Vector2:
	var frames := prop_sprite.sprite_frames
	if frames == null:
		return Vector2(160.0, 160.0)
	var names := frames.get_animation_names()
	if names.is_empty():
		return Vector2(160.0, 160.0)
	var anim := StringName(names[0])
	if frames.get_frame_count(anim) <= 0:
		return Vector2(160.0, 160.0)
	var texture := frames.get_frame_texture(anim, 0)
	if texture == null:
		return Vector2(160.0, 160.0)
	return texture.get_size()


func _offset_animation_phase() -> void:
	var frames := prop_sprite.sprite_frames
	if frames == null:
		return
	var anim := prop_sprite.animation
	if not frames.has_animation(anim):
		return
	var count := frames.get_frame_count(anim)
	if count <= 1:
		return
	prop_sprite.play(anim)
	prop_sprite.set_frame_and_progress(randi() % count, randf())
