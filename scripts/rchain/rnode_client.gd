class_name RNodeClient
extends RefCounted
## Typed, synchronous HTTP client for the RNode public/admin API (docs/rchain/protocol.md).
## Uses Godot's low-level HTTPClient with a bounded poll loop so SignalBridge can read synchronously.

var base_url: String
var admin_url: String


func _init() -> void:
	var host: String = _env("RCHAIN_HOST", "localhost")
	var public_port: String = _env("RCHAIN_PUBLIC_PORT", "40403")
	var admin_port: String = _env("RCHAIN_ADMIN_PORT", "40405")
	base_url = "http://%s:%s" % [host, public_port]
	admin_url = "http://%s:%s" % [host, admin_port]


## Read an environment variable, defaulting when absent.
## OS env is used so this also works in `--script` (headless) contexts where autoloads are not globals.
func _env(key: String, default: String) -> String:
	var v := OS.get_environment(key)
	return v if not v.is_empty() else default


## Low-level request. Returns Result.ok({status, body}) on transport success (any HTTP status).
func _request(method: HTTPClient.Method, url: String, body: String = "") -> Result:
	var parsed := _parse_url(url)
	if parsed.is_empty():
		return Result.err("invalid url: " + url)

	var client := HTTPClient.new()
	var err := client.connect_to_host(parsed["host"], parsed["port"])
	if err != OK:
		return Result.err("connect failed: %s" % str(err))

	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return Result.err("could not connect to %s" % parsed["host"])

	var headers: Array[String] = ["Content-Type: application/json"]
	if not body.is_empty():
		headers.append("Content-Length: %d" % body.to_utf8_buffer().size())

	var path: String = parsed["path"]
	var req_err := client.request(method, path, headers, body)
	if req_err != OK:
		return Result.err("request failed: %s" % str(req_err))

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	if not client.has_response():
		return Result.err("no response from node")

	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
		else:
			response_body.append_array(chunk)

	var status: int = client.get_response_code()
	var text: String = response_body.get_string_from_utf8()
	client.close()
	return Result.ok({"status": status, "body": text})


func _parse_url(url: String) -> Dictionary:
	var rest := url
	if "://" in rest:
		rest = rest.split("://")[1]
	var host_port := rest
	var path := "/"
	if "/" in rest:
		var parts := rest.split("/", true, 1)
		host_port = parts[0]
		path = "/" + parts[1]
	var host := host_port
	var port := 80
	if ":" in host_port:
		var hp := host_port.rsplit(":", true, 1)
		host = hp[0]
		port = int(hp[1])
	return {"host": host, "port": port, "path": path}


func _http_get(url: String) -> Result:
	return _request(HTTPClient.METHOD_GET, url)


func _post(url: String, body: String = "") -> Result:
	return _request(HTTPClient.METHOD_POST, url, body)


## GET /api/status -> node status dict.
func get_status() -> Result:
	var r := _http_get(base_url + "/api/status")
	if r.is_err():
		return r
	var d: Dictionary = r.get_data()
	if d.get("status", 0) != 200:
		return Result.err("status %d" % d.get("status", 0))
	var parsed = JSON.parse_string(d.get("body", ""))
	if parsed == null:
		return Result.err("invalid status JSON")
	return Result.ok(parsed)


## POST /api/explore-deploy -> {expr, block}.
func explore_deploy(term: String) -> Result:
	var r := _post(base_url + "/api/explore-deploy", JSON.stringify(term))
	if r.is_err():
		return r
	var d: Dictionary = r.get_data()
	if d.get("status", 0) != 200:
		return Result.err("explore-deploy %d: %s" % [d.get("status", 0), d.get("body", "")])
	var parsed = JSON.parse_string(d.get("body", ""))
	if parsed == null:
		return Result.err("invalid explore-deploy JSON")
	return Result.ok(parsed)


