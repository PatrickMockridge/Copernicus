# Copernicus — User Manual

Welcome to Copernicus. This manual is written the way the old home-computer manuals were: it assumes
you're meeting this software for the first time, and it takes you by the hand — one idea at a time —
until the whole thing feels natural.

Take your time. Everything in Copernicus fits together, and once you see how, it all clicks.

---

## Chapter 1 — What Copernicus is

Copernicus is a **robot design interface**. You use it to load a robot, look at it, move its joints,
watch what its sensors see, drive it around, and — when you're ready — publish your design and put it
to work. It is built on Godot 4, the free game engine.

The important thing to understand is the *shape* of the program. It is laid out like a classic
**dungeon-crawler game** — the kind of game that filled home computers in the 1980s. Not the swords
and monsters: the *arrangement*.

A dungeon-crawler always gives you the same three things on one screen:

- **The world** — the one thing you're always looking at.
- **The log** — a strip of text that tells you what just happened.
- **The commands** — a row of things you can do next.

Copernicus keeps that arrangement exactly, but the "world" is a robot, the "log" is a terminal, and the
"commands" are words you type (or buttons you press). This is a forty-year-old, well-worn way to lay
out a tool, because it answers three questions at once: *where am I?*, *what just happened?*, and *what
can I do next?* — without you ever having to hunt through a pile of floating windows.

---

## Chapter 2 — The screen

When Copernicus starts, you see one window. From left to right, top to bottom, it looks like this:

```
┌──────────────────────────────────────────────────────────────┐
│  menu bar                                                    │
├────┬────────┬───────────────────────────────┬────────────────┤
│    │        │                               │                │
│rail│journal │            stage              │   assistant    │
│    │ (side  │   (the robot, in 3D)          │   (the AI)     │
│    │  bar)  │                               │                │
│    │        ├───────────────────────────────┤                │
│    │        │            log                │                │
│    │        │   (the terminal)              │                │
├────┴────────┴───────────────────────────────┴────────────────┤
│  status bar                                                  │
└──────────────────────────────────────────────────────────────┘
```

Here is each part, in plain words:

- **The rail** (far left) — a column of small icons. These are your *screens*: the different places you
  can go. Click one to switch to it.
- **The journal** (side bar) — context for whatever you're doing. When you're designing, it shows your
  current objective and its checklist.
- **The stage** (centre) — the main area. This is where the 3D robot appears. It's the "world".
- **The assistant** (right) — the AI helper. It stays tucked away until you want it.
- **The log** (bottom) — the terminal. This is the heart of the program, and Chapter 3 is all about it.
- **The status bar** (bottom edge) — a back button, a breadcrumb showing where you are, and small
  readouts (mode, wallet, node, ROS 2, frames-per-second).

Don't memorise all of that yet. Just know: **watch the stage, talk to the log, switch screens from the
rail.**

---

## Chapter 3 — The terminal (the log, and the verbs)

This is the part worth reading slowly, because it's the trick that makes Copernicus feel different —
and, with a little use, wonderfully simple.

**The terminal is not an optional extra. It is the command line and the log rolled into one.** It is
styled after a Commodore 64: blue screen, UPPERCASE text, a solid blinking block for a cursor.

Here is the key idea:

> **Everything you can do in Copernicus is a word.** The buttons and menus just type those words for you.

If you want to open the Marketplace, you can click its rail icon, *or* you can type:

```
> open marketplace
```

Both do exactly the same thing. The terminal echoes what you typed, does it, and prints the result. That
is why it sits permanently at the bottom of the window — it is the running record of your whole session,
just like the message strip at the bottom of a dungeon-crawler.

### Your first three words

