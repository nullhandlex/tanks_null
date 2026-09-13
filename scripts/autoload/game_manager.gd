extends Node

## Battle flow manager.
## Owns wave state, spawner queues, battle coins, and victory/defeat.

enum BattleState {
	PREPARING,
	WAVE_ACTIVE,
	TRANSITION,
	VICTORY,
	DEFEAT,
}

signal battle_state_changed(state: BattleState)
signal battle_coins_changed(amount: int)
signal wave_changed(wave_number: int, total_waves: int)
signal wave_cleared(wave_number: int)
signal enemies_alive_changed(count: int)
signal energy_changed(current: float, max_energy: float)

const VICTORY_MULTIPLIER := 1.5
const WAVE_TRANSITION_SEC := 2.0
const SPAWN_STAGGER_SEC := 0.3

const MAX_ENERGY := 100.0
## Ult unlock thresholds double as their activation costs.
const MG_ULT_COST := 50.0
const CANNON_ULT_COST := 100.0

var current_level_id: int = 1
var battle_state: BattleState = BattleState.PREPARING
var current_wave_index: int = -1
var coins_earned_for_level: int = 0
var reward_claimed: bool = false
var energy: float = 0.0

var _waves: Array[WaveDefinition] = []
var _base_ref: Node2D = null
var _enemies_container: Node2D = null
var _spawners: Array[Node] = []
var _enemies_alive: int = 0
var _spawners_finished: int = 0
var _active_spawners: int = 0


func _ready() -> void:
	clear_battle_registration()


func reset_battle() -> void:
	current_wave_index = -1
	coins_earned_for_level = 0
	reward_claimed = false
	_enemies_alive = 0
	_spawners_finished = 0
	_active_spawners = 0
	energy = 0.0
	energy_changed.emit(energy, MAX_ENERGY)
	_set_battle_state(BattleState.PREPARING)


func clear_battle_registration() -> void:
	reset_battle()
	_waves.clear()
	_base_ref = null
	_enemies_container = null
	_spawners.clear()


func is_combat_active() -> bool:
	return battle_state == BattleState.WAVE_ACTIVE


func register_battle_level(
	base: Node2D,
	spawners: Array[Node],
	enemies_container: Node2D,
	waves: Array[WaveDefinition],
) -> void:
	_base_ref = base
	_spawners = spawners.duplicate()
	_enemies_container = enemies_container
	_waves = waves.duplicate()

	for spawner in _spawners:
		if spawner.has_signal("enemy_spawned") and not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			spawner.enemy_spawned.connect(_on_enemy_spawned)
		if spawner.has_signal("queue_empty") and not spawner.queue_empty.is_connected(_on_spawner_queue_empty):
			spawner.queue_empty.connect(_on_spawner_queue_empty)

	if _base_ref != null and _base_ref.has_signal("destroyed"):
		if not _base_ref.destroyed.is_connected(_on_base_destroyed):
			_base_ref.destroyed.connect(_on_base_destroyed)


func start_battle(level_id: int = 1) -> void:
	reset_battle()
	current_level_id = level_id
	_set_battle_state(BattleState.PREPARING)
	start_next_wave()


func get_total_waves() -> int:
	return _waves.size()


func get_waves_completed() -> int:
	if battle_state == BattleState.VICTORY:
		return _waves.size()
	return maxi(current_wave_index, 0)


func start_next_wave() -> void:
	if battle_state == BattleState.VICTORY or battle_state == BattleState.DEFEAT:
		return

	current_wave_index += 1
	if current_wave_index >= _waves.size():
		return

	_spawners_finished = 0
	_active_spawners = 0
	_set_battle_state(BattleState.WAVE_ACTIVE)
	wave_changed.emit(current_wave_index + 1, _waves.size())
	_fill_spawner_queues(_waves[current_wave_index])


func add_battle_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins_earned_for_level += amount
	battle_coins_changed.emit(coins_earned_for_level)


