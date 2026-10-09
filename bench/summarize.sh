#!/usr/bin/env bash
# Turn a bench run's rows.jsonl into a markdown table, averaged over repeats.
#
#   bench/summarize.sh bench/results/20261009-120000

set -euo pipefail
dir="${1:?usage: summarize.sh <results-dir>}"
rows="$dir/rows.jsonl"
[ -f "$rows" ] || { echo "summarize: no rows.jsonl in $dir" >&2; exit 2; }

# "input" is the prompt summed over every model request, cached part included.
echo "| task | preset | runs | ok | input | cached | out | items | wall s |"
echo "|---|---|---:|---:|---:|---:|---:|---:|---:|"

jq -s -r '
  def avg(f): (map(f // 0) | add) / length;
  def r2(x): (x * 100 | round) / 100;
  group_by([.task, .preset])
  | sort_by(.[0].task, .[0].preset)
  | .[]
  | "| \(.[0].task) | \(.[0].preset) | \(length) | \(map(select(.ok)) | length) " +
    "| \(avg(.input) | round) | \(avg(.cached) | round) | \(avg(.output) | round) " +
    "| \(r2(avg(.turns))) | \(r2(avg(.wall_s))) |"
' "$rows"
