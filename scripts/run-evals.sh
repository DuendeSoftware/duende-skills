#!/usr/bin/env bash
set -euo pipefail

# run-evals.sh — Run skill evals via GitHub Models API and grade results.
#
# Usage:
#   ./scripts/run-evals.sh [OPTIONS]
#
# Options:
#   --skill <name>       Run evals for a single skill (default: all skills)
#   --eval-id <N>        Run a single eval by ID within the selected skill(s)
#   --iteration <N>      Iteration number (default: auto-detect next)
#   --model <model>      Model ID for GitHub Models API (default: openai/gpt-4o)
#   --grader-model <m>   Model for grading (default: same as --model)
#   --max-tokens <N>     Max tokens for response generation (default: 4096)
#   --force              Re-run even if outputs already exist
#   --skip-grading       Generate responses only, skip grading
#   --grade-only         Grade existing responses without re-generating
#   --dry-run            Show what would be run without executing
#   --verbose            Print detailed progress
#   --delay <seconds>     Delay between API calls to avoid rate limits (default: 2)
#   --help               Show this help message
#
# Authentication:
#   Uses GitHub token from `gh auth token` (requires `gh` CLI authenticated).
#   Override with GITHUB_TOKEN environment variable.
#
# Model selection (GitHub Models API):
#   OpenAI:     openai/gpt-4o, openai/gpt-4o-mini, gpt-4o, gpt-4o-mini
#   Anthropic:  anthropic/claude-sonnet-4, anthropic/claude-opus-4.6 (if available)
#   Meta:       Meta-Llama-3.1-405B-Instruct, Meta-Llama-3.1-70B-Instruct
#
#   Run with --dry-run to verify model access before a full run.
#   Claude models may require GitHub Copilot Enterprise or specific plan access.
#
# Examples:
#   ./scripts/run-evals.sh --skill duende-bff --iteration 2
#   ./scripts/run-evals.sh --model openai/gpt-4o --verbose
#   ./scripts/run-evals.sh --model openai/gpt-4o --delay 5 --verbose
#   ./scripts/run-evals.sh --model anthropic/claude-sonnet-4 --verbose
#   ./scripts/run-evals.sh --dry-run --verbose
#   ./scripts/run-evals.sh --grade-only --iteration 1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
SKILLS_DIR="$REPO_ROOT/skills"
API_URL="https://models.github.ai/inference/chat/completions"

# Defaults
SKILL_FILTER=""
EVAL_ID_FILTER=""
ITERATION=""
MODEL="openai/gpt-4o"
GRADER_MODEL=""
MAX_TOKENS=4096
FORCE=false
SKIP_GRADING=false
GRADE_ONLY=false
DRY_RUN=false
VERBOSE=false
DELAY=10

# Counters
total_evals=0
completed_evals=0
skipped_evals=0
error_count=0
start_time=$(date +%s)

# ─── Argument Parsing ────────────────────────────────────────────────────────

show_help() {
  sed -n '/^# /{ s/^# //; s/^#$//; p }' "$0" | head -40
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)        SKILL_FILTER="$2"; shift 2 ;;
    --eval-id)      EVAL_ID_FILTER="$2"; shift 2 ;;
    --iteration)    ITERATION="$2"; shift 2 ;;
    --model)        MODEL="$2"; shift 2 ;;
    --grader-model) GRADER_MODEL="$2"; shift 2 ;;
    --max-tokens)   MAX_TOKENS="$2"; shift 2 ;;
    --force)        FORCE=true; shift ;;
    --skip-grading) SKIP_GRADING=true; shift ;;
    --grade-only)   GRADE_ONLY=true; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --verbose)      VERBOSE=true; shift ;;
    --delay)        DELAY="$2"; shift 2 ;;
    --help)         show_help ;;
    *)              echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ─── Prerequisites ───────────────────────────────────────────────────────────

# Default grader model to same as generation model if not specified
if [ -z "$GRADER_MODEL" ]; then
  GRADER_MODEL="$MODEL"
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI is required. Install from: https://cli.github.com" >&2
  exit 1
