extends Node2D

@export var max_hp: float = 1000.0
@export var visual_width: float = 1080.0
@export var stop_distance: float = 260.0
## Kept narrower than the map so attack slots never land on the edge tree line.
@export var attack_line_width: float = 780.0
@export var slot_spacing: float = 130.0
## Attackers form several staggered ranks instead of one overcrowded line.
@export var attack_rows: int = 5
@export var row_spacing: float = 145.0
## How far below the painted silhouette a shell bursts, in pixels. A small inset
## makes the explosion overlap the masonry instead of hovering on its outline.
@export var impact_inset: float = 22.0

## Weapon platform centres as fractions of the base texture, so the mount markers
## stay aligned if `visual_width` or the artwork changes.
@export var weapon_mount_uvs: Array[Vector2] = [
	Vector2(0.0776, 0.7726),
	Vector2(0.5000, 0.3557),
	Vector2(0.9224, 0.7755),
]

signal health_changed(current_hp: float, max_hp: float)
signal destroyed

const IMPACT_PROFILE_SAMPLES := 64
const _DamageShader := preload("res://shaders/battle/base_damage.gdshader")
const _CRACK_SEED := 90211

var hp: float
var _visual_top_offset: float = 40.0
var _impact_half_width: float = 300.0
## Top of the painted silhouette per sampled column, as an offset from the base
## centre. Shells land on this line so they burst on the wall and the towers
## rather than in the air above them.
var _impact_profile: PackedFloat32Array = PackedFloat32Array()

var _slot_occupants: Dictionary = {}
var _enemy_slot_indices: Dictionary = {}
var _enemy_impact_positions: Dictionary = {}
var _damage_material: ShaderMaterial = null
var _cracks: Array[Line2D] = []

@onready var visual: Sprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var weapon_mounts: Node2D = $WeaponMounts


func _ready() -> void:
	hp = max_hp
	_setup_visual()
	health_changed.emit(hp, max_hp)


func _setup_visual() -> void:
	if visual.texture == null:
		return

	var tex_size := visual.texture.get_size()
	if tex_size.x <= 0.0:
		return

	var scale_factor := visual_width / tex_size.x
	visual.scale = Vector2(scale_factor, scale_factor)
	_setup_ruin_visuals()

	var body_height := tex_size.y * scale_factor
	_impact_half_width = visual_width * 0.375
	_build_impact_profile(body_height)

	collision_shape.position = Vector2(0.0, body_height * 0.15)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(visual_width * 0.75, body_height * 0.35)
	collision_shape.shape = rect

	_place_weapon_mounts(visual_width, body_height)
	_setup_cracks()
	_update_ruin_visual()


func get_visual_half_height() -> float:
	if visual == null or visual.texture == null:
		return 0.0
	return visual.texture.get_size().y * absf(visual.scale.y) * 0.5


## Traces the top of the artwork so the impact line follows the wall and towers.
func _build_impact_profile(body_height: float) -> void:
	_impact_profile = PackedFloat32Array()
	var image := visual.texture.get_image()
	if image == null:
		_visual_top_offset = body_height * 0.1
		return
	if image.is_compressed():
		image.decompress()

	var half_height := body_height * 0.5
	for sample in IMPACT_PROFILE_SAMPLES:
		var x := int(float(sample) / float(IMPACT_PROFILE_SAMPLES - 1) * (image.get_width() - 1))
		var top_row := image.get_height() - 1
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.06:
				top_row = y
				break
		var world_y := float(top_row) / float(image.get_height()) * body_height
		_impact_profile.append(world_y - half_height + impact_inset)

	# Fallback for callers with no particular column in mind.
	_visual_top_offset = -_impact_profile[IMPACT_PROFILE_SAMPLES / 2]


func _impact_offset_for_x(world_x: float) -> float:
	if _impact_profile.is_empty():
		return -_visual_top_offset
	var t := clampf((world_x - global_position.x) / visual_width + 0.5, 0.0, 1.0)
	var pos := t * float(_impact_profile.size() - 1)
	var low := int(floorf(pos))
	var high := mini(low + 1, _impact_profile.size() - 1)
	return lerpf(_impact_profile[low], _impact_profile[high], pos - float(low))


