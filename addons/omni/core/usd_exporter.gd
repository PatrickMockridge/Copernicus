# usd_exporter.gd
# Export Godot scenes to USD format
# Uses Python subprocess with pxr.Usd for writing

class_name USDExporter
extends RefCounted


## ===== Configuration =====

var _export_scale: float = 1.0  # 1.0 = meters
var _export_materials: bool = true
var _export_lights: bool = true
var _export_cameras: bool = true


func configure(config: Dictionary) -> void:
	_export_scale = config.get("scale", 1.0)
	_export_materials = config.get("export_materials", true)
	_export_lights = config.get("export_lights", true)
	_export_cameras = config.get("export_cameras", true)


## ===== Main Export =====

## Export a Godot scene to USD file
func export_scene(scene: Node3D, output_path: String) -> bool:
	if scene == null:
		push_error("USDExporter: scene is null")
		return false

	var script_path = _get_python_script_path()
	var scene_data = _collect_scene_data(scene)

	# Write Python export script
	var py_code = _generate_export_script(scene_data, output_path)

	# Execute export
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(py_code)
		file.close()

	var output = []
	var result = OS.execute("python3", [script_path], output, true)

	if result == OK:
		print("USDExporter: exported to ", output_path)
		return true
	else:
		push_error("USDExporter: export failed: ", output)
		return false


## Export scene with animation
func export_scene_with_animation(scene: Node3D, output_path: String, anim_name: String = "Animation") -> bool:
	# TODO: Support animation export
	return export_scene(scene, output_path)


## ===== Scene Data Collection =====

func _collect_scene_data(node: Node3D) -> Dictionary:
	var data = {
		"nodes": [],
		"materials": [],
		"meshes": []
	}

	_collect_node_recursive(node, data, "/")

	return data


func _collect_node_recursive(node: Node, data: Dictionary, usd_path: String) -> void:
	if not node:
		return

	var node_data = {
		"path": usd_path,
		"name": node.name,
		"type": _get_node_usd_type(node),
		"transform": _get_node_transform(node),
		"children": []
	}

	# Collect node-specific data
	if node is MeshInstance3D:
		_collect_mesh_data(node, data, usd_path)
		node_data["mesh"] = node.name + "_mesh"

	if node is Camera3D:
		_collect_camera_data(node, node_data)

	if node is DirectionalLight3D or node is OmniLight3D or node is SpotLight3D:
		_collect_light_data(node, node_data)

	if node is CollisionShape3D:
		_collect_collision_data(node, node_data)

	data["nodes"].append(node_data)

	# Recurse children
	for child in node.get_children():
		if child is Node3D:
			var child_path = usd_path + "/" + child.name
			_collect_node_recursive(child, data, child_path)


func _get_node_usd_type(node: Node) -> String:
	if node is MeshInstance3D:
		return "Mesh"
	if node is Camera3D:
		return "Camera"
	if node is DirectionalLight3D:
		return "DistantLight"
	if node is OmniLight3D:
		return "SphereLight"
	if node is SpotLight3D:
		return "SpotLight"
	if node is CollisionShape3D:
		return "Mesh"  # Collision shapes become meshes
	if node is Node3D:
		return "Xform"
	return "Scope"


func _get_node_transform(node: Node) -> Array:
	if node is Node3D:
		var t = node.transform
		var basis = t.basis

		# Row-major 4x4 matrix
		return [
			basis.x.x, basis.y.x, basis.z.x, 0,
			basis.x.y, basis.y.y, basis.z.y, 0,
			basis.x.z, basis.y.z, basis.z.z, 0,
			t.origin.x, t.origin.y, t.origin.z, 1
		]
	return [
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1
	]


