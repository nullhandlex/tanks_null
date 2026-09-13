extends Node2D

## Roster for this level, ordered weakest to strongest; the wave table indexes
## into it. Gatling, Minigun, Mine and Boss Anigil are held back for the next level.
const ENEMY_TYPES: Array[PackedScene] = [
	preload("res://scenes/enemies/EnemySoldier.tscn"),
	preload("res://scenes/enemies/EnemyCar.tscn"),
	preload("res://scenes/enemies/EnemyTank.tscn"),
	preload("res://scenes/enemies/EnemyTos.tscn"),
	preload("res://scenes/enemies/EnemyHeavyTank.tscn"),
	preload("res://scenes/enemies/BossDora.tscn"),
]

## One row per wave, one count per ENEMY_TYPES entry. The boss only shows up in
## the final wave, escorted by a full complement of regulars.
const WAVE_TABLE := [
	#sold car tank tos heavy boss
	[4, 2, 1, 0, 0, 0],
	[5, 3, 2, 0, 0, 0],
	[6, 4, 2, 1, 0, 0],
	[6, 5, 3, 1, 1, 0],
	[7, 5, 4, 2, 1, 0],
	[8, 6, 4, 2, 2, 0],
	[9, 6, 5, 3, 2, 0],
	[10, 7, 5, 3, 3, 0],
	[11, 8, 6, 4, 3, 0],
	[12, 8, 6, 4, 4, 1],
]

const HINT_HOLD_SEC := 1.8
const HINT_FADE_SEC := 0.7
const DESIGN_SPAWN_Y := 96.0
const NAV_TOP_DESIGN := 60.0
const NAV_BOTTOM := 1540.0
const NAV_LEFT := 40.0
const NAV_RIGHT := 1040.0
const HP_BAR_HEIGHT := 14.0
const BASE_TO_HP_OVERLAP := 6.0

@onready var base_node: Node2D = $World/Base
@onready var spawners: Array[Node] = [
	$World/Spawners/EnemySpawnerLeft,
	$World/Spawners/EnemySpawnerLeftCenter,
	$World/Spawners/EnemySpawnerRightCenter,
	$World/Spawners/EnemySpawnerRight,
]
@onready var enemies_container: Node2D = $World/Enemies
@onready var wave_label: Label = $UI/BattleUI/TopBar/VBoxContainer/WaveLabel
@onready var enemies_label: Label = $UI/BattleUI/TopBar/VBoxContainer/EnemiesLabel
@onready var hint_banner: Control = $UI/BattleUI/HintBanner
@onready var base_health_bar: Control = $UI/BattleUI/BaseHealth
@onready var level_coins_label: Label = $UI/BattleUI/TopBar/VBoxContainer/LevelCoinsLabel
@onready var energy_bar: Control = $UI/BattleUI/EnergyBar
@onready var pause_button: TextureButton = $UI/BattleUI/PauseButton
@onready var pause_menu: PauseMenu = $UI/PauseMenu
@onready var result_screen: Control = $UI/ResultScreen

const _Press := preload("res://scripts/ui/press_feedback.gd")
const _UltWeapons := preload("res://scripts/battle/ult_weapons.gd")

var _hint_pulse: Tween
var _enemy_pool: EnemyPool


