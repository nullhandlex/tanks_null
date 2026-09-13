extends TextureButton
class_name SettingsToggle

signal setting_changed(enabled: bool)

const TEX_ACT := preload("res://assets/ui/figma_settings/btn_set_act.png")
const TEX_PASS := preload("res://assets/ui/figma_settings/btn_set_pass.png")
const LABEL_ACT := preload("res://resources/ui/label_snd_act.tres")
const LABEL_PASS := preload("res://resources/ui/label_snd_pass.tres")
const _Press := preload("res://scripts/ui/press_feedback.gd")

@export var title: String = "Музыка"
@export var enabled: bool = true
@export var icon_act: Texture2D
@export var icon_pass: Texture2D

@onready var _label: Label = %ToggleLabel
@onready var _icon: TextureRect = %ToggleIcon


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_Press.bind(self)
	pressed.connect(_on_pressed)
	_apply()


func set_title(value: String) -> void:
	title = value
	if is_node_ready():
		_apply()


func set_enabled(value: bool, notify: bool = false) -> void:
	enabled = value
	_apply()
	if notify:
		setting_changed.emit(enabled)


func _on_pressed() -> void:
	set_enabled(not enabled, true)


func _apply() -> void:
	texture_normal = TEX_ACT if enabled else TEX_PASS
	texture_pressed = texture_normal
	texture_hover = texture_normal
	if _label:
		_label.text = title
		_label.label_settings = LABEL_ACT if enabled else LABEL_PASS
	if _icon:
		_icon.texture = icon_act if enabled else icon_pass
		_icon.visible = _icon.texture != null
	var row := _label.get_parent() if _label != null else null
	if row is Control:
		(row as Control).reset_size()
