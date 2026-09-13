@tool
extends Sprite2D

enum StretchMode {
	STRETCH,
	COVER,
	CONTAIN,
}

## Portrait design resolution for this project.
const DESIGN_SIZE := Vector2(1080.0, 1920.0)

@export var stretch_mode: StretchMode = StretchMode.COVER:
	set(value):
		stretch_mode = value
		_apply_design_fit()


func _ready() -> void:
	if not Engine.is_editor_hint():
		var viewport := get_viewport()
		if viewport != null and not viewport.size_changed.is_connected(_apply_design_fit):
			viewport.size_changed.connect(_apply_design_fit)
	_apply_design_fit()
	if not Engine.is_editor_hint():
		call_deferred("_apply_design_fit")


func _enter_tree() -> void:
	# Editor instances skip some of _ready until the scene is fully loaded;
	# fitting here keeps the sprite aligned with the 1080×1920 world.
	if Engine.is_editor_hint():
		call_deferred("_apply_design_fit")


func _apply_design_fit() -> void:
	if not is_inside_tree():
		return

	centered = true
	if Engine.is_editor_hint():
		position = DESIGN_SIZE * 0.5
		_stretch_to_target(DESIGN_SIZE)
		return

	var vis := get_viewport().get_visible_rect().size
	position = PlayfieldCamera.camera_position_for_view(vis)
	_stretch_to_target(Vector2(maxf(vis.x, DESIGN_SIZE.x), maxf(vis.y, DESIGN_SIZE.y)))


func _stretch_to_target(target: Vector2) -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	match stretch_mode:
		StretchMode.STRETCH:
			scale = Vector2(
				target.x / tex_size.x,
				target.y / tex_size.y,
			)
		StretchMode.COVER:
			var uniform_scale := maxf(
				target.x / tex_size.x,
				target.y / tex_size.y,
			)
			scale = Vector2(uniform_scale, uniform_scale)
		StretchMode.CONTAIN:
			var fit_scale := minf(
				target.x / tex_size.x,
				target.y / tex_size.y,
			)
			scale = Vector2(fit_scale, fit_scale)
