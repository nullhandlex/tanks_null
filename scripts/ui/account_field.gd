extends Control
class_name AccountField

signal committed(value: String)

@export var title: String = ""
@export var placeholder: String = ""
@export var keyboard: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT

@onready var title_label: Label = %TitleLabel
@onready var field: LineEdit = %Field


func _ready() -> void:
	_apply()
	field.text_submitted.connect(func (_t: String) -> void: committed.emit(get_value()))


func configure(
	p_title: String,
	p_placeholder: String,
	p_keyboard: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT
) -> void:
	title = p_title
	placeholder = p_placeholder
	keyboard = p_keyboard
	if is_node_ready():
		_apply()


func _apply() -> void:
	if title_label != null:
		title_label.text = title
	if field != null:
		field.placeholder_text = placeholder
		field.virtual_keyboard_type = keyboard


func get_value() -> String:
	return field.text.strip_edges() if field else ""


func set_value(value: String) -> void:
	if not is_node_ready():
		await ready
	field.text = value
