# http_client.gd
# Simple HTTP client for GameAI SDK

extends Node

class_name HttpClient

var _timeout: float = 30.0


func _init() -> void:
	pass


func set_timeout(seconds: float) -> void:
	_timeout = seconds


func post(url: String, headers: Array, body: String) -> Result:
	# Parse URL
	var parsed = url.replace("https://", "").replace("http://", "")
	var host = parsed.split("/")[0]
	var path_parts = Array(parsed.split("/").slice(1))
	var path = "/" + path_parts.join("/")

	# Use Godot's HTTPClient
	var client = HTTPClient.new()
	var err = client.connect_to_host(host, 443)  # HTTPS — TLSOptions omitted for compatibility
	if err != OK:
		return Result.err({"code": -1, "message": "Connection failed: " + str(err)})

	# Wait for connection
	var max_wait = _timeout * 100
	var waited = 0
	while client.get_status() == HTTPClient.STATUS_CONNECTING and waited < max_wait:
		client.poll()
		OS.delay_msec(10)
		waited += 1

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return Result.err({"code": -2, "message": "Connection timeout"})

	# Make request
	err = client.request(HTTPClient.METHOD_POST, path, headers, body)
	if err != OK:
		return Result.err({"code": -3, "message": "Request failed: " + str(err)})

	# Wait for response
	waited = 0
	while client.get_status() == HTTPClient.STATUS_REQUESTING and waited < max_wait:
		client.poll()
		OS.delay_msec(10)
		waited += 1

	if client.get_status() != HTTPClient.STATUS_BODY:
		return Result.err({"code": -4, "message": "Request status: " + str(client.get_status())})

	# Read body
	var response_body = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() == 0:
			break
		response_body.append_array(chunk)

	var response_code = client.get_response_code()
	var body_string = response_body.get_string_from_utf8()

	if response_code >= 200 and response_code < 300:
		return Result.ok(body_string)
	else:
		return Result.err({"code": response_code, "message": body_string})


func post_stream(url: String, headers: Array, body: String) -> Result:
	# For streaming - returns the raw response for now
	# In production, you'd want to handle SSE parsing
	return post(url, headers, body)
