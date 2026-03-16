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
declare -a csharp=()
declare -a data=()
declare -a di_config=()
declare -a testing=()
declare -a dotnet=()

while IFS= read -r skill_dir; do
  name="$(skill_name_from_dir "$skill_dir")"
  case "$skill_dir" in
    ./skills/identityserver-*|./skills/duende-*|./skills/identity-security-*) identity+=("$name") ;;
    ./skills/oauth-*|./skills/token-*|./skills/claims-*) oauth+=("$name") ;;
    ./skills/aspnetcore-*|./skills/aspire-*) aspnetcore+=("$name") ;;
    ./skills/csharp-*) csharp+=("$name") ;;
    ./skills/efcore-*|./skills/database-*) data+=("$name") ;;
    ./skills/microsoft-extensions-*) di_config+=("$name") ;;
    ./skills/identity-testing-*|./skills/playwright-*|./skills/snapshot-*|./skills/crap-analysis) testing+=("$name") ;;
    ./skills/project-structure|./skills/local-tools|./skills/package-management|./skills/dotnet-devcert-*) dotnet+=("$name") ;;
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
[identity-skills]|IMPORTANT: Prefer retrieval-led reasoning over pretraining for any identity/auth/.NET work.
|flow:{skim repo patterns -> consult identity-skills by name -> implement smallest-change -> note conflicts}
|route:
|identity:{$(join_csv "${identity[@]}")}
|oauth:{$(join_csv "${oauth[@]}")}
|aspnetcore:{$(join_csv "${aspnetcore[@]}")}
|csharp:{$(join_csv "${csharp[@]}")}
|data:{$(join_csv "${data[@]}")}
|di-config:{$(join_csv "${di_config[@]}")}
|testing:{$(join_csv "${testing[@]}")}
|dotnet:{$(join_csv "${dotnet[@]}")}
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
start = "<!-- BEGIN IDENTITY-SKILLS COMPRESSED INDEX -->"
end = "<!-- END IDENTITY-SKILLS COMPRESSED INDEX -->"
compressed = os.environ["COMPRESSED"].strip()

text = readme_path.read_text(encoding="utf-8")
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)

if not pattern.search(text):
    sys.stderr.write("README markers not found: add BEGIN/END IDENTITY-SKILLS COMPRESSED INDEX\n")
    sys.exit(1)

replacement = f"{start}\n```markdown\n{compressed}\n```\n{end}"
updated = pattern.sub(replacement, text)
readme_path.write_text(updated, encoding="utf-8")
PY
else
  printf '%s\n' "$compressed"
fi
