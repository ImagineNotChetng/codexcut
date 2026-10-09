#!/usr/bin/env bash
# The subcommand lists in bin/codexcut are hardcoded, because asking the CLI at
# launch would cost a `--help` run on every invocation. So they can fall behind
# a Codex release.
#
# This compares them against the live `codex --help` output. Every subcommand
# must be either passed through uncut or known to take the cut flags. A new
# one that is in neither list fails the test, so someone decides which it is.
set -euo pipefail
export LC_ALL=C   # comm needs one sort order on both sides

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v codex >/dev/null || { echo "test: codex not on PATH" >&2; exit 1; }

# Session subcommands: these get the cut flags.
cut="exec e review resume fork"

# The pass-through case label spans several lines with backslash continuations.
pass="$(sed -n '/^    agents|/,/passthrough=1/p' "$ROOT/bin/codexcut" \
  | tr -d ' \\\n' | sed 's/)passthrough=1;;//' | tr '|' '\n')"

ours="$(printf '%s\n' $cut $pass | sort -u)"

# Names and aliases: "  exec   Run ... [aliases: e]".
live="$(codex --help 2>&1 | sed -n '/^Commands:/,/^Arguments:/p' \
  | awk '
      /^  [a-z]/ { print $1 }
      match($0, /\[aliases: [^]]*\]/) {
        s = substr($0, RSTART + 10, RLENGTH - 11); gsub(/,/, " ", s)
        n = split(s, a, " "); for (i = 1; i <= n; i++) print a[i]
      }' | sort -u)"

missing="$(comm -13 <(printf '%s\n' "$ours") <(printf '%s\n' "$live"))"
extra="$(comm -23 <(printf '%s\n' "$ours") <(printf '%s\n' "$live"))"

[ -n "$extra" ] && printf 'test: extras, hidden or gone: %s\n' "$(echo $extra)"

if [ -n "$missing" ]; then
  printf 'test: FAIL - subcommands this CLI has that codexcut does not know:\n'
  printf '  %s\n' $missing
  printf 'Add them to bin/codexcut (pass-through) or to "cut" in this test.\n'
  exit 1
fi

# Every cut flag must still be accepted. `debug prompt-input` loads the config
# and renders the prompt locally, so this costs no model call.
flags=()
while IFS= read -r f; do [ -n "$f" ] && flags+=("$f"); done \
  < <(. "$ROOT/lib/presets.sh"; codexcut_preset_flags sh)
if ! codex debug prompt-input "${flags[@]}" hi >/dev/null 2>"${TMPDIR:-/tmp}/codexcut-test.err"; then
  printf 'test: FAIL - codex rejected the sh preset flags:\n'
  cat "${TMPDIR:-/tmp}/codexcut-test.err"
  exit 1
fi

printf 'test: ok - %s knows every subcommand and accepts the sh preset\n' "$(codex --version)"
