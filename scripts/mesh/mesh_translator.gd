# mesh_translator.gd
# Dispatches a mesh file to the right parser by extension, returning an
# ArrayMesh. Used by the URDF importer when native load() cannot read a file
# (STL/OBJ/DAE).

class_name MeshTranslator

const StlParser = preload("res://scripts/mesh/stl_parser.gd")
const ObjParser = preload("res://scripts/mesh/obj_parser.gd")
const DaeParser = preload("res://scripts/mesh/dae_parser.gd")


static func translate(path: String) -> Mesh:
	var ext := path.get_extension().to_lower()
	match ext:
		"stl":
			return StlParser.parse(path)
		"obj":
			return ObjParser.parse(path)
		"dae":
			return DaeParser.parse(path)
	return null