func _collect_mesh_data(mesh_node: MeshInstance3D, data: Dictionary, usd_path: String) -> void:
	if not mesh_node.mesh:
		return

	var mesh_data = {
		"name": mesh_node.name + "_mesh",
		"path": usd_path + "/" + mesh_node.name + "_mesh",
		"vertices": [],
		"normals": [],
		"uvs": [],
		"indices": []
	}

	# Extract vertices from mesh
	if mesh_node.mesh is ArrayMesh:
		for surface_idx in range(mesh_node.mesh.get_surface_count()):
			var arrays = mesh_node.mesh.surface_get_arrays(surface_idx)
			if arrays.size() > 0:
				var verts = arrays[Mesh.ARRAY_VERTEX]
				if verts is PackedVector3Array:
					for v in verts:
						mesh_data["vertices"].append([v.x, v.y, v.z])

				# Normals
				if arrays.size() > Mesh.ARRAY_NORMAL:
					var nrm = arrays[Mesh.ARRAY_NORMAL]
					if nrm is PackedVector3Array:
						for n in nrm:
							mesh_data["normals"].append([n.x, n.y, n.z])

				# UVs
				if arrays.size() > Mesh.ARRAY_TEX_UV:
					var uv = arrays[Mesh.ARRAY_TEX_UV]
					if uv is PackedVector2Array:
						for u in uv:
							mesh_data["uvs"].append([u.x, u.y])

			# Indices
			if arrays.size() > Mesh.ARRAY_INDEX:
				var idx = arrays[Mesh.ARRAY_INDEX]
				if idx is PackedInt32Array:
					for i in idx:
						mesh_data["indices"].append(int(i))

	data["meshes"].append(mesh_data)

	# Collect material if present
	if _export_materials:
		var mat = mesh_node.material_override
		if not mat and mesh_node.mesh is ArrayMesh and mesh_node.mesh.get_surface_count() > 0:
			mat = mesh_node.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var mat_data = _collect_material_data(mat, mesh_data["path"])
			if not mat_data.is_empty():
				data["materials"].append(mat_data)


func _collect_material_data(mat: StandardMaterial3D, binding_path: String) -> Dictionary:
	var mat_name = binding_path.get_file() + "_material"
	var mat_path = binding_path + "/" + mat_name

	var data = {
		"name": mat_name,
		"path": mat_path,
		"binding": binding_path
	}

	data["diffuseColor"] = [mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b]
	data["metallic"] = mat.metallic
	data["roughness"] = mat.roughness
	data["opacity"] = mat.albedo_color.a

	if mat.emission_enabled:
		data["emissiveColor"] = [mat.emission.r * mat.emission_energy_multiplier,
		                         mat.emission.g * mat.emission_energy_multiplier,
		                         mat.emission.b * mat.emission_energy_multiplier]

	return data


func _collect_camera_data(camera: Camera3D, node_data: Dictionary) -> void:
	node_data["focalLength"] = 0.036 / tan(deg_to_rad(camera.fov / 2.0))
	node_data["horizontalAperture"] = 0.036


func _collect_light_data(light: Node, node_data: Dictionary) -> void:
	if light is DirectionalLight3D:
		node_data["intensity"] = light.light_energy * 100000
		node_data["color"] = [light.light_color.r, light.light_color.g, light.light_color.b]
		node_data["angle"] = rad_to_deg(light.angle)
	elif light is OmniLight3D:
		node_data["intensity"] = light.light_energy * 100000
		node_data["color"] = [light.light_color.r, light.light_color.g, light.light_color.b]
		node_data["radius"] = light.omni_range
	elif light is SpotLight3D:
		node_data["intensity"] = light.light_energy * 100000
		node_data["color"] = [light.light_color.r, light.light_color.g, light.light_color.b]
		node_data["angle"] = rad_to_deg(light.spot_angle)


func _collect_collision_data(collision: CollisionShape3D, node_data: Dictionary) -> void:
	# Collision shapes could be exported as mesh
	pass


## ===== Python Script Generation =====

