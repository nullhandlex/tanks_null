extends Node2D

## Consumes enemy queue filled externally by GameManager.
## Does NOT choose wave composition.

signal enemy_spawned(enemy: Node2D)
signal queue_empty

@export var spawn_interval: float = 1.2
@export var lateral_spawn_range: float = 420.0
@export var spawn_y_offset: float = 0.0

var enemy_queue: Array[PackedScene] = []
var enemy_pool: EnemyPool = null
var start_delay: float = 0.0

var _base_target: Node2D = null
var _enemies_container: Node2D = null

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func add_enemy_to_queue(enemy_scene: PackedScene) -> void:
	if enemy_scene == null:
		return
	enemy_queue.append(enemy_scene)


func clear_queue() -> void:
	enemy_queue.clear()


func start_spawning(base_target: Node2D, enemies_container: Node2D) -> void:
	_base_target = base_target
	_enemies_container = enemies_container
	spawn_timer.wait_time = spawn_interval
	if not spawn_timer.is_stopped():
		spawn_timer.stop()
	if start_delay > 0.0:
		spawn_timer.start(spawn_interval + start_delay)
		spawn_timer.wait_time = spawn_interval
	else:
		spawn_timer.start()


func stop_spawner() -> void:
	spawn_timer.stop()
	clear_queue()


func spawn_next_enemy() -> Node2D:
	if enemy_queue.is_empty():
		return null

	var scene: PackedScene = enemy_queue.pop_front()
	if scene == null:
		return null

	var container := _enemies_container if _enemies_container != null else get_parent()
	var enemy: Node2D = null
	if enemy_pool != null:
		enemy = enemy_pool.acquire(scene, container)
	else:
		enemy = scene.instantiate() as Node2D
		if enemy != null:
			container.add_child(enemy)
	if enemy == null:
		return null

	var lateral_offset := randf_range(-lateral_spawn_range, lateral_spawn_range)
	enemy.global_position = Vector2(global_position.x + lateral_offset, global_position.y + spawn_y_offset)

	if enemy.has_method("is_sleeping_in_pool") and enemy.is_sleeping_in_pool():
		enemy.wake_from_pool()

	if _base_target != null and enemy.has_method("set_attack_target"):
		enemy.set_attack_target(_base_target)

	if enemy.has_signal("defeated") and not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)

	enemy_spawned.emit(enemy)
	return enemy


func _on_spawn_timer_timeout() -> void:
	if enemy_queue.is_empty():
		spawn_timer.stop()
		queue_empty.emit()
		return

	if enemy_pool != null and not enemy_pool.try_begin_spawn(spawn_next_enemy):
		return

	spawn_next_enemy()


func _on_enemy_defeated(reward_amount: int) -> void:
	GameManager.add_battle_coins(reward_amount)
