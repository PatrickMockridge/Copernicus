# Copernicus Terminal — User Manual

The terminal is the heart of Copernicus. Everything the GUI can do, the terminal can do — and
plugins expose their features through it too. It boots to a prompt, you type a command, and it prints
output or a `?`-prefixed error.

## 1. Getting started

On launch the bottom panel prints:

```
COPENICUS TERMINAL v1
READY.
```

Type a command at the `> ` prompt and press **Enter**. Press **↑**/**↓** to recall previous commands.
Type `clear` to wipe the screen, `list` to see every command.

## 2. Command reference

### Views

| Command | What it does |
|---|---|
| `open <view>` | Open a view: `editor`, `wallet`, `marketplace`, `vcs`, `coordination`, `raas`, `robots`, `ai`, `plugins` |

```
> open marketplace
> open wallet
```

### Robots

| Command | What it does |
|---|---|
| `load <id>` | Load a library robot: `turtlebot`, `arm6`, `quadruped`, `gripper`, `drone` |
| `load <path>` | Load a `.urdf` or `.mjcf` file |

```
> load arm6
> load "/home/me/my_robot.urdf"
```

### View toggles

| Command | What it does |
|---|---|
| `wireframe [on\|off]` | Toggle or set wireframe |
| `grid [on\|off]` | Toggle or set the grid |
| `sensors <lidar\|camera\|imu> [on\|off]` | Toggle or set a sensor |

```
> wireframe on
> sensors lidar on
> sensors imu off
```

### Demos & tools

| Command | What it does |
|---|---|
| `demo <physics\|turtle>` | Open a demo |
| `tool <ik\|physics\|nav\|gpu\|omni\|industrial>` | Open a tool selector |
| `ros2` | Connect the ROS2 bridge |

### Navigation & status

| Command | What it does |
|---|---|
| `back` | Go back to the previous view |
| `mode` | Show the current objective and mode |

### Meta

| Command | What it does |
|---|---|
| `plugins` | Open the plugin manager |
| `list` (or `commands`) | Print the command catalog |
| `help [command]` | Show help for one command, or the catalog with no argument |
| `clear` | Clear the terminal |

## 3. Errors

Errors begin with `?`.

| Error | Meaning |
|---|---|
| `?UNKNOWN COMMAND` | No command matches what you typed |
| `?SYNTAX ERROR` | A command is missing a required argument |
| `?BAD ARGUMENT` | An argument isn't one of the allowed values |
| `?FILE NOT FOUND` | `load` couldn't find the file |

```
> opn marketplace
?UNKNOWN COMMAND
> open
?SYNTAX ERROR
> open nope
?BAD ARGUMENT: nope
```

## 4. Plugins

Plugins add their own commands. After a plugin is enabled (see `plugins`), its verbs appear in
`list` and work at the prompt. For example, the coordination plugin contributes:

```
> register my_robot
registered my_robot
```

## 5. The command palette

Press `` ` `` / `Ctrl+Shift+P` / `Ctrl+K` to open the palette. It fuzzy-searches the same command
catalog; picking a command fills the terminal prompt so you can add arguments and press Enter.
