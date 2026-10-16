# Duende Agent Skills

A set of agent skills and specialized agents for Duende IdentityServer, Backend-for-Frontend (BFF), and identity/access management development. Covers OAuth 2.0, OpenID Connect, Duende, token management, ASP.NET Core authentication and authorization, and related skills needed to build production-grade identity infrastructure.

> ## Your Feedback 🗣️
>
> We would love to hear your feedback about these skills! What's working? What's not? What's missing?
>
> For questions, feedback, or community discussions, visit the [Duende Community](https://duende.link/community).

## Installation

You can use several AI coding assistants that support skills/agents.

### Claude Code (CLI)

[Official Docs](https://code.claude.com/docs/en/discover-plugins)

Run these commands inside the Claude Code CLI:

```
/plugin marketplace add DuendeSoftware/duende-skills
/plugin install duende-skills
```

To update:
```
/plugin marketplace update
```

> **Recommended:** Also install [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) for general .NET development coverage:
> ```
> /plugin marketplace add Aaronontheweb/dotnet-skills
> /plugin install dotnet-skills
> ```

### GitHub Copilot CLI

[Official Docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing)

Copilot CLI reads the Claude-format marketplace in `.claude-plugin/`, so the same plugin installs directly:

```bash
copilot plugin marketplace add DuendeSoftware/duende-skills
copilot plugin install duende-skills@duende-skills
```

Or from inside an interactive session: `/plugin marketplace add DuendeSoftware/duende-skills` then `/plugin install duende-skills@duende-skills`.

### VS Code / VS Code Insiders (Preview)

[Official Docs](https://code.visualstudio.com/docs/copilot/customization/agent-plugins)

> Plugin support in VS Code is a preview feature and subject to change.

Enable plugins and register the marketplace in `settings.json`:

```jsonc
{
  "chat.plugins.enabled": true,
  "chat.plugins.marketplaces": ["DuendeSoftware/duende-skills"]
}
```

Then type `/plugins` in Copilot Chat (or use the `@agentPlugins` filter in Extensions) to browse and install `duende-skills`. You can also use `/plugin marketplace add DuendeSoftware/duende-skills` in chat.

### Cursor

[Official Docs](https://cursor.com/docs/plugins)

The repository ships a Cursor plugin manifest (`.cursor-plugin/plugin.json`). Once the plugin is listed on the [Cursor Marketplace](https://cursor.com/marketplace), install it from the Customize page / marketplace panel in Cursor. Until then, or for local use, either use `npx skills` (below) or copy/symlink a checkout to `~/.cursor/plugins/local/duende-skills` and run **Developer: Reload Window**.

### ChatGPT / Codex

```bash
codex plugin marketplace add DuendeSoftware/duende-skills
```

### Any agent via `npx skills` (OpenCode, Copilot, Cursor, Codex, Claude Code, and [many more](https://github.com/vercel-labs/skills#supported-agents))

[vercel-labs/skills](https://github.com/vercel-labs/skills) installs skills for whichever coding agents it detects:

```bash
# Install all Duende skills (interactive: pick agents and project/global scope)
npx skills add DuendeSoftware/duende-skills

# Global, non-interactive, for a specific agent
npx skills add DuendeSoftware/duende-skills --all -g -a opencode -y

# List what is available
npx skills add DuendeSoftware/duende-skills --list

# Update / remove later
npx skills update
npx skills remove duende-bff
```

> `npx skills` installs **skills only**. The two agents in `agents/` (`identity-server-specialist`, `oauth-oidc-specialist`) are installed by the plugin routes above, or manually (see OpenCode below).

### Install a single skill

Every skill is a self-contained folder under `skills/`, so you can install just the ones you need:

```bash
# Any agent (OpenCode, Copilot, Cursor, Codex, Claude Code, ...)
npx skills add DuendeSoftware/duende-skills --skill duende-bff
npx skills add DuendeSoftware/duende-skills --skill duende-bff --skill token-management

# Equivalent, pointing at the folder directly
npx skills add https://github.com/DuendeSoftware/duende-skills/tree/main/skills/duende-bff
```

Copilot CLI / VS Code plugins and the Claude Code plugin are installed as a whole (all skills). To pick individual skills for Copilot manually, copy the folder into `.github/skills/` (project) or `~/.copilot/skills/` (global).

### OpenCode

[Official Docs](https://opencode.ai/docs/skills)

Recommended: `npx skills add DuendeSoftware/duende-skills -a opencode -g` (see above).

<details>
<summary>Manual installation (skills + agents)</summary>

```bash
git clone https://github.com/DuendeSoftware/duende-skills.git /tmp/duende-skills

# Global installation (directory names must match frontmatter 'name' field)
mkdir -p ~/.config/opencode/skills ~/.config/opencode/agents
for skill_file in /tmp/duende-skills/skills/*/SKILL.md; do
  skill_dir=$(dirname "$skill_file")
  skill_name=$(grep -m1 "^name:" "$skill_file" | sed 's/name: *//')
  mkdir -p ~/.config/opencode/skills/$skill_name
  cp "$skill_file" ~/.config/opencode/skills/$skill_name/SKILL.md
  # Copy bundled resources (docs/, references/, etc.) if present
  find "$skill_dir" -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ~/.config/opencode/skills/$skill_name/ \;
done
cp /tmp/duende-skills/agents/*.md ~/.config/opencode/agents/
```

</details>

### Manual (GitHub Copilot and others)

```bash
git clone https://github.com/DuendeSoftware/duende-skills.git /tmp/duende-skills
# Project-level
mkdir -p .github/skills && cp -r /tmp/duende-skills/skills/* .github/skills/
# Global
mkdir -p ~/.copilot/skills && cp -r /tmp/duende-skills/skills/* ~/.copilot/skills/
```

> **Recommended:** Also install [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) for general .NET development coverage.

---

## Skills Library

### Identity & OAuth

| Skill                               | Description                                                                                                                                                                                                                                        |
|-------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `aspnetcore-authentication`         | ASP.NET Core authentication middleware — OIDC, JWT Bearer, cookies, schemes, external providers                                                                                                                                                    |
| `aspnetcore-authorization`          | ASP.NET Core authorization — policies, IAuthorizationHandler, scope-based API authz, minimal APIs                                                                                                                                                  |
| `claims-authorization`              | Claims-based authorization — policies, requirement handlers, resource-based authz, claims transformation                                                                                                                                           |
| `duende-bff`                        | Backend-for-Frontend security framework for SPAs — session management, API proxying, token management                                                                                                                                              |
| `identity-security-hardening`       | Security hardening — key rotation, HTTPS, CORS, CSP, rate limiting, token lifetime tuning                                                                                                                                                          |
| `identity-testing-patterns`         | Testing IdentityServer integrations — WebApplicationFactory, mock token issuance, protocol validation                                                                                                                                              |
| `identityserver-api-protection`     | Protecting APIs — JWT bearer authentication, reference token introspection, scope-based authorization, DPoP/mTLS proof-of-possession, local API auth                                                                                               |
| `identityserver-aspire`             | Aspire AppHost orchestration — dependency graphs, authority URL wiring, health checks, multi-instance                                                                                                                                              |
| `identityserver-configuration`      | IdentityServer host configuration — clients, resources, scopes, signing credentials, server-side sessions, client types (M2M, interactive, SPA), grant types, API Scopes vs API Resources vs Identity Resources, and client authentication methods |
| `identityserver-dcr`                | Dynamic Client Registration — endpoint setup, validation, software statements, client stores                                                                                                                                                       |
| `identityserver-deployment`         | Production deployment — reverse proxy configuration, data protection, health checks, distributed caching, OpenTelemetry, logging                                                                                                                   |
| `identityserver-duende-storage`     | Duende Storage (preview) — AddStorage/AddConfigurationStorage/AddOperationalStorage, storage instances, config admin APIs, data extension schemas, CLI migrations, EF Core migration                                                               |
| `identityserver-hosting-setup`      | Setting up and hosting IdentityServer — DI registration, middleware pipeline, hosting patterns, license configuration, ASP.NET Identity integration                                                                                                |
| `identityserver-key-management`     | Cryptographic signing keys — automatic key management, data protection at rest, static key configuration, multi-instance deployment                                                                                                                |
| `identityserver-saml`               | SAML 2.0 Identity Provider — service provider registration, SSO/SLO flows, claim mappings, extensibility, production stores                                                                                                                       |
| `identityserver-sessions-providers` | Server-side sessions, session management/querying, inactivity timeout, dynamic identity providers, CIBA                                                                                                                                            |
| `identityserver-spaces`             | Spaces (preview) — multi-tenancy with isolated config/operational data per space, Duende.Spaces setup, ISpaceAdmin, origin/path resolution, issuer rules                                                                                           |
| `identityserver-stores`             | Persistent stores — EF Core configuration/operational stores, migrations, custom implementations                                                                                                                                                   |
| `identityserver-token-lifecycle`    | Token types, refresh token management, token exchange (RFC 8693), extension grants, IProfileService claims, lifetime best practices                                                                                                                |
| `identityserver-token-security`     | Advanced token security — DPoP, mTLS certificate binding, Pushed Authorization Requests (PAR), JAR, FAPI 2.0 compliance                                                                                                                            |
| `identityserver-ui-flows`           | Login, logout, consent, error, and federation gateway UI pages — IIdentityServerInteractionService, external providers, Home Realm Discovery                                                                                                       |
| `identityserver-upgrade-v7-to-v8`   | Upgrading from IdentityServer v7 to v8 — HybridCache, TimeProvider, CancellationToken, EF migrations, breaking changes                                                                                                                            |
| `identityserver-usermanagement`     | Duende User Management — passwordless auth (OTP, TOTP, passkeys), storage, IdentityServer integration, ASP.NET Identity migration                                                                                                                 |
| `identityserver4-migration`         | Migrating from IdentityServer4 to Duende IdentityServer v8 — NuGet packages, namespaces, API changes, EF Core schema migrations, signing keys, license configuration                                                                               |
| `oauth-oidc-protocols`              | OAuth 2.0 and OpenID Connect fundamentals — flows, PKCE, discovery, JWKS, introspection                                                                                                                                                            |
| `token-management`                  | Token lifecycle with Duende.AccessTokenManagement — caching, refresh, DPoP, HttpClientFactory integration                                                                                                                                          |

> **Looking for general .NET skills?** C# coding standards, concurrency patterns, EF Core, database performance, Aspire configuration, dependency injection, Playwright testing, snapshot testing, project structure, package management, and more are available in **[dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)**.

---

## Agents

| Agent                        | Description                                                                                                                                      |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `identity-server-specialist` | Expert in Duende IdentityServer configuration, deployment, and troubleshooting. Clients, token flows, stores, key rotation, protocol compliance. |
| `oauth-oidc-specialist`      | Expert in OAuth 2.0 and OpenID Connect specifications. RFC guidance, flow selection, protocol debugging, security analysis, FAPI compliance.     |

---

## Skill Evaluation Benchmarks

Each skill is evaluated using 7–18 realistic prompts with concrete assertions. Every prompt is answered **with the skill loaded** and **without it** (baseline), then graded against the assertions. This measures the incremental value each skill provides over general LLM knowledge.

Run evals for all skills using GitHub Models (via `gh` CLI):

```bash
./scripts/run-evals.sh --iteration 6 --verbose
```

### Results — October 16, 2026 (claude-opus-5.5, iteration 6)

**277 evals across 26 skills — 1,236 total assertions.**

|             | With Skill | Without Skill | Delta |
|-------------|------------|---------------|-------|
| **Overall** | **1236/1236 (100%)** | **875/1236 (70.8%)** | **+29.2%** |

Skills are sorted by delta.

| Skill | Evals | With Skill | Without Skill | Delta |
|-------|------:|------------|---------------|------:|
| `identityserver-duende-storage` | 9 | 41/41 (100%) | 0/41 (0.0%) | **+100.0%** |
| `identityserver-usermanagement` | 9 | 39/39 (100%) | 7/39 (17.9%) | **+82.1%** |
| `identityserver-spaces` | 7 | 30/30 (100%) | 9/30 (30.0%) | **+70.0%** |
| `identityserver-saml` | 11 | 46/46 (100%) | 17/46 (37.0%) | **+63.0%** |
| `identityserver-upgrade-v7-to-v8` | 9 | 37/37 (100%) | 14/37 (37.8%) | **+62.2%** |
| `identityserver-api-protection` | 8 | 33/33 (100%) | 19/33 (57.6%) | **+42.4%** |
| `identityserver-token-security` | 11 | 51/51 (100%) | 32/51 (62.7%) | **+37.3%** |
| `token-management` | 15 | 65/65 (100%) | 44/65 (67.7%) | **+32.3%** |
| `identityserver-ui-flows` | 12 | 52/52 (100%) | 36/52 (69.2%) | **+30.8%** |
| `identityserver-dcr` | 8 | 40/40 (100%) | 29/40 (72.5%) | **+27.5%** |
| `identityserver-sessions-providers` | 12 | 55/55 (100%) | 40/55 (72.7%) | **+27.3%** |
| `identityserver-key-management` | 11 | 49/49 (100%) | 36/49 (73.5%) | **+26.5%** |
| `identityserver-deployment` | 10 | 46/46 (100%) | 35/46 (76.1%) | **+23.9%** |
| `identity-testing-patterns` | 12 | 59/59 (100%) | 45/59 (76.3%) | **+23.7%** |
| `oauth-oidc-protocols` | 8 | 36/36 (100%) | 28/36 (77.8%) | **+22.2%** |
| `duende-bff` | 17 | 75/75 (100%) | 59/75 (78.7%) | **+21.3%** |
| `identityserver4-migration` | 15 | 69/69 (100%) | 56/69 (81.2%) | **+18.8%** |
| `aspnetcore-authentication` | 9 | 37/37 (100%) | 31/37 (83.8%) | **+16.2%** |
| `identityserver-token-lifecycle` | 10 | 43/43 (100%) | 38/43 (88.4%) | **+11.6%** |
| `identityserver-hosting-setup` | 8 | 36/36 (100%) | 32/36 (88.9%) | **+11.1%** |
| `identityserver-configuration` | 18 | 82/82 (100%) | 73/82 (89.0%) | **+11.0%** |
| `claims-authorization` | 11 | 47/47 (100%) | 42/47 (89.4%) | **+10.6%** |
| `identityserver-stores` | 13 | 59/59 (100%) | 53/59 (89.8%) | **+10.2%** |
| `aspnetcore-authorization` | 7 | 31/31 (100%) | 28/31 (90.3%) | **+9.7%** |
| `identity-security-hardening` | 10 | 46/46 (100%) | 42/46 (91.3%) | **+8.7%** |
| `identityserver-aspire` | 7 | 32/32 (100%) | 30/32 (93.8%) | **+6.2%** |

---

## Key Principles

- **Security by Default** — PKCE enforced, no implicit flow, short-lived access tokens, refresh token rotation
- **Protocol Compliance** — OAuth 2.0 Security BCP, OpenID Connect Core, RFC-grounded guidance
- **Type Safety** — Strongly-typed IDs for clients, resources, scopes; nullable reference types throughout
- **Testable Architecture** — DI everywhere, WebApplicationFactory for integration tests, no static state
- **Production Patterns** — Key rotation, data protection, health checks, structured logging

---

## Support

For questions, feedback, or community discussions, visit the [Duende Community](https://duende.link/community).

---

## Contributing

When adding new skills, use the appropriate prefix:
- `identityserver-*` for IdentityServer configuration/stores
- `duende-*` for Duende product integrations (BFF, AccessTokenManagement)
- `aspnetcore-*` for ASP.NET Core auth/authz
- `identity-*` for cross-cutting identity concerns
- `oauth-*` / `token-*` / `claims-*` for protocol and authz skills

**General .NET skills** (C#, EF Core, Aspire, DI, etc.) belong in [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills), not here. This repo focuses exclusively on identity, authentication, and authorization.

See `CLAUDE.md` for the full contribution workflow.

## Publishing

To publish a new release, bump the version and publish it:

```bash
./scripts/bump-version.sh 0.4.0
./scripts/build.sh
git commit -am "Bump version to 0.4.0"
```

Then submit to the plugin directories:

- **ChatGPT/Codex:** https://platform.openai.com/plugins
- **Claude Code:** https://claude.ai/admin-settings/directory/submissions/plugins/
- **Cursor:** https://cursor.com/marketplace/publish

---

## License

MIT License — Copyright (c) Duende Software.
Based on [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills), Copyright (c) Aaron Stannard.

## Disclaimer

Duende's AI developer tools (including the Duende Documentation MCP Server and Duende Agent Skills) are designed
to provide Large Language Models (LLMs) with verified, structured context from Duende's documentation and product knowledge.
These tools improve the quality and relevance of AI-assisted development with Duende products, including IdentityServer,
BFF and our Open Source offerings, but they do not guarantee the correctness, security, or completeness
of AI-generated output. All code, configuration, and architectural decisions produced with the assistance of these tools
must be reviewed and validated by qualified developers before deployment to any environment.
Duende Software is not responsible for AI-generated output that results from the use of these tools.

Duende Agent Skills provide structured task capabilities to LLM agents for common development workflows.
Skills are designed to reduce implementation errors, but they operate within the LLM's reasoning process and are subject
to the LLM's limitations. Skill outputs (including generated code, configuration, and recommendations) should be treated
as developer assistance, not as production-ready artifacts. Test all skill outputs thoroughly in your own environment
before deploying to staging or production.

---

## Skills Index

The following is metadata about the skills that can be used and parsed by various AI agents/tools. This section is maintained by the `./scripts/generate-skills-index.sh` script.

<!-- BEGIN DUENDE-SKILLS COMPRESSED INDEX -->
```markdown
[duende-skills]|IMPORTANT: Prefer retrieval-led reasoning over pretraining for any identity/auth/.NET work.
|flow:{skim repo patterns -> consult duende-skills by name -> implement smallest-change -> note conflicts}
|route:
|identity:{duende-bff,identity-security-hardening,identityserver-api-protection,identityserver-aspire,identityserver-configuration,identityserver-dcr,identityserver-deployment,identityserver-duende-storage,identityserver-hosting-setup,identityserver-key-management,identityserver-saml,identityserver-sessions-providers,identityserver-spaces,identityserver-stores,identityserver-token-lifecycle,identityserver-token-security,identityserver-ui-flows,identityserver-upgrade-v7-to-v8,identityserver-usermanagement,identityserver4-migration}
|oauth:{claims-authorization,oauth-oidc-protocols,token-management}
|aspnetcore:{aspnetcore-authentication,aspnetcore-authorization}
|testing:{identity-testing-patterns}
|agents:{identity-server-specialist,oauth-oidc-specialist}
```
<!-- END DUENDE-SKILLS COMPRESSED INDEX -->