func _place_weapon_mounts(body_width: float, body_height: float) -> void:
	if weapon_mounts == null:
		return
	var markers := weapon_mounts.get_children()
	for index in mini(markers.size(), weapon_mount_uvs.size()):
		var marker := markers[index] as Node2D
		if marker == null:
			continue
		var uv: Vector2 = weapon_mount_uvs[index]
		marker.position = Vector2(
			(uv.x - 0.5) * body_width,
			(uv.y - 0.5) * body_height,
		)


## Mount point for a base weapon; index 0 = left tower, 1 = centre, 2 = right.
func get_weapon_mount(index: int) -> Node2D:
	if weapon_mounts == null:
		return null
	if index < 0 or index >= weapon_mounts.get_child_count():
		return null
	return weapon_mounts.get_child(index) as Node2D


func assign_attack_slot(enemy: Node2D) -> Vector2:
	var slot_count := _slot_columns() * maxi(attack_rows, 1)
	var enemy_id := enemy.get_instance_id()
	var slot_index := _find_free_slot_index(slot_count, enemy_id)

	_slot_occupants[slot_index] = enemy
	_enemy_slot_indices[enemy_id] = slot_index

	var hold_position := _get_slot_world_position(slot_index, slot_count)
	_enemy_impact_positions[enemy_id] = _get_perimeter_impact_for_x(hold_position.x)
	return hold_position


func release_attack_slot(enemy: Node2D) -> void:
	var enemy_id := enemy.get_instance_id()
	_enemy_impact_positions.erase(enemy_id)

	if not _enemy_slot_indices.has(enemy_id):
		return

	var slot_index: int = _enemy_slot_indices[enemy_id]
	_enemy_slot_indices.erase(enemy_id)

	if _slot_occupants.get(slot_index) == enemy:
		_slot_occupants.erase(slot_index)


func get_attack_target_position() -> Vector2:
	return get_shot_impact_position()


func get_shot_impact_position() -> Vector2:
	return global_position + Vector2(0.0, -_visual_top_offset)


func get_shot_impact_position_for(enemy: Node2D) -> Vector2:
	var enemy_id := enemy.get_instance_id()
	if _enemy_impact_positions.has(enemy_id):
		return _enemy_impact_positions[enemy_id]
	if enemy.global_position != Vector2.ZERO:
		return _get_perimeter_impact_for_x(enemy.global_position.x)
	return get_shot_impact_position()


## The impact VFX is owned by the projectile that landed, so the position is
## accepted only to keep the call signature uniform across damage sources.
func apply_damage(amount: float, _impact_position: Vector2 = Vector2.INF) -> void:
	if hp <= 0.0:
		return

	hp = clampf(hp - amount, 0.0, max_hp)
	health_changed.emit(hp, max_hp)
	_update_ruin_visual()
	_play_hit_shake()

	if hp <= 0.0:
		destroyed.emit()


func _find_free_slot_index(slot_count: int, enemy_id: int) -> int:
	for slot_index in slot_count:
		if not _slot_occupants.has(slot_index):
			return slot_index

		var occupant: Node2D = _slot_occupants[slot_index]
		if occupant == null or not is_instance_valid(occupant):
			return slot_index

	return enemy_id % slot_count


func _slot_columns() -> int:
	return maxi(int(round(attack_line_width / slot_spacing)), 1)


func _get_slot_world_position(slot_index: int, _slot_count: int) -> Vector2:
	var columns := _slot_columns()
	var column := slot_index % columns
	var row := slot_index / columns
	# Odd ranks are offset by half a slot so units behind peek through the gaps.
	var stagger := 0.5 if row % 2 == 1 else 0.0
	var t := (float(column) + 0.5 + stagger) / float(columns)
	var x := global_position.x - attack_line_width * 0.5 + t * attack_line_width
	var y := global_position.y - stop_distance - float(row) * row_spacing
	return Vector2(x, y)


func _get_perimeter_impact_for_x(world_x: float) -> Vector2:
	var line_left := global_position.x - attack_line_width * 0.5
	var line_right := global_position.x + attack_line_width * 0.5
	var t := clampf((world_x - line_left) / maxf(line_right - line_left, 1.0), 0.0, 1.0)
	var local_x := lerpf(-_impact_half_width, _impact_half_width, t)
	return global_position + Vector2(local_x, _impact_offset_for_x(global_position.x + local_x))


