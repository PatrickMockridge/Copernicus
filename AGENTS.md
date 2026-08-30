# AGENTS.md — Copernicus

Copernicus is an open-source **operating system for robotics** built on Godot 4. A small **kernel**
(viewport, terminal, screen schema, AI assistant, wallet + RaaS) sits in the middle; **apps (plugins)**
run on it; **robots (backends)** plug in via ROS 2; a **blockchain + RaaS** layer takes a design from
simulation into a real robot.

## Read first

- **Full orientation** (model, directory map, conventions, gotchas, run/test): [`docs/ai-entrypoint.md`](docs/ai-entrypoint.md)
- **The rule** (small fixed kernel, everything else plugs in): [`docs/spec/00-kernel.md`](docs/spec/00-kernel.md)
- **Backends**: [`docs/spec/13-backend-interface.md`](docs/spec/13-backend-interface.md) · **Plugins**: [`docs/spec/12-plugins.md`](docs/spec/12-plugins.md)

## Quick map

- `scripts/` — GDScript: `core/`, `ui/`, `ai/`, `robots/`, `rchain/`, `coordination/`, `marketplace/`, `vcs/`, and domain backends `gpu|ik|nav|physics|sensors/`
- `scenes/` — `main.tscn` (the kernel shell) + selectors/demos
- `addons/` — `godot_ros2`, `rchain`, `industrial`, `primitives`, `omni` (`GameAI`/`hyperobject`/`ROSCoder` dormant)
- `docs/` — `spec/` (00–13) + manuals

## Rules of the codebase

1. **Backends** extend `CopernicusModule`, self-register in `_static_init()` via `ModuleRegistry.register`, and are reached **only** through `ModuleRegistry.create`. Never import a backend class directly; `is_available()` must be an honest check.
2. **Everything is a verb** in the terminal; the GUI types the words.
3. **Styling** uses `UiTheme` tokens — no raw colors.
4. **Long work** goes through the `TaskRunner`, never the main thread.

## Run / test

```bash
godot scenes/main.tscn
godot --headless --script res://scripts/test_cli.gd     # also test_navigation, test_scenarios,
                                                        # test_state, test_shell, test_ik,
                                                        # test_shortcuts, test_mesh, test_rchain
mdbook build
```

## Dead / dormant (avoid)

`GameAI`, `ROSAI`, `ROSCoder`, `AO`/`Arweave`/`Hyperobject`, `CopernicusTheme`,
`UiField`/`UiModal`/`UiStageRail`, `joint_panel.gd`, `context_menu_requested`.

See [`docs/ai-entrypoint.md`](docs/ai-entrypoint.md) for the full orientation.
