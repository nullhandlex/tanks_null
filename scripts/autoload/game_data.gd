extends Node

## Persistent progression singleton.
## Owns total coins, completed/unlocked levels, and save/load.

const SAVE_PATH := "user://savegame.json"

var total_coins: int = 0
var player_name: String = ""
var player_email: String = ""
var player_phone: String = ""
var player_age: String = ""
var player_avatar_path: String = ""
var music_enabled: bool = true
var vibro_enabled: bool = true
var sfx_enabled: bool = true
var completed_levels: Array[int] = []
var unlocked_levels: Array[int] = [1]


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_to_defaults()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameData: failed to open save file.")
		_reset_to_defaults()
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameData: invalid save format.")
		_reset_to_defaults()
		return

	var data: Dictionary = parsed
	total_coins = int(data.get("total_coins", 0))
	player_name = str(data.get("player_name", ""))
	player_email = str(data.get("player_email", ""))
	player_phone = str(data.get("player_phone", ""))
	player_age = str(data.get("player_age", ""))
	player_avatar_path = str(data.get("player_avatar_path", ""))
	music_enabled = bool(data.get("music_enabled", true))
	vibro_enabled = bool(data.get("vibro_enabled", true))
	sfx_enabled = bool(data.get("sfx_enabled", true))
	if player_name.strip_edges().to_lower() in ["зарегистрироваться", "нужно ввести данные"]:
		player_name = ""
	completed_levels = _to_int_array(data.get("completed_levels", []))
	unlocked_levels = _to_int_array(data.get("unlocked_levels", [1]))

	if unlocked_levels.is_empty():
		unlocked_levels = [1]

	print("GameData: loaded total_coins = ", total_coins)


func save_progress() -> void:
	var data := {
		"total_coins": total_coins,
		"player_name": player_name,
		"player_email": player_email,
		"player_phone": player_phone,
		"player_age": player_age,
		"player_avatar_path": player_avatar_path,
		"music_enabled": music_enabled,
		"vibro_enabled": vibro_enabled,
		"sfx_enabled": sfx_enabled,
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
	}
	var json_text := JSON.stringify(data, "\t")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameData: failed to write save file.")
		return

	file.store_string(json_text)
	print("GameData: saved total_coins = ", total_coins)


func mark_level_completed(level_id: int) -> void:
	if level_id not in completed_levels:
		completed_levels.append(level_id)

	var next_level_id := level_id + 1
	if next_level_id not in unlocked_levels:
		unlocked_levels.append(next_level_id)

	save_progress()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	total_coins += amount
	save_progress()


func _reset_to_defaults() -> void:
	total_coins = 0
	player_name = ""
	player_email = ""
	player_phone = ""
	player_age = ""
	player_avatar_path = ""
	music_enabled = true
	vibro_enabled = true
	sfx_enabled = true
	completed_levels = []
	unlocked_levels = [1]


func _to_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(int(item))
	return result