fi

# Resolve GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
  GITHUB_TOKEN=$(gh auth token 2>/dev/null) || {
    echo "Error: Not authenticated. Run 'gh auth login' first." >&2
    exit 1
  }
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Could not obtain GitHub token. Run 'gh auth login' or set GITHUB_TOKEN." >&2
  exit 1
fi

# ─── Logging ─────────────────────────────────────────────────────────────────

log() { echo "[$1] $2"; }
log_verbose() { $VERBOSE && echo "  $1" || true; }
log_error() { echo "  ERROR: $1" >&2; }

# Throttle between API calls
throttle() {
  if [ "$DELAY" -gt 0 ] 2>/dev/null; then
    log_verbose "Throttling ${DELAY}s between API calls..."
    sleep "$DELAY"
  fi
}

# ─── API Helpers ─────────────────────────────────────────────────────────────

# Call GitHub Models API (OpenAI-compatible chat completions) with retry logic.
# Args: $1=system_prompt, $2=user_message, $3=model, $4=max_tokens
# Outputs: response text to stdout. Returns non-zero on failure.
call_llm() {
  local system_prompt="$1"
  local user_message="$2"
  local model="$3"
  local max_tokens="$4"
  local attempt=0
  local max_retries=3
  local backoff=15
  local last_http_code=""

  # Build request JSON using jq to properly escape all strings
  local request_body
  request_body=$(jq -n \
    --arg model "$model" \
    --argjson max_tokens "$max_tokens" \
    --arg system "$system_prompt" \
    --arg user "$user_message" \
    '{
      model: $model,
      max_tokens: $max_tokens,
      messages: [
        { role: "system", content: $system },
        { role: "user", content: $user }
      ]
    }')

  while [ $attempt -lt $max_retries ]; do
    attempt=$((attempt + 1))

    local tmp_file
    tmp_file=$(mktemp)

    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$tmp_file" \
      -L -X POST "$API_URL" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      -d "$request_body" \
      --max-time 180)

    local response
    response=$(cat "$tmp_file")
    rm -f "$tmp_file"

    # Check for success
    if [ "$http_code" = "200" ]; then
      local text
      text=$(echo "$response" | jq -r '.choices[0].message.content // empty')
      if [ -n "$text" ]; then
        echo "$text"
        return 0
      fi
      log_error "Empty response body (attempt $attempt/$max_retries)"
    elif [ "$http_code" = "429" ] || [ "$http_code" = "529" ] || [ "$http_code" = "500" ] || [ "$http_code" = "503" ]; then
      # Rate limit, overloaded, or server error — retry with backoff
      last_http_code="$http_code"
      log_verbose "API returned $http_code, retrying in ${backoff}s (attempt $attempt/$max_retries)"
      sleep $backoff
      backoff=$((backoff * 2))
    else
      log_error "API returned HTTP $http_code: $(echo "$response" | jq -r '.error.message // .error // .message // "unknown"' 2>/dev/null)"
      return 1
    fi
  done

  log_error "All $max_retries retries exhausted (last HTTP $last_http_code)"
  return 1
}

# ─── Grading ─────────────────────────────────────────────────────────────────

GRADING_SYSTEM_PROMPT='You are an expert grader evaluating LLM responses against specific assertions.

You will receive:
1. The original prompt that was given to the LLM
2. The LLM response to evaluate
3. A list of assertions to check

For each assertion, determine if the response satisfies it (pass) or not (fail).
Be strict but fair: the response must clearly demonstrate the assertion, not just vaguely hint at it.
For code assertions, check that the actual code pattern is present, not just mentioned in prose.

You MUST respond with ONLY valid JSON in this exact format, no other text:
{
  "assertions": [
    {
      "assertion": "exact assertion text",
      "pass": true,
      "rationale": "brief explanation of why it passed or failed"
    }
  ]
}

Important:
- Return ALL assertions, in the same order they were provided
- "pass" must be a boolean (true or false)
- "rationale" should be 1-2 sentences
- Do NOT include any text outside the JSON object'

