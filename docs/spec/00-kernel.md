# 00 — The Kernel

This document defines **Copernicus's kernel** and its three-layer architecture. It is normative and
falsifiable. It is the root of the specification set; `01`–`13` build on it.

## Mission

Copernicus is an **open-source, customisable NVIDIA Isaac Sim / Omniverse for the Open Source
Industrial Metaverse** — a free alternative to closed, proprietary industrial-simulation stacks. It is
built on Godot 4, ships as a small, legible kernel, and grows through plugins and swappable robotics
backends.

## 1. The three layers

| Layer | What it is | Spec |
|---|---|---|
| **Kernel** | The always-present, non-negotiable core. | this doc; `07`, `08`, `09`, `10`, `11` |
| **Plugins** | Opt-in UI surfaces mounted on the kernel. | `12` |
| **Backends** | Swappable robotics capabilities behind `tool <x>`. | `13` |

**Contract:** the kernel runs without any plugin or backend enabled. Plugins add *screens and
commands*; backends add *robotics capability* (physics, IK, sensors, navigation, RL, industrial, ROS2,
Omniverse). Nothing in the kernel imports a plugin or backend directly — they register through
`ModuleRegistry` and are reached by id.

## 2. The kernel's five components

1. **Viewport** — the 3D robot editor (camera, selection, modes, loading). Spec `08`.
2. **Terminal** — the Commodore-64 command line and event log. Spec `07`.
3. **Screen schema** — the dungeon-crawler-style layout (rail · journal · stage · assistant · log ·
   status). Spec `09`.
4. **AI assistant** — the agentic Claude assistant that edits a user workspace. Spec `10`.
5. **Wallet + RaaS** — blockchain identity/funds and robotics-as-a-service. Spec `11`.

**Contract:** these five are always present; the editor and terminal are the two non-negotiable
surfaces, the wallet is the second pinned surface (funds at risk), and the AI assistant is a persistent
toggleable panel.

## 3. What the kernel is / is not

**The kernel is** a design surface + a command layer + an identity + an agent:

- a fast 3D editor for loading, inspecting, and posing robots;
- a verb-first terminal that records every action;
- a deterministic screen-based UI;
- an agent that edits files in a user workspace;
- a blockchain identity with on-chain coordination and work-metered RaaS.

**The kernel is not** a physics research simulator, an IK solver, a motion planner, or a training
harness. Those are **backends** (`13`) — optional, swappable, and reachable through the kernel's
`tool <x>` verbs and selectors, never hard-wired into the core.

**Falsifiable:** `grep` over `scripts/` shows the kernel surfaces (`main_shell.gd`,
`robot_viewer_controller.gd`, `composite_workspace.gd`, `scripts/ai/`, `scripts/rchain/`,
`scripts/coordination/`) never import a backend's concrete class by name; they resolve it via
`ModuleRegistry.create(category, id, config)`.

## 4. The four interfaces

The kernel talks to everything else through four contracts:

1. **Signals** — `03-signal-backbone.md`: all events on the main thread; long work through `TaskRunner`.
2. **Verbs** — `07-terminal.md`: the terminal is the single command layer; GUI dispatches to the same
   handlers.
3. **Screens** — `09-screen-schema.md`: plugins mount as screens in the stage, or as panels.
4. **Backends** — `13-backend-interface.md`: `CopernicusModule` + `ModuleRegistry` + `BaseSelector`.

## 5. Conformance checklist

- `docs/spec/` reads as one architecture: `00` → components (`07`–`11`) → plugins (`12`) → backends (`13`).
- `02-inventory.md` classifies every feature as kernel / plugin / backend / experimental / dead.
- The kernel launches and runs with all plugins disabled and no backend selected.

## See also

- `02-inventory.md` — the classified feature inventory.
- `03-signal-backbone.md`, `07-terminal.md`, `08-viewport.md`, `09-screen-schema.md`,
  `10-ai-assistant.md`, `11-wallet-raas.md`, `12-plugins.md`, `13-backend-interface.md`.
