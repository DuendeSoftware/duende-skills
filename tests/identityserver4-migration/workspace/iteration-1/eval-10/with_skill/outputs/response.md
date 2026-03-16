# Complete Migration Checklist: IdentityServer4 v4.x → Duende IdentityServer v7

Here is a step-by-step migration checklist in recommended order. Since you use EF Core stores, ASP.NET Identity integration, and deploy behind a reverse proxy, I've included considerations for all of those.

## Pre-Migration

- [ ] **Run the Migration Analysis Tool** — Drop `MigrationAnalysisController.cs` into your running IS4 project and navigate to `/MigrationAnalysis` to get a baseline report of your configuration, client inventory, signing keys, data protection, and authentication schemes.
- [ ] **Inventory clients** — Count interactive (authorization code) vs. non-interactive (client credentials) clients to determine the Duende license edition you need.

## Step 1: Update .NET Target Framework

- [ ] **Update the target framework** from `netcoreapp3.1` to `net8.0` or `net10.0` (LTS). This is one of the first steps because all subsequent package updates depend on the target framework.
- [ ] Follow Microsoft's ASP.NET Core migration guides for each major version jump.

## Step 2: Replace NuGet Packages

- [ ] **Replace IdentityServer4 NuGet packages with Duende equivalents**:
  - `IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`
  - `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity`
  - `IdentityModel` → `Duende.IdentityModel`
- [ ] Update `Microsoft.EntityFrameworkCore.*` packages to match the new target framework.

## Step 3: Update Namespaces

- [ ] **Update all namespaces from `IdentityServer4` to `Duende.IdentityServer`** across all `.cs` and `.cshtml` files. Search and replace `using IdentityServer4` with `using Duende.IdentityServer`.

## Step 4: Convert to Minimal Hosting

- [ ] Convert the `Startup.cs` + `Program.cs` pattern to `WebApplication.CreateBuilder` minimal hosting model.

## Step 5: Preserve Issuer URI

- [ ] **Set `options.IssuerUri` explicitly** to match the current issuer value from `/.well-known/openid-configuration`. Critical when changing hosting infrastructure.

## Step 6: Configure License Key

- [ ] **Configure a Duende IdentityServer license key** via `options.LicenseKey` loaded from a secret manager or environment variable. Never store in source-controlled `appsettings.json`.

## Step 7: Update Signing Keys

- [ ] Remove `AddDeveloperSigningCredential()` — use Duende's automatic key management (Business/Enterprise) or a static signing credential.

## Step 8: Create and Apply Database Migrations

- [ ] **Create EF Core migrations for both `ConfigurationDbContext` and `PersistedGrantDbContext`**:
  ```bash
  dotnet ef migrations add UpdateToDuende_v7 -c ConfigurationDbContext
  dotnet ef migrations add UpdateToDuende_v7 -c PersistedGrantDbContext
  ```
- [ ] Apply migrations to your database.

## Step 9: Configure Data Protection

- [ ] Set `SetApplicationName()` with an explicit, stable name on `AddDataProtection()`.
- [ ] Ensure persistent key storage is configured (`PersistKeysToDbContext`, etc.).

## Step 10: Verify Authentication Schemes

- [ ] Update third-party authentication handler NuGet packages for the new .NET version.
- [ ] Test all external login flows (Google, WS-Fed, SAML2P, etc.).

## Step 11: Update UI Templates

- [ ] Update `@using IdentityServer4` directives in `.cshtml` files to `@using Duende.IdentityServer`.
- [ ] Consider scaffolding fresh Duende UI templates with `dotnet new duende-is-ui`.

## Step 12: Verify Deployment

- [ ] **Check the discovery document** at `/.well-known/openid-configuration` — verify the issuer, endpoints, and signing keys are correct.
- [ ] **Test token issuance and validation** end-to-end with your clients and APIs.
- [ ] **Configure forwarded headers** for reverse proxy (if not already done).
- [ ] **Check application logs** for warnings or errors on startup.
