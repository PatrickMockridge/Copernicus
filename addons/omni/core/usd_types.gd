# usd_types.gd
# USD type definitions and utilities for parsing USD files

class_name USDTypes
extends RefCounted


## ===== USD Prim Types =====

enum PrimType {
	UNKNOWN = 0,
	SCOPE = 1,
	XFORM = 2,
	MESH = 3,
	CAMERA = 4,
	LIGHT = 5,
	SKELETON = 6,
	ROBOT = 7,
	ARTICULATED = 8
}


## ===== Transform Math =====

## Convert Godot transform to USD matrix
static func godot_transform_to_usd_matrix(transform: Transform3D) -> Array:
	var basis = transform.basis
	var origin = transform.origin

	# USD uses row-major 4x4 matrices
	var matrix = []
	for i in range(3):
		matrix.append(basis.x[i])
		matrix.append(basis.y[i])
		matrix.append(basis.z[i])
		matrix.append(0.0)
	# Translation row
	matrix.append(origin.x)
	matrix.append(origin.y)
	matrix.append(origin.z)
	matrix.append(1.0)

	return matrix


## Convert USD matrix to Godot transform
static func usd_matrix_to_godot_transform(matrix: Array) -> Transform3D:
	if matrix.size() < 16:
		return Transform3D.IDENTITY

	# Extract basis (first 3 rows, first 3 columns)
	var basis = Basis()
	basis.x = Vector3(matrix[0], matrix[1], matrix[2])
	basis.y = Vector3(matrix[4], matrix[5], matrix[6])
	basis.z = Vector3(matrix[8], matrix[9], matrix[10])

	# Extract translation (fourth column of fourth row)
	var origin = Vector3(matrix[12], matrix[13], matrix[14])

	return Transform3D(basis, origin)


## ===== USD Path Utilities =====

## Normalize a USD path
static func normalize_path(path: String) -> String:
	if path.is_empty():
		return "/"
	if not path.begins_with("/"):
		path = "/" + path
	# Remove trailing slash unless root
	if path != "/" and path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
	return path


## Get parent path
static func parent_path(path: String) -> String:
	path = normalize_path(path)
	var last_slash = path.rfind("/")
	if last_slash <= 0:
		return "/"
	return path.substr(0, last_slash)


## Get prim name from path
static func prim_name(path: String) -> String:
	path = normalize_path(path)
	var last_slash = path.rfind("/")
	if last_slash < 0:
		return path
	return path.substr(last_slash + 1)


## ===== Material Conversion =====

## Convert USD material to Godot material
static func convert_material(material_data: Dictionary) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()

	# PBR properties
	if material_data.has("diffuseColor"):
		mat.albedo_color = Color(material_data["diffuseColor"][0],
		                         material_data["diffuseColor"][1],
		                         material_data["diffuseColor"][2])

	if material_data.has("metallic"):
		mat.metallic = material_data["metallic"]

	if material_data.has("roughness"):
		mat.roughness = material_data["roughness"]

	if material_data.has("opacity"):
		mat.albedo_color.a = material_data["opacity"]

	# Texture inputs
	if material_data.has("diffuseColor_texture"):
		var tex_path = material_data["diffuseColor_texture"]
		mat.albedo_texture = load(tex_path)

	if material_data.has("normal_texture"):
		var tex_path = material_data["normal_texture"]
		mat.normal_texture = load(tex_path)

	if material_data.has("metallicRoughness_texture"):
		var tex_path = material_data["metallicRoughness_texture"]
		mat.metallic_texture = load(tex_path)

	return mat


## ===== Mesh Data =====