## POST /api/deploy (signed DeployRequest) -> deploy id (submit + poll to terminal).
func deploy(request: Dictionary) -> Result:
	var r := _post(base_url + "/api/deploy", JSON.stringify(request))
	if r.is_err():
		return r
	var d: Dictionary = r.get_data()
	if d.get("status", 0) != 200:
		return Result.err("deploy %d: %s" % [d.get("status", 0), d.get("body", "")])
	var body: String = d.get("body", "")
	var parsed_body = JSON.parse_string(body)
	if typeof(parsed_body) == TYPE_STRING:
		body = parsed_body
	var deploy_id := _parse_deploy_id(body)
	if deploy_id.is_empty():
		return Result.err("could not parse deploy id from: " + d.get("body", ""))

	for i in range(60):
		var st := deploy_status(deploy_id)
		if st.is_err():
			return st
		var info: Dictionary = st.get_data()
		var status: String = info.get("status", "")
		if status == "ProcessedWithSuccess":
			return Result.ok({"deploy_id": deploy_id, "result": info.get("result", [])})
		if status == "ProcessedWithError":
			return Result.err("deploy processed with error: %s" % str(info.get("error", "")))
		OS.delay_msec(3000)

	return Result.err("timed out waiting for deploy result")


func _parse_deploy_id(body: String) -> String:
	# Response is a JSON-encoded string like "Success!\nDeployId is: <hex>".
	var idx := body.find("DeployId is: ")
	if idx == -1:
		return ""
	return body.substr(idx + "DeployId is: ".length()).strip_edges()


## GET /api/v1/deploy-status/:id -> {status, result, error}.
func deploy_status(id: String) -> Result:
	var r := _http_get(base_url + "/api/v1/deploy-status/" + id)
	if r.is_err():
		return r
	var d: Dictionary = r.get_data()
	if d.get("status", 0) != 200:
		return Result.err("deploy-status %d" % d.get("status", 0))
	var parsed = JSON.parse_string(d.get("body", ""))
	if parsed == null:
		return Result.err("invalid deploy-status JSON")
	if parsed.has("ProcessedWithSuccess"):
		return Result.ok({"status": "ProcessedWithSuccess", "result": parsed["ProcessedWithSuccess"].get("deployResult", [])})
	if parsed.has("ProcessedWithError"):
		return Result.ok({"status": "ProcessedWithError", "error": parsed["ProcessedWithError"].get("deployError", "")})
	return Result.ok({"status": "NotProcessed", "detail": parsed.get("NotProcessed", {})})


## POST /api/data-at-name -> {exprs, length}.
func data_at_name(name_rho: Dictionary, depth: int = 1) -> Result:
	var r := _post(base_url + "/api/data-at-name", JSON.stringify({"name": name_rho, "depth": depth}))
	if r.is_err():
		return r
	var d: Dictionary = r.get_data()
	if d.get("status", 0) != 200:
		return Result.err("data-at-name %d" % d.get("status", 0))
	var parsed = JSON.parse_string(d.get("body", ""))
	if parsed == null:
		return Result.err("invalid data-at-name JSON")
	return Result.ok(parsed)


## GET /api/block/:hash.
func get_block(hash: String) -> Result:
	return _http_get(base_url + "/api/block/" + hash)


## POST /api/propose (admin).
func propose() -> Result:
	return _post(admin_url + "/api/propose")


## POST /api/faucet -> {deploy_id, amount, to}.
func faucet(address: String) -> Result:
	var r := _post(base_url + "/api/faucet", JSON.stringify({"address": address}))
	if r.is_err():
		return r
	var d: Dictionary = r.get_data()
	if d.get("status", 0) != 200:
		return Result.err("faucet %d: %s" % [d.get("status", 0), d.get("body", "")])
	var parsed = JSON.parse_string(d.get("body", ""))
	if parsed == null:
		return Result.err("invalid faucet JSON")
	return Result.ok(parsed)


## GET /api/v1/capabilities.
func get_capabilities() -> Result:
	return _http_get(base_url + "/api/v1/capabilities")


## GET /api/v1/deploys.
func get_pooled_deploys() -> Result:
	return _http_get(base_url + "/api/v1/deploys")
