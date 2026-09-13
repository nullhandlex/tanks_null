class_name PauseMenu
extends Control

signal resume_pressed
signal menu_pressed
signal quit_pressed

const _Press := preload("res://scripts/ui/press_feedback.gd")

@onready var music_toggle: SettingsToggle = %MusicToggle
@onready var vibro_toggle: SettingsToggle = %VibroToggle
@onready var sfx_toggle: SettingsToggle = %SfxToggle
@onready var menu_button: TextureButton = %MenuButton
@onready var quit_button: TextureButton = %QuitButton
@onready var continue_button: TextureButton = %ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_Press.bind(menu_button)
	_Press.bind(quit_button)
	_Press.bind(continue_button)
	menu_button.pressed.connect(func () -> void: menu_pressed.emit())
	quit_button.pressed.connect(func () -> void: quit_pressed.emit())
	continue_button.pressed.connect(func () -> void: resume_pressed.emit())
	music_toggle.setting_changed.connect(_on_music_changed)
	vibro_toggle.setting_changed.connect(_on_vibro_changed)
	sfx_toggle.setting_changed.connect(_on_sfx_changed)


func show_menu() -> void:
	_sync_toggles()
	visible = true


func hide_menu() -> void:
	visible = false


func _sync_toggles() -> void:
	if music_toggle == null:
		return
	music_toggle.set_title("Музыка")
	vibro_toggle.set_title("Вибро")
	sfx_toggle.set_title("Звуковые эффекты")
	music_toggle.set_enabled(GameData.music_enabled)
	vibro_toggle.set_enabled(GameData.vibro_enabled)
	sfx_toggle.set_enabled(GameData.sfx_enabled)


func _on_music_changed(enabled: bool) -> void:
	GameData.music_enabled = enabled
	GameData.save_progress()


func _on_vibro_changed(enabled: bool) -> void:
	GameData.vibro_enabled = enabled
	GameData.save_progress()


func _on_sfx_changed(enabled: bool) -> void:
	GameData.sfx_enabled = enabled
	GameData.save_progress()