## Parse mesh from USD mesh prim data
static func parse_mesh(mesh_data: Dictionary) -> Dictionary:
	var result = {
		"vertices": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"uvs": PackedVector2Array(),
		"triangles": PackedInt32Array(),
		"vertex_count": 0,
		"face_count": 0
	}

	if mesh_data.has("points"):
		var points = mesh_data["points"]
		for i in range(0, points.size(), 3):
			result["vertices"].append(Vector3(points[i], points[i+1], points[i+2]))
		result["vertex_count"] = result["vertices"].size()

	if mesh_data.has("normals"):
		var normals = mesh_data["normals"]
		for i in range(0, normals.size(), 3):
			result["normals"].append(Vector3(normals[i], normals[i+1], normals[i+2]))

	if mesh_data.has("uvs"):
		var uvs = mesh_data["uvs"]
		for i in range(0, uvs.size(), 2):
			result["uvs"].append(Vector2(uvs[i], uvs[i+1]))

	if mesh_data.has("face_vertex_counts"):
		var fvc = mesh_data["face_vertex_counts"]
		for count in fvc:
			result["face_count"] += count

	if mesh_data.has("face_vertex_indices"):
		result["triangles"] = PackedInt32Array(mesh_data["face_vertex_indices"])

	return result


## ===== USD Stage Info =====

## Get information about a USD stage without full import
static func get_stage_info(file_path: String) -> Dictionary:
	var py_code = """
import sys
sys.path.insert(0, 'addons/omni/scripts')
from usd_pipeline import USDReader

reader = USDReader()
try:
    stage = reader.open_stage('%s')
    info = {
        'prim_count': reader.count_prims(stage),
        'layers': reader.get_layers(stage),
        'default_prim': reader.get_default_prim(stage),
        'prims': reader.list_all_prims(stage)
    }
    import json
    print(json.dumps(info))
except Exception as e:
    print(json.dumps({'error': str(e)}))
""" % file_path.replace("\\", "\\\\").replace("'", "\\'")

	return _run_python(py_code)


## List all prims under a path
static func list_prims(file_path: String, prim_path: String = "/") -> Array:
	var py_code = """
import sys
sys.path.insert(0, 'addons/omni/scripts')
from usd_pipeline import USDReader

reader = USDReader()
try:
    stage = reader.open_stage('%s')
    prims = reader.list_prims_at_path(stage, '%s')
    import json
    print(json.dumps(prims))
except Exception as e:
    print(json.dumps({'error': str(e)}))
""" % (file_path.replace("\\", "\\\\").replace("'", "\\'"), prim_path.replace("\\", "\\\\").replace("'", "\\'"))

	var result = _run_python(py_code)
	if result is Dictionary and result.has("error"):
		return []
	return result


## Get properties for a specific prim
static func get_prim_props(file_path: String, prim_path: String) -> Dictionary:
	var py_code = """
import sys
sys.path.insert(0, 'addons/omni/scripts')
from usd_pipeline import USDReader

reader = USDReader()
try:
    stage = reader.open_stage('%s')
    props = reader.get_prim_properties(stage, '%s')
    import json
    print(json.dumps(props))
except Exception as e:
    print(json.dumps({'error': str(e)}))
""" % (file_path.replace("\\", "\\\\").replace("'", "\\'"), prim_path.replace("\\", "\\\\").replace("'", "\\'"))

	var result = _run_python(py_code)
	if result is Dictionary and result.has("error"):
		return {}
	return result


## ===== Internal Python Bridge =====

