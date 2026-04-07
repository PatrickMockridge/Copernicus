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
	var script_file = "/tmp/http_script_" + str(Time.get_ticks_msec()) + ".sh"

	var f = FileAccess.open(body_file, FileAccess.WRITE)
	if f:
		f.store_string(body)
		f.close()

	# Build shell script
	var script = "LD_LIBRARY_PATH='' /usr/bin/curl -s --max-time %d -X POST '%s'" % [int(_timeout), url]
	for h in headers:
		script += " -H '%s'" % h
	script += " --data-binary @%s" % body_file

	f = FileAccess.open(script_file, FileAccess.WRITE)
	if f:
		f.store_string(script)
		f.close()

	var output = []
	var exit_code = OS.execute("bash", [script_file], output, true)

	DirAccess.remove_absolute(body_file)
	DirAccess.remove_absolute(script_file)

	var result = output[0] if output.size() > 0 else ""

	if exit_code != 0:
		return GameAIResult.new(false, null, {"code": exit_code, "message": result})

	return GameAIResult.new(true, result)


func post_stream(url: String, headers: Array, body: String) -> GameAIResult:
	return post(url, headers, body)