func _ready() -> void:
	_enemy_pool = EnemyPool.new()
	_enemy_pool.name = "EnemyPool"
	add_child(_enemy_pool)
	for spawner in spawners:
		spawner.enemy_pool = _enemy_pool

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_fit_playfield):
		viewport.size_changed.connect(_fit_playfield)
	_fit_playfield()

	var waves := _build_prototype_waves()
	GameManager.register_battle_level(base_node, spawners, enemies_container, waves)
	_setup_ult_weapons()

	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.battle_coins_changed.connect(_on_battle_coins_changed)
	GameManager.battle_state_changed.connect(_on_battle_state_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	GameManager.wave_cleared.connect(_on_wave_cleared)
	GameManager.enemies_alive_changed.connect(_on_enemies_alive_changed)

	if base_node != null and base_node.has_signal("health_changed"):
		base_node.health_changed.connect(_on_base_health_changed)
		_on_base_health_changed(base_node.hp, base_node.max_hp)

	result_screen.claim_pressed.connect(_on_result_claim_pressed)
	result_screen.hide_result()

	_Press.bind(pause_button)
	pause_button.pressed.connect(_on_pause_pressed)
	pause_menu.resume_pressed.connect(_on_pause_resume)
	pause_menu.menu_pressed.connect(_on_pause_to_menu)
	pause_menu.quit_pressed.connect(_on_pause_quit)
	_on_energy_changed(GameManager.energy, GameManager.MAX_ENERGY)

	_update_battle_coins_label(GameManager.coins_earned_for_level)
	_on_enemies_alive_changed(0)
	_show_intro_hint()

	# Started last so the first wave_changed signal reaches the already-wired UI.
	GameManager.start_battle(1)
	_prewarm_enemy_pool()


func _fit_playfield() -> void:
	if not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var visible_top := PlayfieldCamera.visible_top_for_view(vis)
	var spawn_y := visible_top + DESIGN_SPAWN_Y
	for spawner in spawners:
		if spawner is Node2D:
			(spawner as Node2D).position.y = spawn_y
	_snap_base_to_hp_bar()
	_fit_navigation(visible_top + NAV_TOP_DESIGN)


func _snap_base_to_hp_bar() -> void:
	if base_node == null or not base_node.has_method("get_visual_half_height"):
		return
	var half_height := float(base_node.get_visual_half_height())
	if half_height <= 0.0:
		return
	base_node.position.y = (
		PlayfieldCamera.DESIGN_SIZE.y - HP_BAR_HEIGHT + BASE_TO_HP_OVERLAP - half_height
	)


func _fit_navigation(top_y: float) -> void:
	var region := $World/NavigationRegion2D as NavigationRegion2D
	if region == null:
		return
	var outline := PackedVector2Array([
		Vector2(NAV_LEFT, top_y),
		Vector2(NAV_RIGHT, top_y),
		Vector2(NAV_RIGHT, NAV_BOTTOM),
		Vector2(NAV_LEFT, NAV_BOTTOM),
	])
	var poly := NavigationPolygon.new()
	poly.vertices = outline
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	poly.add_outline(outline)
	region.navigation_polygon = poly


func _prewarm_enemy_pool() -> void:
	if _enemy_pool == null:
		return
	var counts := [3, 2, 1, 1, 1, 1]
	for type_index in mini(ENEMY_TYPES.size(), counts.size()):
		for _n in counts[type_index]:
			_enemy_pool.prewarm(ENEMY_TYPES[type_index], 1)
			await get_tree().process_frame


func _build_prototype_waves() -> Array[WaveDefinition]:
	var waves: Array[WaveDefinition] = []
	for counts in WAVE_TABLE:
		waves.append(_make_wave(counts))
	return waves


func _make_wave(counts: Array) -> WaveDefinition:
	var wave := WaveDefinition.new()
	var entries: Array[WaveEntry] = []
	for index in mini(counts.size(), ENEMY_TYPES.size()):
		if int(counts[index]) <= 0:
			continue
		entries.append(_make_wave_entry(ENEMY_TYPES[index], int(counts[index])))
	wave.entries = entries
	return wave


func _make_wave_entry(enemy_scene: PackedScene, count: int) -> WaveEntry:
	var entry := WaveEntry.new()
	entry.enemy_scene = enemy_scene
	entry.count = count
	entry.spawner_index = 0
	return entry


func _on_base_health_changed(current_hp: float, max_hp: float) -> void:
	if base_health_bar != null and base_health_bar.has_method("update_hp"):
		base_health_bar.update_hp(current_hp, max_hp)


func _on_battle_coins_changed(amount: int) -> void:
	_update_battle_coins_label(amount)


func _setup_ult_weapons() -> void:
	var ult := _UltWeapons.new()
	ult.name = "UltWeapons"
	add_child(ult)
	ult.setup(base_node, $Effects)


func _on_energy_changed(current: float, max_energy: float) -> void:
	if energy_bar != null and energy_bar.has_method("set_fill_ratio"):
		energy_bar.set_fill_ratio(current / maxf(max_energy, 1.0))


func _show_intro_hint() -> void:
	if hint_banner == null:
		return
	hint_banner.visible = true
	hint_banner.modulate = Color(1, 1, 1, 1)
	hint_banner.scale = Vector2.ONE
	await get_tree().process_frame
	hint_banner.pivot_offset = hint_banner.size * 0.5

	if _hint_pulse != null:
		_hint_pulse.kill()
	_hint_pulse = create_tween()
	_hint_pulse.set_loops()
	_hint_pulse.tween_property(hint_banner, "scale", Vector2(1.05, 1.05), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_pulse.tween_property(hint_banner, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var hold := get_tree().create_timer(HINT_HOLD_SEC)
	hold.timeout.connect(_hide_intro_hint)


func _hide_intro_hint() -> void:
	if hint_banner == null:
		return
	if _hint_pulse != null:
		_hint_pulse.kill()
		_hint_pulse = null
	var fade := create_tween()
	fade.tween_property(hint_banner, "modulate:a", 0.0, HINT_FADE_SEC)
	fade.finished.connect(func () -> void:
		hint_banner.visible = false
		hint_banner.scale = Vector2.ONE
	)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _on_pause_pressed() -> void:
	if result_screen != null and result_screen.visible:
		return
	_set_paused(not get_tree().paused)


func _on_pause_resume() -> void:
	_set_paused(false)


func _on_pause_to_menu() -> void:
	_set_paused(false)
	GameManager.clear_battle_registration()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _on_pause_quit() -> void:
	_set_paused(false)
	get_tree().quit()


func _set_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = paused
	if is_instance_valid(pause_menu):
		if paused:
			pause_menu.show_menu()
		else:
			pause_menu.hide_menu()


func _on_battle_state_changed(state: GameManager.BattleState) -> void:
	if state == GameManager.BattleState.VICTORY or state == GameManager.BattleState.DEFEAT:
		_set_paused(false)
	match state:
		GameManager.BattleState.VICTORY:
			var reward := GameManager.get_final_reward(true)
			result_screen.show_result(
				reward,
				true,
				GameManager.get_waves_completed(),
				GameManager.get_total_waves(),
			)
		GameManager.BattleState.DEFEAT:
			var reward := GameManager.get_final_reward(false)
			result_screen.show_result(
				reward,
				false,
				GameManager.get_waves_completed(),
				GameManager.get_total_waves(),
			)


func _on_wave_changed(wave_number: int, total_waves: int) -> void:
	wave_label.text = "Волн: %d / %d" % [wave_number, total_waves]


func _on_wave_cleared(_wave_number: int) -> void:
	pass


func _on_enemies_alive_changed(count: int) -> void:
	enemies_label.text = "Количество врагов: %d" % count


func _on_result_claim_pressed() -> void:
	var victory := GameManager.battle_state == GameManager.BattleState.VICTORY
	GameManager.claim_reward(victory)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _update_battle_coins_label(amount: int) -> void:
	level_coins_label.text = "Коины: %d" % amount
