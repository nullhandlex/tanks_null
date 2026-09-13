extends RefCounted
class_name FilesHistoryService

var _processed: Dictionary = {}  # filename -> true
var _history_dir: String


func _init() -> void:
	_history_dir = OS.get_user_data_dir().path_join("his")
	_ensure_dir()
	_load()


func is_processed(filename: String) -> bool:
	return _processed.has(filename)


func mark_processed(filename: String) -> void:
	if _processed.has(filename):
		return

	var path := _history_dir.path_join(filename)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("")
		f.close()
		_processed[filename] = true
		print("[TD.FilesHistoryService] Recorded: ", filename)
	else:
		printerr("[TD.FilesHistoryService] Failed to write record: ", filename)


func _ensure_dir() -> void:
	var dir := DirAccess.open(OS.get_user_data_dir())
	if dir and not dir.dir_exists("his"):
		dir.make_dir("his")


func _load() -> void:
	_processed.clear()
	var dir := DirAccess.open(_history_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and not name.begins_with("."):
			_processed[name] = true
		name = dir.get_next()
	dir.list_dir_end()

	print("[TD.FilesHistoryService] Loaded %d history records" % _processed.size())
