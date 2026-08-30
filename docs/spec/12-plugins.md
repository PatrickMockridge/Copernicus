# 12 — UI Plugins

This document defines **how UI plugins work** — how a plugin mounts a screen, commands, and status on
the kernel. It builds on `00` (kernel), `09` (screen schema), `07` (verbs), and `13` (backends, for the
module registry).

## 1. What a plugin is

A plugin is an opt-in, disable-able surface that contributes at least one of:

1. a **screen** — a `Route` (`scripts/ui/navigation/route.gd`) with `in_rail = true`, mounted in the
   stage;
2. **commands** — `CopernicusModule.get_commands()` → `ModuleRegistry.get_contributed_commands()` →
   `CommandRegistry`, reachable from the terminal and palette;
3. a **status item** — a `UiStatusItem` readout in the status bar.

**Contract:** the kernel (`main_shell.gd`) owns the plugin list (`_build_plugins`), registration
(`_reg_route`), and enable/disable (`_set_plugin_enabled`). A plugin is declared, not loaded eagerly.

## 2. The built-in plugins

| id | surface | section | contributes |
|---|---|---|---|
| `robots` | screen (rail) | design | `load <id>`, robot gallery |
| `marketplace` | screen (rail) | publish | `listings`/`search`/`buy` |
| `coordination` | screen (rail) | publish | `register`/`publish`/`claim`/`settle` |
| `vcs` | screen (rail) | utility | `status`/`log`/`commit`/`push`/`pull`/`clone` |
| `raas` | screen (rail) | operate | RaaS demos |
| `ai` | panel (right) | utility | agentic assistant (spec `10`) |

**Contract:** `ai` is a panel, not a screen — it is excluded from the rail and toggled via the
top-right button / Tools / `open ai` (`09` §2).

## 3. Mounting

- A screen mounts in the **stage** (`_editor_host`) via `_ensure_panel`, cached identity-stable.
- The assistant mounts in the **right panel** (`_right_content`).
- A route may supply a `sidebar_factory` to populate the journal (side bar).

**Contract:** `_ensure_panel`/`_show_panel` special-case only `"ai"`; every other plugin mounts in
`_editor_host`.

## 4. Enable/disable + persistence

`user://plugins.json` maps `id → bool`. Toggling calls `_register_plugin` (adds the `Route`) or
`_unregister_plugin` (removes the route and open tab). Disabled plugins contribute no screen, command,
or status.

**Contract:** disabling a plugin makes its surface unreachable; re-enabling restores it identically.

## 5. Conformance checklist

- `scripts/test_shell.gd` asserts editor + wallet are the only pinned activities, and plugin factories
  are identity-stable.
- `scripts/test_screen_schema.gd` asserts the rail = pinned + `in_rail` screens, grouped by section.
- Launching with every plugin disabled still shows the editor, terminal, wallet, and Settings.

## See also

- `docs/development/plugin-guide.md`, `docs/terminal-developer-manual.md`, `scripts/ui/main_shell.gd`,
  `scripts/core/module.gd`, `scripts/core/module_registry.gd`.
