# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

**Canonical repository:** https://github.com/DuendeSoftware/duende-skills

This is the official Claude Code Marketplace for Duende IdentityServer development skills and agents. It covers the full identity and access management stack: OAuth 2.0, OpenID Connect, Duende IdentityServer, Duende BFF, token management, ASP.NET Core authentication and authorization, and related .NET ecosystem skills.

This is a knowledge base repository — not a traditional code project. There is no build system or compiled output. Skills are evaluated using assertion-based benchmarks (see [Adding Evals](#adding-evals)).

## Structure

```
duende-skills/
├── .claude-plugin/
│   ├── marketplace.json    # Marketplace catalog
│   └── plugin.json         # Plugin metadata + skill/agent registry
├── skills/                 # Flat structure for Copilot compatibility
│   ├── identityserver-configuration/SKILL.md
│   ├── oauth-oidc-protocols/SKILL.md
│   ├── aspnetcore-authentication/SKILL.md
│   ├── duende-bff/SKILL.md
│   └── ...
├── tests/                  # Eval data per skill
│   ├── duende-bff/
│   │   ├── evals.json      # Prompts + assertions
│   │   └── files/begin-state/  # Reference code files
│   └── ...
├── agents/                 # Agent definitions (flat .md files)
└── scripts/                # Validation, eval, and sync scripts
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
2. Add evals for the new skill (see [Adding Evals](#adding-evals) below)
3. Add the skill path to `.claude-plugin/plugin.json` in the `skills` array
4. Run `./scripts/validate-marketplace.sh` to verify
5. Run `./scripts/generate-skill-index-snippets.sh --update-readme` to regenerate the compressed index
6. Commit all changes together (SKILL.md, evals, plugin.json, and README.md)

### Adding Skills to Index Categories

When adding a skill with a **new prefix pattern**, update `scripts/generate-skill-index-snippets.sh` to handle the new pattern in its `case` statement. Otherwise the skill will be silently ignored when generating the index.

### Adding Evals

Every new or updated skill **must** include evals. Evals measure the incremental value the skill provides over baseline LLM knowledge.

1. Create a test directory: `tests/<skill-name>/`
2. Add an `evals.json` file with 5–10 realistic prompts and concrete assertions:
   ```json
   {
     "skill_name": "<skill-name>",
     "evals": [
       {
         "id": 1,
         "prompt": "A realistic developer question that the skill should help answer",
         "expected_output": "Human-readable description of an ideal answer (informational only)",
         "files": ["files/begin-state/Program.cs"],
         "assertions": [
           "Specific, checkable statement the response must satisfy",
           "Another concrete assertion — be precise about API names, patterns, etc."
         ]
       }
     ]
   }
   ```
3. Optionally add reference files in `tests/<skill-name>/files/begin-state/` (e.g., `Program.cs`, `*.csproj`, `appsettings.json`) that provide starter code context for the prompts
4. Run evals to verify: `./scripts/run-evals.sh --skill <skill-name> --iteration 1 --verbose`
5. Aim for **100% pass rate** with skill loaded and a meaningful delta (>10%) over the without-skill baseline

**When updating an existing skill**, run its evals to confirm no regressions. Add new evals if the update introduces new patterns or APIs.

**Eval design tips:**
- Write prompts that mirror real developer questions (troubleshooting, setup, migration)
- Assertions should test Duende-specific knowledge that generic LLMs would miss
- Include at least one troubleshooting/debugging prompt per skill
- Use reference files when the prompt involves modifying existing code

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
/plugin marketplace add DuendeSoftware/duende-skills
/plugin install duende-skills
```

## Content Guidelines

- Skills should be comprehensive reference documents (10–40 KB)
- Include concrete code examples using modern C# patterns
- Reference authoritative sources (Duende docs, RFCs, ASP.NET Core docs) rather than duplicating content
- Agents define personas with expertise areas and diagnostic approaches
- Identity-specific skills should reference relevant RFCs and Duende documentation
- Security guidance must be current with OAuth 2.0 Security Best Current Practice
