# URDF Import

Copernicus can load robot models described in URDF (Unified Robot Description Format) files.

---

## What is URDF?

URDF is an XML format used by ROS to describe robot kinematics and dynamics. It defines:
- **Links**: Rigid bodies with mass, collision geometry, visual mesh
- **Joints**: Connections between links with type (revolute, prismatic, fixed), axis, and limits
- **Materials**: Colors and texture references

---

## Loading a URDF File

### Basic Import

```gdscript
var urdf_importer = URDFToGodot.new()
var robot_root = urdf_importer.import_file("res://robots/my_robot.urdf")
add_child(robot_root)
```

### Programmatic Construction

```gdscript
var urdf_importer = URDFToGodot.new()

# Load from file path
var robot_root = urdf_importer.import_file("res://urdf/turtlebot3.urdf")

# Or parse from string
var urdf_xml = FileAccess.get_file_as_string("res://robot.urdf")
var robot_root = urdf_importer.import_string(urdf_xml)
```

---

## URDF Structure Mapping

Copernicus converts URDF elements to Godot nodes:

| URDF Element | Godot Node | Notes |
|--------------|------------|-------|
| `<link>` | `Node3D` + `MeshInstance3D` + `CollisionShape3D` | Visual and collision |
| `<joint type="revolute">` | `PinJoint3D` | Rotation around axis |
| `<joint type="prismatic">` | `SliderJoint3D` | Translation along axis |
| `<joint type="fixed">` | (parent-child hierarchy only) | No joint node |
| `<origin>` | `Transform3D` | Position and rotation |
| `<material>` | `StandardMaterial3D` | Color, not textures |

---

## Joint Types

### Revolute Joint (Rotation)

```xml
<joint name="shoulder_pan" type="revolute">
  <parent link="base_link"/>
  <child link="shoulder_link"/>
  <origin xyz="0 0 0.1" rpy="0 0 0"/>
  <axis xyz="0 0 1"/>
  <limit lower="-3.14159" upper="3.14159" effort="100" velocity="10"/>
</joint>
```

Creates `PinJoint3D` with:
- Rotation axis from `<axis>`
- Position from `<origin>`
- Limits enforced by physics

### Prismatic Joint (Slider)

```xml
<joint name="slider_joint" type="prismatic">
  <parent link="base"/>
  <child link="slide"/>
  <origin xyz="0 0 0" rpy="0 0 0"/>
  <axis xyz="1 0 0"/>
  <limit lower="0" upper="1.0" effort="100" velocity="5"/>
</joint>
```

Creates `SliderJoint3D` with:
- Translation axis from `<axis>`
- Position from `<origin>`

### Fixed Joint

```xml
<joint name="base_to_sensor" type="fixed">
  <parent link="base_link"/>
  <child link="sensor_link"/>
  <origin xyz="0.1 0 0.2" rpy="0 0 0"/>
</joint>
```

No joint node created — links are parented directly.

---

## Link Properties

### Visual Geometry

```xml
<link name="base_link">
  <visual>
    <origin xyz="0 0 0" rpy="0 0 0"/>
    <geometry>
      <mesh filename="package://meshes/base.stl"/>
      <!-- or -->
      <box size="0.3 0.3 0.1"/>
      <sphere radius="0.05"/>
      <cylinder length="0.1" radius="0.03"/>
    </geometry>
    <material name="blue">
      <color rgba="0 0 0.8 1"/>
    </material>
  </visual>
</link>
```

### Collision Geometry

```xml
<link name="base_link">
  <collision>
    <origin xyz="0 0 0" rpy="0 0 0"/>
    <geometry>
      <box size="0.3 0.3 0.1"/>
    </geometry>
  </collision>
</link>
```

### Inertial (Mass Properties)

```xml
<link name="base_link">
  <inertial>
    <mass value="5.0"/>
    <origin xyz="0 0 0" rpy="0 0 0"/>
    <inertia ixx="0.01" ixy="0" ixz="0" iyy="0.01" iyz="0" izz="0.01"/>
  </inertial>
</link>
```

**Note:** Copernicus currently uses simplified mass handling.

---

## Handling package:// URLs

URDF often references mesh files with `package://` URLs:

```xml
<mesh filename="package://my_robot/meshes/base.stl"/>
```

Copernicus resolves these via `RobotDescription` path remapping:

```gdscript
urdf_importer.add_package_path_mapping("my_robot", "res://robots/my_robot/")
```

---

## Robot Hierarchy Example

```
RobotRoot (from URDF)
├── base_link (MeshInstance3D + CollisionShape3D)
│   └── fixed (no joint node)
│       └── sensor_mount (MeshInstance3D + CollisionShape3D)
│           └── shoulder_pan (PinJoint3D)
│               └── shoulder_link (MeshInstance3D + CollisionShape3D)
│                   └── shoulder_pitch (PinJoint3D)
│                       └── upper_arm (MeshInstance3D + CollisionShape3D)
...
```

---

## Working with Imported Robots

### Getting Joints

```gdscript
func get_joint_by_name(robot: Node3D, joint_name: String) -> Node:
    # Search recursively for joint
    for child in robot.get_children():
        if child.name == joint_name:
            return child
    return null
```

### Controlling Joints

```gdscript
var joint = robot.get_node("shoulder_pan")
if joint is PinJoint3D:
    # Set target position
    joint.set_param(Joint3D.PARAM_BIAS, target_angle)
```

### Getting Links

```gdscript
func get_all_links(robot: Node3D) -> Array:
    var links = []
    for child in robot.get_children():
        if child is MeshInstance3D or child.name.ends_with("_link"):
            links.append(child)
    return links
```

---

## Limitations

Current URDF importer limitations:

1. **Materials**: Only `<color>` supported, not texture filenames
2. **Inertia**: Simplified — full 6x6 inertia matrix not used
3. **Sensors**: Camera/LIDAR/gazebo extensions not parsed
4. **Transmissions**: `transmission` tags not implemented
5. **Plugins**: Gazebo plugin tags ignored

---

## Example: Loading TurtleBot3

```bash
# Assuming turtlebot3_description package is in ROS path
godot scenes/robot_viewer.tscn
# Then use File menu to load URDF
```

Or programmatically:

```gdscript
func load_turtlebot():
    var importer = URDFToGodot.new()
    # Add mesh path mapping for package:// URLs
    importer.add_package_path_mapping("turtlebot3_description",
                                       "/opt/ros/humble/share/turtlebot3_description/")

    var robot = importer.import_file("/opt/ros/humble/share/turtlebot3_description/urdf/turtlebot3_burger.urdf")
    add_child(robot)
```

---

## See Also

- [Control](control.md) — Joint control and PID
- [Sensors Overview](../sensors/overview.md) — Sensor simulation
- [Physics Backends](../physics/backends.md) — Physics engine options