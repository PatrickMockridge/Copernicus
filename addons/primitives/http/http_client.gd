# http_client.gd
# Unified HTTP client for all SDKs.
# Synchronous (blocking) over Godot's low-level HTTPClient — run from a background
# thread via RChainService.run_async for UI calls that must not block.

class_name HyperHttpClient
extends RefCounted

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


func fetch(url: String, extra_headers: Dictionary = {}) -> Result:
	return _request(HTTPClient.METHOD_GET, _build_url(url), "", _build_headers(extra_headers))


func post(url: String, body: Variant = null, extra_headers: Dictionary = {}) -> Result:
	return _request(HTTPClient.METHOD_POST, _build_url(url), _serialize_body(body), _build_headers(extra_headers))


func put(url: String, body: Variant = null, extra_headers: Dictionary = {}) -> Result:
	return _request(HTTPClient.METHOD_PUT, _build_url(url), _serialize_body(body), _build_headers(extra_headers))


func delete(url: String, extra_headers: Dictionary = {}) -> Result:
	return _request(HTTPClient.METHOD_DELETE, _build_url(url), "", _build_headers(extra_headers))


func _serialize_body(body: Variant) -> String:
	if body == null:
		return ""
	if body is PackedByteArray:
		return (body as PackedByteArray).get_string_from_utf8()
	if body is Dictionary or body is Array:
		return JSON.stringify(body)
	return str(body)


func _request(method: HTTPClient.Method, url: String, body: String, headers: Array) -> Result:
	var parsed := _parse_url(url)
	if parsed.is_empty():
		return Result.err("invalid url: " + url)

	var client := HTTPClient.new()
	var tls_options: TLSOptions = null
	if parsed.get("tls", false):
		tls_options = TLSOptions.client()
	var err := client.connect_to_host(parsed["host"], parsed["port"], tls_options)
	if err != OK:
		return Result.err("connect failed: %s" % str(err))

	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return Result.err("could not connect to %s" % parsed["host"])

	if not body.is_empty():
		headers.append("Content-Length: %d" % body.to_utf8_buffer().size())

	var req_err := client.request(method, parsed["path"], headers, body)
	if req_err != OK:
		return Result.err("request failed: %s" % str(req_err))

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	if not client.has_response():
		return Result.err("no response from %s" % parsed["host"])

	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
		else:
			response_body.append_array(chunk)

	var response_code := client.get_response_code()
	var response_headers := client.get_response_headers()
	client.close()

	var body_str := response_body.get_string_from_utf8()
	var response := {
		"status_code": response_code,
		"headers": response_headers,
		"body": response_body,  # raw bytes
		"body_string": body_str  # text
	}

	var content_type := _get_header(response_headers, "content-type")
	if content_type and content_type.contains("json"):
		var json = JSON.parse_string(body_str)
		if json != null:
			response["json"] = json

	if response_code >= 200 and response_code < 300:
		return Result.ok(response)
	elif response_code >= 400:
		return Result.err("HTTP %d: %s" % [response_code, body_str])
	return Result.ok(response)


func _parse_url(url: String) -> Dictionary:
	var tls := false
	var rest := url
	if rest.begins_with("https://"):
		tls = true
		rest = rest.trim_prefix("https://")
	elif rest.begins_with("http://"):
		rest = rest.trim_prefix("http://")
	elif "://" in rest:
		rest = rest.split("://")[1]
	var host_port := rest
	var path := "/"
	if "/" in rest:
		var parts := rest.split("/", true, 1)
		host_port = parts[0]
		path = "/" + parts[1]
	var host := host_port
	var port := 443 if tls else 80
	if ":" in host_port:
		var hp := host_port.rsplit(":", true, 1)
		host = hp[0]
		port = int(hp[1])
	return {"host": host, "port": port, "path": path, "tls": tls}


func _build_url(url: String) -> String:
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	if _base_url.length() > 0:
		return _base_url.trim_suffix("/") + "/" + url.trim_prefix("/")
	return url


func _build_headers(extra_headers: Dictionary) -> Array:
	var headers = []
	for key in _headers:
		headers.append(key + ": " + str(_headers[key]))
	for key in extra_headers:
		headers.append(key + ": " + str(extra_headers[key]))
	return headers


func _get_header(headers: Array, key: String) -> String:
	for header in headers:
		if header.to_lower().begins_with(key.to_lower() + ":"):
			var parts = header.split(":", 1)
			if parts.size() > 1:
				return parts[1].strip_edges()
	return ""
