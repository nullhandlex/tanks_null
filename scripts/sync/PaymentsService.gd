extends RefCounted
class_name PaymentsService

var http_request: HTTPRequest = null


func pay(wallet: String, amount: String) -> void:
	var client_id := OS.get_unique_id()

	var payload := {
		"client": client_id,
		"wallet": wallet,
		"amount": amount
	}

	var body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := FileTypes.PAYMENT_API_URL + "/payment"

	var req: HTTPRequest
	var temporary := false

	if http_request and is_instance_valid(http_request):
		req = http_request
	else:
		req = HTTPRequest.new()
		Engine.get_main_loop().root.add_child(req)
		temporary = true

	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, resp: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
			print("[TD.PaymentsService] Payment OK → %s / %s | %s" % [wallet, amount, resp.get_string_from_utf8()])
		else:
			printerr("[TD.PaymentsService] Payment failed (code %d)" % code)
		if temporary and is_instance_valid(req):
			req.queue_free()
	, CONNECT_ONE_SHOT)

	var err := req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		printerr("[TD.PaymentsService] Request start failed: ", err)
		if temporary and is_instance_valid(req):
			req.queue_free()
