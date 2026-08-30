# dae_parser.gd
# COLLADA/DAE -> ArrayMesh. Best-effort parser: takes the first <float_array>
# as vertex positions and the first <p> index list as triangles. Assumes the
# position index is offset 0 of each stride (standard COLLADA VERTEX input).

class_name DaeParser


static func parse(path: String) -> ArrayMesh:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		return null

	var float_arrays: Array = []   # Array[PackedFloat32Array]
	var p_text := ""
	var in_float_array := false
	var float_text := ""
	var in_p := false
	var in_primitives := false
	var primitive_inputs := 0
	var p_stride := 1

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var name := parser.get_node_name()
				if name == "float_array":
					in_float_array = true
					float_text = ""
				elif name == "p":
					in_p = true
					p_text = ""
				elif name == "input" and in_primitives:
					primitive_inputs += 1
				elif name == "triangles" or name == "polylist" or name == "polygons":
					in_primitives = true
					primitive_inputs = 0
			XMLParser.NODE_TEXT:
				var data := parser.get_node_data()
				if in_float_array:
					float_text += data
				elif in_p:
					p_text += data
			XMLParser.NODE_ELEMENT_END:
				var name := parser.get_node_name()
				if name == "float_array":
					in_float_array = false
					float_arrays.append(_parse_floats(float_text))
				elif name == "p":
					in_p = false
					p_stride = max(primitive_inputs, 1)
				elif name == "triangles" or name == "polylist" or name == "polygons":
					in_primitives = false

	if float_arrays.is_empty() or float_arrays[0].size() < 9:
		return null
	var positions: PackedFloat32Array = float_arrays[0]
	var p_ints := _parse_ints(p_text)
	if p_ints.size() < p_stride * 3:
		return null

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tri_count := int(p_ints.size() / p_stride) / 3
	var k := 0
	for t in tri_count:
		var i0 := p_ints[k] * 3; k += p_stride
		var i1 := p_ints[k] * 3; k += p_stride
		var i2 := p_ints[k] * 3; k += p_stride
		var v0 := Vector3(positions[i0], positions[i0 + 1], positions[i0 + 2])
		var v1 := Vector3(positions[i1], positions[i1 + 1], positions[i1 + 2])
		var v2 := Vector3(positions[i2], positions[i2 + 1], positions[i2 + 2])
		var n := _face_normal(v0, v1, v2)
		vertices.append(v0); normals.append(n)
		vertices.append(v1); normals.append(n)
		vertices.append(v2); normals.append(n)

	return _build(vertices, normals)


static func _parse_floats(text: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for tok in _tokens(text):
		out.append(float(tok))
	return out


static func _parse_ints(text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tok in _tokens(text):
		out.append(int(tok))
	return out


static func _tokens(text: String) -> PackedStringArray:
	return text.replace("\r", " ").replace("\n", " ").replace("\t", " ").split(" ", false)


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
