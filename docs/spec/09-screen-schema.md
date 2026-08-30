# 09 — Screen Schema

This document defines the **screen schema** — the modular, screen-based layout that the GUI plugins
mount into, on top of the terminal. It is normative and falsifiable. It builds on `04-components.md`
(the component library), `05-state-transitions.md` (the route/panel model), `06-deterministic-rendering.md`
(the token/layout rules), and `07-terminal.md` (the verb layer).

The structure deliberately mirrors a classic dungeon-scroller / turn-based RPG — *not* its theme, its
**layout pattern**: one persistent "world" view, a scrolling "event log", a left "command rail", and
self-contained sub-screens you switch to, all driven by verb commands. In Copernicus these are the 3D
editor, the C64 terminal, the left toolbar, the plugins, and the `open <id>` verbs.

## Design rationale

This layout is a 40-year-tested genre convention (Ultima, Wizardry, The Bard's Tale, Dungeon Master)
chosen for three reasons: it keeps the user oriented ("where am I, what just happened, what can I do
next") without floating windows; it matches the robot-design loop, which is inherently turn-based —
*look at the robot → issue a verb → read the log → repeat*; and it pairs with the Commodore verb
grammar, where the rail is the same verbs rendered as buttons (the GUI is a layer over the terminal,
never a second command system). The full developer rationale is in `design-philosophy.md`; the
user-facing explanation is in `interface-user-manual.md`.

## 1. Fixed layout

The shell body is, left to right, then top to bottom:

1. **Rail** — the left toolbar (`UiActivityBar`), the screen selector.
2. **Journal** — the side bar (`UiBrief`/route `sidebar_factory`), the active screen's context.
3. **Stage** — the main viewport region (`_editor_host`), where a screen's panel mounts.
4. **Assistant** — the AI right panel (`_right_panel`), a persistent toggleable surface.
5. **Log** — the terminal (`UiConsole`), always docked at the bottom of the workbench.
6. **Status bar** — the bottom chrome.

**Contract:** the editor (stage) and the terminal (log) are persistent — nothing destroys them on
navigation (`05-state-transitions.md` §6). The rail and the log are the two fixed anchors; every other
surface is a screen or a panel.

## 2. Screens vs panels

A plugin contributes one of two surface kinds:

- **Screen** — mounts in the **stage**; listed in the **rail**; reachable by `open <id>`. It replaces
  the current stage panel (tab semantics).
- **Panel** — a persistent surface that does not mount in the stage: the **log** (terminal) and the
  **assistant** (AI right panel).

**Contract:** `ai` is a panel (not a screen) — it is excluded from the rail and toggled by the
viewport's top-right button / Tools menu / `open ai`.

## 3. The screen contract

A screen is a `Route` with `in_rail = true` (or pinned `in_activity_bar = true`). Its fields:
`{id, title, glyph, section, order, command_id, factory, sidebar_factory}`.

**Contract:** a screen declares all of: an `id` (also the `open` verb target), a `title`, a `glyph`
(rail icon), a `section` (rail group), an `order` (within the section), a `command_id`, and a `factory`
that builds the stage panel.

## 4. The rail

The rail lists every screen (pinned + `in_rail`), ordered by `NavigationModel.ordered_routes()`
(section rank, then `order`), and groups them with a separator when the `section` changes.

**Contract:** the rail entries equal `{ r in ordered_routes() : r.in_activity_bar or r.in_rail }`,
grouped by `r.section`. `ai`, `plugins`, and `manual` are not rail entries.

## 5. Verb ↔ screen correspondence

The rail, the terminal `open <id>`, and the command palette all resolve a screen to the same handler
(`_cmd_open` → `_navigate`; rail `activity_selected` → `_navigate`). There is one navigation path.

**Contract:** `open marketplace` and clicking the marketplace rail icon produce the same
`route_changed` and stage panel.

## 6. Mounting rules

- Screens mount into `_editor_host` (`_ensure_panel`), cached identity-stable (`05` §4).
- The assistant mounts into `_right_content` (right panel).
- The log is always docked; the journal shows only when the active screen has a `sidebar_factory`.

**Contract:** `_ensure_panel`/`_show_panel` special-case only `"ai"` (right panel); every other screen
mounts in `_editor_host`.

## 7. Conformance checklist

- `godot --headless --import` clean; `test_shell`, `test_navigation`, `test_cli`, `test_screen_schema`
  PASS.
- `test_screen_schema.gd` asserts: rail entries are grouped by `section` in `SECTION_ORDER`; every rail
  id resolves via `NavigationModel`; `ai` is not a rail entry.
- Launch: the rail shows the screens grouped (design · publish · operate · utility); clicking a screen
  navigates the stage; `open marketplace` matches the rail click; the AI assistant stays in the right
  panel; the terminal stays docked.
