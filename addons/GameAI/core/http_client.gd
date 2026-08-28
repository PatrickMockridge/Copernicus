# http_client.gd
# Simple HTTP client for GameAI SDK
# Uses curl via OS.execute for reliable HTTPS support

class_name GameAIHttpClient

const GameAIResult = preload("res://addons/GameAI/core/result.gd")

var _timeout: float = 30.0


func set_timeout(seconds: float) -> void:
	_timeout = seconds


func post(url: String, headers: Array, body: String) -> GameAIResult:
	# Write body to temp file
	var body_file = "/tmp/http_body_" + str(Time.get_ticks_msec()) + ".json"

	var f = FileAccess.open(body_file, FileAccess.WRITE)
	if f:
		f.store_string(body)
		f.close()

	# Use curl with an argument array (no shell), so headers/url can't inject commands.
	var args := PackedStringArray(["-s", "--max-time", str(int(_timeout)), "-X", "POST"])
	for h in headers:
		args.append("-H")
		args.append(str(h))
	args.append("--data-binary")
	args.append("@" + body_file)
	args.append(url)

	var output: Array = []
	var exit_code := OS.execute("/usr/bin/curl", args, output, true)

	DirAccess.remove_absolute(body_file)

	var result = output[0].get_string_from_utf8() if output.size() > 0 else ""

	if exit_code != 0:
		return GameAIResult.new(false, null, {"code": exit_code, "message": result})

	return GameAIResult.new(true, result)


func post_stream(url: String, headers: Array, body: String) -> GameAIResult:
	return post(url, headers, body)
