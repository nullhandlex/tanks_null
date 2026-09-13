class_name MenuHeader
extends Control

## Shared player header: plates, avatar, name, coins.
## Used on every main-menu tab and on win/lose result screens.

signal profile_pressed

const NAME_PLACEHOLDER := "Зарегистрироваться"
const AVATAR_STUB := preload("res://assets/ui/avatar_stub.png")
const NAME_SETTINGS := preload("res://resources/ui/label_header_name.tres")

@export var name_interactive: bool = true

@onready var plates: TextureRect = $HeaderPlates
@onready var name_label: Label = $NameLabel
@onready var name_hit: Button = $NameHit
@onready var coins_label: Label = $CoinsLabel
@onready var header_avatar: TextureRect = $HeaderAvatar
@onready var header_stub_fill: TextureRect = $HeaderStubFill
@onready var header_stub_knight: TextureRect = $HeaderStubKnight

const PLATE_NATIVE := Vector2(1127.0, 202.0)


func _ready() -> void:
	if name_hit != null:
		name_hit.pressed.connect(_on_name_hit)
		_apply_interactive()
	resized.connect(_fit_plates)
	_fit_plates()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_plates()


func _fit_plates() -> void:
	var width := size.x
	if width < 2.0:
		width = 1080.0
	var height := width * (PLATE_NATIVE.y / PLATE_NATIVE.x)
	if plates != null:
		plates.offset_top = 0.0
		plates.offset_bottom = height
	offset_bottom = maxf(height, 230.0)


func set_name_interactive(enabled: bool) -> void:
	name_interactive = enabled
	_apply_interactive()


func refresh() -> void:
	_update_name()
	_update_coins()
	_update_avatar()


func _apply_interactive() -> void:
	if name_hit == null:
		return
	name_hit.visible = name_interactive
	name_hit.mouse_filter = (
		MOUSE_FILTER_STOP if name_interactive else MOUSE_FILTER_IGNORE
	)


func _update_name() -> void:
	if name_label == null:
		return
	var filled := GameData.player_name.strip_edges()
	name_label.label_settings = NAME_SETTINGS
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text = NAME_PLACEHOLDER if filled.is_empty() else filled


func _update_coins() -> void:
	if coins_label != null:
		coins_label.text = str(GameData.total_coins)


func _update_avatar() -> void:
	var path := GameData.player_avatar_path.strip_edges()
	var tex: Texture2D = AVATAR_STUB
	if not path.is_empty() and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	var custom := tex != AVATAR_STUB
	if header_avatar != null:
		header_avatar.visible = custom
		if custom:
			header_avatar.texture = tex
	if header_stub_fill != null:
		header_stub_fill.visible = not custom
	if header_stub_knight != null:
		header_stub_knight.visible = not custom


func _on_name_hit() -> void:
	if name_interactive:
		profile_pressed.emit()
