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

## Design direction: a dungeon-scroller interface

The interaction model is deliberate and opinionated. Copernicus's window is laid out like a classic
**dungeon-scroller / turn-based RPG** — not its theme, its *structure*:

- one **persistent "world" view** (the 3D editor) you never lose sight of,
- a **scrolling "event log"** (the terminal) that always records what happened,
- a **left "command rail"** (the toolbar) of verbs/screens,
- **self-contained sub-screens** (plugins) you open and come back from.

This is specified in `docs/spec/09-screen-schema.md` and explained for users in
`docs/interface-user-manual.md`.

Why this shape, over a "corporate dashboard" of floating panels:

1. **It's a 40-year-tested convention.** Dungeon-scrollers (Ultima, Wizardry, The Bard's Tale, Dungeon
   Master) converged on *one view + one log + one verb rail* because it answers "where am I, what just
   happened, what can I do next" without the user hunting through windows. That ergonomics transfers
   directly.
2. **It matches a robot-design loop.** Designing a robot is turn-based: *look at the robot → issue a
   command → read the result → repeat*. A persistent 3D view plus an event log plus a verb rail is
   exactly that loop.
3. **It pairs with the Commodore verb grammar.** The terminal is verb-first (`open`, `load`,
   `wireframe`, `grid`, `sensors`, `tool`, …). A rail of screens is the *same verbs* rendered as
   buttons; the GUI is a layer over the terminal, never a second, divergent command system.

The result is a single, learnable mental model: **watch the stage, talk to the log, switch screens from
the rail.** New surfaces are *screens* that plug into this schema rather than new windows competing for
attention.

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

## The three layers

The architecture is a kernel with two kinds of extension (see `spec/00-kernel.md`):

| Layer | What it is | Examples |
|-------|-------------|----------|
| **Kernel** | always present, non-negotiable | viewport, terminal, screen schema, AI assistant, wallet + RaaS |
| **Plugins** | opt-in UI apps (screens + commands) | robots library, marketplace, coordination, VCS, RaaS |
| **Backends** | swappable robotics capability behind `tool <x>` | physics, IK, sensors, nav, RL, industrial, ROS 2, Omniverse |

The kernel runs with nothing else enabled. Plugins add surfaces; backends add capability. Nothing in the
kernel imports a plugin or backend by name — they register through `ModuleRegistry` and are reached by
id (`spec/13-backend-interface.md`).

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
