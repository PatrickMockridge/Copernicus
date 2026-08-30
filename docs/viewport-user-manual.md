# Copernicus Viewport — User Manual

The viewport is the 3D robot editor, the top half of the window. This manual covers the camera,
selection, modes, the right-click menu, shortcuts, and the render toggle.

## 1. Moving the camera

| Action | Control |
|---|---|
| Orbit | right-click + drag |
| Pan | `W` `A` `S` `D` or the arrow keys, or middle-drag / Shift+right-drag |
| Zoom | mouse wheel |
| Reset view | `Ctrl`-menu or the toolbar **Reset** button |

## 2. Selecting

- **Left-click** a robot link or joint to select it (it highlights).
- Click empty space to clear the selection.

## 3. Modes

| Mode | What it does | Switch via |
|---|---|---|
| Select | click to pick entities | `Ctrl+1` or the right-click menu |
| Translate | drag the selected entity to move it | `Ctrl+2` |
| Rotate | drag the selected entity to rotate it | `Ctrl+3` |

## 4. Right-click menu

Right-click in the viewport to open the menu. It lists the three modes plus actions:

- **Reset view** — reset the camera.
- **Load robot** — open a URDF/MJCF file.
- **Wireframe** — toggle the flat debug view.
- **Grid** — show/hide the ground grid.
- **Render (Simple / Meshes)** — switch between primitives and translated meshes.
- **Sensors** — toggle LIDAR / camera / IMU.

## 5. Shortcuts

The default shortcuts are:

| Shortcut | Action |
|---|---|
| `Ctrl+1` | Select mode |
| `Ctrl+2` | Translate mode |
| `Ctrl+3` | Rotate mode |
| `Ctrl+G` | Toggle grid |
| `Ctrl+W` | Toggle wireframe |
| `Ctrl+R` | Toggle render (simple/proper meshes) |

Shortcuts are stored in `user://shortcuts.json`; edit that file to remap them.

## 6. Render modes

- **Simple** — imported robots are drawn as boxes/cylinders/spheres (from their collision geometry).
- **Meshes** — imported robots are drawn with their actual meshes (STL/OBJ/DAE translated to Godot).

Toggle with the right-click menu or `Ctrl+R`. Built-in library robots (TurtleBot, Arm6, …) are always
simple shapes.

## 7. The terminal

The viewport and the terminal work together. Load a robot from the terminal with `load <id|path>`;
see [the terminal user manual](terminal-user-manual.md) for the full command list.
