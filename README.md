# Duende IdentityServer Skills for Claude Code

A Claude Code plugin with **19 skills** and **5 specialized agents** for Duende IdentityServer and identity/access management development. Covers OAuth 2.0, OpenID Connect, Duende BFF, token management, ASP.NET Core authentication and authorization, and the .NET ecosystem skills needed to build production-grade identity infrastructure.

> **Tip: 📦 Use with [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)**
>
> Duende IdentityServer Skills focus on **identity and security**. For general .NET development skills (C# coding standards, EF Core, Aspire configuration, dependency injection, concurrency patterns, database performance, and more), install **[dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)** as well. The skills in each repo are complementary and additive. No overlapping skills, with full coverage when used together.

## Installation

This plugin works with multiple AI coding assistants that support skills/agents.

### Claude Code (CLI)

[Official Docs](https://code.claude.com/docs/en/discover-plugins)

Run these commands inside the Claude Code CLI:

```
/plugin marketplace add DuendeSoftware/identity-skills
/plugin install identity-skills
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

### GitHub Copilot

[Official Docs](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)

Clone or copy skills to your project or global config:

**Project-level** (recommended):
```bash
git clone https://github.com/DuendeSoftware/identity-skills.git /tmp/identity-skills
cp -r /tmp/identity-skills/skills/* .github/skills/
```

**Global** (all projects):
```bash
mkdir -p ~/.copilot/skills
cp -r /tmp/identity-skills/skills/* ~/.copilot/skills/
```

> **Recommended:** Also install [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) for general .NET development coverage.

### OpenCode

[Official Docs](https://opencode.ai/docs/skills)

```bash
git clone https://github.com/DuendeSoftware/identity-skills.git /tmp/identity-skills

# Global installation (directory names must match frontmatter 'name' field)
mkdir -p ~/.config/opencode/skills ~/.config/opencode/agents
for skill_file in /tmp/identity-skills/skills/*/SKILL.md; do
  skill_name=$(grep -m1 "^name:" "$skill_file" | sed 's/name: *//')
  mkdir -p ~/.config/opencode/skills/$skill_name
  cp "$skill_file" ~/.config/opencode/skills/$skill_name/SKILL.md
done
cp /tmp/identity-skills/agents/*.md ~/.config/opencode/agents/
```

> **Recommended:** Also install [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) for general .NET development coverage.

---

## Skills Library

### Identity & OAuth

| Skill | Description |
|-------|-------------|
| `identityserver-configuration` | IdentityServer host configuration — clients, resources, scopes, signing credentials, server-side sessions |
| `identityserver-stores` | Persistent stores — EF Core configuration/operational stores, migrations, custom implementations |
| `identityserver-saml` | SAML 2.0 Identity Provider — service provider setup, endpoints, attribute mapping, signing behavior |
| `identityserver-dcr` | Dynamic Client Registration — endpoint setup, validation, software statements, client stores |
| `identityserver-aspire` | Aspire AppHost orchestration — dependency graphs, authority URL wiring, health checks, multi-instance |
| `oauth-oidc-protocols` | OAuth 2.0 and OpenID Connect fundamentals — flows, PKCE, discovery, JWKS, introspection |
| `duende-bff` | Backend-for-Frontend security framework for SPAs — session management, API proxying, token management |
| `token-management` | Token lifecycle with Duende.AccessTokenManagement — caching, refresh, DPoP, HttpClientFactory integration |
| `identity-testing-patterns` | Testing IdentityServer integrations — WebApplicationFactory, mock token issuance, protocol validation |
| `claims-authorization` | Claims-based authorization — policies, requirement handlers, resource-based authz, claims transformation |
| `identity-security-hardening` | Security hardening — key rotation, HTTPS, CORS, CSP, rate limiting, token lifetime tuning |
| `aspnetcore-authentication` | ASP.NET Core authentication middleware — OIDC, JWT Bearer, cookies, schemes, external providers |
| `aspnetcore-authorization` | ASP.NET Core authorization — policies, IAuthorizationHandler, scope-based API authz, minimal APIs |

### Testing & Quality

| Skill | Description |
|-------|-------------|
| `aspire-integration-testing` | Integration testing with Aspire — DistributedApplication, OAuth test patterns, auth bypass strategies |
| `playwright-blazor` | End-to-end testing with Playwright for Blazor — authentication flows, OAuth redirect mocking |
| `snapshot-testing` | Snapshot testing with Verify — IdentityServer protocol response snapshots, token structure validation |

### .NET Ecosystem (Identity-Focused)

| Skill | Description |
|-------|-------------|
| `project-structure` | Solution and project structure — IdentityServer solution layout, Duende package grouping, MSBuild |
| `local-tools` | Local .NET tools — dotnet-ef migrations for IdentityServer stores, dotnet user-jwts, CSharpier |
| `package-management` | NuGet package management — Duende package version variables, Central Package Management |

> **Looking for general .NET skills?** C# coding standards, concurrency patterns, EF Core, database performance, Aspire configuration, dependency injection, and more are available in **[dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)**.

---

## Agents

| Agent | Description |
|-------|-------------|
| `identity-server-specialist` | Expert in Duende IdentityServer configuration, deployment, and troubleshooting. Clients, token flows, stores, key rotation, protocol compliance. |
| `oauth-oidc-specialist` | Expert in OAuth 2.0 and OpenID Connect specifications. RFC guidance, flow selection, protocol debugging, security analysis, FAPI compliance. |
| `dotnet-concurrency-specialist` | Diagnoses .NET concurrency issues — deadlocks, race conditions, async anti-patterns, thread safety. |
| `dotnet-performance-analyst` | Interprets profiler traces and benchmark results — allocation hot paths, GC pressure, throughput analysis. |
| `dotnet-benchmark-designer` | Designs statistically valid BenchmarkDotNet harnesses — avoiding common measurement pitfalls. |

---

## Key Principles

- **Security by Default** — PKCE enforced, no implicit flow, short-lived access tokens, refresh token rotation
- **Protocol Compliance** — OAuth 2.0 Security BCP, OpenID Connect Core, RFC-grounded guidance
- **Type Safety** — Strongly-typed IDs for clients, resources, scopes; nullable reference types throughout
- **Testable Architecture** — DI everywhere, WebApplicationFactory for integration tests, no static state
- **Production Patterns** — Key rotation, data protection, health checks, structured logging

---

## Repository Structure

```
identity-skills/
├── .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json
├── agents/
│   ├── identity-server-specialist.md
│   ├── oauth-oidc-specialist.md
│   ├── dotnet-benchmark-designer.md
│   ├── dotnet-concurrency-specialist.md
│   └── dotnet-performance-analyst.md
├── skills/
│   ├── identityserver-configuration/
│   ├── oauth-oidc-protocols/
│   ├── aspnetcore-authentication/
│   ├── duende-bff/
│   └── ... (19 skills total)
├── scripts/
│   ├── validate-marketplace.sh
│   └── generate-skill-index-snippets.sh
├── AGENTS.md
├── CLAUDE.md
└── README.md
```

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

---

## License

MIT License — Copyright (c) 2026 Duende Software.
Based on [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills), Copyright (c) 2025 Aaron Stannard.

<!-- BEGIN IDENTITY-SKILLS COMPRESSED INDEX -->
```markdown
[identity-skills]|IMPORTANT: Prefer retrieval-led reasoning over pretraining for any identity/auth/.NET work.
|flow:{skim repo patterns -> consult identity-skills by name -> implement smallest-change -> note conflicts}
|route:
|identity:{duende-bff,identity-security-hardening,identityserver-aspire,identityserver-configuration,identityserver-dcr,identityserver-saml,identityserver-stores}
|oauth:{claims-authorization,oauth-oidc-protocols,token-management}
|aspnetcore:{aspire-integration-testing,aspnetcore-authentication,aspnetcore-authorization}
|testing:{identity-testing-patterns,playwright-blazor-testing,snapshot-testing}
|dotnet:{dotnet-local-tools,package-management,dotnet-project-structure}
|agents:{dotnet-benchmark-designer,dotnet-concurrency-specialist,dotnet-performance-analyst,identity-server-specialist,oauth-oidc-specialist}
```
<!-- END IDENTITY-SKILLS COMPRESSED INDEX -->
