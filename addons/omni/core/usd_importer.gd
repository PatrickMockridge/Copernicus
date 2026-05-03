# usd_importer.gd
# Import USD files into Godot scene tree
# Uses Python subprocess with pxr.Usd for parsing

class_name USDImporter
extends RefCounted


## ===== Core Import =====

## Import a USD file and return root Godot node
func import_file(file_path: String) -> Node3D:
	if not FileAccess.file_exists(file_path):
		push_error("USDImporter: file not found: ", file_path)
		return null

	var stage_info = _get_stage_info(file_path)
	if stage_info.is_empty():
		push_error("USDImporter: failed to read USD stage: ", file_path)
		return null

	# Create root node named after file
	var root_name = file_path.get_file().get_basename()
	var root = Node3D.new()
	root.name = root_name

	# Parse and build scene tree
	_build_scene_from_usd(root, file_path, stage_info)

	return root


## Import a robot from USD (expects robot prim)
func import_robot(file_path: String, robot_name: String) -> Node3D:
	var root = import_file(file_path)

	# Find robot prim and extract as separate scene
	var robot_prims = _find_robot_prims(file_path)
	for prim in robot_prims:
		if prim.get("name") == robot_name or prim.get("path").contains(robot_name):
			# Found matching robot, could extract subgraph
			pass

	return root


## ===== Scene Building =====

func _build_scene_from_usd(parent_node: Node3D, file_path: String, stage_info: Dictionary) -> void:
	if not stage_info.has("prims"):
		return

	# Build parent-child relationships from prim paths
	var prims = stage_info["prims"]
	var node_map = {}

	# First pass: create nodes
	for prim in prims:
		var prim_path = prim.get("path", "/")
		var prim_name = prim.get("name", "prim")
		var prim_type = prim.get("type", "Xform")

		var node = _create_node_for_prim(prim_type, prim_name)
		if node:
			node_map[prim_path] = node

	# Second pass: build hierarchy
	for prim in prims:
		var prim_path = prim.get("path", "/")
		var node = node_map.get(prim_path)

		if node:
			var parent_prim_path = _parent_path(prim_path)
			var parent_node_godot = node_map.get(parent_prim_path)

			if parent_node_godot:
				parent_node_godot.add_child(node)
			else:
				# No parent found, add to root
				parent_node.add_child(node)

	# Third pass: batch-query all prim properties in one Python invocation
	var prim_paths = []
	for prim in prims:
		prim_paths.append(prim.get("path", "/"))
	var all_props = _get_all_prim_props(file_path, prim_paths)

	for prim in prims:
		var prim_path = prim.get("path", "/")
		var node = node_map.get(prim_path)
		var props = all_props.get(prim_path, {})

		if node and node is Node3D:
			_apply_prim_properties(node, props)


## ===== Node Creation =====

func _create_node_for_prim(prim_type: String, name: String) -> Node:
	match prim_type:
		"Mesh":
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.name = name
			return mesh_instance
		"Camera":
			var camera = Camera3D.new()
			camera.name = name
			return camera
		"Light":
			var light = DirectionalLight3D.new()
			light.name = name
			return light
		"Xform", "Scope", "SkelRoot", "Robot":
			var xform = Node3D.new()
			xform.name = name
			return xform
		_:
			var generic = Node3D.new()
			generic.name = name
			return generic


## ===== Property Application =====

func _apply_prim_properties(node: Node, props: Dictionary) -> void:
	if node is Node3D and props.has("transform"):
		var transform_data = props["transform"]
		if transform_data is Array and transform_data.size() >= 16:
			var godot_transform = _usd_matrix_to_transform(transform_data)
			node.transform = godot_transform

	if node is MeshInstance3D and props.has("mesh"):
		_apply_mesh_to_instance(node, props["mesh"])

	if node is MeshInstance3D and props.has("material"):
		var mat = USDTypes.convert_material(props["material"])
		node.material_override = mat

	if node is Camera3D:
		_apply_camera_properties(node, props)


