class_name EnemyPool
extends Node

## Reuses enemy scenes so a wave does not hitch on PackedScene.instantiate.
## Spawners still consume GameManager queues; this only supplies instances.

const MAX_SPAWNS_PER_FRAME := 1

var _idle: Dictionary = {}
var _holder: Node2D
var _budget_frame: int = -1
var _spawns_this_frame: int = 0
var _pending: Array[Callable] = []


func _ready() -> void:
	_holder = Node2D.new()
	_holder.name = "IdleEnemies"
	_holder.visible = false
	_holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_holder)
	set_process(false)


func _process(_delta: float) -> void:
	_reset_budget_if_needed()
	while _spawns_this_frame < MAX_SPAWNS_PER_FRAME and not _pending.is_empty():
		var job: Callable = _pending.pop_front()
		if job.is_valid():
			_spawns_this_frame += 1
			job.call()
	if _pending.is_empty():
		set_process(false)


func try_begin_spawn(on_ready: Callable) -> bool:
	_reset_budget_if_needed()
	if _spawns_this_frame >= MAX_SPAWNS_PER_FRAME:
		_pending.append(on_ready)
		set_process(true)
		return false
	_spawns_this_frame += 1
	return true


func acquire(scene: PackedScene, container: Node) -> Node2D:
	if scene == null or container == null:
		return null
	var path := scene.resource_path
	var idle: Array = _idle.get(path, [])
	var enemy: Node2D = null
	if not idle.is_empty():
		enemy = idle.pop_back() as Node2D
		_idle[path] = idle
	if enemy == null or not is_instance_valid(enemy):
		enemy = scene.instantiate() as Node2D
		if enemy == null:
			return null
		_bind(enemy, path)
		container.add_child(enemy)
		return enemy
	_bind(enemy, path)
	if enemy.get_parent() != container:
		enemy.reparent(container)
	return enemy


func put_back(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var path := str(enemy.get_meta("pool_scene_path", ""))
	if enemy.has_method("sleep_in_pool"):
		enemy.sleep_in_pool()
	if enemy.get_parent() != _holder:
		enemy.reparent(_holder)
	if path.is_empty():
		enemy.queue_free()
		return
	var idle: Array = _idle.get(path, [])
	idle.append(enemy)
	_idle[path] = idle


func prewarm(scene: PackedScene, count: int) -> void:
	if scene == null or count <= 0:
		return
	var path := scene.resource_path
	var idle: Array = _idle.get(path, [])
	for _i in count:
		var enemy := scene.instantiate() as Node2D
		if enemy == null:
			continue
		_bind(enemy, path)
		_holder.add_child(enemy)
		if enemy.has_method("sleep_in_pool"):
			enemy.sleep_in_pool()
		idle.append(enemy)
	_idle[path] = idle


func _bind(enemy: Node2D, path: String) -> void:
	enemy.set_meta("enemy_pool", self)
	enemy.set_meta("pool_scene_path", path)


func _reset_budget_if_needed() -> void:
	var frame := Engine.get_process_frames()
	if frame == _budget_frame:
		return
	_budget_frame = frame
	_spawns_this_frame = 0
