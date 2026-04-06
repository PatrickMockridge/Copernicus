# Contributing

## How to Contribute

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests (if any)
5. Submit a pull request

## Coding Standards

- Follow Godot GDScript conventions
- Use 4-space indentation (no tabs)
- Document all public methods with docstrings
- Keep classes focused (single responsibility)

## Testing

```bash
# Run headless test
godot --headless --quit

# Run editor test
godot -e --headless --quit
```

## Commit Messages

Use clear, descriptive commit messages:
- Start with a verb (Add, Fix, Update, Remove)
- Keep the first line under 72 characters
- Reference issues when applicable

## Source Control

### Adding New Files

When adding new GDScript files:
1. One class per file
2. Use `class_name` to register the class
3. Place in appropriate `addons/godot_ros2/` subdirectory

### File Naming

| Type | Convention | Example |
|------|-----------|---------|
| Class files | snake_case.gd | `lidar_sensor.gd` |
| Plugin configs | plugin.cfg | `plugin.cfg` |
| Docs | kebab-case.md | `getting-started.md` |

## Documentation

- Update relevant docs when changing code
- Add code examples where possible
- Keep docs in `docs/` directory
- Link from main README.md
