# IdentityServer4 v4.x → Duende IdentityServer v7/v8 migration checklist

You're on IdentityServer4 v4.x with EF Core stores, ASP.NET Identity, and a reverse proxy — so you go **directly to Stage 2** (no v3→v4 API restructuring needed). Follow the steps in this order.

## 0. Baseline (before touching code)
- [ ] **Run the Migration Analysis Tool** against your running IS4 instance (`MigrationAnalysisController.cs` dropped into the project, browse to `/MigrationAnalysis`). It reports your .NET version, IS4 version, client counts (interactive vs. non-interactive → license edition), issuer URI, signing store, and data protection setup.
- [ ] **Inventory clients** — interactive (`authorization_code`) vs. non-interactive (`client_credentials`) — to pick the license edition.

## 1. Framework and packages
- [ ] **Update the .NET target framework** — from `netcoreapp3.1` to a current LTS (`net8.0` for Duende v7, `net10.0` for Duende v8). Do this first; follow Microsoft's ASP.NET Core migration guides for each major hop.
- [ ] **Replace NuGet packages** — `IdentityServer4.*` → `Duende.IdentityServer.*` (`IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`, `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity`, `IdentityModel` → `Duende.IdentityModel`). Bump `Microsoft.EntityFrameworkCore.*` to match the framework.

## 2. Code changes
- [ ] **Update namespaces** — `IdentityServer4` → `Duende.IdentityServer`, `IdentityModel` → `Duende.IdentityModel`, across `.cs` and `.cshtml` files (in `Config.cs`, `using IdentityServer4.Models` → `using Duende.IdentityServer.Models`).
- [ ] **Convert to minimal hosting** — fold `Startup.cs` + `Program.cs` into a single `Program.cs` using `WebApplication.CreateBuilder` (keep the same middleware order: `UseRouting` → `UseIdentityServer` → `UseAuthorization`).
- [ ] **Remove `AddDeveloperSigningCredential()`** — use Duende automatic key management (or a static `AddSigningCredential`).
- [ ] **Preserve the issuer URI** — set `options.IssuerUri` to match your existing deployment, especially important since you're behind a reverse proxy.
- [ ] **Configure the license key** — `options.LicenseKey` loaded from configuration / secret manager (never source-controlled `appsettings.json`).

## 3. Data and infrastructure
- [ ] **Create and apply EF Core migrations for both contexts** —
  ```bash
  dotnet ef migrations add UpdateToDuende -c ConfigurationDbContext -o Migrations/ConfigurationDb
  dotnet ef migrations add UpdateToDuende -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
  dotnet ef database update -c ConfigurationDbContext
  dotnet ef database update -c PersistedGrantDbContext
  ```
  New tables: `Keys`, `ServerSideSessions`, `PushedAuthorizationRequests`, `IdentityProviders`; new client columns for DPoP/PAR.
- [ ] **Configure Data Protection** — `SetApplicationName("YourIdentityServer")` + a persistent key repository (`PersistKeysToDbContext`/file system/blob). Critical behind a reverse proxy and across .NET versions so persisted grants and cookies keep decrypting.
- [ ] **Configure forwarded headers** — behind nginx/reverse proxy, add `UseForwardedHeaders` so the discovery document reflects the correct external HTTPS scheme/host.
- [ ] **Migrate signing keys** — restart all relying parties to pick up the new key, or keep the old key for validation during a transition.

## 4. UI and auth
- [ ] **Update UI templates** — update `@using IdentityServer4` → `@using Duende.IdentityServer` in `_ViewImports.cshtml`/views, fix v4 API changes; consider scaffolding fresh Duende templates (`dotnet new duende-is-ui`). Skip if the project has no UI.
- [ ] **Verify ASP.NET Identity integration** and any third-party auth handlers — update their NuGet packages to match the new .NET version.

## 5. Verify (after deploy)
- [ ] **Check the discovery document** at `/.well-known/openid-configuration` — confirm the `issuer`, `jwks_uri`, endpoints, and that keys are published.
- [ ] **Test token issuance and validation** end-to-end — client-credentials token for `m2m.client`, authorization-code + PKCE flow for `interactive.client`, and confirm APIs accept the tokens.
- [ ] **Check application logs** for licensing or data-protection warnings.

**Rough order:** framework → packages → namespaces → hosting/signing/issuer/license → DB migrations + data protection + forwarded headers → UI/auth → verify.
