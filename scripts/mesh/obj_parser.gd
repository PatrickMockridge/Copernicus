# obj_parser.gd
# Wavefront OBJ -> ArrayMesh. Positions are indexed; faces are fan-triangulated
# and emitted non-indexed with flat (computed) normals.

class_name ObjParser


static func parse(path: String) -> ArrayMesh:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var positions: Array[Vector3] = []
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts[0] == "v" and parts.size() >= 4:
			positions.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
		elif parts[0] == "f" and parts.size() >= 4:
			_emit_face(parts, positions, out_verts, out_normals)
	if out_verts.is_empty():
		return null
	return _build(out_verts, out_normals)


static func _emit_face(parts: PackedStringArray, positions: Array, out_verts: PackedVector3Array, out_normals: PackedVector3Array) -> void:
	var idx: Array[int] = []
	for i in range(1, parts.size()):
		var seg := parts[i].split("/")
		idx.append(int(seg[0]) - 1)
	if idx.size() < 3:
		return
	for i in range(1, idx.size() - 1):
		var v0 := _resolve(positions, idx[0])
		var v1 := _resolve(positions, idx[i])
		var v2 := _resolve(positions, idx[i + 1])
		var n := _face_normal(v0, v1, v2)
		out_verts.append(v0); out_verts.append(v1); out_verts.append(v2)
		out_normals.append(n); out_normals.append(n); out_normals.append(n)


static func _resolve(positions: Array, i: int) -> Vector3:
	if i < 0:
		i = positions.size() + i
	if i >= 0 and i < positions.size():
		return positions[i]
	return Vector3.ZERO


static func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.is_zero_approx():
		return Vector3.UP
	return n.normalized()


static func _build(vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
