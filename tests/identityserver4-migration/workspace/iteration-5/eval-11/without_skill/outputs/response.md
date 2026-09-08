# Using an IdentityServer4 → Duende guide for an IdentityServer3 project

Short answer: **not directly.** A guide written for migrating IdentityServer4 to Duende IdentityServer assumes you're already on IdentityServer4, and that doesn't describe your project. You're on **IdentityServer3**, which is a different product.

## IdentityServer3 vs. IdentityServer4

These are not two versions of the same thing — they were rebuilt from scratch:

- **IdentityServer3** targets the **.NET Framework** and is hosted with **OWIN/Katana** middleware. That's your 4.8 project.
- **IdentityServer4** was a ground-up rewrite for **ASP.NET Core**, with a different hosting model, different configuration API, and different extensibility surface.

Duende IdentityServer is the continuation of IdentityServer4, so all the "just rename the packages and namespaces" advice you'll see for the IS4→Duende move relies on the ASP.NET Core foundation that IS3 doesn't have. None of that applies cleanly to an OWIN/Katana app.

One thing worth calling out to avoid confusion: **"IdentityServer3" is not the same as "IdentityServer4 version 3.x."** IdentityServer4 had its own 1.x–4.x release line, all on ASP.NET Core. The product named IdentityServer3 is the older OWIN/.NET Framework one. Make sure you're actually on IS3 (Katana/OWIN, `Thinktecture`/`IdentityServer3` packages) and not just an older IS4 release, because the paths are very different.

## Recommended route

Plan for **two stages**:

1. **Re-platform IdentityServer3 → IdentityServer4 on ASP.NET Core.** This is effectively a rewrite of the host: move off OWIN/Katana and .NET Framework onto ASP.NET Core, re-create your clients, scopes, and resources in the IS4 model, and port your login/consent UI. Use the older IdentityServer3-to-IdentityServer4 migration material for this part.
2. **Then migrate IdentityServer4 → Duende IdentityServer** using the guide you have (package swaps, namespace changes, framework bump, EF migrations, licensing).

There isn't a supported single leap from IS3 straight to Duende — you have to land on IdentityServer4 (ASP.NET Core) in between.