func _apply_mesh_to_instance(mesh_node: MeshInstance3D, mesh_data: Variant) -> void:
	if not mesh_data is Dictionary:
		return

	var array_mesh = ArrayMesh.new()

	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()

	if mesh_data.has("points"):
		var points = mesh_data["points"]
		for i in range(0, points.size(), 3):
			vertices.append(Vector3(points[i], points[i + 1], points[i + 2]))

	if mesh_data.has("indices"):
		for i in mesh_data["indices"]:
			indices.append(int(i))

	if mesh_data.has("normals"):
		for i in range(0, mesh_data["normals"].size(), 3):
			normals.append(Vector3(mesh_data["normals"][i], mesh_data["normals"][i + 1], mesh_data["normals"][i + 2]))

	if mesh_data.has("uvs"):
		for i in range(0, mesh_data["uvs"].size(), 2):
			uvs.append(Vector2(mesh_data["uvs"][i], mesh_data["uvs"][i + 1]))

	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices

		if normals.size() == vertices.size():
			arrays[Mesh.ARRAY_NORMAL] = normals

		if uvs.size() == vertices.size():
			arrays[Mesh.ARRAY_TEX_UV] = uvs

		if indices.size() > 0:
			arrays[Mesh.ARRAY_INDEX] = indices

		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_node.mesh = array_mesh


func _apply_camera_properties(camera: Camera3D, props: Dictionary) -> void:
	if props.has("focalLength"):
		# Convert focal length to FOV
		camera.fov = 2.0 * atan(0.036 / props["focalLength"])
	if props.has("horizontalAperture"):
		camera.size = props["horizontalAperture"] / 1000.0


## ===== Matrix Conversion =====

func _usd_matrix_to_transform(matrix: Array) -> Transform3D:
	if matrix.size() < 16:
		return Transform3D.IDENTITY

	# USD matrix is row-major, Godot Basis expects column-major
	# Columns of Godot Basis = rows of USD matrix
	var col0 = Vector3(matrix[0], matrix[1], matrix[2])
	var col1 = Vector3(matrix[4], matrix[5], matrix[6])
	var col2 = Vector3(matrix[8], matrix[9], matrix[10])
	var origin = Vector3(matrix[12], matrix[13], matrix[14])

	var basis = Basis(col0, col1, col2)
	return Transform3D(basis, origin)


## ===== Path Utilities =====

func _parent_path(path: String) -> String:
	if path == "/":
		return ""
	var segments = path.split("/")
	if segments.size() <= 2:
		return "/"
	segments.pop_back()
	return "/".join(segments)


## ===== Python Bridge =====

func _get_stage_info(file_path: String) -> Dictionary:
	var script_path = _get_python_script_path()
	var escaped_path = file_path.replace("\\", "\\\\").replace("'", "\\'")

	var py_code = """
import sys
import json

# Try to import pxr
try:
    from pxr import Usd, UsdGeom, Sdf
    USD_AVAILABLE = True
except ImportError:
    USD_AVAILABLE = False

if not USD_AVAILABLE:
    # Fallback: try to read ASCII USD header
    try:
        with open('%s', 'r') as f:
            content = f.read(1000)
        result = {'usd_available': False, 'ascii': True, 'header': content[:500]}
        print(json.dumps(result))
    except Exception as e:
        print(json.dumps({'error': str(e)}))
    sys.exit(0)

try:
    import json

    stage = Usd.Stage.Open('%s')

    # Collect prim info
    prims = []
    for prim in stage.Traverse():
        prims.append({
            'path': str(prim.GetPath()),
            'name': prim.GetName(),
            'type': prim.GetTypeName()
        })

    # Get layers
    layers = []
    for layer in stage.GetUsedLayers():
        layers.append(str(layer.identifier))

    # Get default prim
    default_prim = stage.GetDefaultPrim()
    default_prim_path = str(default_prim.GetPath()) if default_prim else None

    result = {
        'usd_available': True,
        'prim_count': len(prims),
        'layers': layers,
        'default_prim': default_prim_path,
        'prims': prims
    }

    print(json.dumps(result))

except Exception as e:
    print(json.dumps({'error': str(e)}))
""" % (escaped_path, escaped_path)

	var result = _execute_python(py_code, script_path)
	return result if result is Dictionary else {}


