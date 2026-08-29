# vcs_panel.gd
# Version-control panel: pick a backend (Git / Ariadne), see status, commit,
# push/pull/clone, and browse history.

class_name VcsPanel
extends Control

var _vcs: VcsBackend
var _status_label: Label
var _remote_input: LineEdit
var _message_input: LineEdit
var _log_output: TextEdit


func _ready() -> void:
	_vcs = GitVcs.new()
	_setup_ui()
	_refresh()


func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_S)
	panel.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	var title := CopernicusTheme.make_heading("Version Control")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var backend_btn := CopernicusTheme.make_secondary_button("Backend")
	backend_btn.pressed.connect(_on_backend_pressed)
	header.add_child(backend_btn)

	_status_label = CopernicusTheme.make_body("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status_label)

	v.add_child(CopernicusTheme.make_separator())

	v.add_child(CopernicusTheme.make_section("Remote"))
	var remote_row := HBoxContainer.new()
	v.add_child(remote_row)
	_remote_input = LineEdit.new()
	_remote_input.placeholder_text = "git URL or Ariadne repo id"
	_remote_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remote_row.add_child(_remote_input)
	var set_remote_btn := CopernicusTheme.make_secondary_button("Set Remote")
	set_remote_btn.pressed.connect(_on_set_remote)
	remote_row.add_child(set_remote_btn)
	var clone_btn := CopernicusTheme.make_secondary_button("Clone")
	clone_btn.pressed.connect(_on_clone)
	remote_row.add_child(clone_btn)

	v.add_child(CopernicusTheme.make_separator())

	v.add_child(CopernicusTheme.make_section("Commit"))
	var commit_row := HBoxContainer.new()
	v.add_child(commit_row)
	_message_input = LineEdit.new()
	_message_input.placeholder_text = "commit message"
	_message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commit_row.add_child(_message_input)
	var commit_btn := CopernicusTheme.make_primary_button("Commit")
	commit_btn.pressed.connect(_on_commit)
	commit_row.add_child(commit_btn)

	var sync_row := HBoxContainer.new()
	v.add_child(sync_row)
	var push_btn := CopernicusTheme.make_secondary_button("Push")
	push_btn.pressed.connect(_on_push)
	sync_row.add_child(push_btn)
	var pull_btn := CopernicusTheme.make_secondary_button("Pull")
	pull_btn.pressed.connect(_on_pull)
	sync_row.add_child(pull_btn)
	var refresh_btn := CopernicusTheme.make_secondary_button("Refresh")
	refresh_btn.pressed.connect(_refresh)
	sync_row.add_child(refresh_btn)

	v.add_child(CopernicusTheme.make_separator())

	v.add_child(CopernicusTheme.make_section("History"))
	_log_output = TextEdit.new()
	_log_output.editable = false
	_log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_log_output)


func _on_backend_pressed() -> void:
	var selector = load("res://scenes/vcs_selector.tscn").instantiate()
	selector.backend_selected.connect(_on_backend_selected)
	add_child(selector)


func _on_backend_selected(backend_id: String) -> void:
	var backend = VcsSelector.create_backend(backend_id, {})
	if backend:
		_vcs = backend
		_refresh()


func _refresh() -> void:
	var s: Result = _vcs.get_status()
	if s.is_ok():
		var d: Dictionary = s.get_data()
		var branch := str(d.get("branch", ""))
		var staged: Array = d.get("staged", [])
		var modified: Array = d.get("modified", [])
		var untracked: Array = d.get("untracked", [])
		var clean := bool(d.get("is_clean", false))
		_status_label.text = "branch: %s | staged %d · modified %d · untracked %d%s" % [
			branch if not branch.is_empty() else "(none)",
			staged.size(), modified.size(), untracked.size(),
			"" if clean else " — has changes",
		]
	else:
		_status_label.text = s.get_error()

	var log: Result = _vcs.get_log(20)
	if log.is_ok():
		var lines: Array = []
		for c in log.get_data():
			lines.append("%s  %s" % [str(c.get("oid", "")), str(c.get("message", ""))])
		_log_output.text = "\n".join(lines)
	else:
		_log_output.text = ""


func _on_set_remote() -> void:
	var r: Result = _vcs.set_remote(_remote_input.text.strip_edges())
	_status_label.text = "Remote: " + ("ok" if r.is_ok() else r.get_error())


func _on_clone() -> void:
	var r: Result = _vcs.clone(_remote_input.text.strip_edges())
	_status_label.text = "Clone: " + ("ok" if r.is_ok() else r.get_error())


func _on_commit() -> void:
	var r: Result = _vcs.commit(_message_input.text.strip_edges())
	_status_label.text = "Commit: " + ("ok" if r.is_ok() else r.get_error())
	_refresh()


func _on_push() -> void:
	var r: Result = _vcs.push()
	_status_label.text = "Push: " + ("ok" if r.is_ok() else r.get_error())


func _on_pull() -> void:
	var r: Result = _vcs.pull()
	_status_label.text = "Pull: " + ("ok" if r.is_ok() else r.get_error())
	_refresh()
