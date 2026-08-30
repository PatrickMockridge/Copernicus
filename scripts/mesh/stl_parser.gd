# stl_parser.gd
# STL (ASCII + binary) -> ArrayMesh. Triangles are non-indexed with per-face
# normals (flat shading).

class_name StlParser


static func parse(path: String) -> ArrayMesh:
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 84:
		return null
	# Binary STL: 80-byte header + uint32 triangle count + count*50 bytes.
	var count := bytes.decode_u32(80)
	if count > 0 and count <= bytes.size() / 50 and 84 + count * 50 == bytes.size():
		return _parse_binary(bytes, count)
	return _parse_ascii(bytes)


static func _parse_binary(bytes: PackedByteArray, count: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var off := 84
	for i in count:
		off += 12  # face normal (recomputed below)
		var v0 := _read_vec3(bytes, off); off += 12
		var v1 := _read_vec3(bytes, off); off += 12
		var v2 := _read_vec3(bytes, off); off += 12
		off += 2  # attribute byte count
		var n := _face_normal(v0, v1, v2)
		vertices.append(v0); normals.append(n)
		vertices.append(v1); normals.append(n)
		vertices.append(v2); normals.append(n)
	return _build(vertices, normals)


static func _parse_ascii(bytes: PackedByteArray) -> ArrayMesh:
	var text := bytes.get_string_from_utf8()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tri: Array[Vector3] = []
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("vertex"):
			continue
		var parts := line.split(" ", false)
		if parts.size() < 4:
			continue
		tri.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
		if tri.size() == 3:
			var n := _face_normal(tri[0], tri[1], tri[2])
			for k in 3:
				vertices.append(tri[k])
				normals.append(n)
			tri.clear()
	if vertices.is_empty():
		return null
	return _build(vertices, normals)


static func _read_vec3(bytes: PackedByteArray, off: int) -> Vector3:
	return Vector3(bytes.decode_float(off), bytes.decode_float(off + 4), bytes.decode_float(off + 8))


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
