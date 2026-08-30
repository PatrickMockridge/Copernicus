# 10 — AI Assistant (agentic Claude)

This document defines the **AI assistant**, a kernel component. It is an agentic Claude integration:
the user gives a task; Claude uses tools to read and edit a **user workspace** directly. It builds on
`00` (kernel), `03` (signals/async), `09` (screen schema — it is a panel, not a screen), and `11` is
unrelated but shares the Settings screen.

## 1. Shape

The assistant is a **panel** (persistent, toggleable right panel), not a stage screen (`09` §2). It is
toggled by the viewport's top-right **AI** button, Tools → AI Assistant, or `open ai`.

**Contract:** `main_shell.gd` mounts the assistant in `_right_content`; `_ensure_panel`/`_show_panel`
special-case `"ai"` only.

## 2. Agent loop

`scripts/ai/agent.gd` (`AgentController`) runs the loop: send the conversation + `tools` to
`/v1/messages`; if the response contains `tool_use` blocks, execute each handler, append `tool_result`
blocks, and re-send — until a final `text` block. Capped at `MAX_TURNS` (20).

**Contract:** the loop is blocking and runs on a `TaskRunner` worker thread (`RChainService.run`); each
run returns `{ok, error, text, messages, events}` as plain data; the panel replays `events` on the main
thread.

## 3. Tools

`scripts/ai/tools.gd` (`AiTools`) exposes five tools:

| Tool | Effect |
|---|---|
| `read_file` | read a workspace file |
| `write_file` | write/overwrite a file (creates dirs) |
| `edit_file` | str_replace — replace one exact occurrence |
| `list_files` | list workspace files by extension |
| `search` | find files containing a substring |

**Contract:** every path resolves under the configured workspace and is clamped to it — `..` escape is
rejected. The workspace is a **user workspace** (default `~/robot_workspace`), never the Copernicus
source tree.

## 4. Client + connection

`scripts/ai/anthropic_client.gd` (`AnthropicClient`) speaks the Anthropic Messages API
(`/v1/messages`, `x-api-key`, `anthropic-version`), sends the `tools` array, parses `text` and
`tool_use` blocks, and provides `test_connection()` — a real `max_tokens: 1` "ping" round-trip.

**Contract:** "connected" is a **tested** fact, never assumed from key presence. The panel tests on
`_ready` and after a Settings save; failures surface loudly (status + chat), and the prompt is kept on
failure.

## 5. Configuration

`scripts/core/settings_store.gd` (`SettingsStore`) is the single source of truth, persisted to
`user://settings.json` (`ai.api_key`, `ai.base_url`, `ai.model`, `ai.workspace`), with `.env`
(`ANTHROPIC_API_KEY`/`ANTHROPIC_BASE_URL`/`ANTHROPIC_MODEL`/`AI_WORKSPACE`) as fallback, then defaults.

**Contract:** key/base URL/model/workspace are set in the **Settings** screen, not inline in the panel.
The agent reads `SettingsStore.resolve_ai()`.

## 6. Conformance checklist

- `open ai` toggles the right panel; the editor stays visible.
- With a valid key, the panel shows "Connected (model)" after a real round-trip; otherwise a loud error.
- `scripts/test_ai_client.gd` and `scripts/test_ai_tools.gd` pass headlessly.

## See also

- `docs/ai-assistant-user-manual.md`, `docs/features.md`, `scripts/ai/`, `scripts/core/settings_store.gd`.
