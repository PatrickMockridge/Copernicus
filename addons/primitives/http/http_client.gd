# http_client.gd
# Unified HTTP client for all SDKs
# STUBBED for Godot 4.4 - returns errors, blockchain testing only

class_name HyperHttpClient
extends Object

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


func fetch(url: String, extra_headers: Dictionary = {}) -> Result:
	return Result.err("HTTP client stubbed - network not available")


func post(url: String, body: Variant = null, extra_headers: Dictionary = {}) -> Result:
	return Result.err("HTTP client stubbed - network not available")


func put(url: String, body: Variant = null, extra_headers: Dictionary = {}) -> Result:
	return Result.err("HTTP client stubbed - network not available")


func delete(url: String, extra_headers: Dictionary = {}) -> Result:
	return Result.err("HTTP client stubbed - network not available")
