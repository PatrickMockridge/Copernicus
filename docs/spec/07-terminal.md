# 07 — Terminal Specification

This document defines Copernicus's **terminal**: the primary, prompt-driven interface from which the
GUI and the plugins are both driven. It is normative and falsifiable. It builds on
`04-components.md` (`UiConsole`, `CommandRegistry`) and `05-state-transitions.md` (the terminal is a
docked panel; every command that changes view/state does so through the same routes/toggles the GUI
uses).

The model is **Commodore-64-like**: boot to a prompt, type a command at a `> ` prompt, get output and
`?`-prefixed errors, and consult a catalog of commands. Commands are **modern lowercase verbs**.

## 1. Boot and prompt

- On boot the terminal prints `COPENICUS TERMINAL v1` followed by `READY.`.
- The input line shows the prompt `> ` (placeholder `> command`).
- Pressing Enter submits the line; the line is echoed with its `> ` prefix, executed, and any output
  or error is printed below it.

## 2. Grammar

A line is one command: `COMMAND [ARG...]`.

- Tokens are separated by ASCII whitespace.
- A token may be a bare word (`arm6`) or a double-quoted string (`"my arm.urdf"`) whose contents may
  contain spaces.
- Empty input and blank lines are ignored (no error).

```
line      := [ command ]
command   := TOKEN { TOKEN }
TOKEN     := QUOTED | BARE
QUOTED    := '"' { any-char-except-'"' } '"'
BARE      := { any-char-except-whitespace }
```

`tokenize(line)` returns an `Array` of tokens (first token = the command name, the rest = args). The
tokenizer is a pure function (headless-testable).

## 3. Command contract

A command is a `Dictionary`:

| Field | Type | Meaning |
|---|---|---|
| `name` | `String` | the verb typed at the prompt (unique key) |
| `syntax` | `String` | usage, e.g. `open <view>` |
| `description` | `String` | one-line description |
| `category` | `String` | catalog group, e.g. `view`, `robot`, `meta` |
| `handler` | `Callable(args, out) -> bool` | the command implementation |

The handler receives `args: Array` (tokens after the name) and `out: Callable(line: String)` (writes a
line to the terminal). It returns `true` on success, `false` on failure — on failure it has already
written a `?`-prefixed error via `out`.

**Contract:** `register` replaces any prior command with the same `name`; `execute` looks the command
up by exact `name` (not fuzzy); the handler is invoked with the parsed args and a working `out`.

## 4. Error model

Errors are written with a leading `?`. The engine emits `?UNKNOWN COMMAND` when no command matches the
verb. Handlers emit `?SYNTAX ERROR` (wrong arity) or `?BAD ARGUMENT` (unknown value). A handler that
returns `false` without writing an error is treated as a silent failure (the engine still returns
`false`).

**Contract:** `execute("nosuchcmd", out)` → `out("?UNKNOWN COMMAND")` and returns `false`.

## 5. Catalog and help

- `list` (alias `commands`) prints every command grouped by `category`, one line per command in the
  form `  name syntax` (e.g. `  open <view>`).
- `help [name]` prints the matching command's `syntax` + `description`; with no argument it prints the
  same output as `list`.

**Contract:** `list` output contains one line per registered command, grouped by category; `help open`
  prints `open <view>` and its description.

## 6. Built-in command catalog

| Verb | Syntax | Category | Action |
|---|---|---|---|
| `open` | `open <view>` | view | open editor·wallet·marketplace·vcs·coordination·raas·robots·ai·plugins |
| `load` | `load <id\|path>` | robot | load a library robot (turtlebot·arm6·quadruped·gripper·drone) or a `.urdf`/`.mjcf` path |
| `back` | `back` | nav | navigate back (history) |
| `mode` | `mode` | nav | print the active scenario title + mode |
| `wireframe` | `wireframe [on\|off]` | view | set/toggle wireframe |
| `grid` | `grid [on\|off]` | view | set/toggle grid |
| `sensors` | `sensors <lidar\|camera\|imu> [on\|off]` | view | set/toggle a sensor |
| `demo` | `demo <physics\|turtle>` | demo | open a demo |
| `tool` | `tool <ik\|physics\|nav\|gpu\|omni\|industrial>` | tool | open a tool selector |
| `ros2` | `ros2` | tool | connect the ROS2 bridge |
| `plugins` | `plugins` | meta | open the plugin manager |
| `list` / `commands` | `list` | meta | print the catalog |
| `help` | `help [command]` | meta | print help |
| `clear` | `clear` | meta | clear the terminal |

## 7. Plugin contribution

A plugin contributes commands by overriding `CopernicusModule.get_commands()` to return an `Array` of
command dicts in the §3 shape. `ModuleRegistry.get_contributed_commands()` collects them; the shell
registers each into the terminal engine and the palette.

**Contract:** a plugin's contributed commands are discoverable via `list`/`help` and callable at the
prompt; each has a unique `name`, a non-empty `syntax`, and a `handler` that writes `?`-prefixed
errors on failure. The default `get_commands()` returns `[]`.

## 8. GUI as a layer

The command palette, menu items, and buttons dispatch to the **same handlers** the terminal invokes.
The terminal catalog is the single source of truth for "what the app can do"; the GUI does not add
secret, terminal-unreachable functionality.

**Contract:** every palette command and every menu action that changes state has a corresponding
terminal verb with the same handler.

## 9. Conformance checklist

- `grep -rn "CommandRegistry.find\|CommandRegistry.run" scripts/ui/main_shell.gd` → zero (the terminal
  dispatches via the CLI engine).
- `test_cli.gd` asserts: tokenizer (quotes + empty tokens), `execute` (good/unknown/arg-error),
  `?UNKNOWN COMMAND`, `?SYNTAX ERROR`, and `list`/`help` output.
- `list` output lists every built-in verb in §6.
- `godot --headless --import` clean; the full test suite passes.
