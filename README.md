# codexcut

Run **Codex CLI** with almost everything cut away.

Same CLI, same account, same login. But a session starts with the shell,
`apply_patch` and web search instead of two dozen tools, and a one-line base prompt instead of
the built-in one.

This is a port of [claudecut](https://github.com/alexgetmancom/claudecut) by
Alex Getman, which does the same for Claude Code.

```
codexcut  -->  Codex CLI     -->  OpenAI
               (unmodified)       shell + web search, one-line prompt

codex     -->  Codex CLI     -->  OpenAI
               (unmodified)       the full thing, untouched
```

- Nothing is patched, wrapped or reinstalled. The cut is made of `-c key=value`
  and `--disable <feature>`, both documented CLI options
- Nothing is written to `~/.codex`. Your plain `codex` command works as before
- `codexcut --full` gives you stock Codex for one run
- `exec`, `review`, `resume` and `fork` are cut too. Other subcommands, like
  `codexcut mcp list`, pass through as typed
- Your `AGENTS.md` files, sandbox mode and approval policy are left alone

## What it costs

**Session overhead**: input tokens of a session that only answers "ok".

| preset | input tokens | what you keep |
|---|---:|---|
| `min` | 3,259 | shell and `apply_patch` |
| `sh` | 5,715 | `min` + web search |
| `skills` | 6,754 | `sh` + your skills list |
| `default` | 17,236 | stock Codex |

**Real work**: the `inspect` task (describe this repository, read-only).
The cut row is the `min` preset; `sh` was not run on this task.

| preset | input tokens | of which cached | output | wall |
|---|---:|---:|---:|---:|
| `min` | 23,550 | 10,624 | 245 | 17s |
| `default` | 76,274 | 68,352 | 355 | 20s |

Both answers named the same entry point and the same two files.

**How much to trust this.** Not much yet:

- One run per cell. No repeats, no variance estimate.
- One machine, Codex CLI 0.161.0, model `gpt-6.1-sol` at low effort.
- The numbers include that machine's own setup: an 800-token global
  `AGENTS.md` (kept in every preset), one MCP server, live web search and a
  long skills list. Your stock number will differ.
- Cached input is billed at a lower rate, so the gap in cost is smaller than
  the gap in tokens.
- Codex prints no dollar cost, so none is reported.

Run the bench on your own machine before trusting any of it.

## Getting started

Open a fresh Codex session and hand it [`setup-prompt.md`](setup-prompt.md).

The agent checks what you already have, asks which preset you want, puts the
command on your `PATH`, verifies the whole path end to end, and finishes by
telling you which capabilities you just gave up.

Or do it by hand. It is a symlink:

```bash
git clone https://github.com/ImagineNotChetng/codexcut ~/projects/codexcut
ln -s ~/projects/codexcut/bin/codexcut ~/.local/bin/codexcut
```

Then use it like Codex, because it is Codex:

```bash
codexcut
codexcut resume --last
codexcut exec "explain src/index.ts"
codexcut --preset min                 # shell only, just this once
codexcut --full                       # stock Codex, just this once
codexcut --show exec hi               # print the command, run nothing
codexcut mcp list                     # passes through untouched
```

## What you give up

In the `sh` preset: subagents, plugins and apps, your MCP servers, the skills
list, image viewing and generation, goals, the `request_user_input`
tool and the built-in Codex instructions. Reading, searching and running all go
through the shell.

Nothing warns you at runtime. If you want something back, use a larger preset,
`--full`, or edit [`lib/presets.sh`](lib/presets.sh).
[`docs/presets.md`](docs/presets.md) lists every switch and what it saves.

OpenAI's config reference strongly discourages `model_instructions_file`,
because the built-in instructions are tuned for each model. Replacing them is
the largest single saving here, and also the one most likely to change how the
model behaves. Edit [`lib/prompt.md`](lib/prompt.md) to taste.

## Configuration

Set these in the environment or in `~/.config/codexcut/config.sh`:

| variable | default | meaning |
|---|---|---|
| `CODEXCUT_PRESET` | `sh` | preset used when `--preset` is not given |
| `CODEXCUT_PROMPT_FILE` | `lib/prompt.md` | the base prompt |
| `CODEXCUT_AUTOCOMPACT` | unset | `model_auto_compact_token_limit`; unset keeps your own |
| `CODEXCUT_EFFORT` | unset | `model_reasoning_effort`; unset keeps your own |
| `CODEXCUT_CODEX_BIN` | from `PATH` | the real `codex` binary |

## Measuring it yourself

```bash
bench/run.sh --tasks hello                      # cheapest: overhead only
bench/run.sh --tasks inspect --repeat 3         # a real task in the current repo
bench/run.sh --presets sh,default --dir ~/code/yours
```

Each cell is a real `codex exec` run and spends real quota, so start with
`hello`. The script records wall time and the tokens Codex reports, and writes
every answer to a text file next to the numbers. It does not tell you whether
the answer was any good. That part is yours to read.

`codex debug prompt-input` is free: it renders the messages Codex would send,
without calling a model. It shows the injected context blocks, but not the base
instructions or the tool schemas.

## How it works

- [`bin/codexcut`](bin/codexcut): finds the real `codex`, puts the preset's
  flags in front of your arguments, and passes non-session subcommands through
- [`lib/presets.sh`](lib/presets.sh): the presets, a few lines each
- [`lib/prompt.md`](lib/prompt.md): the base prompt
- [`test/subcommands.sh`](test/subcommands.sh): checks the subcommand list and
  the preset flags against the installed Codex, without calling a model

It is a script and not a profile file, because a profile has to live in
`~/.codex`, and MCP servers can only be turned off one by one, by name. The
launcher reads those names from your `config.toml` at start.

## Requirements

macOS or Linux with bash (Windows via WSL), the
[Codex CLI](https://developers.openai.com/codex/cli), and `jq` for the bench.

## Caveats

- **The sandbox and approval settings are yours.** codexcut does not change
  them. The shell tool runs with whatever you already allow.
- **Measured on one version**, 0.161.0. Feature names and defaults move between
  releases. Run `test/subcommands.sh` after an update.
- **Only `codex exec` was measured.** The interactive TUI gets the same flags
  but its overhead was not measured separately.

## Uninstall

Delete the symlink and the checkout. See [`docs/uninstall.md`](docs/uninstall.md).

## License

MIT. Based on [claudecut](https://github.com/alexgetmancom/claudecut),
copyright Alex Getman.
