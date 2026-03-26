# Complete Migration Checklist: IdentityServer4 v4.x → Duende IdentityServer v7

Here is a comprehensive, ordered migration checklist based on your project (EF Core stores, ASP.NET Identity, reverse proxy deployment):

## Phase 1: Preparation

- [ ] **Run the Migration Analysis Tool** — Drop `MigrationAnalysisController.cs` into your running IS4 project and navigate to `/MigrationAnalysis`. Review the report for your .NET version, client inventory, signing key configuration, and data protection settings.
- [ ] **Inventory your clients** — Count interactive (authorization_code) vs. non-interactive (client_credentials) clients to determine the Duende license edition you need.
- [ ] **Back up your database** — Take a full backup of both the configuration and operational databases before any changes.
- [ ] **Record current issuer URI** — Check `/.well-known/openid-configuration` and note the `issuer` value.

## Phase 2: Project and Package Updates

- [ ] **Update the .NET target framework** — Change `<TargetFramework>netcoreapp3.1</TargetFramework>` to `<TargetFramework>net8.0</TargetFramework>` (or `net10.0`). Follow Microsoft's ASP.NET Core migration guides for each major version jump.
- [ ] **Replace IdentityServer4 NuGet packages with Duende equivalents**:
  - `IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`
  - `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity`
  - `IdentityModel` → `Duende.IdentityModel` (if used)
- [ ] **Update EF Core and ASP.NET Core packages** to match the target framework version (e.g., `Microsoft.EntityFrameworkCore.SqlServer` 8.0.x for net8.0).

## Phase 3: Code Changes

- [ ] **Update all namespaces** — Search and replace `IdentityServer4` → `Duende.IdentityServer` across all `.cs` and `.cshtml` files. Replace `using IdentityModel;` with `using Duende.IdentityModel;`.
- [ ] **Convert to minimal hosting** — Replace `Startup.cs` + `Program.cs` with a single `Program.cs` using `WebApplication.CreateBuilder`.
- [ ] **Remove `AddDeveloperSigningCredential()`** — Duende's automatic key management replaces it. No explicit call needed.
- [ ] **Set the issuer URI explicitly** — `options.IssuerUri = "https://identity.example.com";` to match the value you recorded in Phase 1.
- [ ] **Configure the license key** — `options.LicenseKey = builder.Configuration["IdentityServer:LicenseKey"];` — store in a secret manager, not in source-controlled files.
- [ ] **Configure Data Protection** — Add `SetApplicationName("YourApp")` to `AddDataProtection()` to prevent key isolation issues after the .NET upgrade.

## Phase 4: Database Migration

- [ ] **Create EF Core migrations for both contexts**:
  ```bash
  dotnet ef migrations add UpdateToDuende_v7 -c ConfigurationDbContext
  dotnet ef migrations add UpdateToDuende_v7 -c PersistedGrantDbContext
  ```
- [ ] **Review the generated migrations** — Verify they don't drop existing tables or columns.
- [ ] **Apply migrations** to a staging database first, then production.

## Phase 5: Authentication and UI

- [ ] **Update third-party authentication handlers** — WS-Federation, SAML2P, and social providers need NuGet package updates for the new .NET version.
- [ ] **Update UI templates** — Either scaffold fresh Duende UI (`dotnet new duende-is-ui`) and port customizations, or incrementally update namespaces in existing Razor views.

## Phase 6: Verification

- [ ] **Verify the discovery document** — Navigate to `/.well-known/openid-configuration` and confirm the `issuer`, `jwks_uri`, and supported endpoints are correct.
- [ ] **Test token issuance** — Request tokens using your m2m and interactive clients. Verify the `iss` claim matches the expected issuer.
- [ ] **Test token validation** — Ensure APIs can validate the new tokens.
- [ ] **Test external login flows** — Verify Google, WS-Fed, SAML, and any other external providers still work.
- [ ] **Check application logs** — Look for any warnings or errors from IdentityServer on startup.
- [ ] **Test refresh token flows** — Verify existing refresh tokens (if Data Protection is configured correctly) still work.
