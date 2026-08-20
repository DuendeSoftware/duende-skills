# AGENTS.md

This repo supports Claude Code, OpenCode, and ChatGPT/Codex.

When adding/removing skills or agents, keep both plugin registries up to date.

Maintenance:
1. Update `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`
2. Run `./scripts/validate-marketplace.sh`
3. Regenerate the compressed index: `./scripts/generate-skill-index-snippets.sh`
4. Package for distribution: `./scripts/build.sh`

See `CLAUDE.md` for more details.