# Grade a response against assertions.
# Args: $1=prompt, $2=response_text, $3=assertions_json_array
# Outputs: grading JSON to stdout
grade_response() {
  local prompt="$1"
  local response_text="$2"
  local assertions_json="$3"

  local user_message
  user_message=$(jq -n \
    --arg prompt "$prompt" \
    --arg response "$response_text" \
    --argjson assertions "$assertions_json" \
    '"## Original Prompt\n\n" + $prompt + "\n\n## LLM Response\n\n" + $response + "\n\n## Assertions to Check\n\n" + ($assertions | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n"))')

  # Remove the outer quotes jq adds to strings
  user_message=$(echo "$user_message" | jq -r '.')

  local grading_output
  grading_output=$(call_llm "$GRADING_SYSTEM_PROMPT" "$user_message" "$GRADER_MODEL" 2048) || return 1

  # Extract JSON from the response (handle potential markdown code blocks)
  local json_output
  json_output=$(echo "$grading_output" | sed -n '/^{/,/^}/p')
  if [ -z "$json_output" ]; then
    # Try extracting from code block
    json_output=$(echo "$grading_output" | sed -n '/```json/,/```/{ /```/d; p; }')
  fi
  if [ -z "$json_output" ]; then
    json_output="$grading_output"
  fi

  # Validate it's valid JSON with assertions array
  if echo "$json_output" | jq -e '.assertions | length > 0' &>/dev/null; then
    echo "$json_output"
    return 0
  fi

  log_error "Grader returned invalid JSON"
  log_verbose "Raw grader output: $grading_output"
  return 1
}

# ─── Benchmark Generation ────────────────────────────────────────────────────

