# Copernicus

Open-source **operating system for robotics** built on Godot 4. A small **kernel** (viewport, terminal,
screen schema, AI assistant, wallet + RaaS) sits in the middle; **apps (plugins)** run on it; **robots
(backends)** plug in via ROS 2; a **blockchain + RaaS** layer takes a design from simulation into a real
robot.

> **Full orientation:** [`docs/ai-entrypoint.md`](docs/ai-entrypoint.md) (and `AGENTS.md`). The formal
> anchor is [`docs/spec/00-kernel.md`](docs/spec/00-kernel.md).

## Rules

- Backends extend `CopernicusModule`, self-register in `_static_init()` via `ModuleRegistry.register`,
  and are reached only through `ModuleRegistry.create`. Never import a backend class directly;
  `is_available()` must be an honest runtime check.
- Everything is a verb in the terminal; the GUI types the words.
- Styling uses `UiTheme` tokens — no raw colors.

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
