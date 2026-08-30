# tools.gd
# The file tools Claude can call while coding in the project. Each tool returns
# {ok, result} or {ok:false, error}. Paths are project-relative and clamped to
# the project root (no escaping via "..").

class_name AiTools
extends RefCounted

const FileUtils = preload("res://scripts/utils/file_utils.gd")

const MAX_LIST := 500
const MAX_SEARCH := 200

var _root: String


func _init(root_dir: String) -> void:
	_root = root_dir.rstrip("/")


func tool_schemas() -> Array:
	return [
		{"name": "read_file", "description": "Read a file in the project. Returns its contents.",
		 "input_schema": {"type": "object", "properties": {"path": {"type": "string", "description": "Project-relative path."}}, "required": ["path"]}},
		{"name": "write_file", "description": "Write content to a file (overwrites; creates parent directories).",
		 "input_schema": {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}}, "required": ["path", "content"]}},
		{"name": "edit_file", "description": "Replace a single occurrence of old_string with new_string in a file. old_string must match exactly once.",
		 "input_schema": {"type": "object", "properties": {"path": {"type": "string"}, "old_string": {"type": "string"}, "new_string": {"type": "string"}}, "required": ["path", "old_string", "new_string"]}},
		{"name": "list_files", "description": "List project files, optionally filtered by extension.",
		 "input_schema": {"type": "object", "properties": {"extensions": {"type": "array", "items": {"type": "string"}, "description": "e.g. [\"gd\", \"tscn\"]; empty = all"}}}},
		{"name": "search", "description": "Search project text files for a substring; returns matching file paths.",
		 "input_schema": {"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}},
	]


func execute(name: String, input: Dictionary) -> Dictionary:
	match name:
		"read_file":
			return _read_file(str(input.get("path", "")))
		"write_file":
			return _write_file(str(input.get("path", "")), str(input.get("content", "")))
		"edit_file":
			return _edit_file(str(input.get("path", "")), str(input.get("old_string", "")), str(input.get("new_string", "")))
		"list_files":
			return _list_files(input.get("extensions", []))
		"search":
			return _search(str(input.get("query", "")))
	return {"ok": false, "error": "Unknown tool: " + name}


## Resolve a project-relative path to an absolute path, or "" if it escapes the root.
func _resolve(rel: String) -> String:
	var clean := rel.strip_edges().replace("\\", "/")
	if clean.begins_with("/"):
		clean = clean.substr(1)
	var abs_path := _root.path_join(clean).simplify_path()
	if abs_path != _root and not abs_path.begins_with(_root + "/"):
		return ""
	return abs_path


func _read_file(rel: String) -> Dictionary:
	var p := _resolve(rel)
	if p.is_empty():
		return {"ok": false, "error": "Path escapes the project root: " + rel}
	if not FileAccess.file_exists(p):
		return {"ok": false, "error": "File not found: " + rel}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "Could not read: " + rel}
	return {"ok": true, "result": f.get_as_text()}


func _write_file(rel: String, content: String) -> Dictionary:
	var p := _resolve(rel)
	if p.is_empty():
		return {"ok": false, "error": "Path escapes the project root: " + rel}
	var dir := p.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Could not write: " + rel}
	f.store_string(content)
	f.close()
	return {"ok": true, "result": "Wrote " + rel + " (" + str(content.length()) + " chars)"}


func _edit_file(rel: String, old_string: String, new_string: String) -> Dictionary:
	var p := _resolve(rel)
	if p.is_empty():
		return {"ok": false, "error": "Path escapes the project root: " + rel}
	if old_string.is_empty():
		return {"ok": false, "error": "old_string is empty"}
	if not FileAccess.file_exists(p):
		return {"ok": false, "error": "File not found: " + rel}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "Could not read: " + rel}
	var content := f.get_as_text()
	var count := content.count(old_string)
	if count == 0:
		return {"ok": false, "error": "old_string not found in " + rel}
	if count > 1:
		return {"ok": false, "error": "old_string matches %d times in %s; make it more specific" % [count, rel]}
	var w := FileAccess.open(p, FileAccess.WRITE)
	if w == null:
		return {"ok": false, "error": "Could not write: " + rel}
	w.store_string(content.replace(old_string, new_string))
	w.close()
	return {"ok": true, "result": "Edited " + rel}


func _list_files(extensions: Array) -> Dictionary:
	var exts := PackedStringArray()
	for e in extensions:
		var s := str(e).to_lower().lstrip(".")
		if not s.is_empty():
			exts.append(s)
	var files := FileUtils.scan_directory(_root, exts)
	var out: Array = []
	for f in files:
		out.append(str(f).substr(_root.length() + 1))
		if out.size() >= MAX_LIST:
			out.append("… (truncated)")
			break
	return {"ok": true, "result": "\n".join(out)}


func _search(query: String) -> Dictionary:
	if query.is_empty():
		return {"ok": false, "error": "query is empty"}
	var exts := PackedStringArray(["gd", "tscn", "tres", "py", "md", "json", "cfg", "godot"])
	var files := FileUtils.scan_directory(_root, exts)
	var hits: Array = []
	for f in files:
		if not FileAccess.file_exists(f):
			continue
		var content := FileAccess.get_file_as_string(f)
		if content.contains(query):
			hits.append(str(f).substr(_root.length() + 1))
			if hits.size() >= MAX_SEARCH:
				break
	if hits.is_empty():
		return {"ok": true, "result": "No matches for: " + query}
	return {"ok": true, "result": "Matches in:\n" + "\n".join(hits)}
