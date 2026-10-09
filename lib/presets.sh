# codexcut presets - sourced by bin/codexcut and bench/run.sh.
#
# A preset is a set of flags handed to the Codex CLI at launch. Nothing is
# patched and nothing is written to ~/.codex: these are `-c key=value` config
# overrides and `--disable <feature>` switches, both documented CLI options.
#
# codexcut_preset_flags <name>   prints the flags, one argument per line.
# codexcut_presets               prints every preset name.

CODEXCUT_ROOT="${CODEXCUT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"

# The whole base prompt. Replaces the model's built-in Codex instructions.
# Your AGENTS.md files are separate and still load.
CODEXCUT_PROMPT_FILE="${CODEXCUT_PROMPT_FILE:-$CODEXCUT_ROOT/lib/prompt.md}"

# Optional. Token count that triggers auto-compaction. Empty keeps whatever
# Codex or your config.toml already uses.
CODEXCUT_AUTOCOMPACT="${CODEXCUT_AUTOCOMPACT:-}"

# Optional. Reasoning effort: low, medium, high... Empty keeps your own setting.
CODEXCUT_EFFORT="${CODEXCUT_EFFORT:-}"

# Where Codex keeps config.toml. Only read, never written.
CODEXCUT_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

# --- Benchmark-only knobs -----------------------------------------------------
# Applied to every arm, the stock one included, so both run the same model at
# the same effort. Empty means "whatever config.toml says".
CODEXCUT_BENCH_MODEL="${CODEXCUT_BENCH_MODEL:-}"
CODEXCUT_BENCH_EFFORT="${CODEXCUT_BENCH_EFFORT:-low}"

codexcut_bench_pin() {
  [ -n "$CODEXCUT_BENCH_MODEL" ]  && printf '%s\n' -m "$CODEXCUT_BENCH_MODEL"
  [ -n "$CODEXCUT_BENCH_EFFORT" ] && printf '%s\n' -c "model_reasoning_effort=\"$CODEXCUT_BENCH_EFFORT\""
  return 0
}

codexcut_presets() {
  printf '%s\n' sh skills min default
}

# One `-c mcp_servers.<name>.enabled=false` per MCP server in config.toml.
# There is no flag that ignores them all, so the names are read from the file.
codexcut_mcp_off() {
  local cfg="$CODEXCUT_CODEX_HOME/config.toml" name
  [ -f "$cfg" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] && printf '%s\n' -c "mcp_servers.$name.enabled=false"
  done < <(sed -n 's/^\[mcp_servers\.\([A-Za-z0-9_-]*\)\].*/\1/p' "$cfg" | sort -u)
  return 0
}

codexcut_preset_flags() {
  local preset="$1"

  # Shared by every cut preset. "default" opts out below.
  local -a common=(
    -c "model_instructions_file=\"$CODEXCUT_PROMPT_FILE\""
    -c agents.enabled=false
    -c include_collaboration_mode_instructions=false
    -c tools.experimental_request_user_input.enabled=false
    --disable default_mode_request_user_input
    --disable plugins
    --disable apps
    --disable view_image
    --disable image_generation
    --disable tool_suggest
    --disable skill_search
    --disable sleep_tool
    --disable goals
  )
  [ -n "$CODEXCUT_AUTOCOMPACT" ] && common+=(-c "model_auto_compact_token_limit=$CODEXCUT_AUTOCOMPACT")
  [ -n "$CODEXCUT_EFFORT" ]      && common+=(-c "model_reasoning_effort=\"$CODEXCUT_EFFORT\"")

  local -a no_web=(-c 'web_search="disabled"')
  local -a no_skills=(-c skills.include_instructions=false)

  case "$preset" in
    # Shell, apply_patch and web search. Web search is not touched, so it
    # follows your own config.toml. MCP servers are off.
    sh)      printf '%s\n' "${common[@]}" "${no_skills[@]}"; codexcut_mcp_off ;;

    # sh plus your skills list.
    skills)  printf '%s\n' "${common[@]}"; codexcut_mcp_off ;;

    # The floor: shell and apply_patch only. No web search.
    min)     printf '%s\n' "${common[@]}" "${no_web[@]}" "${no_skills[@]}"; codexcut_mcp_off ;;

    # Stock Codex. The baseline you are measuring against.
    default) : ;;

    *) printf 'codexcut: unknown preset: %s\n' "$preset" >&2; return 1 ;;
  esac
}
