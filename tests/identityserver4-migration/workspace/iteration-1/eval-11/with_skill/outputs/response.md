# IdentityServer3 on .NET Framework 4.8 — Migration Path

**No — this migration guide does not cover IdentityServer3.** The guide is specifically for migrating from **IdentityServer4** (v3.x and v4.x) to Duende IdentityServer.

## Why IdentityServer3 Is Different

**IdentityServer3** (the `Thinktecture.IdentityServer3` / `IdentityServer3` NuGet package) is a **fundamentally different product** from IdentityServer4. Key differences:

- **Hosting stack**: IdentityServer3 runs on **OWIN/Katana** on **.NET Framework** — not ASP.NET Core
- **Configuration model**: Completely different API surface for clients, scopes, and resources
- **Middleware pipeline**: OWIN middleware vs. ASP.NET Core middleware
- **Dependency injection**: No built-in DI container (or uses Autofac) vs. ASP.NET Core's `IServiceCollection`

IdentityServer3 and IdentityServer4 v3.x are **not the same thing**. IdentityServer4 v3.x is a version of IdentityServer4 that runs on ASP.NET Core and .NET Core 3.1. IdentityServer3 is the predecessor product that only runs on .NET Framework.

## Recommended Migration Path

You need a **two-stage migration**:

1. **Stage 1: IdentityServer3 → IdentityServer4 on ASP.NET Core**
   - Port your application from .NET Framework 4.8 to ASP.NET Core
   - Replace OWIN/Katana middleware with ASP.NET Core middleware
   - Rewrite the IdentityServer configuration using the IdentityServer4 API surface
   - Migrate your data stores (clients, scopes, persisted grants)
   - This is the harder stage — it's effectively a rewrite of the hosting layer

2. **Stage 2: IdentityServer4 → Duende IdentityServer**
   - Once on IdentityServer4 (ASP.NET Core), use this migration guide to upgrade to Duende IdentityServer v7
   - This stage is primarily namespace/package renames and database schema updates

Duende also offers a [free upgrade assessment](https://duendesoftware.com) that can help you plan the full migration path from IdentityServer3.