func _find_robot_prims(file_path: String) -> Array:
	var stage_info = _get_stage_info(file_path)
	if not stage_info.has("prims"):
		return []

	var robot_prims = []
	for prim in stage_info["prims"]:
		var name = prim.get("name", "").to_lower()
		var path = prim.get("path", "").to_lower()
		if "robot" in name or "arm" in name or "manipulator" in path:
			robot_prims.append(prim)

	return robot_prims


func _get_all_prim_props(file_path: String, prim_paths: Array) -> Dictionary:
	var escaped_path = file_path.replace("\\", "\\\\").replace("'", "\\'")
	var paths_json = JSON.stringify(prim_paths)
	var escaped_paths = paths_json.replace("'", "\\'")

	var py_code = """
import sys
import json

try:
    from pxr import Usd, UsdGeom, UsdShade

    stage = Usd.Stage.Open('%s')
    prim_paths = json.loads('%s')

    result = {}
    for prim_path in prim_paths:
        prim = stage.GetPrimAtPath(prim_path)
        if not prim:
            result[prim_path] = {"error": "prim not found"}
            continue

        props = {}

        # Transform
        xformable = UsdGeom.Xformable(prim)
        if xformable:
            try:
                matrix = xformable.GetLocalTransformation()
                props['transform'] = [matrix[i][j] for i in range(4) for j in range(4)]
            except:
                pass

        # Mesh data: vertices, normals, UVs, indices
        mesh = UsdGeom.Mesh(prim)
        if mesh:
            mesh_data = {}
            try:
                points_attr = mesh.GetPointsAttr()
                if points_attr:
                    points = points_attr.Get()
                    if points:
                        mesh_data['points'] = [float(p) for p in points]
            except:
                pass

            try:
                indices_attr = mesh.GetFaceVertexIndicesAttr()
                if indices_attr:
                    idxs = indices_attr.Get()
                    if idxs:
                        mesh_data['indices'] = [int(i) for i in idxs]
            except:
                pass

            try:
                normals_attr = mesh.GetNormalsAttr()
                if normals_attr:
                    normals = normals_attr.Get()
                    if normals:
                        mesh_data['normals'] = [float(n) for n in normals]
            except:
                pass

            try:
                uv_primvar = mesh.GetPrimvar('st')
                if uv_primvar:
                    uvs = uv_primvar.Get()
                    if uvs is not None and len(uvs) > 0:
                        mesh_data['uvs'] = [float(u) for u in uvs]
            except:
                pass

            props['mesh'] = mesh_data

            # Material bindings
            try:
                mat_binding = UsdShade.MaterialBindingAPI(prim)
                if mat_binding:
                    bound_mat, relationship = mat_binding.ComputeBoundMaterial()
                    if bound_mat:
                        mat_data = {}
                        mat_data['path'] = str(bound_mat.GetPath())
                        # Walk surface shader outputs
                        for child in bound_mat.GetPrim().GetChildren():
                            if child.GetTypeName() == 'Shader':
                                for attr in child.GetAttributes():
                                    mat_data[attr.GetName()] = attr.Get().Convert('json')
                        props['material'] = mat_data
            except:
                pass

        # Generic attributes
        for attr in prim.GetAttributes():
            try:
                props[attr.GetName()] = attr.Get().Convert('json')
            except:
                pass

        result[prim_path] = props

    print(json.dumps(result))

except Exception as e:
    print(json.dumps({'error': str(e)}))
""" % (escaped_path, escaped_paths)

	var result = _execute_python(py_code, _get_python_script_path())
	return result if result is Dictionary else {}