func _generate_export_script(scene_data: Dictionary, output_path: String) -> String:
	# Convert scene data to JSON
	var scene_json = JSON.stringify(scene_data)

	# Escape for Python
	var escaped_json = scene_json.replace("\\", "\\\\").replace("'", "\\'")
	var escaped_output = output_path.replace("\\", "\\\\").replace("'", "\\'")

	var py_code = """
import json
import sys

try:
    from pxr import Usd, UsdGeom, UsdShade, Sdf, Gf

    # Scene data from Godot
    scene_json = '%s'
    scene_data = json.loads(scene_json.replace('\\\\"', '"'))

    # Create stage
    stage = Usd.Stage.CreateNew('%s')

    # Default prim
    root_prim = stage.DefinePrim("/World", "Scope")
    stage.SetDefaultPrim(root_prim)

    # Export materials first (so we can bind them to meshes)
    material_map = {}
    for mat in scene_data.get('materials', []):
        mat_path = mat['path']
        mat_prim = stage.DefinePrim(mat_path, 'Material')
        shader_path = mat_path + '/Shader'
        shader_prim = stage.DefinePrim(shader_path, 'Shader')
        shader_prim.CreateAttribute('info:id', Sdf.ValueTypeNames.Token).Set('UsdPreviewSurface')

        if 'diffuseColor' in mat:
            shader_prim.CreateAttribute('inputs:diffuseColor', Sdf.ValueTypeNames.Color3f).Set(
                Gf.Vec3f(*mat['diffuseColor']))
        if 'metallic' in mat:
            shader_prim.CreateAttribute('inputs:metallic', Sdf.ValueTypeNames.Float).Set(
                float(mat['metallic']))
        if 'roughness' in mat:
            shader_prim.CreateAttribute('inputs:roughness', Sdf.ValueTypeNames.Float).Set(
                float(mat['roughness']))
        if 'opacity' in mat:
            shader_prim.CreateAttribute('inputs:opacity', Sdf.ValueTypeNames.Float).Set(
                float(mat['opacity']))

        usd_mat = UsdShade.Material(mat_prim)
        usd_shader = UsdShade.Shader(shader_prim)
        usd_mat.CreateSurfaceOutput().ConnectToSource(usd_shader.ConnectableAPI(), 'surface')
        material_map[mat['binding']] = mat_path

    # Export nodes
    for node in scene_data.get('nodes', []):
        usd_path = node['path']
        node_type = node.get('type', 'Xform')

        prim = stage.DefinePrim(usd_path, node_type)

        # Set transform
        if 'transform' in node:
            matrix = node['transform']
            gf_matrix = Gf.Matrix4d(*matrix)
            xform = UsdGeom.Xformable(prim)
            xform.SetLocalTransformation(gf_matrix)

        # Camera properties
        if node_type == 'Camera' and 'focalLength' in node:
            camera_api = UsdGeom.Camera(prim)
            camera_api.CreateFocalLengthAttr().Set(node['focalLength'])
            camera_api.CreateHorizontalApertureAttr().Set(node.get('horizontalAperture', 0.036))

        # Light properties
        if 'intensity' in node:
            if node_type == 'DistantLight':
                light_api = UsdGeom.DistantLight(prim)
            elif node_type == 'SphereLight':
                light_api = UsdGeom.SphereLight(prim)
            elif node_type == 'SpotLight':
                light_api = UsdGeom.SphereLight(prim)
            else:
                light_api = UsdGeom.DistantLight(prim)

            light_api.CreateIntensityAttr().Set(node['intensity'])
            if 'color' in node:
                light_api.CreateColorAttr().Set(Gf.Vec3f(*node['color']))

    # Export meshes
    for mesh_data in scene_data.get('meshes', []):
        mesh_path = mesh_data['path']
        mesh_prim = stage.DefinePrim(mesh_path, 'Mesh')

        points = mesh_data.get('vertices', [])
        if points:
            usd_points = [Gf.Vec3f(*p) for p in points]
            mesh = UsdGeom.Mesh(mesh_prim)
            mesh.CreatePointsAttr().Set(usd_points)

            indices = mesh_data.get('indices', [])
            if indices:
                mesh.CreateFaceVertexIndicesAttr().Set(indices)
                face_count = len(indices) // 3
                if face_count > 0:
                    mesh.CreateFaceVertexCountsAttr().Set([3] * face_count)

            normals = mesh_data.get('normals', [])
            if normals and len(normals) == len(points):
                mesh.CreateNormalsAttr().Set([Gf.Vec3f(*n) for n in normals])

            uvs = mesh_data.get('uvs', [])
            if uvs and len(uvs) == len(points):
                mesh.CreatePrimvar('st', Sdf.ValueTypeNames.TexCoord2fArray).Set(
                    [Gf.Vec2f(*u) for u in uvs])

        # Bind material
        mat_path = material_map.get(mesh_path)
        if mat_path:
            mat_prim = stage.GetPrimAtPath(mat_path)
            if mat_prim:
                UsdShade.MaterialBindingAPI(mesh_prim).Bind(
                    UsdShade.Material(mat_prim))

    # Save
    stage.GetRootLayer().Save()

    print('Export successful')

except Exception as e:
    print('Export failed: ' + str(e), file=sys.stderr)
    sys.exit(1)
""" % [escaped_json, escaped_output]

	return py_code


## ===== Utility =====

func _get_python_script_path() -> String:
	var temp_dir = ProjectSettings.globalize_path("res://addons/omni/scripts")
	var dir = DirAccess.open(temp_dir)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(temp_dir)
	return temp_dir + "/usd_exporter_node.py"


## ===== USD Generation (ASCII) =====

## Generate ASCII USD file directly (without pxr dependency)
func generate_ascii_usd(scene: Node3D) -> String:
	var lines = []
	lines.append("#usda 1.0")
	lines.append("")
	lines.append("(defaultPrim = World)")
	lines.append("")

	# World root
	lines.append("def Scope 'World' {")

	# Recursively add children
	_generate_usd_recursive(scene, lines, 1)

	lines.append("}")

	return "\n".join(lines)


