# file_utils.gd
# Shared file system utilities used across the codebase

class_name FileUtils
extends RefCounted


static func scan_directory(dir_path: String, extensions: PackedStringArray) -> Array[String]:
	var files: Array[String] = []

	if not DirAccess.dir_exists_absolute(dir_path):
		return files

	var dir = DirAccess.open(dir_path)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while not file_name.is_empty():
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				files.append_array(scan_directory(dir_path + "/" + file_name, extensions))
		else:
			var ext = file_name.get_extension().to_lower()
			if extensions.has(ext):
				files.append(dir_path + "/" + file_name)

		file_name = dir.get_next()

	dir.list_dir_end()
	return files


static func get_content_type(extension: String) -> String:
	match extension:
		"gd": return "text/x-gdscript"
		"tscn": return "text/plain"
		"tres": return "text/plain"
		"urdf": return "application/xml"
		"glb": return "model/gltf-binary"
		"gltf": return "model/gltf+json"
		"obj": return "model/obj"
		"stl": return "model/stl"
		"vrm": return "model/vrm"
		"png": return "image/png"
		"jpg", "jpeg": return "image/jpeg"
		"json": return "application/json"
		"md": return "text/markdown"
		_: return "application/octet-stream"
