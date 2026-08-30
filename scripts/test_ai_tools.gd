# test_ai_tools.gd
# Headless test for the AI file tools. Run:
#   godot --headless --script res://scripts/test_ai_tools.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var root := "/tmp/copernicus_ai_test"
	if DirAccess.dir_exists_absolute(root):
		_rmdir(root)
	DirAccess.make_dir_recursive_absolute(root)
	var tools := AiTools.new(root)

	# write / read round trip (creates parent dirs)
	_ok(tools.execute("write_file", {"path": "a/b.txt", "content": "hello world"}).get("ok", false), "write creates dirs")
	_ok(tools.execute("read_file", {"path": "a/b.txt"}).get("result", "") == "hello world", "read round-trips")

	# edit single occurrence
	_ok(tools.execute("edit_file", {"path": "a/b.txt", "old_string": "world", "new_string": "there"}).get("ok", false), "edit ok")
	_ok(tools.execute("read_file", {"path": "a/b.txt"}).get("result", "") == "hello there", "edit applied")

	# edit non-unique old_string errors
	tools.execute("write_file", {"path": "dup.txt", "content": "x x"})
	_ok(not tools.execute("edit_file", {"path": "dup.txt", "old_string": "x", "new_string": "y"}).get("ok", false), "non-unique old_string errors")

	# edit missing old_string errors
	_ok(not tools.execute("edit_file", {"path": "dup.txt", "old_string": "zzz", "new_string": "y"}).get("ok", false), "missing old_string errors")

	# path escape rejected
	_ok(not tools.execute("read_file", {"path": "../secret.txt"}).get("ok", false), "../ read escape rejected")
	_ok(not tools.execute("write_file", {"path": "../../etc/x", "content": "nope"}).get("ok", false), "../ write escape rejected")

	# list + search
	_ok(tools.execute("list_files", {"extensions": ["txt"]}).get("ok", false), "list ok")
	tools.execute("write_file", {"path": "foo.gd", "content": "func hello():\n\tpass\n"})
	var sr := tools.execute("search", {"query": "hello"})
	_ok(sr.get("ok", false), "search ok")
	_ok("foo.gd" in str(sr.get("result", "")), "search finds .gd")

	# unknown tool
	_ok(not tools.execute("nope", {}).get("ok", false), "unknown tool errors")

	_rmdir(root)

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _rmdir(p: String) -> void:
	var dir := DirAccess.open(p)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while not n.is_empty():
		if n != "." and n != "..":
			var full := p + "/" + n
			if dir.current_is_dir():
				_rmdir(full)
			else:
				DirAccess.remove_absolute(full)
		n = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(p)


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
