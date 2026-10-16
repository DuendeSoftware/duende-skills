**Not directly.** The guide covers **IdentityServer4** (v3.x/v4.x on ASP.NET Core) only. IdentityServer3 (OWIN/Katana, .NET Framework) is a fundamentally different product: different API surface, configuration model and hosting stack.

What to do:
1. **First port to IdentityServer4 on ASP.NET Core** (ASP.NET Core, new hosting, new configuration model, ApiScope/ApiResource/IdentityResource definitions, stores and UI rewritten).
2. Once you're on IdentityServer4 (v4.x), use the migration guide: .NET upgrade (Duende v7 → net8.0, v8 → net10.0; .NET Framework 4.8 isn't an option), package/namespace replacement, EF schema migration, license key, signing keys, data protection, UI.

If you're on IdentityServer3 you'd be best served by a freshly written Duende host and moving data (clients, scopes, secrets) over, rather than trying an in-place upgrade. Duende offers a free upgrade assessment for planning.