static func _run_python(code: String) -> Variant:
	var temp_dir = ProjectSettings.globalize_path("res://addons/omni/scripts")
	var script_path = temp_dir + "/usd_pipeline.py"

	# Create scripts directory if needed
	var dir = DirAccess.open(temp_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(temp_dir)

	# Create the USD pipeline script
	var script_content = """
import json
try:
    from pxr import Usd, UsdGeom, Sdf, Tf
    USD_AVAILABLE = True
except ImportError:
    USD_AVAILABLE = False


class USDReader:
    def __init__(self):
        self.stage = None

    def open_stage(self, file_path):
        if not USD_AVAILABLE:
            raise Exception("pxr module not available - install with: pip install pxr")

        self.stage = Usd.Stage.Open(file_path)
        return self.stage

    def count_prims(self, stage):
        count = 0
        for prim in stage Traverse():
            count += 1
        return count

    def get_layers(self, stage):
        layers = []
        for layer in stage.GetUsedLayers():
            layers.append(str(layer.identifier))
        return layers

    def get_default_prim(self, stage):
        default = stage.GetDefaultPrim()
        return str(default.GetPath()) if default else None

    def list_all_prims(self, stage):
        prims = []
        for prim in stage Traverse():
            prims.append({
                'path': str(prim.GetPath()),
                'type': prim.GetTypeName(),
                'name': prim.GetName()
            })
        return prims

    def list_prims_at_path(self, stage, path):
        prims = []
        try:
            prim = stage.GetPrimAtPath(path)
            if prim:
                for child in prim.GetChildren():
                    prims.append({
                        'path': str(child.GetPath()),
                        'type': child.GetTypeName(),
                        'name': child.GetName()
                    })
        except Exception as e:
            pass
        return prims

    def get_prim_properties(self, stage, path):
        props = {}
        try:
            prim = stage.GetPrimAtPath(path)
            if prim:
                for attr in prim.GetAttributes():
                    props[attr.GetName()] = attr.Get().Convert('json')
        except Exception as e:
            props['error'] = str(e)
        return props
"""

	# Write script to file
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()

	# Execute
	var output = []
	var result = OS.execute("python3", ["-c", code], output, true)
	if result == OK:
		var json_str = output[0].strip()
		if json_str:
			return JSON.parse_string(json_str)
	return {}


## ===== Prim Type Detection =====

## Detect prim type from USD type name
static func detect_prim_type(type_name: String) -> PrimType:
	match type_name:
		"Scope":
			return PrimType.SCOPE
		"Xform":
			return PrimType.XFORM
		"Mesh":
			return PrimType.MESH
		"Camera":
			return PrimType.CAMERA
		"Light":
			return PrimType.LIGHT
		"Skeleton":
			return PrimType.SKELETON
		_:
			return PrimType.UNKNOWN


## Check if prim is a robot-related type
static func is_robot_prim(prim_data: Dictionary) -> bool:
	var prim_type = prim_data.get("type", "")
	var prim_name = prim_data.get("name", "").to_lower()

	return ("robot" in prim_name or "arm" in prim_name or
	        "manipulator" in prim_name or prim_type == "Robot")


## Check if prim is an articulated figure
static func is_articulated_prim(prim_data: Dictionary) -> bool:
	var prim_name = prim_data.get("name", "").to_lower()
	var prim_type = prim_data.get("type", "")

	return ("joint" in prim_name or "articulation" in prim_name or
	        prim_type == "ArticulationRoot" or prim_type == "PhysicsArticulationRoot")


## ===== Validation =====

## Validate USD file format
static func validate_usd_file(file_path: String) -> Dictionary:
	var result = {
		"valid": false,
		"format": "unknown",
		"has_robot": false,
		"has_mesh": false,
		"prim_count": 0,
		"error": ""
	}

	if not FileAccess.file_exists(file_path):
		result["error"] = "File not found"
		return result

	# Check file header for USD magic bytes
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		# USD binary files start with USD magic or usda text starts with #usda
		var header = file.get_buffer(10)
		if header.size() >= 4:
			# Check for usda ASCII marker
			var header_str = header.get_string_from_ascii()
			if header_str.begins_with("#usda") or header_str.begins_with("usda"):
				result["format"] = "usda"
				result["valid"] = true
			elif header_str.begins_with("PXR"):
				result["format"] = "usdc"
				result["valid"] = true
		file.close()

	# Try to get more info if pxr is available
	var info = get_stage_info(file_path)
	if info.has("prim_count"):
		result["prim_count"] = info["prim_count"]
		result["valid"] = true

	if info.has("prims"):
		for prim in info["prims"]:
			if is_robot_prim(prim):
				result["has_robot"] = true
			if prim.get("type") == "Mesh":
				result["has_mesh"] = true

	return result