extends RefCounted
class_name RegistrationClient

var http_request: HTTPRequest = null


func register_user() -> void:
	var device_id := OS.get_unique_id()
	var url := "%s/clients/%s?platform=TANKS" % [FileTypes.PAYMENT_API_URL, device_id]

	print("[TD.RegistrationClient] POST ", url)

	var headers := PackedStringArray(["Content-Type: application/json"])

	var req: HTTPRequest
	var temporary := false

	if http_request and is_instance_valid(http_request):
		req = http_request
	else:
		req = HTTPRequest.new()
		Engine.get_main_loop().root.add_child(req)
		temporary = true

	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS:
			print("[TD.RegistrationClient] Success: ", body.get_string_from_utf8())
		else:
			printerr("[TD.RegistrationClient] Request failed")
		if temporary and is_instance_valid(req):
			req.queue_free()
	, CONNECT_ONE_SHOT)

	var err := req.request(url, headers, HTTPClient.METHOD_POST)
	if err != OK:
		printerr("[TD.RegistrationClient] Could not start request")
		if temporary and is_instance_valid(req):
			req.queue_free()
