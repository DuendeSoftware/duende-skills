# AGENTS.md

This repo supports Claude Code, GitHub Copilot (CLI + VS Code), Cursor, OpenCode (via `npx skills`), and ChatGPT/Codex.

When adding/removing skills or agents, keep all plugin registries up to date.

Maintenance:
1. Update all plugin manifests — always, never just one:
   - `.claude-plugin/plugin.json`: add/remove the path in the `skills` or `agents` array
   - `.codex-plugin/plugin.json`: skills are discovered from `./skills/`, but the Codex listing must still be kept current — update `interface.longDescription`, `keywords`, and `defaultPrompt` to reflect added/removed coverage
   - `.cursor-plugin/plugin.json`: skills are discovered from `./skills/`; keep `description`/`keywords` current
   - GitHub Copilot CLI / VS Code read `.claude-plugin/`; `npx skills` discovers `skills/*/SKILL.md` (directory name must match frontmatter `name`) — no extra files
   - Versions are kept in sync across all manifests and `.claude-plugin/marketplace.json` by `./scripts/bump-version.sh`
2. Run `./scripts/validate-marketplace.sh`
3. Regenerate the compressed index: `./scripts/generate-skill-index-snippets.sh`
4. Package for distribution: `./scripts/build.sh`

See `CLAUDE.md` for more details.