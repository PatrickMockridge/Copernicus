# ui_brief.gd
# The always-visible objective: current scenario title + brief + live checklist.
# Reads the ScenarioService autoload and re-renders on verdict_changed.

class_name UiBrief
extends UiPanel

var _checks_host: VBoxContainer
var _message: UiLabel


func configure() -> UiBrief:
	setup("Current Objective")
	ScenarioService.verdict_changed.connect(_on_verdict)
	_render()
	return self


func _on_verdict(_verdict) -> void:
	_render()


func _render() -> void:
	_clear_body()
	if ScenarioService.active == null:
		body().add_child(UiLabel.new().setup("No active scenario", UiLabel.Kind.BODY, UiLabel.Tone.MUTED))
		return
	var headline := UiLabel.new().setup(
		"%s — %s" % [ScenarioService.active.title, ScenarioService.active.brief],
		UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY
	)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(headline)
	_checks_host = VBoxContainer.new()
	_checks_host.add_theme_constant_override("separation", 0)
	body().add_child(_checks_host)
	_message = UiLabel.new().setup("", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
	body().add_child(_message)
	_fill_verdict()


func _fill_verdict() -> void:
	if ScenarioService.verdict == null:
		return
	for c in ScenarioService.verdict.checks:
		var key := str(c.get("key", ""))
		if not key.is_empty() and not ScenarioService.is_produced(key):
			continue
		_checks_host.add_child(UiChecklistItem.new().setup(
			str(c.get("label", "")),
			bool(c.get("ok", false)),
			str(c.get("actual", "")),
			str(c.get("expected", ""))
		))
	_message.setup(ScenarioService.verdict.message, UiLabel.Kind.SMALL, UiLabel.Tone.SUCCESS if ScenarioService.verdict.passed else UiLabel.Tone.MUTED)


func _clear_body() -> void:
	var b := body()
	while b.get_child_count() > 0:
		var child := b.get_child(0)
		b.remove_child(child)
		child.free()