func _setup_ruin_visuals() -> void:
	if visual == null:
		return
	visual.self_modulate = Color.WHITE
	if visual.material is ShaderMaterial:
		_damage_material = visual.material as ShaderMaterial
	else:
		_damage_material = ShaderMaterial.new()
		_damage_material.shader = _DamageShader
		visual.material = _damage_material
	visual.use_parent_material = false
	if _damage_material.shader == null:
		_damage_material.shader = _DamageShader


func _setup_cracks() -> void:
	_cracks.clear()
	var leftover := get_node_or_null("Rubble")
	if leftover != null:
		leftover.queue_free()
	if visual == null or visual.texture == null:
		return

	visual.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var holder := visual.get_node_or_null("Cracks") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "Cracks"
		visual.add_child(holder)
	else:
		for child in holder.get_children():
			child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = _CRACK_SEED
	var tex := visual.texture.get_size()
	# Pixel coords on the castle PNG, converted to the centred sprite.
	var stems: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(160, 292), Vector2(280, 278), Vector2(410, 298), Vector2(470, 286)]),
		PackedVector2Array([Vector2(490, 310), Vector2(610, 292), Vector2(740, 308), Vector2(880, 286)]),
		PackedVector2Array([Vector2(210, 268), Vector2(230, 318), Vector2(248, 338)]),
		PackedVector2Array([Vector2(720, 262), Vector2(748, 322), Vector2(768, 340)]),
		PackedVector2Array([Vector2(340, 274), Vector2(360, 330)]),
		PackedVector2Array([Vector2(640, 270), Vector2(628, 328)]),
		PackedVector2Array([Vector2(190, 250), Vector2(300, 200), Vector2(430, 158)]),
		PackedVector2Array([Vector2(650, 156), Vector2(780, 198), Vector2(890, 248)]),
		PackedVector2Array([Vector2(250, 228), Vector2(360, 186), Vector2(420, 176)]),
		PackedVector2Array([Vector2(660, 174), Vector2(760, 210), Vector2(840, 236)]),
		PackedVector2Array([Vector2(120, 236), Vector2(70, 258), Vector2(48, 292), Vector2(90, 318)]),
		PackedVector2Array([Vector2(960, 234), Vector2(1010, 260), Vector2(1034, 294), Vector2(990, 320)]),
		PackedVector2Array([Vector2(470, 86), Vector2(510, 54), Vector2(560, 48), Vector2(610, 78)]),
		PackedVector2Array([Vector2(500, 150), Vector2(541, 96), Vector2(590, 148)]),
		PackedVector2Array([Vector2(80, 210), Vector2(84, 265), Vector2(140, 300)]),
		PackedVector2Array([Vector2(940, 208), Vector2(998, 266), Vector2(1040, 298)]),
		PackedVector2Array([Vector2(400, 240), Vector2(460, 220), Vector2(540, 228), Vector2(620, 218)]),
		PackedVector2Array([Vector2(280, 256), Vector2(400, 248), Vector2(520, 260)]),
	]
	for i in stems.size():
		var pts := _jagged_polyline(stems[i], tex, rng, 0.012 + float(i % 3) * 0.004)
		_add_crack_line(holder, pts, 0.03 + float(i) * 0.045, 3.2, 6.8)
		if i % 2 == 0:
			var branch := _crack_branch(stems[i], rng)
			if branch.size() >= 2:
				_add_crack_line(
					holder,
					_jagged_polyline(branch, tex, rng, 0.01),
					0.08 + float(i) * 0.045,
					2.0,
					4.2,
				)
	_add_crack_line(holder, _jagged_polyline(_arc_pixels(Vector2(84, 265), 76.0, 0.35, 2.45, 9), tex, rng, 0.006), 0.1, 3.0, 5.8)
	_add_crack_line(holder, _jagged_polyline(_arc_pixels(Vector2(84, 265), 60.0, 3.3, 5.2, 8), tex, rng, 0.006), 0.18, 2.4, 4.6)
	_add_crack_line(holder, _jagged_polyline(_arc_pixels(Vector2(541, 122), 104.0, -0.25, 2.15, 10), tex, rng, 0.005), 0.22, 3.4, 6.4)
	_add_crack_line(holder, _jagged_polyline(_arc_pixels(Vector2(541, 122), 86.0, 2.5, 4.7, 9), tex, rng, 0.005), 0.3, 2.6, 5.0)
	_add_crack_line(holder, _jagged_polyline(_arc_pixels(Vector2(998, 266), 76.0, 0.45, 2.55, 9), tex, rng, 0.006), 0.12, 3.0, 5.8)
	_add_crack_line(holder, _jagged_polyline(_arc_pixels(Vector2(998, 266), 60.0, 3.25, 5.15, 8), tex, rng, 0.006), 0.2, 2.4, 4.6)


