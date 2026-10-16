## Migration checklist: IdentityServer4 v4.x → Duende IdentityServer

You're already on v4.x (EF Core, ASP.NET Identity, reverse proxy), so you go straight to the single "Stage 2" upgrade. If you were on v3 you'd first need the v3→v4 change (scopes become top-level `ApiScope`s, plus a data-preserving DB migration).

Target: v7 → `net8.0`/EF Core 8; v8 → `net10.0`/EF Core 10.

### Order of work

0. **Baseline.** Back up the databases. Run Duende's **Migration Analysis Tool** (`MigrationAnalysisController.cs`, dropped into the existing IS4 project; replace its placeholder authorization check, browse to `/MigrationAnalysis`). It reports .NET/IS4 version, client inventory (interactive vs. non-interactive, which determines the license edition), `IssuerUri`, signing credential key ID/store, data protection app name and repository, and the registered authentication schemes. Record the old `/.well-known/openid-configuration` (issuer, jwks).
1. **Upgrade the target framework** (`netcoreapp3.1` → `net8.0`/`net10.0`) and EF Core packages.
2. **Replace packages**: `IdentityServer4` → `Duende.IdentityServer`, `.EntityFramework`, `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity`, `IdentityModel` → `Duende.IdentityModel`.
3. **Update namespaces** everywhere (code, config, `.cshtml`, `_ViewImports.cshtml`).
4. **Convert to minimal hosting** (recommended): merge `Startup.cs` into `Program.cs`.
5. **Preserve the issuer URI.** Take the `issuer` from the old discovery document and set `options.IssuerUri` explicitly.
6. **Reverse proxy**: configure forwarded headers (`UseForwardedHeaders`, `X-Forwarded-Proto`/`Host`) before IdentityServer so discovery shows HTTPS and the right host.
7. **License key**: `options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"]`, from a secret store / env var, not source control.
8. **Signing keys**: remove `AddDeveloperSigningCredential()`. If you can restart all clients/APIs, use automatic key management (Business/Enterprise). Otherwise keep the old key (`AddSigningCredential`/validation key) while new keys roll in. Community edition: static `AddSigningCredential`.
9. **Database**: 
   ```bash
   dotnet ef migrations add UpdateToDuende -c PersistedGrantDbContext -o Data/Migrations/IdentityServer/PersistedGrantDb
   dotnet ef migrations add UpdateToDuende -c ConfigurationDbContext -o Data/Migrations/IdentityServer/ConfigurationDb
   dotnet ef database update -c PersistedGrantDbContext
   dotnet ef database update -c ConfigurationDbContext
   ```
   (New tables: `Keys`, `ServerSideSessions`, `PushedAuthorizationRequests`, `IdentityProviders`, etc.; `RedirectUri` shrinks 2000→400 chars.) Test on a copy.
10. **Data Protection**: `SetApplicationName("YourIdentityServer")` explicitly plus a persistent key repository (`PersistKeysToDbContext`, file system, blob...). The default (content root path) differs across .NET versions, which breaks decryption of persisted grants. Share keys across instances.
11. **ASP.NET Identity**: use `Duende.IdentityServer.AspNetIdentity`, keep `AddAspNetIdentity<TUser>()`, update the Identity EF packages and apply Identity migrations.
12. **External authentication handlers**: update WS-Fed, SAML (Sustainsys), social provider packages to versions for the new framework.
13. **UI**: update namespaces, fix API changes (`@using IdentityServer4` → `@using Duende.IdentityServer`) or start fresh with `dotnet new install Duende.Templates` / `dotnet new duende-is-ui`.
14. **Verify**: discovery document, token issuance and validation by APIs, external logins, logs.

Checklist for the proxy: forwarded headers, explicit issuer, HTTPS scheme, same public URL.
