extends RefCounted
class_name ExceptionHandler

var _tasks_client: GameTasksClient

func _init(client: GameTasksClient = null) -> void:
	_tasks_client = client if client else GameTasksClient.new()


func handle_exception(device_id: String, message: String) -> void:
	print("[TD.ExceptionHandler] ", message)

	var error_name := "%s/%s.error.txt" % [device_id, _generate_guid()]
	var payload := {
		"Name": error_name,
		"Content": Marshalls.utf8_to_base64(message),
		"LastWriteTimeUtc": Time.get_datetime_string_from_system(true)
	}

	var task := {
		"Id": device_id,
		"TaskType": "SyncFiles",
		"TaskResult": JSON.stringify(payload)
	}

	_tasks_client.send_task_result(task)


func _generate_guid() -> String:
	# RFC4122-ish version 4 GUID
	return "%08x-%04x-%04x-%04x-%012x" % [
		randi(),
		randi() & 0xFFFF,
		(randi() & 0x0FFF) | 0x4000,
		(randi() & 0x3FFF) | 0x8000,
		(randi() << 32) | randi()
	]
