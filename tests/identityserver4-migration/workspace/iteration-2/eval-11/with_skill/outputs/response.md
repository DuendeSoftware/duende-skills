# IdentityServer3 on .NET Framework — Not Covered by This Migration Guide

**No — this migration guide does not cover IdentityServer3.** It covers IdentityServer4 only.

## IdentityServer3 ≠ IdentityServer4

IdentityServer3 and IdentityServer4 are **fundamentally different products**:

| | IdentityServer3 | IdentityServer4 |
|---|---|---|
| **Hosting** | OWIN/Katana middleware | ASP.NET Core middleware |
| **Runtime** | .NET Framework 4.x | .NET Core / .NET 5+ |
| **NuGet package** | `IdentityServer3` (Thinktecture) | `IdentityServer4` |
| **Configuration model** | Factory pattern, `IdentityServerServiceFactory` | ASP.NET Core DI, `IServiceCollection` |
| **API surface** | Completely different | Basis for Duende IdentityServer |

These are not different versions of the same product — they are separate products with different architectures.

## What You Need to Do

You must first **port from IdentityServer3 to IdentityServer4 on ASP.NET Core**, which involves:

1. Migrating from .NET Framework 4.8 to .NET Core / .NET 5+
2. Replacing the OWIN/Katana hosting with ASP.NET Core middleware
3. Rewriting your configuration from the IdentityServer3 factory pattern to ASP.NET Core DI
4. Migrating your database schema from IdentityServer3 to IdentityServer4

Once you are running IdentityServer4 on ASP.NET Core, **then** you can use this migration guide to upgrade from IdentityServer4 to Duende IdentityServer.

## Important: Don't Confuse IdentityServer3 with IdentityServer4 v3.x

- **IdentityServer3** = the Thinktecture product on .NET Framework (OWIN/Katana)
- **IdentityServer4 v3.x** = version 3 of IdentityServer4 on ASP.NET Core

This guide covers IdentityServer4 v3.x → v4.x → Duende, but NOT the Thinktecture IdentityServer3 product.
