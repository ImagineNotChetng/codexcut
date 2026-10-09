# codexcut: setup and management

Give this file to a fresh Codex session, whether you are installing for the
first time or changing an existing setup. The agent works out which case it is
on its own.

---

Set up a `codexcut` command on my machine that runs the stock Codex CLI with
most of its tools and its built-in prompt removed, so a session starts with far
less context. Do not patch, wrap or reinstall Codex itself, and do not change
how my plain `codex` command behaves.

## Step 0: inspect, then ask

**Establish what already exists.** Do not assume a fresh install, and do not
assume an existing one:

- Where does `codex` resolve to, and what does `codex --version` print?
- Is there a checkout of this repository on the machine already, and is
  `codexcut` on `PATH` or defined in my shell startup files?
- Does `~/.config/codexcut/config.sh` exist, and what does it set?
- Do I have `jq`, which the benchmark needs?
- Does `~/.codex/config.toml` set `model`, `model_reasoning_effort`,
  `model_auto_compact_token_limit` or `web_search`? Which MCP servers does
  `codex mcp list` show? Report the values, never the whole file.
- Which name do I want for the command, if `codexcut` is taken? Check with
  `command -v` and by grepping my startup files before claiming a name is free.

Show me the current state as a short table. If nothing exists, say so in a line.

**Then ask me what I want,** and wait:

- **Install** the command for the first time
- **Change the default preset**, or add a preset of my own
- **Retune**: base prompt, auto-compact limit, effort level
- **Remove** it

For an install or a preset change, also ask which preset should be the default,
and state the trade-off for each in one sentence. Do not editorialise beyond
that; [`docs/presets.md`](docs/presets.md) has the detail and the measured
numbers. The options are `min`, `sh`, `skills` and `default`.

Make clear which capabilities a preset removes. Subagents, plugins, apps, MCP
servers, the skills list and image tools are switched off with no warning at
runtime.

## Step 1: get the files in place

Clone this repository somewhere permanent, or use the existing checkout if one
is already there. Do not copy the scripts into `~/.codex`: they are a launcher
that sits beside Codex, not part of it.

Verify the tree has `bin/codexcut`, `lib/presets.sh`, `lib/prompt.md`,
`test/subcommands.sh` and `bench/`. Make the scripts executable.

## Step 2: put the command on PATH

Prefer a symlink into a directory already on my `PATH`:

```bash
ln -s /abs/path/to/codexcut/bin/codexcut ~/.local/bin/codexcut
```

If no suitable directory exists, add the repository's `bin/` to `PATH` in the
correct shell startup file, matching the style of what is already there.

Do **not** create an alias. The launcher has to decide per subcommand whether
the cut flags apply, and an alias can only prepend text.

Do **not** name it `codex`, and do not shadow the real binary, unless I
explicitly ask for that and confirm I understand it would capture every script,
cron job and editor integration that calls `codex`.

## Step 3: configure, if I asked for anything non-default

Write `~/.config/codexcut/config.sh` only if I chose something other than the
defaults. It is sourced by the launcher, so it holds shell variable assignments
and nothing else:

```bash
CODEXCUT_PRESET=sh
CODEXCUT_EFFORT=low
CODEXCUT_AUTOCOMPACT=200000
CODEXCUT_PROMPT_FILE="$HOME/.config/codexcut/prompt.md"
```

`CODEXCUT_EFFORT` and `CODEXCUT_AUTOCOMPACT` are unset by default, which keeps
whatever my `config.toml` already says. Set them only if I ask.

Never put any of this in `~/.codex/config.toml`. That file also drives the
plain `codex` command, and keeping the two apart is the point of this setup.

If I want a preset of my own, add a case to `codexcut_preset_flags` in
`lib/presets.sh`, then measure it (step 4) instead of asserting it is cheaper.

## Step 4: verify, with commands you actually ran

Every claim must come from output you saw. Do not report success from reasoning:

- `test/subcommands.sh` prints `test: ok`. It checks the subcommand list and
  the preset flags against my installed Codex, and calls no model
- `codexcut --show exec hi` prints a command line carrying
  `model_instructions_file`, `agents.enabled=false` and `--disable plugins`
- `codexcut --show mcp list` prints the bare binary with **no** cut flags
- `codexcut --show --full exec hi` prints the bare binary too
- `codexcut exec "Do not call any tool. List the exact name of every tool you have, one per line." </dev/null`
  returns a short list with no subagent, plugin, image or goal tools. Keep the
  `</dev/null`: without it `codex exec` waits on stdin when run from a script
- `codex --version` still works exactly as before, and the modification
  time of `~/.codex/config.toml` shows it was not written
- Any other command I already had still resolves where it did

Then run the cheapest benchmark cell and show me the table:

```bash
bench/run.sh --tasks hello --presets sh,default
```

This spends a little of my quota: two real `codex exec` runs. Tell me what one
trivial turn costs under each, from that run, not from the numbers in this
repository, which came from someone else's machine.

## Step 5: tell me what I lost

Close by listing, in plain terms, the capabilities the chosen preset removed and
how to get each back for one session (`codexcut --full`, or `--preset` with a
larger preset). Do not oversell the setup. If I picked `sh`, say outright that
subagents, plugins, MCP servers and the skills list are gone until I ask for
them back, and that the built-in Codex instructions are replaced by one line.

## Changing an existing setup

- **Change preset:** edit `CODEXCUT_PRESET` in the config file. One line.
- **Retune:** adjust `CODEXCUT_*` variables. Add no new variable without a
  reason you can state. [`docs/presets.md`](docs/presets.md) lists every switch
  and what it was measured to save.
- **Remove:** follow [`docs/uninstall.md`](docs/uninstall.md): drop the symlink
  or PATH entry, delete the checkout, delete `~/.config/codexcut`. Ask before
  touching anything in `~/.codex`, since none of it belongs to this project.

Finish in one move: no TODOs, no stubs, no half-installed command.

## Constraints

- Never modify, patch, repackage or reinstall the Codex binary.
- Never write to `~/.codex/config.toml` unless I ask for it by name.
- Never print or log credentials, tokens, or the contents of config files.
- Do not weaken sandbox or approval settings to make something work. If a step
  needs a permission I have not granted, stop and tell me.
- Ask me only for genuine product choices. Verify every discoverable machine
  detail yourself instead of reasoning about it.
