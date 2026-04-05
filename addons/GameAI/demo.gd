extends Control

var _api_key: String = ""


func _ready() -> void:
	$Panel/VBox/Title.text = "GameAI SDK Demo"


func _on_connect_pressed() -> void:
	_api_key = $Panel/VBox/ApiKey.text
	if _api_key == "":
		$Panel/VBox/Output.text = "Please enter an API key"
		return

	GameAI.configure({
		"anthropic": {"api_key": _api_key},
		"default": "anthropic"
	})
	$Panel/VBox/Output.text = "Connected to Anthropic Claude!"


func _on_npc_chat_pressed() -> void:
	# Initialize an NPC
	GameAI.npc_init("guard", "A gruff dwarven guard who loves ale and hates elves")
	GameAI.npc_say("guard", "What brings you to this gate?")


func _on_generate_code_pressed() -> void:
	var result = await GameAI.generate_code("a function that calculates fibonacci numbers", "gdscript")
	if result.is_ok():
		$Panel/VBox/Output.text = result.ok_value().content
	else:
		$Panel/VBox/Output.text = "Error: " + str(result.err_value())
