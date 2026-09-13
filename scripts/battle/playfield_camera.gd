class_name PlayfieldCamera
extends Camera2D

## Pins the 1080×1920 playfield to the bottom of the screen so the Base sits
## on the HP bar. Extra height on tall phones opens above the spawn line.
const DESIGN_SIZE := Vector2(1080.0, 1920.0)


static func camera_position_for_view(view_size: Vector2) -> Vector2:
	var vis := Vector2(maxf(view_size.x, 1.0), maxf(view_size.y, 1.0))
	return Vector2(DESIGN_SIZE.x * 0.5, DESIGN_SIZE.y - vis.y * 0.5)


static func visible_top_for_view(view_size: Vector2) -> float:
	return DESIGN_SIZE.y - maxf(view_size.y, 1.0)


func _ready() -> void:
	enabled = true
	make_current()
	ignore_rotation = true
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(fit_to_screen):
		viewport.size_changed.connect(fit_to_screen)
	fit_to_screen()


func fit_to_screen() -> void:
	position = camera_position_for_view(get_viewport().get_visible_rect().size)
