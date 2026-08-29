# 04 — Component Specification

Every component has a fixed spec: **Purpose · Extends · Props/Slots/Events · Rendering · Contract**.
The **Contract** is the falsifiable part — a list of assertions verifiable headless or in the component
gallery. This document is the conformance checklist.

## Component tree

```
MainShell (Control) — renders the whole Workbench Loop
├── UiBrief                (objective + live verdict)
├── UiStageRail            (six-stage progression)
├── MenuBar
├── UiActivityBar          (modes + utilities)
├── UiSideBar              (mode-specific content)
├── UiEditorGroup (UiTabBar + host)
│   ├── CompositeWorkspace   [Design/Test: 3D viewer + JointPanel]
│   ├── RobotGallery         [Acquire]
│   ├── VcsPanel             [Design: versioning]
│   ├── MarketplacePanel     [Acquire+Publish]
│   ├── WalletPanel          [identity/funds]
│   ├── CoordinationPanel    [register + operate]
│   ├── RaasLauncher         [Operate]
│   ├── UiManual             [reference]
│   └── ExtensionsPanel
├── UiConsole              (terminal)
└── UiStatusBar
```

## Logic components (headless-testable)

### Scenario (`RefCounted`)
Purpose: a Zachtronics "brief" (objective + checks). Props: `id,title,brief,mode,requires,setup,checks,manual_refs`. Contract: `make()` returns a Scenario with fields set; `checks` items are `{label, check: Callable(ctx)->Variant, expect}`.

### ValidationResult (`RefCounted`)
Purpose: verdict of evaluating a scenario. Props: `passed, checks, metrics, message`. Contract: `build(checks)` sets `passed = all(check.ok)`.

### ScenarioEvaluator (`RefCounted`)
Purpose: pure evaluate. `static evaluate(scenario, ctx) -> ValidationResult`. Contract: runs each `check.call(ctx)`, sets `ok = actual == expect`. (Covered by `test_scenarios.gd`.)

### ProgressionModel (`RefCounted`)
Purpose: the scenario ladder + unlock graph. Signals: `scenario_changed`. Contract: `next_unlocked` respects `requires`; `activate(locked)` is a no-op; `complete` emits once. (Covered by `test_scenarios.gd`.)

### ScenarioService (autoload)
Purpose: holds the ladder, the live `context`, and the current `verdict`; re-evaluates on state change. Signals: `verdict_changed`. Contract: `activate(id)` sets `active` and re-evaluates; `complete_current` advances to `next_unlocked`.

### Route (`RefCounted`)
Purpose: a navigation destination. Props: `id,title,glyph,section,order,command_id,factory,sidebar_factory,in_activity_bar`.

### NavigationModel (`RefCounted`)
Purpose: the route graph + current route. Signals: `route_changed`. Contract: `navigate` sets `current` + emits once; `back` pops history; `sections()` is loop-ordered (`design→test→publish→operate→utility→manual`); `resolve_command(cmd)` finds the route. (Covered by `test_navigation.gd`.)

## UI components (`scripts/ui/components/`)

Each extends a Control, reads tokens from `UiTheme`, applies its own style locally, and has no call-site inline overrides.

### UiTheme (autoload)
Purpose: design tokens + `style()`. Contract: `color(name)`, `font(name)`, `space(name)`, `font_size(name)`, `style(name)` return non-default values for known keys; `style()` returns a `StyleBoxFlat`.

### UiLabel (`Label`)
Purpose: atomic text. Props: `text, kind{TITLE,HEADING,BODY,SMALL,MONO}, tone{PRIMARY,MUTED,FAINT,ACCENT,SUCCESS,WARNING,ERROR}`. Contract: `setup(t,k,tone)` sets text + font/color from tokens.

### UiButton (`Button`)
Purpose: atomic action. Props: `text, variant{PRIMARY,SECONDARY,GHOST,ICON}`. Contract: `setup` applies the variant stylebox; `pressed` fires.