Open the terminal (it's already there at the bottom) and type these, pressing Enter after each:

```
> list
```

This prints the whole command catalogue, grouped by category. Then:

```
> help load
```

This prints what the `load` command does and how to use it. Then:

```
> clear
```

This wipes the screen. That's the pattern for every command: **type a word, see what it does.**

If you type a word Copernicus doesn't know, it tells you — with a `?` before the message, in the style
of old BASIC:

```
> florb
?UNKNOWN COMMAND
```

Errors are loud on purpose. If something goes wrong, the terminal tells you.

---

## Chapter 4 — Your first robot

Let's do something real. Type:

```
> load arm6
```

A 6-jointed robot arm appears in the stage. That's a *built-in robot* — Copernicus ships with a small
library of them. Try a couple more:

```
> load turtlebot
> load quadruped
> load drone
```

Each one replaces the last. Now let's look at one properly. Load the arm again:

```
> load arm6
```

To look around the robot, use the mouse:

| Do this | To do this |
|---|---|
| **Left-drag** | orbit around the robot |
| **Middle-drag** (or `WASD` / arrow keys) | pan |
| **Mouse wheel** | zoom in and out |
| **Left-click** a part | select it (it highlights) |

Two more handy words:

```
> wireframe on
> grid off
```

`wireframe` shows the robot as a flat, see-through cage (good for seeing the skeleton). `grid` toggles
the floor grid. Try `wireframe off` and `grid on` to put them back.

---

## Chapter 5 — The screens (the rail)

The rail down the left side is your map of the program. Each icon is a **screen** — a different place to
go. From top to bottom, grouped loosely by purpose:

| Screen | What it's for |
|---|---|
| **Editor** | The 3D robot view — the "world". |
| **Robots** | Browse the built-in robot library and pick one. |
| **Wallet** | Your identity and funds (on-chain). |
| **Marketplace** | Buy, sell, and list robot designs. |
| **Coordination** | Register robots and take on jobs. |
| **RaaS** | Robotics-as-a-Service demos. |
| **Version Control** | Git history and remotes for your work. |
| **Settings** | Your AI key and endpoint, wallet import, and more. |

To open any screen, click its icon — or type `open <name>`, for example `open wallet`.

To go back to where you were, click the **◀ back** button in the status bar, or type `back`. The
breadcrumb in the status bar shows your path, so you always know where you are.

---

## Chapter 6 — The Workbench Loop (your quest)

Copernicus guides you through a **ten-step journey** from "first light" to a shipped, validated design.
You'll see it in the side bar when you're on the Editor screen: an objective and a checklist.

The ten steps, in order:

1. **First Light** — load a robot.
2. **Set the Pose** — move the arm and zero it.
3. **Reach the Target** — make the arm reach a marker (inverse kinematics).
4. **See What It Sees** — turn on its sensors.
5. **Make It Move** — drive it.
6. **Wire It to ROS 2** — connect the bridge.
7. **Register It** — register it on-chain.
8. **Put It On the Market** — list it.
9. **Run It For Hire** — take a job and settle the fee.
10. **Ship** — a validated, published design.

Each step is an objective with a checklist; finish the checklist and the next step unlocks. You can see
where you are at any time by typing:

```
> mode
```

The whole thing is explained, step by step, in the two case studies:
[the robot arm](case-study-robot-arm.md) and [the TurtleBot](case-study-turtlebot.md).

---

## Chapter 7 — The helper and the treasury

Two more parts round out the program:

**The AI assistant** (right-hand panel) is your coding companion. Tell it what to build and it reads and
edits the files in a workspace for you. Toggle it with the **AI** button in the top-right of the
viewport, or `open ai`. You'll need to set an API key first — see [the AI manual](ai-assistant-user-manual.md).

**The wallet** is your on-chain identity. It's the second most important screen after the Editor, because
it holds your funds. You can create a key, or import one you already have — see
[the wallet spec](rchain/wallet-spec.md) and the Settings screen.

---

## Chapter 8 — Where to go next

- [The terminal manual](terminal-user-manual.md) — every command, in full.
- [The viewport manual](viewport-user-manual.md) — camera, selection, modes, and shortcuts.
- [The AI assistant manual](ai-assistant-user-manual.md).
- [The feature index](features.md) — one line per feature, with links to the deep guides.
- [The case studies](case-study-robot-arm.md) — work through the arm and the TurtleBot end to end.

That's the whole of Copernicus. **Watch the stage, talk to the log, switch screens from the rail** — and
type a word whenever you're unsure. `help` is always there.
