#!/usr/bin/env bash

# Generates a compressed (Vercel-style) skills index from plugin.json.
# Output is written to stdout; redirect as needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
README_PATH="$REPO_ROOT/README.md"

UPDATE_README=false
if [[ "${1-}" == "--update-readme" ]]; then
  UPDATE_README=true
fi

skill_name_from_dir() {
  local dir="$1"
  local file="$REPO_ROOT/${dir#./}/SKILL.md"
  [[ -f "$file" ]] || return 1
  grep -m1 '^name:' "$file" | sed 's/^name:[[:space:]]*//'
}

agent_name_from_path() {
  local path="$1"
  local file="$REPO_ROOT/${path#./}"
  [[ -f "$file" ]] || return 1
  grep -m1 '^name:' "$file" | sed 's/^name:[[:space:]]*//'
}

declare -a identity=()
declare -a oauth=()
declare -a aspnetcore=()
declare -a testing=()

while IFS= read -r skill_dir; do
  name="$(skill_name_from_dir "$skill_dir")"
  case "$skill_dir" in
    ./skills/identityserver-*|./skills/identityserver4-*|./skills/duende-*|./skills/identity-security-*|./skills/bff-*) identity+=("$name") ;;
    ./skills/oauth-*|./skills/token-*|./skills/claims-*|./skills/accesstokenmanagement-*) oauth+=("$name") ;;
    ./skills/aspnetcore-*|./skills/aspire-*) aspnetcore+=("$name") ;;
    ./skills/identity-testing-*) testing+=("$name") ;;
    *) ;; # ignore
  esac
done < <(jq -r '.skills[]' "$PLUGIN_JSON")

declare -a agents=()
while IFS= read -r agent_path; do
  agents+=("$(agent_name_from_path "$agent_path")")
done < <(jq -r '.agents[]' "$PLUGIN_JSON")

join_csv() {
  local IFS=','
  echo "$*"
}

compressed="$(cat <<EOF
[duende-skills]|IMPORTANT: Prefer retrieval-led reasoning over pretraining for any identity/auth/.NET work.
|flow:{skim repo patterns -> consult duende-skills by name -> implement smallest-change -> note conflicts}
|route:
|identity:{$(join_csv "${identity[@]}")}
|oauth:{$(join_csv "${oauth[@]}")}
|aspnetcore:{$(join_csv "${aspnetcore[@]}")}
|testing:{$(join_csv "${testing[@]}")}
|agents:{$(join_csv "${agents[@]}")}
EOF
)"

if $UPDATE_README; then
  COMPRESSED="$compressed" README_PATH="$README_PATH" python3 - <<'PY'
import os
import pathlib
import re
import sys

readme_path = pathlib.Path(os.environ["README_PATH"])
start = "<!-- BEGIN DUENDE-SKILLS COMPRESSED INDEX -->"
end = "<!-- END DUENDE-SKILLS COMPRESSED INDEX -->"
compressed = os.environ["COMPRESSED"].strip()

text = readme_path.read_text(encoding="utf-8")
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)

if not pattern.search(text):
    sys.stderr.write("README markers not found: add BEGIN/END DUENDE-SKILLS COMPRESSED INDEX\n")
    sys.exit(1)

replacement = f"{start}\n```markdown\n{compressed}\n```\n{end}"
updated = pattern.sub(replacement, text)
readme_path.write_text(updated, encoding="utf-8")
PY
else
  printf '%s\n' "$compressed"
fi