func _get_prim_props(file_path: String, prim_path: String) -> Dictionary:
	var escaped_path = file_path.replace("\\", "\\\\").replace("'", "\\'")
	var escaped_prim = prim_path.replace("\\", "\\\\").replace("'", "\\'")

	var py_code = """
import sys
import json

try:
    from pxr import Usd, UsdGeom, UsdShade

    stage = Usd.Stage.Open('%s')
    prim = stage.GetPrimAtPath('%s')

    if not prim:
        print(json.dumps({'error': 'prim not found'}))
        sys.exit(0)

    props = {}

    # Transform
    xformable = UsdGeom.Xformable(prim)
    if xformable:
        matrix = xformable.GetLocalTransformation()
        props['transform'] = [matrix[i][j] for i in range(4) for j in range(4)]

    # Mesh data: vertices, normals, UVs, indices
    mesh = UsdGeom.Mesh(prim)
    if mesh:
        mesh_data = {}
        try:
            points = mesh.GetPointsAttr().Get()
            if points:
                mesh_data['points'] = [float(p) for p in points]
        except:
            pass

        try:
            idxs = mesh.GetFaceVertexIndicesAttr().Get()
            if idxs:
                mesh_data['indices'] = [int(i) for i in idxs]
        except:
            pass

        try:
            normals = mesh.GetNormalsAttr().Get()
            if normals:
                mesh_data['normals'] = [float(n) for n in normals]
        except:
            pass

        try:
            uv_primvar = mesh.GetPrimvar('st')
            if uv_primvar:
                uvs = uv_primvar.Get()
                if uvs is not None and len(uvs) > 0:
                    mesh_data['uvs'] = [float(u) for u in uvs]
        except:
            pass

        props['mesh'] = mesh_data

        # Material bindings
        try:
            mat_binding = UsdShade.MaterialBindingAPI(prim)
            if mat_binding:
                bound_mat, relationship = mat_binding.ComputeBoundMaterial()
                if bound_mat:
                    mat_data = {}
                    mat_data['path'] = str(bound_mat.GetPath())
                    for child in bound_mat.GetPrim().GetChildren():
                        if child.GetTypeName() == 'Shader':
                            for attr in child.GetAttributes():
                                mat_data[attr.GetName()] = attr.Get().Convert('json')
                    props['material'] = mat_data
        except:
            pass

    # Generic attributes
    for attr in prim.GetAttributes():
        try:
            props[attr.GetName()] = attr.Get().Convert('json')
        except:
            pass

    print(json.dumps(props))

except Exception as e:
    print(json.dumps({'error': str(e)}))
""" % (escaped_path, escaped_prim)

	var result = _execute_python(py_code, _get_python_script_path())
	return result if result is Dictionary else {}


## ===== Validation =====

func validate_file(file_path: String) -> Dictionary:
	return USDTypes.validate_usd_file(file_path)


## ===== Python Execution Bridge =====

func _get_python_script_path() -> String:
	var temp_dir = ProjectSettings.globalize_path("res://addons/omni/scripts")
	var dir = DirAccess.open(temp_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(temp_dir)
	return temp_dir + "/usd_importer_node.py"


func _execute_python(code: String, script_path: String) -> Variant:
	# Write the code to script file
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()

	# Execute via OS.execute
	var output = []
	var result = OS.execute("python3", ["-c", code], output, true)

	if result == OK and output.size() > 0:
		var json_str = output[0].strip()
		if json_str:
			var parsed = JSON.parse_string(json_str)
			return parsed if parsed else {}

	return {}


## ===== Mesh Creation Helpers =====

## Create ArrayMesh from USD mesh data
static func create_array_mesh(vertices: PackedVector3Array, indices: PackedInt32Array,
                             normals: PackedVector3Array = PackedVector3Array(),
                             uvs: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var mesh = ArrayMesh.new()

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	if normals.size() == vertices.size():
		arrays[Mesh.ARRAY_NORMAL] = normals

	if uvs.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs

	# Add index array if we have triangles
	if indices.size() > 0:
		arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


## Convert USD points array to Godot Vector3 array
static func convert_points(points: Array) -> PackedVector3Array:
	var result = PackedVector3Array()
	for i in range(0, points.size(), 3):
		result.append(Vector3(points[i], points[i+1], points[i+2]))
	return result


## Convert USD indices array
static func convert_indices(indices: Array) -> PackedInt32Array:
	var result = PackedInt32Array()
	for idx in indices:
		result.append(int(idx))
	return result
