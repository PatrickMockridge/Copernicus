# 08 — Viewport Specification

This document defines the **viewport** — the 3D robot editor that, together with the terminal, is
one of the two main entrypoints. It is normative and falsifiable. It builds on `04-components.md`
(the viewer/toolbar) and `05-state-transitions.md` (the viewer is a persistent view; nothing
destroys it on navigation).

The viewport is **Gazebo-like**: a camera you orbit/pan/zoom, entities you select with a click and
manipulate in modes, a right-click menu of modes/actions, keyboard shortcuts, and a toggle between
simple Godot shapes and translated meshes.

## 1. Camera

- **Orbit** — right-drag.
- **Pan** — `W`/`A`/`S`/`D` or the arrow keys (in the camera's forward/right/up plane), and
  middle-drag or Shift-right-drag.
- **Zoom** — mouse wheel.

The camera is an orbit target (`_cam_yaw`/`_cam_pitch`/`_cam_distance`) plus a pan offset
(`_cam_pan`). Keyboard panning is only active when the pointer is over the viewport and no mode is
dragging.

**Contract:** `orbit_camera`/`pan_camera`/`set_camera_distance` update the camera transform; `W`/`A`/
`S`/`D`/arrows pan; wheel zooms; `reset_view()` restores yaw/pitch/distance/pan.

## 2. Selection

- **Left-click (Select mode)** casts a ray from the camera through the pointer and intersects the
  robot's collision shapes.
- The hit node is highlighted and `selection_changed(node)` is emitted; clicking empty space clears
  the selection (`selection_changed(null)`).

**Contract:** clicking a link/joint selects it (highlight + signal); clicking empty space clears
selection.

## 3. Modes

| Mode | Key | Behaviour |
|---|---|---|
| `SELECT` | `Ctrl+1` | click picks an entity |
| `TRANSLATE` | `Ctrl+2` | drag the selected entity to move it (axis gizmo) |
| `ROTATE` | `Ctrl+3` | drag the selected entity to rotate it (axis gizmo) |

**Contract:** `set_mode(mode)` changes the active mode; only one mode is active; the right-click
menu check-items and the shortcut both reflect/set it.

## 4. Context menu

Right-click opens a **viewport-owned** `PopupMenu`:

- Mode check-items — Select / Translate / Rotate.
- Actions — Reset view, Load robot, Wireframe, Grid, Render (Simple/Meshes), sensors.

Viewport-internal items (modes, render toggle) are handled locally; shell-level actions (load robot,
sensors, …) are emitted as `viewport_action(id)`.

**Contract:** the menu is the viewport's, not the shell's; `viewport_action` carries shell-level
requests.

## 5. Shortcuts

Ctrl/Alt + key, with defaults, stored in `user://shortcuts.json`.

| Shortcut | Action |
|---|---|
| `Ctrl+1` | Select mode |
| `Ctrl+2` | Translate mode |
| `Ctrl+3` | Rotate mode |
| `Ctrl+G` | Toggle grid |
| `Ctrl+W` | Toggle wireframe |
| `Ctrl+R` | Toggle render (simple/proper meshes) |

**Contract:** `ShortcutManager` maps an `InputEventKey` to an action id; the mapping is loaded from
and saved to `user://shortcuts.json`; the defaults are the table above.

## 6. Render modes

A `render_proper_meshes` flag. When **off**, imported URDF/MJCF robots fall back to primitives
(box/cylinder/sphere from collision geometry). When **on**, the visual mesh is loaded through the
mesh translator. Procedural library robots remain simple shapes.

**Contract:** toggling the flag re-imports (or re-renders) the current robot with the chosen
representation.

## 7. Mesh translation

`MeshTranslator.translate(path) -> Mesh` dispatches by extension:

| Extension | Parser | Notes |
|---|---|---|
| `.stl` | `stl_parser.gd` | ASCII + binary → `ArrayMesh` |
| `.obj` | `obj_parser.gd` | Wavefront OBJ → `ArrayMesh` |
| `.dae` | `dae_parser.gd` | COLLADA → `ArrayMesh` |

`urdf_to_godot.gd` falls back to `MeshTranslator.translate(path)` when native `load()` fails.

**Contract:** a valid STL/OBJ file translates into a non-empty `ArrayMesh`; DAE likewise once its
parser is complete.

## 8. Conformance checklist

- `godot --headless --import` clean; the existing suites pass.
- `test_mesh.gd` asserts STL (ASCII + binary) and OBJ → non-empty `ArrayMesh`.
- Launch: WASD/arrows pan; left-click selects/highlights; right-click opens the menu; Ctrl+1/2/3
  switch modes; Ctrl+G toggles the grid; the render toggle swaps a URDF robot between primitives and
  translated meshes.
