extends Control

enum Tab { SETTINGS, BASE, BATTLE, WALLET }

const ARENAS: Array[Dictionary] = [
	{"id": 1, "title": "Арена 1: Поле", "playable": true},
	{"id": 2, "title": "Арена 2", "playable": false},
	{"id": 3, "title": "Арена 3", "playable": false},
]

const TAB_NORMAL: Array[Texture2D] = [
	preload("res://assets/ui/settings.png"),
	preload("res://assets/ui/base_off.png"),
	preload("res://assets/ui/fight.png"),
	preload("res://assets/ui/wallet.png"),
]

const TAB_ACTIVE: Array[Texture2D] = [
	preload("res://assets/ui/settings_act.png"),
	preload("res://assets/ui/base_off.png"),
	preload("res://assets/ui/fight_act.png"),
	preload("res://assets/ui/wallet_act.png"),
]

const TAB_INACTIVE_HEIGHT := 200.0
const TAB_ACTIVE_HEIGHT := 225.0
const TAB_BAR_HEIGHT := 225.0

const _Press := preload("res://scripts/ui/press_feedback.gd")

var _arena_index: int = 0
var _tab: Tab = Tab.BATTLE
var _on_account: bool = false

@onready var menu_header: MenuHeader = %MenuHeader
@onready var title_label: Label = %TitleLabel
@onready var map_preview: TextureRect = %MapPreview
@onready var lock_overlay: TextureRect = %LockOverlay
@onready var start_button: TextureButton = %StartButton
@onready var prev_button: Button = %PrevArena
@onready var next_button: Button = %NextArena
@onready var level_select: Control = %LevelSelect
@onready var coming_soon: Control = %ComingSoon
@onready var coming_soon_label: Label = %ComingSoonLabel
@onready var base_lock_label: Label = %BaseLockLabel
@onready var settings_root: Control = %SettingsRoot
@onready var account_root: Control = %AccountRoot
@onready var music_toggle: SettingsToggle = %MusicToggle
@onready var vibro_toggle: SettingsToggle = %VibroToggle
@onready var sfx_toggle: SettingsToggle = %SfxToggle
@onready var account_button: TextureButton = %AccountButton
@onready var quit_button: TextureButton = %QuitButton
@onready var save_button: BaseButton = %SaveButton
@onready var back_button: BaseButton = %BackButton
@onready var account_stub_fill: TextureRect = %AccountStubFill
@onready var account_stub_knight: TextureRect = %AccountStubKnight
@onready var account_avatar: TextureRect = %AccountAvatar
@onready var account_avatar_hit: BaseButton = %AccountAvatarHit
@onready var name_field: AccountField = %NameField
@onready var email_field: AccountField = %EmailField
@onready var phone_field: AccountField = %PhoneField
@onready var age_field: AccountField = %AgeField
@onready var preview_name: Label = %PreviewName
@onready var preview_age: Label = %PreviewAge
@onready var preview_email: Label = %PreviewEmail
@onready var preview_phone: Label = %PreviewPhone
@onready var tab_buttons: Array[TextureButton] = [
	%TabSettings,
	%TabBase,
	%TabBattle,
	%TabWallet,
]


