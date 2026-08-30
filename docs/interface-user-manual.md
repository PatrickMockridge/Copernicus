# Copernicus Interface — User Manual

Copernicus is a robot design interface. Its window is laid out like a classic **dungeon-scroller** —
the kind of game that dominated home computers in the 1980s. Not the swords-and-sorcery *theme*: the
**layout logic**. This manual explains that logic, because once you see it, the whole interface makes
sense.

## 1. What a dungeon-scroller is (and why it matters here)

A dungeon-scroller (Ultima, Wizardry, The Bard's Tale, Dungeon Master, Eye of the Beholder) is a
turn-based game with a very specific shape:

- **One screen you're always looking at** — the "world" (a first-person corridor, a top-down map, or a
  party standing in a room). You never lose sight of where you are.
- **A scrolling event log** — a strip of text that records what just happened ("A door opens", "The
  goblin attacks", "You found a key"). You always know what the last action *did*.
- **A column of commands** — a rail of buttons/verbs down one edge (Open, Use, Cast, Examine, Talk).
  You *do* things by issuing verbs.
- **Self-contained sub-screens** — opening your inventory, map, character sheet, or journal takes you
  to a whole new screen, then you come *back*.

That shape is a 40-year-old, battle-tested way to answer three questions at once: *where am I?*,
*what just happened?*, and *what can I do next?* — without the user having to hunt through floating
windows.

Copernicus keeps exactly this shape, but the "world" is a robot, the "log" is a terminal, and the
"verbs" are the commands you type or click.

## 2. The layout

```
┌────────────────────────────────────────────────────────────┐
│  menu bar                                                  │
├───┬────────┬──────────────────────────────┬───────────────┤
│   │        │                              │               │
│ r │ journal│            stage             │   assistant   │
│ a │ (side  │    (the 3D robot editor —    │   (the AI,    │
│ i │  bar)  │     the screen you open)     │    toggleable)│
│ l │        │                              │               │
│   │        ├──────────────────────────────┤               │
│   │        │            log               │               │
│   │        │   (the terminal — always     │               │
│   │        │    docked at the bottom)     │               │
├───┴────────┴──────────────────────────────┴───────────────┤
│  status bar                                                │
└────────────────────────────────────────────────────────────┘
```

| Region | What it is |
|---|---|
| **Rail** (left) | The command rail — a column of icons, grouped by section. Click one to open that screen. |
| **Journal** (side) | The active screen's context (for the editor, the current objective and its checklist). |
| **Stage** (center) | The main area. The 3D editor lives here, and each screen replaces it while it's open. |
| **Assistant** (right) | The AI assistant — a persistent, toggleable panel. |
| **Log** (bottom) | The terminal — always docked, always recording what happened. |
| **Status bar** | Back button, breadcrumb, and system readouts (mode, wallet, node, ROS2, FPS). |

## 3. The logic — verbs first

This is the part that takes a little getting used to, and it's the heart of the design:

**The terminal is the source of truth; the GUI is a layer on top of it.**

Every thing you can do in Copernicus is a **verb** in the terminal. `open marketplace`, `load
turtlebot`, `wireframe`, `grid`, `sensors lidar on`. The buttons, the rail, and the menu all do the
*same thing* as typing the verb — they just save you the typing.

Concretely: clicking the **Marketplace** icon in the rail and typing `open marketplace` in the
terminal are the same action. The terminal echoes what you did and reports the result. This is why the
terminal sits permanently at the bottom of the window — it is the **log**, the running record of your
session, exactly like the event strip in a dungeon-scroller.

The C64-style look (blue screen, uppercase, block cursor) is deliberate: it's the same retro verb
grammar that dungeon-scrollers grew up alongside. See the [terminal manual](terminal-user-manual.md)
for the full command list.

## 4. The screens

The rail (left) groups the screens by what they're for:

| Screen | Section | What it's for |
|---|---|---|
| **Editor** | design | The 3D robot view — load, select, and move robots. This is "the world". |
| **Robots** | design | Browse the built-in robot library and load one. |
| **Wallet** | publish | Your identity and funds (password keystore, on-chain operations). |
| **Marketplace** | publish | Buy, sell, and list robot designs. |
| **Coordination** | publish | Register robots and coordinate work on-chain. |
| **RaaS** | operate | Robotics-as-a-Service demos. |
| **Version Control** | utility | Git history and remotes for your designs. |
| **AI Assistant** | (right panel) | The agentic Claude assistant — it edits files in a workspace for you. |

Open a screen by clicking its rail icon, or with `open <id>` in the terminal. Press **Back** (the ◀ in
the status bar) or `back` to return to where you were.

## 5. The terminal

The terminal is both the command line and the log. It's Commodore-64 flavoured: blue, uppercase,
block cursor. Type `help` to list commands, or `help <command>` for details. See the
[terminal user manual](terminal-user-manual.md) for everything it can do.

## 6. Why this shape

| Dungeon-scroller | Copernicus |
|---|---|
| the world | the 3D robot editor |
| the event log | the terminal |
| the command rail | the left toolbar |
| the inventory / map / journal | the screens (marketplace, vcs, robots, …) |
| the character sheet / quest log | the side bar (objective + checklist) |
| the sage / helper | the AI assistant |

A robot-design session *is* a turn-based loop: look at the robot, issue a command, read what happened,
repeat. A persistent view + an event log + a verb rail is exactly the interface for that loop — it's
why the genre convention has survived forty years, and why it fits this tool better than a grid of
floating dashboard panels.

## 7. Further reading

- [Terminal user manual](terminal-user-manual.md)
- [Viewport user manual](viewport-user-manual.md) — the 3D editor's camera, selection, and modes
- [AI assistant user manual](ai-assistant-user-manual.md)
- [Design philosophy](design-philosophy.md) — the developer-facing rationale