### UiField (`VBoxContainer`)
Purpose: labeled input. Props: `label,value,placeholder,secret`. Events: `changed(text)`. Contract: `value()` returns the input text; `get_input()` non-null.

### UiSection (`Label`) — uppercase small muted header. UiSeparator (`HSeparator`) — 1px border line. UiSpacer (`Control`) — flexible filler.

### UiTitleBar (`PanelContainer`)
Purpose: window header. Props: `title`. Slots: `actions()` HBox. Contract: `actions()` non-null after `setup`; `set_title(t)` updates the label.

### UiPanel (`PanelContainer`)
Purpose: the window frame. Props: `title, padding`. Slots: `title_actions()`, `body()`. Contract: `body()` and `title_actions()` non-null after `setup(title)`; children added to `body()` render inside the margin.

### UiScrollList (`ScrollContainer`) — vertical slot `content()`. UiCard (`Button`) — selectable card with `title,subtitle,swatch,enabled`; `set_title` updates.

### UiStatusItem (`HBoxContainer`)
Purpose: dot + "name: value". Props: `name,value,state{OFF,OK}`. Contract: `set_state(OK, v)` turns the dot success and updates text.

### UiStatusBar (`PanelContainer`) — `left()`/`right()` slots.

### UiActivityBar (`PanelContainer`)
Purpose: icon rail. Props: `entries[{id,glyph,title}]`. Events: `activity_selected(id)`. Contract: `set_active(id)` highlights exactly the given id.

### UiConsole (`UiPanel`)
Purpose: terminal. Events: `command_submitted(text)`. Contract: `echo(line)` appends and autoscrolls; `clear()` empties output.

### UiModal (`Control`)
Purpose: the single modal. Slots: `content()`. Events: `closed`. Contract: Esc emits `closed` and frees.

### UiChecklistItem (`HBoxContainer`) — `label,ok,actual,expect` pass/fail row.

### UiBrief (`UiPanel`)
Purpose: objective + live checklist. Contract: renders `ScenarioService.active` title/brief; re-renders on `verdict_changed`; `_checks_host` has one row per verdict check.

### UiStageRail (`PanelContainer`) — six stages; `set_active(stage)` highlights one.

### UiManual (`UiPanel`) — lists `docs/*.md`, shows selected doc.

## Services (autoloads)

- `RChainService` — owns node/wallet/sdk/bridge; `run_async` (→ `TaskRunner`). Signals via `SignalBridge`/`CoordinationCore`.
- `GodotROS2` — `initialize`, `create_publisher/subscription`, signals `initialization_completed`, `topic_received`.
- `ModuleRegistry` — `register/create/get_available/get_all_categories`; will accept command/view/status contributions.
- `CommandRegistry` — `register/find/run/group_by_category`.
- `RobotLibrary` — `get_definitions/build(id)`.
- `EnvService` — `.env` keys.

## Domain backends

`MarketplaceCore` + `MockMarketplace`/`RChainMarketplace`/`AOMarketplace`(dormant); `CoordinationCore` +
`MockCoordination`/`RChainCoordination`; `GPUBackend` + `PyTorchLearner`/`ComputeRaycast`/`CUDAPhysics`;
`VcsBackend` + `GitVcs`/`AriadneVcs`; IK/physics/nav/industrial backends. Each satisfies the
`CopernicusModule` contract and emits its domain signals (see `03-signal-backbone.md` event table).
Contract: `is_available()`, `get_module_name()`, `get_module_category()` are static and consistent;
`create(category, id, config)` returns an initialized instance.

## Views (screens)

`MainShell`, `CompositeWorkspace`, `RobotGallery`, `MarketplacePanel`, `WalletPanel`,
`CoordinationPanel`, `VcsPanel`, `AiAssistantPanel`, `PublishPanel`, `RaasLauncher`, `CommandPalette`,
`BaseSelector`. Each is a `UiPanel` (or `UiModal`) composition of the above; **no inline styling**, no
`make_*`, no raw `Node.new()` styling. Contract: each view is reachable via `NavigationModel`; each
subscribes to its backend's signals (never polls return values); no view opens a separate window.
