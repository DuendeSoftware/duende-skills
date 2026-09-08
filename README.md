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
  skill_dir=$(dirname "$skill_file")
  skill_name=$(grep -m1 "^name:" "$skill_file" | sed 's/name: *//')
  mkdir -p ~/.config/opencode/skills/$skill_name
  cp "$skill_file" ~/.config/opencode/skills/$skill_name/SKILL.md
  # Copy bundled resources (docs/, references/, etc.) if present
  find "$skill_dir" -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ~/.config/opencode/skills/$skill_name/ \;
done
cp /tmp/duende-skills/agents/*.md ~/.config/opencode/agents/
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
| `identityserver-hosting-setup`      | Setting up and hosting IdentityServer — DI registration, middleware pipeline, hosting patterns, license configuration, ASP.NET Identity integration                                                                                                |
| `identityserver-key-management`     | Cryptographic signing keys — automatic key management, data protection at rest, static key configuration, multi-instance deployment                                                                                                                |
| `identityserver-saml`               | SAML 2.0 Identity Provider — service provider registration, SSO/SLO flows, claim mappings, extensibility, production stores                                                                                                                       |
| `identityserver-sessions-providers` | Server-side sessions, session management/querying, inactivity timeout, dynamic identity providers, CIBA                                                                                                                                            |
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

Each skill is evaluated using 5–12 realistic prompts with concrete assertions. Every prompt is answered **with the skill loaded** and **without it** (baseline), then graded against the assertions. This measures the incremental value each skill provides over general LLM knowledge.

Run evals for all skills using GitHub Models (via `gh` CLI):

```bash
./scripts/run-evals.sh --iteration 5 --verbose
```

### Results — September 8, 2026 (claude-opus-4.8, iteration 5)

**241 evals across 24 skills — 1,079 total assertions**

|             | With Skill            | Without Skill        | Delta      |
|-------------|-----------------------|----------------------|------------|
| **Overall** | **1079/1079 (100%)**  | **833/1079 (77.2%)** | **+22.8%** |

| Skill                               | Evals | With Skill    | Without Skill   |      Delta | Prev Delta |
|-------------------------------------|------:|---------------|-----------------|------------|------------|
| `identityserver-saml`               |    10 | 43/43 (100%)  |   9/43 (20.9%)  | **+79.1%** |    +79.4%  |
| `identityserver-usermanagement`     |     7 | 29/29 (100%)  |  14/29 (48.3%)  | **+51.7%** |    +69.0%  |
| `duende-bff`                        |    15 | 67/67 (100%)  |  34/67 (50.7%)  | **+49.3%** |    +65.1%  |
| `token-management`                  |    13 | 58/58 (100%)  |  36/58 (62.1%)  | **+37.9%** |    +61.4%  |
| `identityserver-api-protection`     |     7 | 30/30 (100%)  |  19/30 (63.3%)  | **+36.7%** |    +53.3%  |
| `identityserver-upgrade-v7-to-v8`   |     8 | 34/34 (100%)  |  22/34 (64.7%)  | **+35.3%** |    +82.8%  |
| `identityserver-dcr`                |     8 | 40/40 (100%)  |  29/40 (72.5%)  | **+27.5%** |    +76.9%  |
| `identityserver-sessions-providers` |    11 | 50/50 (100%)  |  37/50 (74.0%)  | **+26.0%** |    +67.6%  |
| `identityserver-deployment`         |     9 | 39/39 (100%)  |  29/39 (74.4%)  | **+25.6%** |    +55.9%  |
| `identityserver-token-security`     |     9 | 41/41 (100%)  |  32/41 (78.0%)  | **+22.0%** |    +61.1%  |
| `identity-testing-patterns`         |    12 | 59/59 (100%)  |  49/59 (83.1%)  | **+16.9%** |    +29.8%  |
| `identityserver-hosting-setup`      |     8 | 36/36 (100%)  |  30/36 (83.3%)  | **+16.7%** |    +33.3%  |
| `aspnetcore-authentication`         |     9 | 37/37 (100%)  |  31/37 (83.8%)  | **+16.2%** |    +30.3%  |
| `identity-security-hardening`       |    10 | 46/46 (100%)  |  39/46 (84.8%)  | **+15.2%** |    +24.3%  |
| `claims-authorization`              |    11 | 47/47 (100%)  |  40/47 (85.1%)  | **+14.9%** |    +47.5%  |
| `identityserver-ui-flows`           |     9 | 39/39 (100%)  |  34/39 (87.2%)  | **+12.8%** |    +40.0%  |
| `identityserver-configuration`      |    18 | 82/82 (100%)  |  72/82 (87.8%)  | **+12.2%** |    +38.9%  |
| `identityserver4-migration`         |    15 | 69/69 (100%)  |  61/69 (88.4%)  | **+11.6%** |    +40.6%  |
| `identityserver-key-management`     |     9 | 37/37 (100%)  |  33/37 (89.2%)  | **+10.8%** |    +50.0%  |
| `oauth-oidc-protocols`              |     8 | 37/37 (100%)  |  33/37 (89.2%)  | **+10.8%** |    +18.9%  |
| `identityserver-token-lifecycle`    |     9 | 40/40 (100%)  |  36/40 (90.0%)  | **+10.0%** |    +36.1%  |
| `identityserver-aspire`             |     7 | 32/32 (100%)  |  30/32 (93.8%)  |  **+6.2%** |    +59.4%  |
| `identityserver-stores`             |    12 | 56/56 (100%)  |  53/56 (94.6%)  |  **+5.4%** |    +25.0%  |
| `aspnetcore-authorization`          |     7 | 31/31 (100%)  |  31/31 (100%)   |  **+0.0%** |    +12.9%  |

**Key findings:**
- **Stronger baseline compresses deltas**: with the latest Opus, the *without-skill* baseline rose from 51.4% (iteration 4) to 77.2%, so headline deltas shrink versus prior runs. Skills still add **+22.8% overall** — a perfect **1079/1079 (100%)** with-skill — and remain decisive wherever knowledge is Duende-specific, newer than the model's training, or easy to get subtly wrong.
- **Highest-value skills** (>30% delta): SAML (+79.1%), User Management (+51.7%), BFF (+49.3%), Token Management (+37.9%), API Protection (+36.7%), Upgrade v7→v8 (+35.3%) — deep Duende-specific API surfaces (`.AddSaml()`/`SamlServiceProvider`, `AddUserManagement`, BFF v4 APIs, `mtls_endpoint_aliases`, v8 license-key format) that a strong generalist still misses or hallucinates.
- **Moderate-value skills** (10–30% delta): DCR, sessions, deployment, token security, testing patterns, hosting, authentication, security hardening, claims, UI flows, configuration, IS4 migration, key management, OAuth/OIDC, token lifecycle — the skill supplies precise option names, edition/version gates, and current-vs-legacy API distinctions on top of correct general knowledge.
- **Near-parity skills** (<10% delta): Aspire, stores, authorization — well-known .NET/ASP.NET Core patterns the base model already handles competently, so the skill mostly adds precision. Notably, `identityserver-stores` eval-5 (Redis-backed config cache) is a case where the skill's current v8 `HybridCache` guidance is *more* correct than the baseline, which reached for the legacy `AddSingleton(typeof(ICache<>), typeof(DistributedCache<>))` pattern that v8 replaced.
- **Perfect with-skill coverage**: every one of the 24 skills scores 100% with the skill loaded (1079/1079 assertions). The stores eval-5 assertion was modernized from the retired v7 `ICache<>`/`DistributedCache<>` registration to the v8 `HybridCache` + distributed Redis backend the skill teaches.
- **Method note**: responses and grading for this iteration were produced by the agent's own Opus model (not GitHub Models); generation and grading share the model, matching the harness default where `--grader-model` equals `--model`.

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
./scripts/bump-version.sh 0.3.0
./scripts/build.sh
git commit -am "Bump version to 0.3.0"
```

Then submit to the plugin directories:

- **ChatGPT/Codex:** https://platform.openai.com/plugins
- **Claude Code:** https://claude.ai/admin-settings/directory/submissions/plugins/

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
|identity:{duende-bff,identity-security-hardening,identityserver-api-protection,identityserver-aspire,identityserver-configuration,identityserver-dcr,identityserver-deployment,identityserver-hosting-setup,identityserver-key-management,identityserver-saml,identityserver-sessions-providers,identityserver-stores,identityserver-token-lifecycle,identityserver-token-security,identityserver-ui-flows,identityserver-upgrade-v7-to-v8,identityserver-usermanagement,identityserver4-migration}
|oauth:{claims-authorization,oauth-oidc-protocols,token-management}
|aspnetcore:{aspnetcore-authentication,aspnetcore-authorization}
|testing:{identity-testing-patterns}
|agents:{identity-server-specialist,oauth-oidc-specialist}
```
<!-- END DUENDE-SKILLS COMPRESSED INDEX -->
