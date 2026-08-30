# AI Assistant

> **Superseded.** This file previously described the old `GameAI`/`ROSAI`/`ROSCoder` stack, which is now
> dormant. The AI assistant is now an **agentic Claude assistant** — a kernel component that edits a
> user workspace with tools.

See:

- [`spec/10-ai-assistant.md`](../spec/10-ai-assistant.md) — the formal spec.
- [`ai-assistant-user-manual.md`](../ai-assistant-user-manual.md) — how to configure and use it.

Implementation: `scripts/ai/` (`agent.gd`, `anthropic_client.gd`, `tools.gd`), configured in Settings.