func _generate_usd_recursive(node: Node, lines: Array, indent: int) -> void:
	if not node:
		return

	var indent_str = "    ".repeat(indent)

	# Node header
	var node_type = _get_usda_node_type(node)
	var node_name = node.name.replace(" ", "_")

	lines.append("%sdef %s '%s' (" % [indent_str, node_type, node_name])

	# Transform
	if node is Node3D:
		var t = node.transform
		lines.append("%s    token xformOp:transform" % indent_str)
		lines.append("%s    uniform token[] xformOpOrder = [xformOp:transform]" % indent_str)

		# Matrix value
		var basis = t.basis
		var origin = t.origin
		var m00 = "%.6f" % basis.x.x
		var m01 = "%.6f" % basis.y.x
		var m02 = "%.6f" % basis.z.x
		var m10 = "%.6f" % basis.x.y
		var m11 = "%.6f" % basis.y.y
		var m12 = "%.6f" % basis.z.y
		var m20 = "%.6f" % basis.x.z
		var m21 = "%.6f" % basis.y.z
		var m22 = "%.6f" % basis.z.z
		var m30 = "%.6f" % origin.x
		var m31 = "%.6f" % origin.y
		var m32 = "%.6f" % origin.z

		lines.append("%s    double4 xformOp:transform = (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 1)" % [
			indent_str, m00, m01, m02, m10, m11, m12, m20, m21, m22, m30, m31, m32])

	if node is Camera3D:
		lines.append("%s    float focalLength = 0.036" % indent_str)
		lines.append("%s    float horizontalAperture = 0.036" % indent_str)

	if node is MeshInstance3D and node.mesh:
		_generate_usd_mesh_data(node, lines, indent_str)

	lines.append("%s) {" % indent_str)

	# Children
	for child in node.get_children():
		if child is Node3D:
			_generate_usd_recursive(child, lines, indent + 1)

	lines.append("%s}" % indent_str)


func _generate_usd_mesh_data(mesh_node: MeshInstance3D, lines: Array, indent_str: String) -> void:
	var mesh = mesh_node.mesh
	if not mesh is ArrayMesh:
		return

	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.size() == 0:
			continue

		var vertices = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else null
		var indices = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
		var normals = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL else null
		var uvs = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV else null

		if vertices and vertices is PackedVector3Array and vertices.size() > 0:
			var pt_strs = []
			for v in vertices:
				pt_strs.append("(%.6f, %.6f, %.6f)" % [v.x, v.y, v.z])
			lines.append("%s    point3f[] points = [%s]" % [indent_str, ", ".join(pt_strs)])

		if indices and indices is PackedInt32Array and indices.size() > 0:
			var idx_strs = []
			for i in indices:
				idx_strs.append(str(i))
			lines.append("%s    int[] faceVertexIndices = [%s]" % [indent_str, ", ".join(idx_strs)])
			# All triangles: each face has 3 vertices
			var face_count = indices.size() / 3
			var fvc_strs = []
			for i in range(face_count):
				fvc_strs.append("3")
			lines.append("%s    int[] faceVertexCounts = [%s]" % [indent_str, ", ".join(fvc_strs)])

		if normals and normals is PackedVector3Array and normals.size() == vertices.size():
			var n_strs = []
			for n in normals:
				n_strs.append("(%.6f, %.6f, %.6f)" % [n.x, n.y, n.z])
			lines.append("%s    normal3f[] primvars:normals = [%s]" % [indent_str, ", ".join(n_strs)])

		if uvs and uvs is PackedVector2Array and uvs.size() == vertices.size():
			var uv_strs = []
			for uv in uvs:
				uv_strs.append("(%.6f, %.6f)" % [uv.x, uv.y])
			lines.append("%s    texCoord2f[] primvars:st = [%s]" % [indent_str, ", ".join(uv_strs)])


func _get_usda_node_type(node: Node) -> String:
	if node is MeshInstance3D:
		return "Mesh"
	if node is Camera3D:
		return "Camera"
	if node is DirectionalLight3D:
		return "DistantLight"
	if node is OmniLight3D:
		return "SphereLight"
	if node is SpotLight3D:
		return "SpotLight"
	return "Xform"


## ===== Quick Export (no Python) =====

## Export to ASCII USDA format (no pxr needed)
func export_as_ascii(scene: Node3D, output_path: String) -> bool:
	var usda_content = generate_ascii_usd(scene)

	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		file.store_string(usda_content)
		file.close()
		return true

	push_error("USDExporter: failed to write file: ", output_path)
	return false
