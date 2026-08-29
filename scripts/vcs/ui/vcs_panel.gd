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
	var win := UiPanel.new().setup("Version Control")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)

	var backend_btn := UiButton.new().setup("Backend", UiButton.Variant.SECONDARY)
	backend_btn.pressed.connect(_on_backend_pressed)
	win.title_actions().add_child(backend_btn)

	var v: VBoxContainer = win.body()

	_status_label = UiLabel.new().setup("", UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status_label)

	v.add_child(UiSeparator.new())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	# Remote
	var remote := _page()
	tabs.add_child(remote)
	tabs.set_tab_title(0, "Remote")
	var remote_row := HBoxContainer.new()
	remote.add_child(remote_row)
	_remote_input = LineEdit.new()
	_remote_input.placeholder_text = "git URL or Ariadne repo id"
	_remote_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remote_row.add_child(_remote_input)
	var set_remote_btn := UiButton.new().setup("Set Remote", UiButton.Variant.SECONDARY)
	set_remote_btn.pressed.connect(_on_set_remote)
	remote_row.add_child(set_remote_btn)
	var clone_btn := UiButton.new().setup("Clone", UiButton.Variant.SECONDARY)
	clone_btn.pressed.connect(_on_clone)
	remote_row.add_child(clone_btn)

	# Commit
	var commit := _page()
	tabs.add_child(commit)
	tabs.set_tab_title(1, "Commit")
	var commit_row := HBoxContainer.new()
	commit.add_child(commit_row)
	_message_input = LineEdit.new()
	_message_input.placeholder_text = "commit message"
	_message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commit_row.add_child(_message_input)
	var commit_btn := UiButton.new().setup("Commit", UiButton.Variant.PRIMARY)
	commit_btn.pressed.connect(_on_commit)
	commit_row.add_child(commit_btn)
	var sync_row := HBoxContainer.new()
	commit.add_child(sync_row)
	var push_btn := UiButton.new().setup("Push", UiButton.Variant.SECONDARY)
	push_btn.pressed.connect(_on_push)
	sync_row.add_child(push_btn)
	var pull_btn := UiButton.new().setup("Pull", UiButton.Variant.SECONDARY)
	pull_btn.pressed.connect(_on_pull)
	sync_row.add_child(pull_btn)
	var refresh_btn := UiButton.new().setup("Refresh", UiButton.Variant.SECONDARY)
	refresh_btn.pressed.connect(_refresh)
	sync_row.add_child(refresh_btn)

	# History
	var history := _page()
	tabs.add_child(history)
	tabs.set_tab_title(2, "History")
	_log_output = TextEdit.new()
	_log_output.editable = false
	_log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.add_child(_log_output)


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UiTheme.space("s"))
	return page


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
