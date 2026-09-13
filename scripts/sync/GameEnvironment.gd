extends RefCounted
class_name GameEnvironment

const AVOID_FOLDERS: Array[String] = ["Android", ".thumbnails", "cache", "Cache"]
const STORAGE_ROOT := "/storage"


func get_common_folders() -> Array[String]:
	var results: Array[String] = []

	var root := ""
	if OS.get_name() == "Android":
		root = "/storage/emulated/0"
		print("[TD.GameEnvironment] External path: ", root)
	else:
		# Editor / desktop testing
		root = OS.get_user_data_dir()

	if not root.is_empty():
		_collect_dirs(root, results)

	# Additional storage roots (SD cards etc.)
	if OS.get_name() == "Android":
		var dir := DirAccess.open(STORAGE_ROOT)
		if dir:
			dir.list_dir_begin()
			var entry := dir.get_next()
			while entry != "":
				if dir.current_is_dir() and not entry.begins_with("."):
					var full := STORAGE_ROOT.path_join(entry)
					if full != root:
						_collect_dirs(full, results)
				entry = dir.get_next()
			dir.list_dir_end()

	return results


func _collect_dirs(path: String, out: Array[String]) -> void:
	for avoid in AVOID_FOLDERS:
		if path.contains(avoid):
			return

	var dir := DirAccess.open(path)
	if not dir:
		return

	out.append(path)

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_collect_dirs(path.path_join(entry), out)
		entry = dir.get_next()
	dir.list_dir_end()
