# Contributing to Copernicus

> **Copernicus is more than software — it's a statement that robotics belongs to everyone.**

Just as Copernicus placed the Sun at the center of the solar system, this project places the **open-source community** at the center of robot development. Every contribution makes robotics more accessible.

---

## The Copernican Principle

Copernicus is built on a simple belief: **robotics should not be locked behind expensive licenses and proprietary black boxes**. By contributing to Copernicus, you're helping create tools that belong to everyone.

---

## How to Contribute

1. **Fork** the repository on [Codeberg](https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface)
2. **Create** a feature branch for your changes
3. **Make** your changes following the coding standards below
4. **Test** your changes with `godot --headless --quit`
5. **Submit** a pull request with a clear description

---

## Creating Modules

Copernicus is designed to be modular. A good module is:

1. **Self-contained** — Has everything it needs within its directory
2. **Documented** — Includes clear comments and usage examples
3. **Optional** — Doesn't break the core if removed
4. **Open** — Licensed under MIT or similar permissive license

### Module Structure

```
your_module/
├── plugin.cfg           # Godot plugin config
├── your_module.gd       # Main script
├── scenes/              # Optional scenes
├── scripts/             # Additional scripts
└── README.md            # Module documentation
```

### Example: Creating a Sensor Module

```gdscript
# my_lidar_sensor.gd
class_name MyLidarSensor
extends Node3D

@export var max_range: float = 10.0
@export var ray_count: int = 360

func scan() -> Array:
    # Your LIDAR implementation
    return distances
```

---

## Coding Standards

- Follow Godot GDScript conventions
- Use 4-space indentation (no tabs)
- Document all public methods with docstrings
- Keep classes focused (single responsibility)
- Use Godot's native nodes where possible (don't reinvent physics)

---

## Testing

```bash
# Run headless test
godot --headless --quit

# Run editor test
godot -e --headless --quit
```

---

## Commit Messages

Use clear, descriptive commit messages:
- Start with a verb (Add, Fix, Update, Remove)
- Keep the first line under 72 characters
- Reference issues when applicable

Example:
```
Add differential drive support to physics_demo

Implements VehicleBody3D-based wheels with keyboard/cmd_vel control.
Fixes #42
```

---

## Source Control

### Adding New Files

When adding new GDScript files:
1. One class per file
2. Use `class_name` to register the class
3. Place in appropriate directory (`scripts/`, `addons/`, etc.)

### File Naming

| Type | Convention | Example |
|------|-----------|---------|
| Class files | snake_case.gd | `lidar_sensor.gd` |
| Plugin configs | plugin.cfg | `plugin.cfg` |
| Docs | kebab-case.md | `my-module.md` |

---

## Documentation

- Update relevant docs when changing code
- Add code examples where possible
- Keep docs in `docs/` directory or your module's README
- Link from main README.md and docs/README.md

---

## Ideas for Contributions

- New robot model loaders (SDF, MJCF)
- Additional sensor visualizations
- More joint types
- Export to various simulator formats
- UI improvements
- Performance optimizations
- New examples and tutorials

---

## License

By contributing to Copernicus, you agree that your contributions will be licensed under the MIT license. This ensures the project stays open and accessible to everyone.
