#!/usr/bin/env bash
set -euo pipefail

# normalize-benchmarks.sh — Normalize all benchmark.json files to a canonical format.
#
# Usage:
#   ./scripts/normalize-benchmarks.sh [--dry-run] [--verbose]
#
# The canonical format:
# {
#   "metadata": { "skill_name", "iteration", "model", "date" },
#   "summary": {
#     "with_skill": { "total_assertions", "passed", "failed", "pass_rate" },
#     "without_skill": { "total_assertions", "passed", "failed", "pass_rate" },
#     "delta": { "assertions_improved", "delta_pass_rate" }
#   },
#   "evals": [
#     {
#       "eval_id": <int>,
#       "prompt_summary": <string>,
#       "with_skill": { "passed", "failed", "total", "pass_rate" },
#       "without_skill": { "passed", "failed", "total", "pass_rate" },
#       "delta": <float>,
#       "without_skill_failures": [<string>]  // optional
#     }
#   ],
#   "analysis": { ... }  // preserved if present in original
# }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
  esac
done

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

normalize_count=0
skip_count=0
error_count=0

for benchmark_file in "$REPO_ROOT"/tests/*/workspace/iteration-*/benchmark.json; do
  if [ ! -f "$benchmark_file" ]; then
    continue
  fi

  # Extract skill name from path: tests/<skill_name>/workspace/...
  skill_dir="${benchmark_file#$REPO_ROOT/tests/}"
  skill_name="${skill_dir%%/*}"
  iteration_dir="${benchmark_file%/benchmark.json}"
  iteration="${iteration_dir##*iteration-}"

  if $VERBOSE; then
    echo "Processing: $skill_name (iteration $iteration)"
  fi

  # Read the original file
  original=$(cat "$benchmark_file")

  # Normalize using jq — handle all known format variants
  normalized=$(jq --arg skill "$skill_name" --argjson iter "$iteration" '
    # Helper: extract passed count from various field names
    def get_passed: (.passed // .pass // .pass_count // .total_pass // .score // 0);
    # Helper: extract failed count from various field names
    def get_failed: (.failed // .fail // (if .max_score then (.max_score - (.score // 0)) else 0 end));
    # Helper: extract total count from various field names
    def get_total: (.total // .total_count // .total_assertions // .max_score // .assertions_count // (get_passed + get_failed));
    # Helper: compute pass_rate as decimal
    def get_pass_rate:
      if .pass_rate then
        if (.pass_rate | type) == "string" then
          (.pass_rate | gsub("%"; "") | tonumber / 100)
        elif (.pass_rate | . > 1) then
          (.pass_rate / 100)
        else
          .pass_rate
        end
      elif (.score and .max_score) then
        (if .max_score > 0 then (.score / .max_score) else 0 end)
      elif .score then .score
      elif .score_pct then (.score_pct / 100)
      else
        (get_total as $t | if $t > 0 then (get_passed / $t) else 0 end)
      end;

    # Extract metadata
    (
      (.skill_name // .skill // $skill) as $sn |
      (.iteration // $iter) as $it |
      (.model // "claude-opus-4.6") as $model |
      (
        if .date then .date
        elif .timestamp then (.timestamp | split("T")[0])
        else "2026-03-19"
        end
      ) as $date |

      # Extract evals array from various container names
      (
        if (.evals | type) == "array" then .evals
        elif (.eval_details | type) == "array" then .eval_details
        elif (.results | type) == "array" then .results
        elif .per_eval then
          [.per_eval | to_entries[] | {
            eval_id: .key,
            with_skill: .value.with_skill,
            without_skill: .value.without_skill,
            delta: .value.delta_pass_rate
          }]
        else []
        end
      ) as $raw_evals |

      # Normalize each eval entry
      ($raw_evals | to_entries | map(
        .value as $e | .key as $idx |
        # Determine the total assertions for this eval from outer context
        ($e.assertions_count // $e.total_assertions // null) as $outer_total |
        {
          eval_id: ($e.eval_id // $e.id // ($idx + 1)),
          prompt_summary: ($e.prompt_summary // null),
          with_skill: (
            ($e.with_skill | get_passed) as $p |
            ($e.with_skill | get_failed) as $f |
            (($e.with_skill | .total // .total_count // .total_assertions // .max_score) // $outer_total // ($p + $f)) as $t |
            {
              passed: $p,
              failed: ($t - $p),
              total: $t,
              pass_rate: (if $t > 0 then ($p / $t) else 0 end)
            }
          ),
          without_skill: (
            ($e.without_skill | get_passed) as $p |
            ($e.without_skill | get_failed) as $f |
            (($e.without_skill | .total // .total_count // .total_assertions // .max_score) // $outer_total // ($p + $f)) as $t |
            {
              passed: $p,
              failed: ($t - $p),
              total: $t,
              pass_rate: (if $t > 0 then ($p / $t) else 0 end)
            }
          ),
          delta: (
            ($e.assertions_count // $e.total_assertions // null) as $eval_total |
            ($e.with_skill | get_passed) as $ws_p |
            ($e.without_skill | get_passed) as $wos_p |
            (($e.with_skill | .total // .total_count // .total_assertions // .max_score) // $eval_total // ($ws_p + ($e.with_skill | get_failed))) as $ws_t |
            (($e.without_skill | .total // .total_count // .total_assertions // .max_score) // $eval_total // ($wos_p + ($e.without_skill | get_failed))) as $wos_t |
            (if $ws_t > 0 then ($ws_p / $ws_t) else 0 end) as $ws_rate |
            (if $wos_t > 0 then ($wos_p / $wos_t) else 0 end) as $wos_rate |
            ($ws_rate - $wos_rate)
          )
        } + (
          if $e.without_skill_failures then
            { without_skill_failures: $e.without_skill_failures }
          elif $e.missed_without_skill then
            { without_skill_failures: $e.missed_without_skill }
          else {}
          end
        )
      )) as $evals |

      # Compute summary from evals
      ([$evals[].with_skill.passed] | add // 0) as $ws_passed |
      ([$evals[].with_skill.total] | add // 0) as $ws_total |
      ([$evals[].without_skill.passed] | add // 0) as $wos_passed |
      ([$evals[].without_skill.total] | add // 0) as $wos_total |
      (if $ws_total > 0 then ($ws_passed / $ws_total) else 0 end) as $ws_rate |
      (if $wos_total > 0 then ($wos_passed / $wos_total) else 0 end) as $wos_rate |

      {
        metadata: {
          skill_name: $sn,
          iteration: $it,
          model: $model,
          date: $date
        },
        summary: {
          with_skill: {
            total_assertions: $ws_total,
            passed: $ws_passed,
            failed: ($ws_total - $ws_passed),
            pass_rate: ($ws_rate * 100 | round / 100)
          },
          without_skill: {
            total_assertions: $wos_total,
            passed: $wos_passed,
            failed: ($wos_total - $wos_passed),
            pass_rate: ($wos_rate * 100 | round / 100)
          },
          delta: {
            assertions_improved: ($ws_passed - $wos_passed),
            delta_pass_rate: (($ws_rate - $wos_rate) * 100 | round / 100)
          }
        },
        evals: $evals
      } + (
        # Preserve analysis section if it exists in the original
        if .analysis then { analysis: .analysis } else {} end
      )
    )
  ' <<< "$original" 2>/dev/null) || {
    echo "  ERROR: Failed to normalize $skill_name" >&2
    error_count=$((error_count + 1))
    continue
  }

  # Check if already in canonical format (metadata key exists and structure matches)
  is_canonical=$(echo "$original" | jq 'has("metadata") and (.metadata | has("skill_name") and has("iteration") and has("model") and has("date")) and has("summary") and (.summary | has("with_skill") and has("without_skill") and has("delta"))' 2>/dev/null || echo "false")

  if [ "$is_canonical" = "true" ]; then
    if $VERBOSE; then
      echo "  SKIP: Already canonical"
    fi
    skip_count=$((skip_count + 1))
    continue
  fi

  if $DRY_RUN; then
    echo "WOULD NORMALIZE: $benchmark_file"
    if $VERBOSE; then
      echo "$normalized" | jq '.metadata'
      echo "  Evals: $(echo "$normalized" | jq '.evals | length')"
      echo "  Summary delta: $(echo "$normalized" | jq '.summary.delta.delta_pass_rate')"
    fi
  else
    # Back up original
    cp "$benchmark_file" "${benchmark_file}.bak"
    # Write normalized
    echo "$normalized" | jq '.' > "$benchmark_file"
    if $VERBOSE; then
      echo "  NORMALIZED (backup: ${benchmark_file}.bak)"
    fi
  fi
  normalize_count=$((normalize_count + 1))
done

echo ""
echo "=== Benchmark Normalization Summary ==="
echo "Normalized: $normalize_count"
echo "Skipped (already canonical): $skip_count"
echo "Errors: $error_count"
if $DRY_RUN; then
  echo "(DRY RUN — no files were modified)"
fi