# Generate benchmark.json from all grading.json files in a workspace iteration dir.
# Args: $1=workspace_dir (e.g., tests/duende-bff/workspace/iteration-2)
#        $2=skill_name, $3=iteration
generate_benchmark() {
  local workspace_dir="$1"
  local skill_name="$2"
  local iteration="$3"
  local today
  today=$(date +%Y-%m-%d)

  # Collect all grading results
  local evals_json="[]"
  for eval_dir in "$workspace_dir"/eval-*/; do
    [ -d "$eval_dir" ] || continue
    local eval_id
    eval_id=$(basename "$eval_dir" | sed 's/eval-//')

    local ws_grading="$eval_dir/with_skill/outputs/grading.json"
    local wos_grading="$eval_dir/without_skill/outputs/grading.json"

    # Skip if grading files don't exist
    [ -f "$ws_grading" ] && [ -f "$wos_grading" ] || continue

    local eval_entry
    eval_entry=$(jq -n \
      --argjson eval_id "$eval_id" \
      --slurpfile ws "$ws_grading" \
      --slurpfile wos "$wos_grading" \
      '{
        eval_id: $eval_id,
        prompt_summary: null,
        with_skill: {
          passed: ($ws[0].assertions | map(select(.pass == true)) | length),
          failed: ($ws[0].assertions | map(select(.pass != true)) | length),
          total: ($ws[0].assertions | length),
          pass_rate: (($ws[0].assertions | map(select(.pass == true)) | length) as $p |
                      ($ws[0].assertions | length) as $t |
                      if $t > 0 then ($p / $t) else 0 end)
        },
        without_skill: {
          passed: ($wos[0].assertions | map(select(.pass == true)) | length),
          failed: ($wos[0].assertions | map(select(.pass != true)) | length),
          total: ($wos[0].assertions | length),
          pass_rate: (($wos[0].assertions | map(select(.pass == true)) | length) as $p |
                      ($wos[0].assertions | length) as $t |
                      if $t > 0 then ($p / $t) else 0 end)
        },
        delta: (
          (($ws[0].assertions | map(select(.pass == true)) | length) as $ws_p |
           ($ws[0].assertions | length) as $ws_t |
           ($wos[0].assertions | map(select(.pass == true)) | length) as $wos_p |
           ($wos[0].assertions | length) as $wos_t |
           (if $ws_t > 0 then ($ws_p / $ws_t) else 0 end) -
           (if $wos_t > 0 then ($wos_p / $wos_t) else 0 end))
        ),
        without_skill_failures: [
          $wos[0].assertions[] | select(.pass != true) | .assertion
        ]
      }')

    evals_json=$(echo "$evals_json" | jq --argjson entry "$eval_entry" '. + [$entry]')
  done

  # Generate full benchmark
  echo "$evals_json" | jq \
    --arg skill "$skill_name" \
    --argjson iter "$iteration" \
    --arg model "$MODEL" \
    --arg date "$today" \
    '{
      metadata: {
        skill_name: $skill,
        iteration: $iter,
        model: $model,
        date: $date
      },
      summary: {
        with_skill: {
          total_assertions: ([.[].with_skill.total] | add // 0),
          passed: ([.[].with_skill.passed] | add // 0),
          failed: ([.[].with_skill.failed] | add // 0),
          pass_rate: (([.[].with_skill.passed] | add // 0) as $p |
                      ([.[].with_skill.total] | add // 0) as $t |
                      if $t > 0 then (($p / $t) * 100 | round / 100) else 0 end)
        },
        without_skill: {
          total_assertions: ([.[].without_skill.total] | add // 0),
          passed: ([.[].without_skill.passed] | add // 0),
          failed: ([.[].without_skill.failed] | add // 0),
          pass_rate: (([.[].without_skill.passed] | add // 0) as $p |
                      ([.[].without_skill.total] | add // 0) as $t |
                      if $t > 0 then (($p / $t) * 100 | round / 100) else 0 end)
        },
        delta: {
          assertions_improved: (([.[].with_skill.passed] | add // 0) - ([.[].without_skill.passed] | add // 0)),
          delta_pass_rate: (
            (([.[].with_skill.passed] | add // 0) as $ws_p |
             ([.[].with_skill.total] | add // 0) as $ws_t |
             ([.[].without_skill.passed] | add // 0) as $wos_p |
             ([.[].without_skill.total] | add // 0) as $wos_t |
             (if $ws_t > 0 then ($ws_p / $ws_t) else 0 end) -
             (if $wos_t > 0 then ($wos_p / $wos_t) else 0 end)) * 100 | round / 100
          )
        }
      },
      evals: .
    }'
}

# ─── Main Loop ───────────────────────────────────────────────────────────────

# Build list of skills to process
if [ -n "$SKILL_FILTER" ]; then
  if [ ! -d "$TESTS_DIR/$SKILL_FILTER" ]; then
    echo "Error: Skill '$SKILL_FILTER' not found in tests/" >&2
    exit 1
  fi
  skill_list=("$SKILL_FILTER")
else
  skill_list=()
  for d in "$TESTS_DIR"/*/; do
    [ -f "$d/evals.json" ] && skill_list+=("$(basename "$d")")
  done
fi

log "run-evals" "Processing ${#skill_list[@]} skill(s) with model=$MODEL"
if $DRY_RUN; then
  log "run-evals" "(DRY RUN — no API calls will be made)"
fi
echo ""

for skill_name in "${skill_list[@]}"; do
  skill_test_dir="$TESTS_DIR/$skill_name"
  skill_md="$SKILLS_DIR/$skill_name/SKILL.md"
  evals_file="$skill_test_dir/evals.json"

  if [ ! -f "$evals_file" ]; then
    log_error "No evals.json for $skill_name, skipping"
    continue
  fi

  # Determine iteration number
  if [ -n "$ITERATION" ]; then
    iter="$ITERATION"
  else
    # Auto-detect: find highest existing iteration and add 1
    iter=1
    for existing in "$skill_test_dir"/workspace/iteration-*/; do
      [ -d "$existing" ] || continue
      existing_num="${existing%/}"
      existing_num="${existing_num##*iteration-}"
      if [ "$existing_num" -ge "$iter" ]; then
        iter=$((existing_num + 1))
      fi
    done
  fi

  workspace_dir="$skill_test_dir/workspace/iteration-$iter"

  # Read SKILL.md content for with_skill variant
  local_skill_content=""
  if [ -f "$skill_md" ]; then
    local_skill_content=$(cat "$skill_md")
  else
    log_error "No SKILL.md for $skill_name at $skill_md"
    continue
  fi

  # Parse evals
  eval_count=$(jq '.evals | length' "$evals_file")
  log "$skill_name" "Running $eval_count evals (iteration $iter)"

  for idx in $(seq 0 $((eval_count - 1))); do
    eval_id=$(jq -r ".evals[$idx].id" "$evals_file")

    # Filter by eval ID if specified
    if [ -n "$EVAL_ID_FILTER" ] && [ "$eval_id" != "$EVAL_ID_FILTER" ]; then
      continue
    fi

    total_evals=$((total_evals + 1))
    eval_prompt=$(jq -r ".evals[$idx].prompt" "$evals_file")
    eval_assertions=$(jq ".evals[$idx].assertions" "$evals_file")
    eval_assertions_count=$(echo "$eval_assertions" | jq 'length')

    # Build user message with reference files
    user_message="$eval_prompt"
    file_count=$(jq -r ".evals[$idx].files | length" "$evals_file")
    if [ "$file_count" -gt 0 ]; then
      for fi in $(seq 0 $((file_count - 1))); do
        rel_path=$(jq -r ".evals[$idx].files[$fi]" "$evals_file")
        full_path="$skill_test_dir/$rel_path"
        if [ -f "$full_path" ]; then
          file_content=$(cat "$full_path")
          user_message="$user_message

---
File: $rel_path
\`\`\`
$file_content
\`\`\`"
        else
          log_verbose "Reference file not found: $full_path"
        fi
      done
    fi

    # Set up output directories
    ws_out="$workspace_dir/eval-$eval_id/with_skill/outputs"
    wos_out="$workspace_dir/eval-$eval_id/without_skill/outputs"

    if $DRY_RUN; then
      log "  eval-$eval_id" "$eval_assertions_count assertions — would run with_skill + without_skill"
      completed_evals=$((completed_evals + 1))
      continue
    fi

    mkdir -p "$ws_out" "$wos_out"

    # ─── WITH SKILL variant ──────────────────────────────────────────
    if ! $GRADE_ONLY; then
      if [ -f "$ws_out/response.md" ] && ! $FORCE; then
        log_verbose "eval-$eval_id with_skill: response exists, skipping"
      else
        log_verbose "eval-$eval_id with_skill: generating response..."
        system_prompt="You are an expert .NET and identity/security developer. Use the following skill reference to inform your response.

$local_skill_content"

        throttle
        if ws_response=$(call_llm "$system_prompt" "$user_message" "$MODEL" "$MAX_TOKENS"); then
          echo "$ws_response" > "$ws_out/response.md"
          log_verbose "eval-$eval_id with_skill: response saved"
        else
          log_error "eval-$eval_id with_skill: API call failed"
          error_count=$((error_count + 1))
        fi
      fi

      # ─── WITHOUT SKILL variant ────────────────────────────────────
      if [ -f "$wos_out/response.md" ] && ! $FORCE; then
        log_verbose "eval-$eval_id without_skill: response exists, skipping"
      else
        log_verbose "eval-$eval_id without_skill: generating response..."
        system_prompt="You are a helpful assistant with expertise in software development."

        throttle
        if wos_response=$(call_llm "$system_prompt" "$user_message" "$MODEL" "$MAX_TOKENS"); then
          echo "$wos_response" > "$wos_out/response.md"
          log_verbose "eval-$eval_id without_skill: response saved"
        else
          log_error "eval-$eval_id without_skill: API call failed"
          error_count=$((error_count + 1))
        fi
      fi
    fi

    # ─── GRADING ─────────────────────────────────────────────────────
    if ! $SKIP_GRADING; then
      for variant in with_skill without_skill; do
        out_dir="$workspace_dir/eval-$eval_id/$variant/outputs"
        response_file="$out_dir/response.md"
        grading_file="$out_dir/grading.json"

        if [ -f "$grading_file" ] && ! $FORCE; then
          log_verbose "eval-$eval_id $variant: grading exists, skipping"
          continue
        fi

        if [ ! -f "$response_file" ]; then
          log_verbose "eval-$eval_id $variant: no response.md, skipping grading"
          continue
        fi

        log_verbose "eval-$eval_id $variant: grading..."
        response_text=$(cat "$response_file")

        throttle
        if grading_json=$(grade_response "$eval_prompt" "$response_text" "$eval_assertions"); then
          # Enrich with metadata
          enriched=$(echo "$grading_json" | jq \
            --argjson eval_id "$eval_id" \
            --arg variant "$variant" \
            '{
              eval_id: $eval_id,
              variant: $variant,
              assertions: .assertions,
              pass_count: ([.assertions[] | select(.pass == true)] | length),
              total_count: (.assertions | length),
              score: (([.assertions[] | select(.pass == true)] | length) as $p |
                      (.assertions | length) as $t |
                      if $t > 0 then ($p / $t) else 0 end)
            }')
          echo "$enriched" | jq '.' > "$grading_file"

          pass_count=$(echo "$enriched" | jq '.pass_count')
          total_count=$(echo "$enriched" | jq '.total_count')
          log_verbose "eval-$eval_id $variant: $pass_count/$total_count passed"
        else
          log_error "eval-$eval_id $variant: grading failed"
          error_count=$((error_count + 1))
        fi
      done
    fi

    completed_evals=$((completed_evals + 1))

    # Print progress
    ws_score="?"
    wos_score="?"
    if [ -f "$ws_out/grading.json" ]; then
      ws_score=$(jq -r '"\(.pass_count)/\(.total_count)"' "$ws_out/grading.json" 2>/dev/null || echo "?")
    fi
    if [ -f "$wos_out/grading.json" ]; then
      wos_score=$(jq -r '"\(.pass_count)/\(.total_count)"' "$wos_out/grading.json" 2>/dev/null || echo "?")
    fi
    log "  eval-$eval_id" "with=$ws_score  without=$wos_score"
  done

  # ─── Generate benchmark.json ─────────────────────────────────────────
  if ! $DRY_RUN && ! $SKIP_GRADING && [ -d "$workspace_dir" ]; then
    log "$skill_name" "Generating benchmark.json..."
    benchmark_json=$(generate_benchmark "$workspace_dir" "$skill_name" "$iter")
    echo "$benchmark_json" | jq '.' > "$workspace_dir/benchmark.json"

    # Print summary
    delta=$(echo "$benchmark_json" | jq '.summary.delta.delta_pass_rate')
    ws_total=$(echo "$benchmark_json" | jq '.summary.with_skill.passed')
    ws_max=$(echo "$benchmark_json" | jq '.summary.with_skill.total_assertions')
    wos_total=$(echo "$benchmark_json" | jq '.summary.without_skill.passed')
    log "$skill_name" "Done: with=$ws_total/$ws_max  without=$wos_total/$ws_max  delta=${delta}"
  fi

  echo ""
done

# ─── Final Summary ───────────────────────────────────────────────────────────

end_time=$(date +%s)
elapsed=$((end_time - start_time))
elapsed_min=$((elapsed / 60))
elapsed_sec=$((elapsed % 60))

echo "═══════════════════════════════════════════"
echo "  Eval Run Summary"
echo "═══════════════════════════════════════════"
echo "  Skills:    ${#skill_list[@]}"
echo "  Evals:     $completed_evals completed, $skipped_evals skipped, $error_count errors"
echo "  Model:     $MODEL"
echo "  Grader:    $GRADER_MODEL"
echo "  Delay:     ${DELAY}s between API calls"
echo "  Duration:  ${elapsed_min}m ${elapsed_sec}s"
if $DRY_RUN; then
  echo "  (DRY RUN — no API calls were made)"
fi
echo "═══════════════════════════════════════════"
