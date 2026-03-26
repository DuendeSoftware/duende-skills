# IdentityServer3 on .NET Framework 4.8 — Migration Path

## This Guide Does NOT Cover IdentityServer3

This migration skill covers **IdentityServer4** (the ASP.NET Core-based product) → Duende IdentityServer. It does **not** cover **IdentityServer3**.

IdentityServer3 and IdentityServer4 are **fundamentally different products**:

| | IdentityServer3 | IdentityServer4 |
|---|---|---|
| **Framework** | .NET Framework 4.5+ | .NET Core / ASP.NET Core |
| **Hosting** | OWIN/Katana middleware | ASP.NET Core middleware |
| **NuGet Package** | `Thinktecture.IdentityServer3` / `IdentityServer3` | `IdentityServer4` |
| **Configuration API** | `IdentityServerServiceFactory` | `IServiceCollection` DI extensions |
| **Maintainer** | Thinktecture → Brock Allen & Dominick Baier | Brock Allen & Dominick Baier → Duende Software |

These are completely different codebases with different APIs, configuration models, and hosting stacks. There is no direct upgrade path from IdentityServer3 to Duende IdentityServer.

## Required Migration Path

You must migrate in two stages:

### Stage 1: IdentityServer3 → IdentityServer4

1. **Port your application from .NET Framework to ASP.NET Core** — This is the biggest step. You need to migrate from OWIN/Katana to ASP.NET Core middleware.
2. **Rewrite your IdentityServer configuration** — IdentityServer4 uses a completely different configuration API (`AddIdentityServer()` with builder extensions vs. `IdentityServerServiceFactory`).
3. **Migrate your data stores** — If using EF-based stores, the database schema is different.
4. **Update your client and resource definitions** — The model types have similar concepts but different class structures.
5. **Target .NET Core 3.1 or .NET 5** initially for IdentityServer4 compatibility.

### Stage 2: IdentityServer4 → Duende IdentityServer

Once you have a working IdentityServer4 project on ASP.NET Core, **then** use this migration guide to upgrade to Duende IdentityServer. This second stage is much simpler — primarily namespace and package renames with database schema additions.

## Important

Do not attempt to skip directly from IdentityServer3 to Duende IdentityServer. The technology stack change (.NET Framework + OWIN → ASP.NET Core) is a fundamental rewrite, not an upgrade. Plan the IdentityServer3 → IdentityServer4 migration as a separate project.
