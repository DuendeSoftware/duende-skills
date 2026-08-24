#!/usr/bin/env bash
set -euo pipefail

# build.sh — Package duende-skills for Claude Code and ChatGPT/Codex marketplaces.
#
# Usage:
#   ./scripts/build.sh                  # validate + package both targets
#   ./scripts/build.sh --target claude   # Claude Code only
#   ./scripts/build.sh --target codex    # ChatGPT/Codex only
#   ./scripts/build.sh --skip-validate   # skip validation step
#   ./scripts/build.sh --output-dir dir  # custom output directory (default: dist/)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/dist"
TARGET="all"
SKIP_VALIDATE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)      TARGET="$2"; shift 2 ;;
    --output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
    --skip-validate) SKIP_VALIDATE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--target claude|codex|all] [--output-dir DIR] [--skip-validate]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Extract "version" value from a JSON file (simple grep, no python)
json_version() {
  grep -m1 '"version"' "$1" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# ── Step 1: Validate ──────────────────────────────────────────────────────────

if [[ "$SKIP_VALIDATE" == false ]]; then
  info "Running marketplace validation..."
  if ! "$REPO_ROOT/scripts/validate-marketplace.sh"; then
    error "Validation failed. Fix errors before packaging."
    exit 1
  fi
  echo ""
fi

# ── Step 2: Sync versions ────────────────────────────────────────────────────

CLAUDE_VERSION=$(json_version "$REPO_ROOT/.claude-plugin/plugin.json")
CLAUDE_MARKETPLACE_VERSION=$(json_version "$REPO_ROOT/.claude-plugin/marketplace.json")
CODEX_VERSION=$(json_version "$REPO_ROOT/.codex-plugin/plugin.json")

if [[ "$CLAUDE_VERSION" != "$CLAUDE_MARKETPLACE_VERSION" || "$CLAUDE_VERSION" != "$CODEX_VERSION" ]]; then
  error "Version mismatch: Claude plugin ($CLAUDE_VERSION), Claude marketplace ($CLAUDE_MARKETPLACE_VERSION), Codex plugin ($CODEX_VERSION)"
  exit 1
fi

VERSION="$CLAUDE_VERSION"
info "Building version $VERSION"

# ── Step 3: Package ──────────────────────────────────────────────────────────

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Common files to include in every package
COMMON_INCLUDES=(
  "skills/"
  "agents/"
  "assets/"
  "LICENSE"
  "README.md"
)

package_claude() {
  info "Packaging for Claude Code..."
  local dest="$OUTPUT_DIR/claude/duende-skills"
  mkdir -p "$dest/.claude-plugin"

  cp "$REPO_ROOT/.claude-plugin/plugin.json"      "$dest/.claude-plugin/"
  cp "$REPO_ROOT/.claude-plugin/marketplace.json"  "$dest/.claude-plugin/"

  for item in "${COMMON_INCLUDES[@]}"; do
    cp -R "$REPO_ROOT/$item" "$dest/$item"
  done

  # Create archive
  (cd "$OUTPUT_DIR/claude" && tar czf "$OUTPUT_DIR/duende-skills-claude-v${VERSION}.tar.gz" duende-skills/)
  info "  -> dist/duende-skills-claude-v${VERSION}.tar.gz"
}

package_codex() {
  info "Packaging for ChatGPT/Codex..."
  local dest="$OUTPUT_DIR/codex/duende-skills"
  mkdir -p "$dest/.codex-plugin" "$dest/.agents/plugins"

  cp "$REPO_ROOT/.codex-plugin/plugin.json"          "$dest/.codex-plugin/"
  cp "$REPO_ROOT/.agents/plugins/marketplace.json"   "$dest/.agents/plugins/"

  for item in "${COMMON_INCLUDES[@]}"; do
    cp -R "$REPO_ROOT/$item" "$dest/$item"
  done

  # Create archive
  (cd "$OUTPUT_DIR/codex" && zip -qr "$OUTPUT_DIR/duende-skills-codex-v${VERSION}.zip" duende-skills/)
  info "  -> dist/duende-skills-codex-v${VERSION}.zip"
}

case "$TARGET" in
  claude) package_claude ;;
  codex)  package_codex ;;
  all)    package_claude; package_codex ;;
  *)      error "Unknown target: $TARGET"; exit 1 ;;
esac

# ── Step 4: Summary ──────────────────────────────────────────────────────────

SKILL_COUNT=$(find "$REPO_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
AGENT_COUNT=$(find "$REPO_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')

echo ""
info "Build complete!"
echo "  Version:  $VERSION"
echo "  Skills:   $SKILL_COUNT"
echo "  Agents:   $AGENT_COUNT"
echo "  Output:   $OUTPUT_DIR/"
find "$OUTPUT_DIR" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.zip' \) -exec ls -lh {} + |
  awk '{print "  " $NF " (" $5 ")"}'
