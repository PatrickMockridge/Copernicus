# test_shortcuts.gd
# Headless unit test for ShortcutManager. Run:
#   godot --headless --script res://scripts/test_shortcuts.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var mgr := ShortcutManager.new()
	_ok(mgr.match_event(_key(KEY_1, true, false, false)) == "mode_select", "Ctrl+1 -> mode_select")
	_ok(mgr.match_event(_key(KEY_2, true, false, false)) == "mode_translate", "Ctrl+2 -> mode_translate")
	_ok(mgr.match_event(_key(KEY_3, true, false, false)) == "mode_rotate", "Ctrl+3 -> mode_rotate")
	_ok(mgr.match_event(_key(KEY_G, true, false, false)) == "toggle_grid", "Ctrl+G -> toggle_grid")
	_ok(mgr.match_event(_key(KEY_W, true, false, false)) == "toggle_wireframe", "Ctrl+W -> toggle_wireframe")
	_ok(mgr.match_event(_key(KEY_R, true, false, false)) == "toggle_render", "Ctrl+R -> toggle_render")
	_ok(mgr.match_event(_key(KEY_G, false, false, false)) == "", "bare G matches nothing")
	_ok(mgr.match_event(_key(KEY_1, false, false, false)) == "", "bare 1 matches nothing")

	# Load from a user-edited JSON remaps the binding.
	var path := "user://test_shortcuts.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"toggle_grid": "Alt+G"}')
	f.close()
	var mgr2 := ShortcutManager.new()
	mgr2.load_from(path)
	_ok(mgr2.match_event(_key(KEY_G, false, true, false)) == "toggle_grid", "remap Alt+G round-trips")
	_ok(mgr2.match_event(_key(KEY_G, true, false, false)) == "", "old Ctrl+G no longer bound")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _key(kc: Key, ctrl: bool, alt: bool, shift: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = kc
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	e.shift_pressed = shift
	e.pressed = true
	return e


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
