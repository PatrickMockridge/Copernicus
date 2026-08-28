# http_client.gd
# Unified HTTP client for all SDKs
# Uses Godot 4's HTTPRequest for actual network requests

class_name HyperHttpClient
extends Node

signal completed(result: Result)
signal progress(downloaded: int, total: int)

var _base_url: String = ""
var _timeout: float = 30.0
var _headers: Dictionary = {}

var _http_request: HTTPRequest
var _pending_request: bool = false
var _request_completed: bool = false
var _request_result: Result = Result.ok(null)


func _init(base_url: String = "") -> void:
	_base_url = base_url


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func _process(delta: float) -> void:
	if _pending_request and _request_completed:
		_pending_request = false
		_request_completed = false
		completed.emit(_request_result)


func set_base_url(url: String) -> void:
	_base_url = url


func set_timeout(seconds: float) -> void:
	_timeout = seconds


func set_header(key: String, value: String) -> void:
	_headers[key] = value


func fetch(url: String, extra_headers: Dictionary = {}) -> Result:
	var full_url = _build_url(url)
	var headers = _build_headers(extra_headers)

	_pending_request = true
	_request_completed = false

	var result = _http_request.request(full_url, headers, HTTPClient.METHOD_GET)

	if result != OK:
		_pending_request = false
		return Result.err("HTTP request failed: " + str(result))

	# Return pending - signal will fire when complete
	return Result.ok({"pending": true})


func post(url: String, body: Variant = null, extra_headers: Dictionary = {}) -> Result:
	var full_url = _build_url(url)
	var headers = _build_headers(extra_headers)

	_pending_request = true
	_request_completed = false

	var body_data = ""
	if body != null:
		if body is Dictionary:
			body_data = JSON.stringify(body)
		else:
			body_data = str(body)

	var body_bytes = body_data.to_utf8_buffer()

	var result = _http_request.request(full_url, headers, HTTPClient.METHOD_POST, body_data)

	if result != OK:
		_pending_request = false
		return Result.err("HTTP request failed: " + str(result))

	return Result.ok({"pending": true})


func put(url: String, body: Variant = null, extra_headers: Dictionary = {}) -> Result:
	var full_url = _build_url(url)
	var headers = _build_headers(extra_headers)

	_pending_request = true
	_request_completed = false

	var body_data = ""
	if body != null:
		if body is Dictionary:
			body_data = JSON.stringify(body)
		else:
			body_data = str(body)

	var result = _http_request.request(full_url, headers, HTTPClient.METHOD_PUT, body_data)

	if result != OK:
		_pending_request = false
		return Result.err("HTTP request failed: " + str(result))

	return Result.ok({"pending": true})


func delete(url: String, extra_headers: Dictionary = {}) -> Result:
	var full_url = _build_url(url)
	var headers = _build_headers(extra_headers)

	_pending_request = true
	_request_completed = false

	var result = _http_request.request(full_url, headers, HTTPClient.METHOD_DELETE)

	if result != OK:
		_pending_request = false
		return Result.err("HTTP request failed: " + str(result))

	return Result.ok({"pending": true})


func _build_url(url: String) -> String:
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	if _base_url.length() > 0:
		return _base_url.trim_suffix("/") + "/" + url.trim_prefix("/")
	return url


func _build_headers(extra_headers: Dictionary) -> Array:
	var headers = []
	for key in _headers:
		headers.append(key + ": " + _headers[key])
	for key in extra_headers:
		headers.append(key + ": " + str(extra_headers[key]))
	return headers


func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	_request_completed = true

	if result != HTTPRequest.RESULT_SUCCESS:
		_request_result = Result.err("HTTP request failed with code: " + str(result))
		return

	# Parse response body as string
	var body_str = body.get_string_from_utf8()

	# Create response object
	var response = {
		"status_code": response_code,
		"headers": headers,
		"body": body_str
	}

	# Try to parse as JSON if content-type suggests it
	var content_type = _get_header(headers, "content-type")
	if content_type and content_type.contains("json"):
		var json = JSON.parse_string(body_str)
		if json != null:
			response["json"] = json

	# Determine success/failure based on status code
	if response_code >= 200 and response_code < 300:
		_request_result = Result.ok(response)
	elif response_code >= 400:
		_request_result = Result.err("HTTP " + str(response_code) + ": " + body_str)
	else:
		_request_result = Result.ok(response)  # 3xx redirects etc - still ok


func _get_header(headers: Array, key: String) -> String:
	for header in headers:
		if header.to_lower().begins_with(key.to_lower() + ":"):
			var parts = header.split(":", 1)
			if parts.size() > 1:
				return parts[1].strip_edges()
	return ""


## ===== Static Helpers =====

## Create a simple HTTP client for a base URL
static func create(base_url: String = "") -> HyperHttpClient:
	var client = HyperHttpClient.new()
	client._base_url = base_url
	return client


## Make a quick GET request
static func get_request(url: String, headers: Dictionary = {}) -> Dictionary:
	var client = HyperHttpClient.new()
	var tree = Engine.get_main_loop()
	var root = tree.get_root()
	root.add_child(client)

	var result = client.fetch(url, headers)

	# For sync access, wait for completion (not recommended in _process)
	var timeout = 10.0
	var elapsed = 0.0
	while result.is_ok() and result.value.get("pending", false) and elapsed < timeout:
		client._process(0.016)
		elapsed += 0.016

	var final_result = client._request_completed if client._pending_request else Result.ok(null)
	client.queue_free()
	return final_result.value if final_result else {}


## Make a quick POST request
static func post_json(url: String, json_data: Dictionary) -> Dictionary:
	var client = HyperHttpClient.new()
	var tree = Engine.get_main_loop()
	var root = tree.get_root()
	root.add_child(client)

	var result = client.post(url, json_data)

	var timeout = 10.0
	var elapsed = 0.0
	while result.is_ok() and result.value.get("pending", false) and elapsed < timeout:
		client._process(0.016)
		elapsed += 0.016

	var final_result = client._request_completed if client._pending_request else Result.ok(null)
	client.queue_free()
	return final_result.value if final_result else {}