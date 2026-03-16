# Duende Agent Skills

A set of agent skills and specialized agents for Duende IdentityServer, Backend-for-Frontend (BFF), and identity/access management development. Covers OAuth 2.0, OpenID Connect, Duende, token management, ASP.NET Core authentication and authorization, and related skills needed to build production-grade identity infrastructure.

> **Tip: 📦 Use with [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)**
>
> Duende Skills focus on **identity and security**. For general .NET development skills (C# coding standards, EF Core, Aspire configuration, dependency injection, concurrency patterns, database performance, and more), install **[dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)** as well. The skills in each repo are complementary and additive. No overlapping skills, with full coverage when used together.

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

### GitHub Copilot

[Official Docs](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)

Clone or copy skills to your project or global config:

**Project-level** (recommended):
```bash
git clone https://github.com/DuendeSoftware/duende-skills.git /tmp/duende-skills
cp -r /tmp/duende-skills/skills/* .github/skills/
```

**Global** (all projects):
```bash
mkdir -p ~/.copilot/skills
cp -r /tmp/duende-skills/skills/* ~/.copilot/skills/
```

> **Recommended:** Also install [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) for general .NET development coverage.

### OpenCode

[Official Docs](https://opencode.ai/docs/skills)

```bash
git clone https://github.com/DuendeSoftware/duende-skills.git /tmp/duende-skills

# Global installation (directory names must match frontmatter 'name' field)
mkdir -p ~/.config/opencode/skills ~/.config/opencode/agents
for skill_file in /tmp/duende-skills/skills/*/SKILL.md; do
  skill_name=$(grep -m1 "^name:" "$skill_file" | sed 's/name: *//')
  mkdir -p ~/.config/opencode/skills/$skill_name
  cp "$skill_file" ~/.config/opencode/skills/$skill_name/SKILL.md
done
cp /tmp/duende-skills/agents/*.md ~/.config/opencode/agents/
```

> **Recommended:** Also install [dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) for general .NET development coverage.

---

## Skills Library

### Identity & OAuth

| Skill | Description |
|-------|-------------|
| `aspnetcore-authentication` | ASP.NET Core authentication middleware — OIDC, JWT Bearer, cookies, schemes, external providers |
| `aspnetcore-authorization` | ASP.NET Core authorization — policies, IAuthorizationHandler, scope-based API authz, minimal APIs |
| `claims-authorization` | Claims-based authorization — policies, requirement handlers, resource-based authz, claims transformation |
| `duende-bff` | Backend-for-Frontend security framework for SPAs — session management, API proxying, token management |
| `identity-security-hardening` | Security hardening — key rotation, HTTPS, CORS, CSP, rate limiting, token lifetime tuning |
| `identity-testing-patterns` | Testing IdentityServer integrations — WebApplicationFactory, mock token issuance, protocol validation |
| `identityserver-api-protection` | Protecting APIs — JWT bearer authentication, reference token introspection, scope-based authorization, DPoP/mTLS proof-of-possession, local API auth |
| `identityserver-aspire` | Aspire AppHost orchestration — dependency graphs, authority URL wiring, health checks, multi-instance |
| `identityserver-clients-resources` | Client and resource configuration — client types (M2M, interactive, SPA), grant types, API Scopes vs API Resources vs Identity Resources, secret management |
| `identityserver-configuration` | IdentityServer host configuration — clients, resources, scopes, signing credentials, server-side sessions |
| `identityserver-dcr` | Dynamic Client Registration — endpoint setup, validation, software statements, client stores |
| `identityserver-deployment` | Production deployment — reverse proxy configuration, data protection, health checks, distributed caching, OpenTelemetry, logging |
| `identityserver-hosting-setup` | Setting up and hosting IdentityServer — DI registration, middleware pipeline, hosting patterns, license configuration, ASP.NET Identity integration |
| `identityserver-key-management` | Cryptographic signing keys — automatic key management, data protection at rest, static key configuration, multi-instance deployment |
| `identityserver-saml` | SAML 2.0 Identity Provider — service provider setup, endpoints, attribute mapping, signing behavior |
| `identityserver-sessions-providers` | Server-side sessions, session management/querying, inactivity timeout, dynamic identity providers, CIBA |
| `identityserver-stores` | Persistent stores — EF Core configuration/operational stores, migrations, custom implementations |
| `identityserver-token-lifecycle` | Token types, refresh token management, token exchange (RFC 8693), extension grants, IProfileService claims, lifetime best practices |
| `identityserver-token-security` | Advanced token security — DPoP, mTLS certificate binding, Pushed Authorization Requests (PAR), JAR, FAPI 2.0 compliance |
| `identityserver-ui-flows` | Login, logout, consent, error, and federation gateway UI pages — IIdentityServerInteractionService, external providers, Home Realm Discovery |
| `identityserver4-migration` | Migrating from IdentityServer4 to Duende IdentityServer v7 — NuGet packages, namespaces, API changes, EF Core schema migrations, signing keys, license configuration |
| `oauth-oidc-protocols` | OAuth 2.0 and OpenID Connect fundamentals — flows, PKCE, discovery, JWKS, introspection |
| `token-management` | Token lifecycle with Duende.AccessTokenManagement — caching, refresh, DPoP, HttpClientFactory integration |

> **Looking for general .NET skills?** C# coding standards, concurrency patterns, EF Core, database performance, Aspire configuration, dependency injection, Playwright testing, snapshot testing, project structure, package management, and more are available in **[dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills)**.

---

## Agents

| Agent | Description |
|-------|-------------|
| `identity-server-specialist` | Expert in Duende IdentityServer configuration, deployment, and troubleshooting. Clients, token flows, stores, key rotation, protocol compliance. |
| `oauth-oidc-specialist` | Expert in OAuth 2.0 and OpenID Connect specifications. RFC guidance, flow selection, protocol debugging, security analysis, FAPI compliance. |

---

## Skill Evaluation Benchmarks

Each skill is evaluated using 5–12 realistic prompts with concrete assertions. Every prompt is answered **with the skill loaded** and **without it** (baseline), then graded against the assertions. This measures the incremental value each skill provides over general LLM knowledge.

Run evals for all skills using GitHub Models (via `gh` CLI):

```bash
./scripts/run-evals.sh --iteration 1 --verbose
```

### Results — March 23, 2026 (claude-opus-4-20250514)

**196 evals across 23 skills — 881 total assertions**

|             | With Skill         | Without Skill       | Delta      |
|-------------|--------------------|---------------------|------------|
| **Overall** | **881/881 (100%)** | **610/881 (69.2%)** | **+30.8%** |

| Skill                               | Evals | With Skill   | Without Skill |      Delta |
|-------------------------------------|------:|--------------|---------------|-----------:|
| `identityserver-saml`               |     8 | 35/35 (100%) | 12/35 (34.3%) | **+65.7%** |
| `identityserver-api-protection`     |     7 | 30/30 (100%) | 12/30 (40.0%) | **+60.0%** |
| `identityserver-ui-flows`           |     7 | 30/30 (100%) | 14/30 (46.7%) | **+53.3%** |
| `token-management`                  |    11 | 49/49 (100%) | 23/49 (46.9%) | **+53.1%** |
| `identityserver-hosting-setup`      |     8 | 36/36 (100%) | 22/36 (61.1%) | **+38.9%** |
| `identityserver-sessions-providers` |     8 | 37/37 (100%) | 23/37 (62.2%) | **+37.8%** |
| `duende-bff`                        |    11 | 50/50 (100%) | 32/50 (64.0%) | **+36.0%** |
| `aspnetcore-authentication`         |     8 | 32/32 (100%) | 21/32 (65.6%) | **+34.4%** |
| `claims-authorization`              |     8 | 36/36 (100%) | 24/36 (66.7%) | **+33.3%** |
| `identityserver-token-security`     |     8 | 36/36 (100%) | 25/36 (69.4%) | **+30.6%** |
| `identityserver-deployment`         |     8 | 33/33 (100%) | 23/33 (69.7%) | **+30.3%** |
| `identityserver4-migration`         |    15 | 69/69 (100%) | 49/69 (71.0%) | **+29.0%** |
| `identityserver-stores`             |    12 | 56/56 (100%) | 40/56 (71.4%) | **+28.6%** |
| `identityserver-key-management`     |     8 | 32/32 (100%) | 23/32 (71.9%) | **+28.1%** |
| `identity-security-hardening`       |     7 | 34/34 (100%) | 25/34 (73.5%) | **+26.5%** |
| `oauth-oidc-protocols`              |     8 | 37/37 (100%) | 28/37 (75.7%) | **+24.3%** |
| `identity-testing-patterns`         |     8 | 39/39 (100%) | 30/39 (76.9%) | **+23.1%** |
| `identityserver-aspire`             |     7 | 32/32 (100%) | 26/32 (81.3%) | **+18.8%** |
| `identityserver-token-lifecycle`    |     8 | 36/36 (100%) | 31/36 (86.1%) | **+13.9%** |
| `identityserver-configuration`      |     8 | 36/36 (100%) | 31/36 (86.1%) | **+13.9%** |
| `identityserver-clients-resources`  |     8 | 36/36 (100%) | 31/36 (86.1%) | **+13.9%** |
| `identityserver-dcr`                |     8 | 39/39 (100%) | 36/39 (92.3%) |  **+7.7%** |
| `aspnetcore-authorization`          |     7 | 31/31 (100%) | 29/31 (93.5%) |  **+6.5%** |

**Key findings:**
- Skills achieve 100% assertion pass rate across all 881 assertions.
- **Highest-value skills** (>40% delta): SAML, API protection, UI flows, token management — deeply Duende-specific knowledge where baseline LLM knowledge falls short.
- **Moderate-value skills** (15–40% delta): Hosting setup, sessions, BFF, authentication, claims authorization, token security, deployment, migration, stores, key management, security hardening, OAuth/OIDC protocols, testing patterns, Aspire — specialized patterns that improve precision significantly.
- **Lower-delta skills** (<15%): Token lifecycle, configuration, clients/resources, DCR, authorization — well-known patterns where baseline model knowledge is already strong, but skills still close remaining gaps.

---

## Key Principles

- **Security by Default** — PKCE enforced, no implicit flow, short-lived access tokens, refresh token rotation
- **Protocol Compliance** — OAuth 2.0 Security BCP, OpenID Connect Core, RFC-grounded guidance
- **Type Safety** — Strongly-typed IDs for clients, resources, scopes; nullable reference types throughout
- **Testable Architecture** — DI everywhere, WebApplicationFactory for integration tests, no static state
- **Production Patterns** — Key rotation, data protection, health checks, structured logging

---

## Support & Feedback

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

The following is metadata about the skills that can be used and parsed by various AI agents/tools. This section is maintaiend by the `./scripts/generate-skills-index.sh` script.

<!-- BEGIN DUENDE-SKILLS COMPRESSED INDEX -->
```markdown
[duende-skills]|IMPORTANT: Prefer retrieval-led reasoning over pretraining for any identity/auth/.NET work.
|flow:{skim repo patterns -> consult duende-skills by name -> implement smallest-change -> note conflicts}
|route:
|identity:{duende-bff,identity-security-hardening,identityserver-api-protection,identityserver-aspire,identityserver-clients-resources,identityserver-configuration,identityserver-dcr,identityserver-deployment,identityserver-hosting-setup,identityserver-key-management,identityserver-saml,identityserver-sessions-providers,identityserver-stores,identityserver-token-lifecycle,identityserver-token-security,identityserver-ui-flows,identityserver4-migration}
|oauth:{claims-authorization,oauth-oidc-protocols,token-management}
|aspnetcore:{aspnetcore-authentication,aspnetcore-authorization}
|testing:{identity-testing-patterns}
|agents:{identity-server-specialist,oauth-oidc-specialist}
```
<!-- END DUENDE-SKILLS COMPRESSED INDEX -->
