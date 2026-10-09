# codexcut

Run **Codex CLI** with almost everything cut away.

> The idea and the original project are by **Alex Getman**:
> [claudecut](https://github.com/alexgetmancom/claudecut) does this for Claude
> Code. codexcut is a port of his work to OpenAI's Codex CLI. The design, the
> structure of this repository and most of this README are his.

Same CLI, same account, same login. But a session starts with seven tools
instead of twenty-five or more, and a one-line base prompt instead of the
default one.

Built for a ChatGPT plan, where the thing you are actually spending is context.

On two real tasks against this repository, a cut session sent about 60% fewer
input tokens than stock Codex, at comparable answer quality. Startup context
drops from 17,236 tokens to 5,715, or to 3,259 with the smallest preset.

**How much to trust each of those**, because they are not equally solid:

| result | evidence |
|---|---|
| Startup context per preset | **One or two runs each.** A second run moved `min` by 8 tokens and `default` by about 5%. |
| What each switch saves | **One run per switch**, added one at a time. Sizes, not constants. See [`docs/presets.md`](docs/presets.md). |
| ~60% fewer input tokens on real tasks | **A trend, not statistics.** One run per task and preset. |
| Comparable quality | **Read, not scored.** All four answers were compared by hand. |
| Long sessions and compaction | **Not measured at all.** |

Outside data points would help on every row. Run the bench and open an issue.

```
codexcut  ──►  Codex CLI     ──►  OpenAI
               (unmodified)       shell · apply_patch · web search · one-line prompt

codex     ──►  Codex CLI     ──►  OpenAI
               (unmodified)       the full thing, untouched
```

- Nothing is patched, wrapped or reinstalled. These are documented CLI options:
  `-c key=value` and `--disable <feature>`
- Your plain `codex` command keeps working exactly as before
- `codexcut --full` gives you stock Codex for one run
- `exec`, `review`, `resume` and `fork` are cut too, because Codex takes its
  global options before the subcommand. Others, like `codexcut mcp list`, pass
  through uncut
- Presets put back exactly as much as you miss, and the bench prices each one

## What it costs

Two numbers matter, and they are different numbers.

**Session overhead**: what a session costs before doing anything, measured with
a prompt that uses no tools:

| preset | input tokens | what you keep |
|---|---:|---|
| `min` | 3,259 | the shell and `apply_patch`, and nothing else |
| `sh` | 5,715 | `min` + web search |
| `skills` | 6,754 | `sh` + your skills list |
| `default` | 17,236 | stock Codex |

**Real work**: both bench tasks against this repository, one run each:

| task | preset | input | of which cached | output | wall |
|---|---|---:|---:|---:|---:|
| `inspect` | `sh` | **30,064** | 19,200 | 237 | 28s |
| `inspect` | `default` | 73,622 | 51,712 | 370 | 24s |
| `trace` | `sh` | **22,728** | 6,528 | 359 | 19s |
| `trace` | `default` | 54,636 | 33,536 | 359 | 20s |

**About 60% fewer input tokens per task, at comparable quality**: -59% on
`inspect`, -58% on `trace`. The 3x gap in session overhead does not fully carry
over, because both sessions read the same files and that content is not free
under any preset. Only the overhead gets cut.

`trace` is a code-search task: find where config is loaded, quote the line,
explain the failure modes. Both presets found the same two places and quoted
the same line.

Codex CLI 0.161.0, `gpt-6.1-sol` at low effort. Codex reports no dollar cost, so
these are tokens. Cached input is billed at a lower rate, so the gap in cost is
smaller than the gap in tokens: counting only uncached input, the cut is -50%
on `inspect` and -23% on `trace`. The numbers also include the test machine's
own setup: an 800-token global `AGENTS.md` (kept in every preset), one MCP
server and a long skills list. Yours will differ. The repository is small, so
overhead weighs more here than it would on a large codebase.

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
codexcut --preset min                 # fewer tools, just this once
codexcut --full                       # stock Codex, just this once
codexcut --show exec hi               # print the command, run nothing
codexcut mcp list                     # passes through untouched
```

## What you give up

The `sh` preset means reading, searching and running all happen through the
shell: `cat`, `rg`, `sed`, `git diff`. Edits go through the shell or
`apply_patch`. Removed: subagents, plugins and apps, your MCP servers, the
skills list, image viewing and generation, goals, the `request_user_input`
tool, and the built-in Codex instructions.

Nothing warns you at runtime. If you want any of it back, that is what the
larger presets and `--full` are for.
[`docs/presets.md`](docs/presets.md) lists what each switch removes.

Your `AGENTS.md` files, sandbox mode and approval policy are left alone.

## Measuring it yourself

```bash
bench/run.sh --tasks hello                      # cheapest: overhead only
bench/run.sh --tasks inspect --repeat 3         # a real task in the current repo
bench/run.sh --presets sh,default --dir ~/code/yours
```

Each cell is a real `codex exec` run and spends real quota, so start with
`hello`. The script records turns, wall time and tokens from the CLI's own JSON
output, and writes every answer to a text file next to the numbers.

It prices a preset. It does not tell you whether the answer was any good. That
part is yours to read. See [`bench/`](bench/run.sh).

## How it works

Three pieces, none of them clever:

- [`bin/codexcut`](bin/codexcut): resolves the real `codex`, puts the preset's
  flags in front of your arguments, and hands non-session subcommands through
  as typed
- [`lib/presets.sh`](lib/presets.sh): the presets, a few lines each, yours to edit
- [`lib/prompt.md`](lib/prompt.md): the one-line base prompt

It is a script rather than a profile file for a concrete reason: a profile has
to live in `~/.codex`, and MCP servers can only be switched off one by one, by
name. The launcher reads those names from your `config.toml` at start and
writes nothing.

Unlike claudecut, there is no replacement shell server. Codex's own shell tool
costs about 640 tokens and keeps the sandbox, so it stays.

## Long sessions

Not measured. claudecut found that compaction, not startup, is what a long
session really pays for, and that a cut session keeps about twice the working
room after each one. Nobody has checked whether that holds for Codex.

What is known: the cut lives in the command line, so a stock `codex resume`
should come back with everything. Use `codexcut resume --last` or
`codexcut resume <id>` to keep the cut.

`CODEXCUT_AUTOCOMPACT` sets `model_auto_compact_token_limit` if you want
compaction to start earlier. It is unset by default.

## Going further

[`docs/presets.md`](docs/presets.md) covers every switch that was tried: what
each one saves, which ones saved nothing, and what is still left in the
smallest preset.

Settings, in the environment or in `~/.config/codexcut/config.sh`:

| variable | default | meaning |
|---|---|---|
| `CODEXCUT_PRESET` | `sh` | preset used when `--preset` is not given |
| `CODEXCUT_PROMPT_FILE` | `lib/prompt.md` | the base prompt |
| `CODEXCUT_AUTOCOMPACT` | unset | `model_auto_compact_token_limit`; unset keeps your own |
| `CODEXCUT_EFFORT` | unset | `model_reasoning_effort`; unset keeps your own |
| `CODEXCUT_CODEX_BIN` | from `PATH` | the real `codex` binary |

## Requirements

macOS or Linux with bash (Windows via WSL) ·
[Codex CLI](https://developers.openai.com/codex/cli) · `jq` if you want to run
the benchmark

## Caveats

- **The shell tool runs commands with whatever permissions you grant it.**
  codexcut does not change your sandbox or approval settings, in either
  direction.
- **The base prompt is replaced.** OpenAI's config reference strongly
  discourages `model_instructions_file`, because the built-in instructions are
  tuned per model. It is the largest single saving here, and the one most
  likely to change how the model behaves.
- **Measured on one version**, 0.161.0, on one machine. Feature names and
  defaults move between releases; run `test/subcommands.sh` and the bench
  rather than trusting this README.
- **One run per cell.** No repeats, no variance estimate.
- **Only `codex exec` was measured.** The interactive TUI gets the same flags,
  but was not measured or tested separately.

## Uninstall

It writes nothing into `~/.codex`. Delete the symlink and the checkout:
[`docs/uninstall.md`](docs/uninstall.md).

## Where this came from

The idea is Alex Getman's. It started as
[one tweet](https://x.com/alexgetmancom/status/2101411232771113143) about
cutting Claude Code down to almost nothing, and became
[claudecut](https://github.com/alexgetmancom/claudecut), with a
[measured answer](https://x.com/alexgetmancom/status/2101683761712636202) to
what that buys you. codexcut applies the same idea to Codex CLI and keeps his
commit history.

## License

MIT. Copyright Alex Getman for the original work.
