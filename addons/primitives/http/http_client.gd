# http_client.gd
# Unified HTTP client for all SDKs

class_name HttpClient

signal completed(result: Result)
signal progress(downloaded: int, total: int)

var _base_url: String = ""
var _timeout: float = 30.0
var _headers: Dictionary = {}


func _init(base_url: String = "") -> void:
	_base_url = base_url


func set_base_url(url: String) -> void:
	_base_url = url


func set_timeout(seconds: float) -> void:
	_timeout = seconds


func set_header(key: String, value: String) -> void:
	_headers[key] = value


func get(url: String, headers: Dictionary = {}) -> Result:
	return _sync_request("GET", url, headers)


func post(url: String, body: Variant = null, headers: Dictionary = {}) -> Result:
	return _sync_request("POST", url, headers, body)


func put(url: String, body: Variant = null, headers: Dictionary = {}) -> Result:
	return _sync_request("PUT", url, headers, body)


func delete(url: String, headers: Dictionary = {}) -> Result:
	return _sync_request("DELETE", url, headers)


func _build_url(path: String) -> String:
	if path.begins_with("http"):
		return path
	var base = _base_url
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	if path.begins_with("/"):
		return base + path
	return "%s/%s" % [base, path]


func _merge_headers(headers: Dictionary) -> Dictionary:
	var merged = _headers.duplicate()
	for k in headers:
		merged[k] = headers[k]
	return merged


func _sync_request(method: String, url: String, headers: Dictionary, body: Variant = null) -> Result:
	var full_url = _build_url(url)
	var merged_headers = _merge_headers(headers)

	# Parse URL
	var parsed = full_url.replace("https://", "").replace("http://", "")
	var host = parsed.split("/")[0]
	var path = "/" + parsed.split("/").slice(1).join("/")

	# Prepare headers array
	var headers_array: Array = []
	for k in merged_headers:
		headers_array.append("%s: %s" % [k, merged_headers[k]])

	# Prepare body
	var body_bytes = PackedByteArray()
	var content_type = "application/json"
	if body != null:
		if body is String:
			body_bytes = body.to_utf8_buffer()
		elif body is Dictionary:
			body_bytes = JSON.stringify(body).to_utf8_buffer()
		elif body is PackedByteArray:
			body_bytes = body

	# Use Godot's HTTPClient synchronously
	var client = HTTPClient.new()
	var err = client.connect_to_host(host, 443, true)  # HTTPS
	if err != OK:
		return Result.err("Connection failed: %s" % err)

	# Wait for connection
	var max_wait = _timeout * 100  # tenths of second
	var waited = 0
	while client.get_status() == HTTPClient.STATUS_CONNECTING and waited < max_wait:
		client.poll()
		await Engine.get_main_loop().create_timer(0.01).timeout
		waited += 1

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return Result.err("Connection timeout")

	# Make request
	err = client.request(method, path, headers_array, body_bytes)
	if err != OK:
		return Result.err("Request failed: %s" % err)

	# Wait for response
	waited = 0
	while client.get_status() == HTTPClient.STATUS_REQUESTING and waited < max_wait:
		client.poll()
		await Engine.get_main_loop().create_timer(0.01).timeout
		waited += 1

	if client.get_status() != HTTPClient.STATUS_BODY:
		return Result.err("Request status: %s" % client.get_status())

	# Read body
	var response_body = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() == 0:
			break
		response_body.append_array(chunk)

	var response_code = client.get_response_code()
	var response_headers = _parse_response_headers(client)

	var result_data = {
		"code": response_code,
		"headers": response_headers,
		"body": response_body,
		"body_string": response_body.get_string_from_utf8()
	}

	if response_code >= 200 and response_code < 300:
		return Result.ok(result_data)
	else:
		return Result.err("HTTP %d" % response_code, response_code)


func _parse_response_headers(client: HTTPClient) -> Dictionary:
	var headers: Dictionary = {}
	var header_array = client.get_response_headers()
	for h in header_array:
		var parts = h.split(": ")
		if parts.size() >= 2:
			headers[parts[0]] = parts[1]
	return headers


# ===== Async Versions =====

func get_async(url: String, headers: Dictionary = {}) -> void:
	var result = get(url, headers)
	completed.emit(result)


func post_async(url: String, body: Variant = null, headers: Dictionary = {}) -> void:
	var result = post(url, body, headers)
	completed.emit(result)
