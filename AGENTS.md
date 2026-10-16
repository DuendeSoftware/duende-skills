# AGENTS.md

This repo supports Claude Code, OpenCode, and ChatGPT/Codex.

When adding/removing skills or agents, keep both plugin registries up to date.

Maintenance:
1. Update both plugin manifests — always, never just one:
   - `.claude-plugin/plugin.json`: add/remove the path in the `skills` or `agents` array
   - `.codex-plugin/plugin.json`: skills are discovered from `./skills/`, but the Codex listing must still be kept current — update `interface.longDescription`, `keywords`, and `defaultPrompt` to reflect added/removed coverage
   - Versions are kept in sync across both manifests and `.claude-plugin/marketplace.json` by `./scripts/bump-version.sh`
2. Run `./scripts/validate-marketplace.sh`
3. Regenerate the compressed index: `./scripts/generate-skill-index-snippets.sh`
4. Package for distribution: `./scripts/build.sh`

See `CLAUDE.md` for more details.