func register_enemy_defeated() -> void:
	_enemies_alive = maxi(_enemies_alive - 1, 0)
	enemies_alive_changed.emit(_enemies_alive)
	_check_wave_completion()


func add_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	energy = clampf(energy + amount, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)


func try_consume_energy(cost: float) -> bool:
	if energy < cost:
		return false
	energy = maxf(energy - cost, 0.0)
	energy_changed.emit(energy, MAX_ENERGY)
	return true


func get_final_reward(victory: bool, victory_multiplier: float = VICTORY_MULTIPLIER) -> int:
	var reward := coins_earned_for_level
	if victory:
		reward = int(round(float(reward) * victory_multiplier))
	return maxi(reward, 0)


func claim_reward(victory: bool, victory_multiplier: float = VICTORY_MULTIPLIER) -> int:
	if reward_claimed:
		return 0
	reward_claimed = true

	var final_reward := get_final_reward(victory, victory_multiplier)
	if final_reward > 0:
		GameData.add_coins(final_reward)

	if victory:
		GameData.mark_level_completed(current_level_id)

	return final_reward


func notify_victory() -> void:
	if battle_state == BattleState.VICTORY or battle_state == BattleState.DEFEAT:
		return
	stop_combat()
	_set_battle_state(BattleState.VICTORY)


func notify_defeat() -> void:
	if battle_state == BattleState.VICTORY or battle_state == BattleState.DEFEAT:
		return
	stop_combat()
	_set_battle_state(BattleState.DEFEAT)


func stop_combat() -> void:
	for spawner in _spawners:
		if spawner.has_method("stop_spawner"):
			spawner.stop_spawner()

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies").duplicate()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()


func _fill_spawner_queues(wave: WaveDefinition) -> void:
	for spawner in _spawners:
		if spawner.has_method("clear_queue"):
			spawner.clear_queue()

	if _spawners.is_empty():
		return

	var mixed_queue: Array[PackedScene] = []
	for entry in wave.entries:
		if entry == null or entry.enemy_scene == null:
			continue
		for _i in entry.count:
			mixed_queue.append(entry.enemy_scene)

	if mixed_queue.is_empty():
		return

	mixed_queue.shuffle()

	var spawner_batches: Array = []
	for _spawner_index in _spawners.size():
		spawner_batches.append([])

	for i in mixed_queue.size():
		var spawner_index := i % _spawners.size()
		spawner_batches[spawner_index].append(mixed_queue[i])

	for spawner_index in _spawners.size():
		var batch: Array = spawner_batches[spawner_index]
		if batch.is_empty():
			continue

		var spawner: Node = _spawners[spawner_index]
		for enemy_scene in batch:
			spawner.add_enemy_to_queue(enemy_scene)

		_active_spawners += 1
		if "start_delay" in spawner:
			spawner.start_delay = float(spawner_index) * SPAWN_STAGGER_SEC
		spawner.start_spawning(_base_ref, _enemies_container)


func _on_enemy_spawned(_enemy: Node2D) -> void:
	_enemies_alive += 1
	enemies_alive_changed.emit(_enemies_alive)


func _on_spawner_queue_empty() -> void:
	_spawners_finished += 1
	_check_wave_completion()


func _check_wave_completion() -> void:
	if battle_state != BattleState.WAVE_ACTIVE:
		return
	if _spawners_finished < _active_spawners:
		return
	if _enemies_alive > 0:
		return

	wave_cleared.emit(current_wave_index + 1)

	if current_wave_index >= _waves.size() - 1:
		notify_victory()
	else:
		_begin_wave_transition()


func _begin_wave_transition() -> void:
	_set_battle_state(BattleState.TRANSITION)
	var timer := get_tree().create_timer(WAVE_TRANSITION_SEC)
	timer.timeout.connect(_on_transition_finished)


func _on_transition_finished() -> void:
	if battle_state != BattleState.TRANSITION:
		return
	start_next_wave()


func _on_base_destroyed() -> void:
	notify_defeat()


func _set_battle_state(state: BattleState) -> void:
	battle_state = state
	battle_state_changed.emit(state)