func _jagged_polyline(
	pixels: PackedVector2Array,
	tex: Vector2,
	rng: RandomNumberGenerator,
	amp_uv: float,
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var half := tex * 0.5
	var subdiv := 7
	for i in pixels.size() - 1:
		var a: Vector2 = pixels[i]
		var b: Vector2 = pixels[i + 1]
		for s in subdiv:
			var t := float(s) / float(subdiv)
			var p := a.lerp(b, t)
			if s > 0 and s < subdiv:
				var delta := b - a
				var n := Vector2(-delta.y, delta.x)
				if n.length_squared() > 0.001:
					n = n.normalized()
				p += n * rng.randf_range(-1.0, 1.0) * amp_uv * tex.x * sin(t * PI)
			out.append(p - half)
		if i == pixels.size() - 2:
			out.append(b - half)
	return out


func _arc_pixels(center: Vector2, radius: float, a0: float, a1: float, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(count, 2)
	for i in n:
		var t := float(i) / float(n - 1)
		var a := lerpf(a0, a1, t)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


func _crack_branch(stem: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	if stem.size() < 2:
		return PackedVector2Array()
	var idx := clampi(rng.randi_range(0, stem.size() - 2), 0, stem.size() - 2)
	var origin: Vector2 = stem[idx]
	var along: Vector2 = stem[idx + 1] - stem[idx]
	if along.length_squared() < 4.0:
		along = Vector2(20.0, 8.0)
	var side := Vector2(-along.y, along.x).normalized()
	if rng.randf() < 0.5:
		side = -side
	var mid := origin + along * 0.35 + side * rng.randf_range(18.0, 42.0)
	var tip := mid + along * 0.45 + side * rng.randf_range(8.0, 24.0)
	return PackedVector2Array([origin, mid, tip])


func _add_crack_line(
	holder: Node2D,
	pts: PackedVector2Array,
	appear_at: float,
	width_min: float,
	width_max: float,
) -> void:
	if pts.size() < 2:
		return
	var line := Line2D.new()
	line.points = pts
	line.width = width_min
	line.default_color = Color(0.04, 0.03, 0.03, 1.0)
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.antialiased = true
	line.visible = false
	line.set_meta("appear_at", appear_at)
	line.set_meta("width_min", width_min)
	line.set_meta("width_max", width_max)
	holder.add_child(line)
	_cracks.append(line)


## Bottom HP bar: cracks spread from the courtyard up the walls and towers.
func _update_ruin_visual() -> void:
	if visual == null:
		return
	visual.self_modulate = Color.WHITE
	var d := 1.0 - clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if _damage_material != null:
		_damage_material.set_shader_parameter("ruin", d)
	for line in _cracks:
		if not is_instance_valid(line):
			continue
		var appear_at := float(line.get_meta("appear_at"))
		var shown := d >= appear_at
		line.visible = shown
		if shown:
			var grown := clampf((d - appear_at) / 0.2, 0.0, 1.0)
			line.modulate.a = lerpf(0.55, 1.0, grown)
			line.width = lerpf(
				float(line.get_meta("width_min")),
				float(line.get_meta("width_max")),
				grown,
			)


func _play_hit_shake() -> void:
	if visual == null:
		return
	var tween := create_tween()
	visual.position = Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))
	tween.tween_property(visual, "position", Vector2.ZERO, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

