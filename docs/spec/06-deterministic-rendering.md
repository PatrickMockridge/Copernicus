# 06 — Deterministic Rendering Specification

This document defines how Copernicus's UI **renders**. It is normative and falsifiable. It builds on
`04-components.md` (what the components are) and `05-state-transitions.md` (how state changes), and it
states the rule that makes both of them trustworthy on screen: **the rendered output is a pure,
explicit function of declared geometry and tokens — never of the engine's implicit defaults.**

The discipline is the one a React or Rust-WASM (egui/yew) renderer enforces by construction: there is
no "what does the engine do if I leave this unset?" — every control declares its rectangle, its
sizing, and its text overflow policy.

## 1. The render model

A `Control`'s on-screen rectangle is fully determined by five explicit things:

| Dimension | Declared via | Left-to-default = |
|---|---|---|
| **Layout role** | `size_flags_horizontal` / `size_flags_vertical` | engine decides expand/shrink/fill |
| **Position/anchors** | `set_anchors_preset` / anchors + offsets | top-left `(0,0)` at zero size |
| **Minimum size** | `custom_minimum_size` | content-derived, font-metric-dependent |
| **Container type** | which `Container` subclass is the parent | child never laid out (vertical text) |
| **Text overflow** | `autowrap_mode` + `text_overrun_behavior` | wraps per-word or draws past the rect |

**Rule:** every `Control` declares all five. If any is omitted, the render is **non-deterministic** —
its geometry depends on font metrics, DPI, window size, or container-sort order rather than on
declared intent.

## 2. Tokens — single source of truth

`UiTheme` (`scripts/ui/ui_theme.gd`) is the only place that may contain:

- **colors** — `COLOR` table (including `backdrop`, `viewport_overlay`);
- **font sizes** — `FONT_SIZE` table;
- **spacing** — `SPACE` table;
- **radii** — `RADIUS` table;
- **styleboxes** — `style(name)`.

Contracts:
- `style(name)` is **memoized** (one `StyleBoxFlat` instance per name, shared).
- `color(name)` **`push_error`s** on an unknown token (a typo'd token fails loudly, not silently).
- Stylebox content margins read `SPACE` tokens, never literal `2`/`4`.

## 3. The rules (guards)

### R1 — Explicit layout
Every `Control` added to a `Container` declares `size_flags_horizontal` and `size_flags_vertical`. A
plain `Control` is never used as a container (its children would keep a `(0,0)` rect). A `Button` is
never used as a container (it does not lay out children).

**Contract:** no `Control.new()` with `add_child` as a content host; no `Button` whose child is
expected to fill it. The side-bar content is a `VBoxContainer`, not a plain `Control`.

### R2 — Explicit text
Every `Label`/`Button` declares its overflow policy. `UiLabel` encodes it by kind: `BODY` sets
`size_flags_horizontal = SIZE_EXPAND_FILL` + word-wrap; `SMALL`/`MONO`/`TITLE`/`HEADING` set
`AUTOWRAP_OFF` + `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`.

**Contract:** no `UiLabel` renders as a vertical word-per-line column; no non-`BODY` label draws past
its rect.

### R3 — Token discipline
No literal color, font size, spacing, or radius outside `ui_theme.gd` and the components.

**Contract:** `grep -rn "Color(" scripts/ui/` matches only `ui_theme.gd` and `components/` (see
§5 for the outstanding exceptions).

### R4 — Explicit splits
A `SplitContainer` separates two panes with `SIZE_EXPAND_FILL` + `stretch_ratio` on **both** children.
A fixed-pixel "split" (one pane `SIZE_FILL` + `custom_minimum_size`) is forbidden — it does not scale.

**Contract:** the editor/terminal workbench (`VSplitContainer`) and the workspace viewport/panel
(`HBoxContainer`) both declare expand + ratio on every pane.

### R5 — One render model
The component library (`scripts/ui/components/`) is the single implementation of each surface. The
shell **adopts** `UiActivityBar`/`UiStatusBar`/`UiStatusItem`/`UiConsole`; it does not hand-roll raw
`Button.new()`/`Label.new()` duplicates. Dead components are deleted, not left to drift.

**Contract:** `grep -rn "Button.new()\|Label.new()" scripts/ui/main_shell.gd` = 0; no
`UiField`/`UiModal`/`UiStageRail` references remain.

### R6 — Explicit overlays & backdrops
An overlay is anchored (`PRESET_FULL_RECT` or explicit offsets). A modal backdrop reads
`UiTheme.color("backdrop")` — one dim value across `ModalLayer`, `ConfirmDialog`, `LoadingOverlay`.

**Contract:** the three modal implementations use the same `backdrop` token; a toolbar overlay is a
`PanelContainer` with a real backdrop stylebox (not an `"normal"` override on a non-stylebox control).

## 4. Component rendering contracts

| Component | Explicit geometry |
|---|---|
| `UiLabel` | BODY → expand + wrap; else ellipsis (§R2) |
| `UiCard` | inner `VBoxContainer` anchored `PRESET_FULL_RECT` with `SPACE` margins; title expands |
| `UiConsole` | output `TextEdit` `SIZE_EXPAND_FILL` + `LINE_WRAPPING_BOUNDARY` |
| `UiStageRail`/`PanelContainer`s | explicit `panel` stylebox (no engine-default theme) |
| `UiActivityBar` | fixed 48px rail, `SIZE_EXPAND_FILL` vertical |
| `UiStatusBar` | fixed 28px bar, left expands / right hugs |
| `ViewportToolbar` | `PanelContainer` overlay, `SIZE_SHRINK_BEGIN` both axes |

## 5. Conformance checklist

Conformant now:
- `grep -rn "change_scene_to_file" scripts/` → zero (except a comment in `test_state.gd`).
- `grep -rn "Button.new()\|Label.new()" scripts/ui/main_shell.gd` → zero.
- No `UiField`/`UiModal`/`UiStageRail` references.
- `UiLabel` BODY expand+wrap / non-BODY ellipsis; `UiCard` container fix; workspace + workbench
  explicit split; `style()` memoized; `color()` errors on unknown token; modal backdrops unified.

Outstanding (tracked, not yet conformant):
- Literal colors in `toast.gd` (`BG_COLORS`) and `marketplace_panel.gd` (asset/price swatches) — to
  be routed through `UiTheme` tokens.
- Grid/wireframe/terminal still have three UI mirrors (View menu, context menu, toolbar) — to be
  unified under one source of truth (`05-state-transitions.md` §WYSIWYG).
- Fixed-size modal boxes (`ConfirmDialog`, `LoadingOverlay`) do not yet autosize to content.

## 6. Verification

- `godot --headless --import` clean; `res://scenes/main.tscn` runs headless with no layout errors.
- `test_shell.gd` asserts factory identity stability and the Editor+Wallet activity guard.
- The component gallery renders each component in isolation at multiple window sizes with no
  vertical text or overflow (manual check on launch).
