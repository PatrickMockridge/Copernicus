# 01 — The Godot Model: how Copernicus uses Godot

This is the normative specification of *how Copernicus is built on Godot*. It is the source of truth;
implementation is judged against these rules, and each rule is falsifiable (a checker or test can
catch a violation). It exists because Copernicus chose Godot specifically for its **scene tree**,
**signals**, and **bare-metal Linux access** — and a coherent modular app is the property of using
those three things *uniformly*, not of any particular font, color, or border.

## Rule 1 — The scene tree is the component tree

Every element of the application — a panel, a button, a robot, a sensor, a demo, a terminal — is a
`Node` in **one** tree. Composition is `add_child`; there is no other way to place a thing on screen.

- A **component** is a reusable, named, typed node with a documented interface (props / slots / events).
  It may be either a `class_name` script (`extends Control`/`Node`) or a `.tscn` scene; both compose
  identically via `add_child`.
- There are **no separate windows**. `change_scene_to_file` is forbidden. A "feature" is either a
  *view* (a `Control` in the tree, reachable through the navigation model) or a *command* (a
  `CommandRegistry` entry). Overlays (selectors, confirm dialogs, detail views) are in-tree `Control`s
  with a dimmed backdrop — **one** `UiModal`, never an OS window or a scene swap.

**Falsifiable:** `grep -r "change_scene_to_file" scripts/` returns nothing; a full-screen `Panel` may
only be added under the shell's editor host or as a `UiModal`, never to `root` directly.

## Rule 2 — Signals are the only event mechanism

State changes and cross-component communication happen exclusively through Godot `signal`s.

- A component that produces events *declares* signals; a component that reacts *connects* to them. A
  component never reaches into another's private state to poll it.
- A signal declared by a service or backend and never connected is a **spec violation** (see
  `03-signal-backbone.md`, the domain-signal rule).
- Signals are emitted on the **main thread**. Background work (threads, subprocesses, network) delivers
  its result by emitting a signal via `call_deferred`, never by touching the scene tree from a thread.

## Rule 3 — Autoloads are services, not helper globals

An autoload is a singleton that owns state and exposes a documented signal surface. There are two
legitimate kinds:

- **Service** — owns state + lifecycle + an I/O model (thread/subprocess). Examples: `RChainService`
  (node/wallet/sdk/bridge + thread pool), `GodotROS2` (bridge + executor), `ModuleRegistry`,
  `CommandRegistry`, `ScenarioService`, `EnvService`.
- **Catalog** — an immutable lookup a component reads from. Examples: `RobotLibrary` (robot
  definitions), `UiTheme` (design tokens).

An autoload must never be a bag of `make_*` node factories, and must never do blocking I/O on the main
thread. `UiTheme` provides *tokens* (`color()`, `font()`, `style()`), not nodes.

**Falsifiable:** no autoload exposes a function that returns a raw Godot node; no autoload does
blocking `HTTPRequest`/`OS.execute` on the main thread.

## Rule 4 — Addons are optional plugins

- **Editor-time** plugins are Godot `EditorPlugin`s (`addons/*/plugin.cfg`), enabled explicitly.
- **Runtime** modules are registered with `ModuleRegistry` (category → id → script) and satisfy the
  `CopernicusModule` contract (name, description, availability, requirements, category). A runtime
  module may *contribute*: commands (to `CommandRegistry`), views/routes (to `NavigationModel`), and
  status items (to the status bar). The shell renders from those contributions; it does not hardcode a
  list of panels.

**Falsifiable:** the shell's activity bar, tabs, and command list are produced from `ModuleRegistry` +
`NavigationModel` contributions, not from a hardcoded array.

## Rule 5 — Bare-metal Linux access goes through adapters

Godot's `OS.execute`, subprocess, TCP/UDP, and filesystem are the "bare-metal" surface Copernicus uses
to talk to ROS2, RNode, and Python. Each such external system gets exactly **one adapter** that runs
its I/O off the main thread and emits Godot signals on the main thread (see `03-signal-backbone.md`).
No panel calls `OS.execute` or raw HTTP directly.

## The consequence

The UI is a *composition* of the components in the tree, driven by *signals* from services, reachable
through a *navigation model* and *command registry*, and styled by a *token table* (`UiTheme`). The
"Zachtronics" quality the project aims for is not a color scheme — it is this coherence: the user can
always see what they are doing (the Brief), the machine's rules are documented (the Manual), and every
piece of the app is a node in one tree responding to signals, exactly as a technical instrument would.
