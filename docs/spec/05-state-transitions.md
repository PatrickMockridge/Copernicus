# 05 — State-Transition Specification

This document defines how Copernicus's **UI state changes** — navigation, mode switches, tab
open/close, panel toggles, overlays — and the rules every transition must obey. It is normative and
falsifiable. It builds on `01-godot-model.md` (tree + signals) and `03-signal-backbone.md` (events),
and it constrains `04-components.md` (how components are wired).

## 1. The UI state model

Copernicus has a small, explicit set of top-level state dimensions. There is no hidden state.

| Dimension | Type | Owner | Notes |
|---|---|---|---|
| Route | single `id` | `NavigationModel` | "which view is active" |
| Mode | single value | derived from active `Scenario` | design · test · publish · operate |
| Open tabs | ordered set | shell editor host | which views are open, in order |
| Panel | boolean | shell | terminal / side bar visible |
| Overlay | stack | `UiModal` | transient, dims the work |
| Work state | per-view | each view caches itself | robot, joint config, form inputs |

**Invariant:** route, mode, tabs, panel, and overlay are independent dimensions. Changing one does not
mutate another. The **work state** (the robot and everything the user has built) is owned by the views
and survives every other transition.

Transitions are **signal-driven**: `route_changed`, `scenario_changed`, and panel/overlay toggles.
Nothing manipulates the scene tree directly to change state.

## 2. The chrome (IDE layout)

- **Top menu bar** — File / View / Tools / Help. Persistent; never re-rendered by navigation.
- **Editor tabs** — the open views. Switching a tab changes only the content host.
- **Bottom pane** — the terminal (`UiConsole`). Docked, toggleable, fed by `CommandRegistry`/`TaskRunner`.
- **Side bar** — mode-contextual (link tree in Design, sensors in Test, register/listing in Publish,
  jobs/channels in Operate).
- **Status bar** — persistent readout: wallet · node · ros2 · fps · current mode.

## 3. The guards — what a transition must NOT do

### G1 — No jarring transitions
A transition is exactly one of: **tab/route swap** (chrome constant, content host swaps) or **toggle**
(panel shows/hides in place). Forbidden: `change_scene_to_file`, full-window repaint, teleporting the
user's context, or an animation that obscures the work.

**Contract:** `grep change_scene_to_file` = 0; no `root.add_child` of a full-screen panel; the menu
bar/status bar/activity bar node identities are stable across `navigate`.

### G2 — Breadcrumbing
At any moment the user can answer: *where am I* (active tab + Brief + mode), *how did I get here*
(history → a visible back affordance), *what's the path* (`mode ▸ section ▸ view`).

**Contract:** the breadcrumb is rendered from `NavigationModel.history` (never a hardcoded string);
`history` is non-empty after the second `navigate`; `back()` pops exactly one entry.

### G3 — Reversibility (lossless)
Every transition is reversible, and reversing restores **state, not just route**:
- `navigate` ↔ `back` (history stack).
- Toggle ↔ toggle (symmetric).
- Overlay ↔ close/cancel (restores the exact prior route + overlay stack).
- Switching back to a view restores its cached scroll / selection / form inputs.

**Contract:** `NavigationModel.navigate(b)` then `back()` yields `current_id == a` and emits
`route_changed` twice; a view's node identity is stable across `navigate` → `back` (views are cached,
never destroyed-and-rebuilt on navigation).

### G4 — No state loss
The robot/3D scene, joint configuration, and form inputs survive any navigation or panel toggle. The
**viewer is persistent** — never freed on a tab switch.

**Contract:** after `navigate(away)` → `navigate(viewer)`, the same `RobotViewerController` instance
and the same `_robot_root` are present; joint slider values are unchanged.

## 4. Tab / dropdown / window taxonomy

| Surface | When | Example |
|---|---|---|
| **Tab** (editor host) | a long-lived view the user works *in* | Viewer, Marketplace, Wallet, Coordination, VCS, Gallery, Manual |
| **Dropdown / menu** | a transient action, no persistent view | Tools ▸ backends, View ▸ sensors, File ▸ Open |
| **Panel** (docked, bottom/side) | a toggleable companion | Terminal, Joint panel, Sensor list |
| **Window** (separate OS window) | **only** on explicit user action | "Detach viewport" to a second monitor |

**Default rule: nothing opens its own window.** A selector is a dropdown or `UiModal`; a detail view is
a tab or an in-tree overlay; a demo is a tab. "Must be its own window" applies only to a user-requested
detach, and it is always reversible (re-attach).

## 5. WYSIWYG principles

1. **The work is always visible.** The 3D viewport is the anchor and is never hidden by navigation.
   Every edit (joint slider, sensor toggle) reflects immediately in the viewport.
2. **Test at any time.** The Test surface (sensors, demos, run/ROS2) is one action away from any
   state; the Brief's checklist reflects test results live. Testing never requires "leaving" the work.
3. **No hidden state.** The status bar, Brief, and StageRail always reflect current state; a form
   field's value is the value that will be used.

## 6. Plugin customization (same rules)

A plugin contributes a **tab** (a `Route` with a `factory`), a **command** (`CommandRegistry`), and/or
a **status item** — never a window or a blocking modal. Plugin views are registered through
`ModuleRegistry` → `NavigationModel`/`CommandRegistry` (not hardcoded in the shell), are reversible and
breadcrumbed like built-ins, are styled by `UiTheme` tokens, and may emit/receive signals on the
backbone like any service.

**Contract:** a plugin's tab/command/status are discoverable in the Extensions view and the palette
without touching the shell; no plugin code calls `change_scene_to_file` or `root.add_child`.

## 7. Per-transition contract table

| Transition | Trigger | Reversal | Falsifiable check |
|---|---|---|---|
| Open view | `navigate(id)` | `back()` | `current_id == id`; `route_changed` emitted once |
| Back | `back()` | `navigate` | restores prior `current_id` |
| Switch mode | `activate(scenario)` | activate prior | `ScenarioService.active.mode` matches; side bar/tabs update |
| Toggle terminal | panel toggle | toggle again | `UiConsole.visible` flips; chrome unchanged |
| Open overlay | show modal | close/cancel | prior route restored; overlay stack popped |
| Detach viewport | explicit action | re-attach | viewer node identity preserved |

## 8. Conformance checklist

- `grep -rn "change_scene_to_file" scripts/` → zero.
- `grep -rn "root.add_child\|get_tree().root.add_child" scripts/` → only `UiModal`/allowed overlays.
- `test_state.gd` asserts G1–G4 and the contract table.
- Component gallery renders the chrome (menu · tabs · terminal · status bar) in isolation.
- `test_rchain.gd`, `test_scenarios.gd`, `test_navigation.gd` all pass (no regression).
