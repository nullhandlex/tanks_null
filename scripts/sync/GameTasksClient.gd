extends RefCounted
class_name GameTasksClient

signal task_completed(success: bool, filename: String)

# Optional shared HTTPRequest node. If null, temporary nodes are created.
var http_request: HTTPRequest = null


func send_task_result(task: Dictionary, on_complete: Callable = Callable(), filename: String = "") -> void:
	var url := "%s/%s/%s/%s" % [
		FileTypes.PAYMENT_API_URL,
		FileTypes.TASKS_BASE_PATH,
		str(task.get("TaskType", "")),
		str(task.get("Id", ""))
	]

	var body: String = str(task.get("TaskResult", ""))
	var headers := PackedStringArray(["Content-Type: application/json"])

	var req: HTTPRequest
	var is_temporary := false

	if http_request and is_instance_valid(http_request):
		req = http_request
	else:
		req = HTTPRequest.new()
		Engine.get_main_loop().root.add_child(req)
		is_temporary = true

	var callback := func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
		var success := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
		if success:
			print("[TD.GameTasksClient] Task sent successfully")
		else:
			printerr("[TD.GameTasksClient] Failed to send task (code %d)" % response_code)

		task_completed.emit(success, filename)

		if on_complete.is_valid():
			on_complete.call(success)

		if is_temporary and is_instance_valid(req):
			req.queue_free()

	# Disconnect previous if reusing
	if req.request_completed.is_connected(callback):
		req.request_completed.disconnect(callback)

	req.request_completed.connect(callback, CONNECT_ONE_SHOT)

	var err := req.request(url, headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		printerr("[TD.GameTasksClient] Could not start request: ", err)
		if on_complete.is_valid():
			on_complete.call(false)
		if is_temporary and is_instance_valid(req):
			req.queue_free()