func _ready() -> void:
	_update_coins_display()
	_Press.bind(start_button)
	_Press.bind(account_button)
	_Press.bind(quit_button)
	_Press.bind(save_button)
	_Press.bind(back_button)
	_Press.bind(account_avatar_hit)
	start_button.pressed.connect(_on_start_pressed)
	prev_button.pressed.connect(_on_prev_arena)
	next_button.pressed.connect(_on_next_arena)
	account_button.pressed.connect(_open_account)
	if menu_header != null:
		menu_header.profile_pressed.connect(_open_account)
	quit_button.pressed.connect(_on_quit_pressed)
	save_button.pressed.connect(_on_save_account_pressed)
	back_button.pressed.connect(_open_settings_home)
	account_avatar_hit.pressed.connect(_pick_avatar)
	name_field.configure("Имя", "Введите ваше имя")
	age_field.configure("Возраст", "Укажите сколько Вам полных лет", LineEdit.KEYBOARD_TYPE_NUMBER)
	phone_field.configure("Телефон", "Введите ваш номер телефона", LineEdit.KEYBOARD_TYPE_PHONE)
	email_field.configure("Почта", "Введите ваш e-mail", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	music_toggle.setting_changed.connect(_on_music_changed)
	vibro_toggle.setting_changed.connect(_on_vibro_changed)
	sfx_toggle.setting_changed.connect(_on_sfx_changed)
	resized.connect(_layout_tabs)
	for i in tab_buttons.size():
		if i == Tab.BASE:
			continue
		var tab_index := i
		tab_buttons[i].pressed.connect(func () -> void:
			_select_tab(tab_index, true)
		)
	_refresh_arena()
	_load_settings_into_ui()
	_select_tab(Tab.BATTLE)
	await get_tree().process_frame
	_layout_tabs()


func _load_settings_into_ui() -> void:
	music_toggle.set_title("Музыка")
	vibro_toggle.set_title("Вибро")
	sfx_toggle.set_title("Звуковые эффекты")
	music_toggle.set_enabled(GameData.music_enabled)
	vibro_toggle.set_enabled(GameData.vibro_enabled)
	sfx_toggle.set_enabled(GameData.sfx_enabled)
	name_field.set_value(GameData.player_name)
	email_field.set_value(GameData.player_email)
	phone_field.set_value(GameData.player_phone)
	age_field.set_value(GameData.player_age)
	_apply_avatar()
	_refresh_account_preview()
	if menu_header != null:
		menu_header.refresh()


func _apply_avatar() -> void:
	var path := GameData.player_avatar_path.strip_edges()
	var tex: Texture2D = null
	if not path.is_empty() and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	var custom := tex != null
	if account_avatar != null:
		account_avatar.visible = custom
		if custom:
			account_avatar.texture = tex
	if account_stub_fill != null:
		account_stub_fill.visible = not custom
	if account_stub_knight != null:
		account_stub_knight.visible = not custom
	if menu_header != null:
		menu_header.refresh()


func _update_coins_display() -> void:
	if menu_header != null:
		menu_header.refresh()


func _arena_id() -> int:
	return int(ARENAS[_arena_index]["id"])


func _is_arena_unlocked() -> bool:
	return bool(ARENAS[_arena_index].get("playable", false))


func _refresh_arena() -> void:
	var arena: Dictionary = ARENAS[_arena_index]
	title_label.text = str(arena["title"])
	var unlocked := _is_arena_unlocked()
	lock_overlay.visible = not unlocked
	map_preview.modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.5, 1.0)
	start_button.disabled = not unlocked
	start_button.modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.55, 1.0)


func _on_prev_arena() -> void:
	_arena_index = (_arena_index - 1 + ARENAS.size()) % ARENAS.size()
	_refresh_arena()


func _on_next_arena() -> void:
	_arena_index = (_arena_index + 1) % ARENAS.size()
	_refresh_arena()


func _on_start_pressed() -> void:
	if not _is_arena_unlocked():
		return
	get_tree().change_scene_to_file("res://scenes/battle/BattleLevel.tscn")


func _select_tab(tab_index: int, from_tab_button: bool = false) -> void:
	if tab_index == Tab.BASE:
		return
	if from_tab_button and tab_index == Tab.SETTINGS and _on_account:
		_open_settings_home()
		return
	_tab = tab_index
	if _tab != Tab.SETTINGS:
		_on_account = false
	var show_battle := _tab == Tab.BATTLE
	var show_settings := _tab == Tab.SETTINGS
	level_select.visible = show_battle
	coming_soon.visible = _tab == Tab.WALLET
	settings_root.visible = show_settings and not _on_account
	account_root.visible = show_settings and _on_account
	if _tab == Tab.WALLET:
		coming_soon_label.text = "Кошелёк — скоро"
	_layout_tabs()
	if menu_header != null:
		menu_header.queue_redraw()


func _open_account() -> void:
	_on_account = true
	_load_settings_into_ui()
	_select_tab(Tab.SETTINGS)


func _open_settings_home() -> void:
	_on_account = false
	_select_tab(Tab.SETTINGS)


func _on_save_account_pressed() -> void:
	_save_account_fields()


func _refresh_account_preview() -> void:
	var filled_name := GameData.player_name.strip_edges()
	preview_name.text = filled_name
	var age_digits := _digits_only(GameData.player_age)
	preview_age.text = _format_age(age_digits)
	preview_email.text = GameData.player_email.strip_edges()
	preview_phone.text = GameData.player_phone.strip_edges()


