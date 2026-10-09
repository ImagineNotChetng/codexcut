# Presets

A preset is a list of Codex CLI options. `codexcut --show` prints the exact
command for the current preset. All of them are defined in
[`lib/presets.sh`](../lib/presets.sh).

| preset | adds back |
|---|---|
| `sh` | nothing: shell and `apply_patch` only |
| `web` | live web search |
| `skills` | the skills list |
| `default` | everything: stock Codex, no flags added |

## What each switch does

Measured with `codex exec`, Codex CLI 0.161.0, model `gpt-6.1-sol`, one run
each, on one machine. "Saves" is the drop in input tokens for a session that
only answers "ok". Treat the numbers as rough sizes, not constants.

| switch | removes | saves |
|---|---|---:|
| `-c model_instructions_file=lib/prompt.md` | the built-in base instructions | ~3,450 |
| `-c agents.enabled=false` | subagent tools and the multi-agent role text | see below |
| `--disable plugins`, `--disable apps` | plugin and app tools and their hints | see below |
| `-c skills.include_instructions=false` | the skills list | see below |
| `-c include_collaboration_mode_instructions=false` | the collaboration mode text | see below |
| `-c mcp_servers.<name>.enabled=false` | your MCP servers, one flag per server | see below |
| `-c web_search="disabled"` | the web search tool | ~2,450 |
| `--disable view_image`, `--disable image_generation` | image tools | ~670 |
| `--disable tool_suggest`, `skill_search`, `sleep_tool`, `goals` | those tools | ~700 |
| `--disable default_mode_request_user_input` and `-c tools.experimental_request_user_input.enabled=false` | the question tool | ~190 |

The five "see below" rows were measured together: about 5,000 tokens on a
machine with one MCP server and a long skills list.

## Switches that were tried and saved nothing

- `--disable multi_agent` and `--disable multi_agent_v2`: the multi-agent text
  stayed. `agents.enabled=false` is what removes it.
- `-c project_doc_max_bytes=0`: the global `AGENTS.md` still loaded.
- `--disable unified_exec`, `code_mode_host`, `code_mode`,
  `context_management`, `hooks`.

## What is left in `sh`

About 3,250 tokens on the test machine, of which roughly 800 were its own
`AGENTS.md`. The model still listed these tools: `exec_command`, `write_stdin`,
`apply_patch`, `exec`, `wait` and `clock__curr_time`. No switch was found for
the last four.

`--disable shell_tool` saves another ~640 tokens, and leaves the model with no
way to run anything. No preset uses it.

Two small context blocks are kept on purpose: the permissions text and the
environment block (working directory, shell, date). Together they are about
170 tokens. `include_permissions_instructions=false` and
`include_environment_context=false` remove them.

## Making your own

Add a case to `codexcut_preset_flags` in `lib/presets.sh` and its name to
`codexcut_presets`. Print one argument per line. Then price it:

```bash
bench/run.sh --tasks hello --presets sh,yours,default
```
