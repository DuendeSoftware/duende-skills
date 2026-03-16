# AGENTS.md

This repo supports both Claude Code and OpenCode.

When adding/removing skills or agents, keep the plugin registry up to date.

Maintenance:
1. Update `.claude-plugin/plugin.json`
2. Run `./scripts/validate-marketplace.sh`
3. Regenerate the compressed index: `./scripts/generate-skill-index-snippets.sh`

See `CLAUDE.md` for more details.