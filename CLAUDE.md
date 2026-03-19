# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

**Canonical repository:** https://github.com/DuendeSoftware/identity-skills

This is the official Claude Code Marketplace for Duende IdentityServer development skills and agents. It covers the full identity and access management stack: OAuth 2.0, OpenID Connect, Duende IdentityServer, Duende BFF, token management, ASP.NET Core authentication and authorization, and related .NET ecosystem skills.

This is a knowledge base repository — not a traditional code project. There is no build system, tests, or compiled output.

## Structure

```
identity-skills/
├── .claude-plugin/
│   ├── marketplace.json    # Marketplace catalog
│   └── plugin.json         # Plugin metadata + skill/agent registry
├── skills/                 # Flat structure for Copilot compatibility
│   ├── identityserver-configuration/SKILL.md
│   ├── oauth-oidc-protocols/SKILL.md
│   ├── aspnetcore-authentication/SKILL.md
│   ├── duende-bff/SKILL.md
│   └── ...
├── agents/                 # Agent definitions (flat .md files)
└── scripts/                # Validation and sync scripts
```

### Skill Naming Convention

Skills use a flat directory structure with prefixes for domain-specific skills:

- `identityserver-*` — Duende IdentityServer configuration and stores
- `duende-*` — Duende-specific products (BFF, AccessTokenManagement)
- `aspnetcore-*` — ASP.NET Core authentication and authorization
- `identity-*` — Cross-cutting identity concerns (testing, security hardening)
- `token-*` — Token management and lifecycle
- `claims-*` — Claims modeling and authorization
- `oauth-*` — OAuth 2.0 / OpenID Connect protocol-level skills
- `csharp-*` — C# language skills
- `aspire-*` — .NET Aspire skills
- No prefix for general .NET skills (e.g., `efcore-patterns`)

## File Formats

**Skills** are folders with `SKILL.md`:
```yaml
---
name: skill-name
description: Brief description used for matching
invocable: false
---
```

**Agents** are markdown files with YAML frontmatter:
```yaml
---
name: agent-name
description: Brief description used for matching
model: sonnet  # sonnet, opus, or haiku
color: purple  # optional
---
```

## Adding New Skills

1. Create a folder: `skills/<skill-name>/SKILL.md`
   - Use appropriate prefix for domain-specific skills (see naming convention above)
   - No prefix for general .NET skills
2. Add the skill path to `.claude-plugin/plugin.json` in the `skills` array
3. Run `./scripts/validate-marketplace.sh` to verify
4. Run `./scripts/generate-skill-index-snippets.sh --update-readme` to regenerate the compressed index
5. Commit all changes together (SKILL.md, plugin.json, and README.md)

### Adding Skills to Index Categories

When adding a skill with a **new prefix pattern**, update `scripts/generate-skill-index-snippets.sh` to handle the new pattern in its `case` statement. Otherwise the skill will be silently ignored when generating the index.

## Adding New Agents

1. Create the agent file: `agents/<agent-name>.md`
2. Add the agent path to `.claude-plugin/plugin.json` in the `agents` array
3. Run `./scripts/validate-marketplace.sh` to verify
4. Run `./scripts/generate-skill-index-snippets.sh --update-readme` to regenerate the compressed index
5. Commit all changes together (agent .md, plugin.json, and README.md)

## Marketplace Publishing

**To publish a release:**
1. Update version in `.claude-plugin/plugin.json`
2. Push a semver tag: `git tag v0.1.0 && git push origin v0.1.0`
3. GitHub Actions creates the release automatically

**Users install with:**
```bash
/plugin marketplace add DuendeSoftware/identity-skills
/plugin install identity-skills
```

## Content Guidelines

- Skills should be comprehensive reference documents (10–40 KB)
- Include concrete code examples using modern C# patterns
- Reference authoritative sources (Duende docs, RFCs, ASP.NET Core docs) rather than duplicating content
- Agents define personas with expertise areas and diagnostic approaches
- Identity-specific skills should reference relevant RFCs and Duende documentation
- Security guidance must be current with OAuth 2.0 Security Best Current Practice
