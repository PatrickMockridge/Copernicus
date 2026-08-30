# test_mesh.gd
# Headless test for the mesh translator (STL ASCII + binary, OBJ, DAE).
# Run: godot --headless --script res://scripts/test_mesh.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var ascii_path := "user://test_tri.stl"
	_write_text(ascii_path, "solid test\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\nvertex 1 0 0\nvertex 0 1 0\nendloop\nendfacet\nendsolid test\n")
	_ok(_has_geometry(MeshTranslator.translate(ascii_path)), "STL ASCII -> non-empty ArrayMesh")

	var bin_path := "user://test_tri_bin.stl"
	_write_binary_stl(bin_path)
	_ok(_has_geometry(MeshTranslator.translate(bin_path)), "STL binary -> non-empty ArrayMesh")

	var obj_path := "user://test_tri.obj"
	_write_text(obj_path, "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n")
	_ok(_has_geometry(MeshTranslator.translate(obj_path)), "OBJ -> non-empty ArrayMesh")

	var dae_path := "user://test_tri.dae"
	_write_text(dae_path, '<?xml version="1.0"?><COLLADA><library_geometries><geometry><mesh><source id="p"><float_array id="pa" count="9">0 0 0 1 0 0 0 1 0</float_array></source><vertices id="v"><input semantic="POSITION" source="#p"/></vertices><triangles count="1"><input semantic="VERTEX" source="#v" offset="0"/><p>0 1 2</p></triangles></mesh></geometry></library_geometries></COLLADA>')
	_ok(_has_geometry(MeshTranslator.translate(dae_path)), "DAE -> non-empty ArrayMesh")

	_ok(MeshTranslator.translate("user://missing.stl") == null, "missing file -> null")
	_ok(MeshTranslator.translate("user://test_tri.xyz") == null, "unknown extension -> null")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _has_geometry(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	var m := mesh as ArrayMesh
	if m.get_surface_count() == 0:
		return false
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return verts.size() >= 3


func _write_text(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func _write_binary_stl(path: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(84 + 50)  # 80 header + 4 count + 1 triangle (50 bytes)
	bytes.encode_u32(80, 1)
	# normal = (0, 0, 1)
	bytes.encode_float(84, 0.0)
	bytes.encode_float(88, 0.0)
	bytes.encode_float(92, 1.0)
	# v0 = (0, 0, 0)
	bytes.encode_float(96, 0.0)
	bytes.encode_float(100, 0.0)
	bytes.encode_float(104, 0.0)
	# v1 = (1, 0, 0)
	bytes.encode_float(108, 1.0)
	bytes.encode_float(112, 0.0)
	bytes.encode_float(116, 0.0)
	# v2 = (0, 1, 0)
	bytes.encode_float(120, 0.0)
	bytes.encode_float(124, 1.0)
	bytes.encode_float(128, 0.0)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
