#!/usr/bin/env bash
# codexcut bench - run one task under several presets and compare the tokens.
#
#   bench/run.sh                                  every preset, every task
#   bench/run.sh --presets sh,default             pick presets
#   bench/run.sh --tasks hello                    pick tasks (bench/tasks/*.md)
#   bench/run.sh --repeat 3                       repeat each cell
#   bench/run.sh --dir ~/projects/some-repo       run against a real codebase
#
# Every run is a real `codex exec` call and spends real quota. Start with the
# `hello` task to see what a run costs before pointing this at anything larger.
#
# What it measures: wall time, turns, and the tokens Codex itself reports.
# Codex prints no dollar cost, so there is none here. What it does NOT measure:
# whether the answer was any good. Read
# bench/results/<stamp>/<task>.<preset>.<n>.txt and judge that yourself.
#
# Runs are ephemeral (no session file is saved) and use your own sandbox and
# approval settings.

set -euo pipefail

CODEXCUT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export CODEXCUT_ROOT
# shellcheck source=../lib/presets.sh
. "$CODEXCUT_ROOT/lib/presets.sh"

presets=""
tasks=""
repeat=1
workdir="$PWD"

while [ $# -gt 0 ]; do
  case "$1" in
    --presets) presets="${2:?}"; shift 2 ;;
    --tasks)   tasks="${2:?}"; shift 2 ;;
    --repeat)  repeat="${2:?}"; shift 2 ;;
    --dir)     workdir="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "bench: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$presets" ] || presets="$(codexcut_presets | paste -sd, -)"
if [ -z "$tasks" ]; then
  tasks="$(find "$CODEXCUT_ROOT/bench/tasks" -name '*.md' -exec basename {} .md \; | sort | paste -sd, -)"
fi

command -v jq >/dev/null || { echo "bench: jq is required" >&2; exit 127; }

stamp="$(date +%Y%m%d-%H%M%S)"
outdir="$CODEXCUT_ROOT/bench/results/$stamp"
mkdir -p "$outdir"

codex_bin="${CODEXCUT_CODEX_BIN:-$(command -v codex)}"
[ -n "$codex_bin" ] || { echo "bench: codex not found in PATH" >&2; exit 127; }

echo "bench: $stamp"
echo "bench: workdir  $workdir"
echo "bench: presets  $presets"
echo "bench: tasks    $tasks"
echo "bench: repeat   $repeat"
echo

IFS=',' read -r -a task_list <<< "$tasks"
IFS=',' read -r -a preset_list <<< "$presets"

for task in "${task_list[@]}"; do
  task_file="$CODEXCUT_ROOT/bench/tasks/$task.md"
  [ -f "$task_file" ] || { echo "bench: no such task: $task" >&2; exit 2; }
  prompt="$(cat "$task_file")"

  for preset in "${preset_list[@]}"; do
    # No mapfile: macOS still ships bash 3.2.
    flags=()
    while IFS= read -r flag; do
      [ -n "$flag" ] && flags+=("$flag")
    done < <(codexcut_preset_flags "$preset")
    # Pin model and effort for every arm, including the "default" one.
    while IFS= read -r flag; do
      flags+=("$flag")
    done < <(codexcut_bench_pin)

    for n in $(seq 1 "$repeat"); do
      label="$task.$preset.$n"
      printf 'bench: %-34s ' "$label"

      start=$(date +%s)
      set +e
      # stdin is closed on purpose: with a pipe there, `codex exec` waits for
      # more prompt text and never starts.
      ( cd "$workdir" && "$codex_bin" ${flags[@]+"${flags[@]}"} exec --json \
          --ephemeral --skip-git-repo-check "$prompt" </dev/null ) \
          > "$outdir/$label.jsonl" 2> "$outdir/$label.err"
      status=$?
      set -e
      end=$(date +%s)

      if [ $status -ne 0 ] || ! grep -q '"turn.completed"' "$outdir/$label.jsonl"; then
        echo "FAILED (exit $status, see $label.err)"
        jq -n --arg task "$task" --arg preset "$preset" --argjson n "$n" \
              --argjson wall "$((end - start))" \
          '{task:$task,preset:$preset,run:$n,ok:false,wall_s:$wall}' \
          >> "$outdir/rows.jsonl"
        continue
      fi

      # Keep the answer next to the numbers, so quality can be judged by hand.
      jq -r 'select(.type=="item.completed" and .item.type=="agent_message") | .item.text' \
        "$outdir/$label.jsonl" > "$outdir/$label.txt"

      # `input` is the prompt summed over every model request in the run, and
      # it already includes the cached part. `turns` counts those requests'
      # visible steps: tool calls plus messages.
      jq -s -c --arg task "$task" --arg preset "$preset" --argjson n "$n" \
         --argjson wall "$((end - start))" '
        (map(select(.type=="turn.completed") | .usage)) as $u
        | {task:$task, preset:$preset, run:$n, ok:true, wall_s:$wall,
           turns:(map(select(.type=="item.completed")) | length),
           input:($u | map(.input_tokens // 0) | add),
           cached:($u | map(.cached_input_tokens // 0) | add),
           output:($u | map(.output_tokens // 0) | add)}' \
        "$outdir/$label.jsonl" | tee -a "$outdir/rows.jsonl" \
        | jq -r '"\(.input) in  \(.cached) cached  \(.output) out  \(.turns) items  \(.wall_s)s"'
    done
  done
done

echo
"$CODEXCUT_ROOT/bench/summarize.sh" "$outdir" | tee "$outdir/summary.md"
echo
echo "bench: raw results in $outdir"
