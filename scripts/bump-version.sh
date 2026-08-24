#!/usr/bin/env bash
set -euo pipefail

# bump-version.sh — Set the version number across all plugin manifests.
#
# Usage:
#   ./scripts/bump-version.sh 0.3.0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

MANIFESTS=(
  "$REPO_ROOT/.claude-plugin/plugin.json"
  "$REPO_ROOT/.claude-plugin/marketplace.json"
  "$REPO_ROOT/.codex-plugin/plugin.json"
)

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

if [[ $# -lt 1 ]] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 <version>  (e.g. 0.3.0)"
  exit 1
fi

NEW_VERSION="$1"
CURRENT=$(grep -m1 '"version"' "${MANIFESTS[0]}" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

echo -e "${GREEN}[INFO]${NC} Current version: $CURRENT"
echo -e "${GREEN}[INFO]${NC} Bumping to: $NEW_VERSION"

for manifest in "${MANIFESTS[@]}"; do
  if [[ ! -f "$manifest" ]]; then
    echo -e "${RED}[ERROR]${NC} Missing manifest: $manifest" >&2
    exit 1
  fi
  manifest_current=$(grep -m1 '"version"' "$manifest" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/\"$manifest_current\"/\"$NEW_VERSION\"/g" "$manifest"
  else
    sed -i "s/\"$manifest_current\"/\"$NEW_VERSION\"/g" "$manifest"
  fi
  echo "  Updated: $manifest"
done

echo ""
echo -e "${GREEN}[INFO]${NC} Done. Next steps:"
echo "  1. git diff"
echo "  2. git commit -am 'Bump version to $NEW_VERSION'"
echo "  3. git tag v$NEW_VERSION && git push origin v$NEW_VERSION"
