# Design Philosophy

> Copernicus places the **open-source community** at the center of robot development, just as Nicolaus Copernicus placed the Sun at the center of our solar system.

---

## Core Tenets

### 1. Pareto Efficiency

Copernicus optimizes for the best **bang per buck** — maximum functionality with minimum complexity. Every line of code, every dependency, every abstraction must justify its existence.

**Rule:** If a feature adds significant complexity but only benefits a small fraction of users, it belongs in a plugin — not in core.

### 2. Composability First

Components must be composable — able to be combined in new ways without modification. This means:

- **Loose coupling** — modules communicate through clear interfaces, not implicit dependencies
- **Single responsibility** — each component does one thing well
- **No hidden globals** — state is passed explicitly or managed by a clearly-owned context

**Rule:** If two modules must be modified together for a new use case, they are not composable.

### 3. Dependency Entanglement is Technical Debt

Complex, entangled dependencies are the primary source of:

- Merge conflicts and integration hell
- Unpredictable behavior from hidden interactions
- Difficulty testing individual components
- Inability to fork or replace pieces

**Rule:** The more entangled a dependency, the more likely it should be an **external plugin** rather than part of this repository.

---

## What This Means in Practice

### Good: Clear Plugin Boundaries

```
addons/
├── demo_framework/      # Reusable infrastructure for demos
├── gpu_sensors/         # GPU-accelerated sensors (optional)
├── industrial/           # Industrial robot plugins (optional)
└── godot_ros2/          # ROS2 bridge (optional)
```

### Bad: Cross-Boundary Entanglement

```
# Anti-pattern (BEFORE refactoring - now fixed):
# addons loading from scripts/ was the old broken state
addons/industrial/industrial.gd → preload("res://scripts/industrial/backends/...")

# Correct: all dependencies point inward to the addon (NOW IMPLEMENTED)
addons/industrial/industrial.gd → preload("res://addons/industrial/backends/...")
```

### The 80/20 Rule for Dependencies

For any given feature:
- **80% of users** need basic functionality → keep it in core
- **20% of users** need advanced integrations → make it a plugin

When in doubt, extract to a plugin. Plugins can be added later to the core repo if demand warrants.

---

## Modularity Checklist

Before adding any code to Copernicus, ask:

1. **Can this be tested independently?** If no, the module has hidden dependencies.
2. **Can this be replaced without modifying caller code?** If no, there's tight coupling.
3. **Does this belong to a specific domain or is it universally useful?** Domain-specific → plugin.
4. **Would a fork want to remove this?** If yes, it should be a plugin.

---

## Architecture Layers

| Layer | Description | Examples |
|-------|-------------|----------|
| **Core** | Essential robot visualization and design | URDF import, joint control, basic physics |
| **Addons** | Optional integrations, swap-in backends | ROS2 bridge, GPU sensors, industrial plugins |
| **External** | Standalone tools, external simulators | Isaac Sim, Gazebo, MoveIt |

Core is minimal. Addons are optional. External integrations are encouraged to stay external.

---

## Design Quotes

> "Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away." — Antoine de Saint-Exupéry

> "The best code is no code at all." — Jeff Atwood

> "Premature optimization is the root of all evil." — Donald Knuth

---

## Further Reading

- [Architecture Overview](03-architecture.md)
- [Contributing Guide](development/contributing.md)
- [Core Concepts](02-concepts.md)
