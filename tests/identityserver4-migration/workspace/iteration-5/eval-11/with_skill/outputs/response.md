# Can you use the IdentityServer4 → Duende guide for IdentityServer3?

**No.** This migration path covers **IdentityServer4 only** (v3.x and v4.x). It does **not** cover **IdentityServer3**, which is what you're running on .NET Framework 4.8 with OWIN/Katana.

## Why IdentityServer3 is out of scope

IdentityServer3 is a **fundamentally different product**, not an earlier point release of the same codebase:

- **Hosting stack:** IdentityServer3 runs on **OWIN/Katana** on the **full .NET Framework**. IdentityServer4 (and its successor, Duende IdentityServer) run on **ASP.NET Core**.
- **API surface & configuration model:** completely different — different service registration, different options, different middleware, different extensibility points. There is no namespace-rename shortcut between IS3 and IS4 the way there is between IS4 and Duende.
- **UI and endpoints:** different embedded assets and hosting model.

Because of that, the Duende migration guidance (swap `IdentityServer4.*` packages for `Duende.IdentityServer.*`, update namespaces, migrate EF schema, etc.) simply doesn't apply to an IS3 codebase.

> ⚠️ **Don't confuse "IdentityServer3" with "IdentityServer4 v3.x."** They are different things. IdentityServer4 had its own version numbers (v1, v2, v3, v4) — "IdentityServer4 v3.x" is still IdentityServer4 on ASP.NET Core and *is* covered by this guide. "IdentityServer3" is the older Thinktecture OWIN/Katana product and is *not*.

## What to do instead

You need a **two-hop migration**:

1. **First, port IdentityServer3 → IdentityServer4** on ASP.NET Core. This is the larger, more involved step: re-platform from OWIN/Katana on .NET Framework to ASP.NET Core, rewrite your host/startup, re-express clients/resources in the IS4 configuration model, and migrate your UI. Follow the historical IdentityServer3 → IdentityServer4 upgrade guidance for this.
2. **Then, migrate IdentityServer4 → Duende IdentityServer** using this guide (packages, namespaces, .NET target framework, EF Core schema, license key, etc.).

There is no supported one-step jump from IdentityServer3 directly to Duende IdentityServer — get onto IdentityServer4 on ASP.NET Core first.