func _format_age(digits: String) -> String:
	if digits.is_empty():
		return ""
	var years := int(digits)
	if years <= 0:
		return ""
	var mod100 := years % 100
	var mod10 := years % 10
	var word := "лет"
	if mod100 < 11 or mod100 > 14:
		if mod10 == 1:
			word = "год"
		elif mod10 >= 2 and mod10 <= 4:
			word = "года"
	return "%d %s" % [years, word]


func _pick_avatar() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()
	if DisplayServer.has_method("file_dialog_show"):
		var err := DisplayServer.file_dialog_show(
			"Выберите фото",
			OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
			"",
			false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"]),
			_on_native_avatar
		)
		if err == OK:
			return
	_pick_avatar_fallback()


func _on_native_avatar(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if not status or paths.is_empty():
		return
	_apply_picked_avatar(paths[0])


func _pick_avatar_fallback() -> void:
	var existing := get_node_or_null("AvatarDialog") as FileDialog
	if existing != null:
		existing.queue_free()
	var dlg := FileDialog.new()
	dlg.name = "AvatarDialog"
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
	dlg.file_selected.connect(_apply_picked_avatar)
	add_child(dlg)
	dlg.popup_centered_ratio(0.7)


func _apply_picked_avatar(path: String) -> void:
	if path.strip_edges().is_empty():
		return
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		push_warning("Account: failed to load image from %s" % path)
		return
	var longest := maxi(img.get_width(), img.get_height())
	if longest > 512:
		var scale := 512.0 / float(longest)
		img.resize(
			maxi(1, int(round(img.get_width() * scale))),
			maxi(1, int(round(img.get_height() * scale))),
			Image.INTERPOLATE_LANCZOS
		)
	var dest := "user://avatar.png"
	var save_err := img.save_png(dest)
	if save_err != OK:
		push_warning("Account: failed to save avatar.")
		return
	GameData.player_avatar_path = dest
	GameData.save_progress()
	_apply_avatar()


func _on_music_changed(enabled: bool) -> void:
	GameData.music_enabled = enabled
	GameData.save_progress()


func _on_vibro_changed(enabled: bool) -> void:
	GameData.vibro_enabled = enabled
	GameData.save_progress()


func _on_sfx_changed(enabled: bool) -> void:
	GameData.sfx_enabled = enabled
	GameData.save_progress()


func _save_account_fields() -> void:
	GameData.player_name = name_field.get_value()
	GameData.player_email = email_field.get_value()
	GameData.player_phone = phone_field.get_value()
	GameData.player_age = _digits_only(age_field.get_value())
	if age_field.get_value() != GameData.player_age:
		age_field.set_value(GameData.player_age)
	GameData.save_progress()
	_refresh_account_preview()
	if menu_header != null:
		menu_header.refresh()


func _digits_only(value: String) -> String:
	var out := ""
	for ch in value:
		if ch >= "0" and ch <= "9":
			out += ch
	return out


func _on_quit_pressed() -> void:
	get_tree().quit()


func _layout_tabs() -> void:
	if tab_buttons.is_empty():
		return
	var nav := tab_buttons[0].get_parent() as Control
	var nav_width := nav.size.x if nav.size.x > 1.0 else size.x
	if nav_width <= 1.0:
		nav_width = 1080.0
	var tab_width := nav_width / float(tab_buttons.size())
	for i in tab_buttons.size():
		var button := tab_buttons[i]
		var is_base := i == Tab.BASE
		var active := (not is_base) and i == int(_tab)
		button.texture_normal = TAB_ACTIVE[i] if active else TAB_NORMAL[i]
		button.texture_pressed = TAB_ACTIVE[i]
		button.disabled = is_base
		button.modulate = Color(0.48, 0.48, 0.54, 1.0) if is_base else Color.WHITE
		var height := TAB_ACTIVE_HEIGHT if active else TAB_INACTIVE_HEIGHT
		button.position = Vector2(tab_width * i, TAB_BAR_HEIGHT - height)
		button.size = Vector2(tab_width, height)
		if is_base:
			base_lock_label.position = Vector2(button.position.x, button.position.y + 6.0)
			base_lock_label.size = Vector2(button.size.x, button.size.y * 0.52)
