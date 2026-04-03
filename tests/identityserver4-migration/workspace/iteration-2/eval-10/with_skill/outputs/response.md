# Migration Checklist: IdentityServer4 v4.x → Duende IdentityServer v7

## Step 0: Pre-Migration Analysis
- [ ] **Run the Migration Analysis Tool** — Add `MigrationAnalysisController.cs` to your IS4 project, navigate to `/MigrationAnalysis` to get a baseline report
- [ ] **Inventory clients** — Count interactive (authorization_code) vs. non-interactive (client_credentials) for license edition selection

## Step 1: Update .NET Target Framework
- [ ] **Update target framework** from `netcoreapp3.1` or `net5.0` to `net8.0` or `net10.0` (LTS)
- [ ] Follow Microsoft ASP.NET Core migration guides for each major version jump
- [ ] Update all `Microsoft.EntityFrameworkCore.*` packages to match the new framework version

## Step 2: Replace NuGet Packages
- [ ] **Replace `IdentityServer4.EntityFramework`** with `Duende.IdentityServer.EntityFramework`
- [ ] **Replace `IdentityServer4.AspNetIdentity`** with `Duende.IdentityServer.AspNetIdentity` (if used)
- [ ] **Replace `IdentityModel`** with `Duende.IdentityModel` (if used)
- [ ] Update all other IdentityServer4 packages to Duende equivalents

## Step 3: Update Namespaces
- [ ] **Search and replace** `IdentityServer4` → `Duende.IdentityServer` across all `.cs` and `.cshtml` files
- [ ] **Replace** `IdentityModel` → `Duende.IdentityModel`
- [ ] Update `@using` directives in `_ViewImports.cshtml` and Razor views

## Step 4: Convert to Minimal Hosting (Recommended)
- [ ] Convert `Startup.cs` + `Program.cs` to a single `Program.cs` using `WebApplication.CreateBuilder`

## Step 5: Configure License Key
- [ ] **Configure license key** via `options.LicenseKey` loaded from configuration/secret manager
- [ ] Ensure the key is NOT in source-controlled `appsettings.json`

## Step 6: Remove AddDeveloperSigningCredential
- [ ] Remove `AddDeveloperSigningCredential()` — use Duende automatic key management or a static credential

## Step 7: Preserve Issuer URI
- [ ] Verify the issuer URI matches the existing deployment
- [ ] Set `options.IssuerUri` explicitly if needed

## Step 8: Configure Data Protection
- [ ] Set `SetApplicationName()` explicitly on `AddDataProtection()`
- [ ] Ensure persistent key storage is configured
- [ ] Verify old Data Protection keys are accessible

## Step 9: Create and Apply Database Migrations
- [ ] **Create migration for `ConfigurationDbContext`**: `dotnet ef migrations add UpdateToDuende_v7 -c ConfigurationDbContext`
- [ ] **Create migration for `PersistedGrantDbContext`**: `dotnet ef migrations add UpdateToDuende_v7 -c PersistedGrantDbContext`
- [ ] Review generated migrations for data safety
- [ ] Apply migrations: `dotnet ef database update`

## Step 10: Verify Authentication Schemes
- [ ] Update third-party auth handler NuGet packages for the new .NET version
- [ ] Test all external login flows end-to-end

## Step 11: Update UI Templates
- [ ] Scaffold fresh Duende templates: `dotnet new install Duende.Templates && dotnet new duende-is-ui`
- [ ] Or update namespaces in existing `.cshtml` files

## Step 12: Verification
- [ ] **Verify discovery document** at `/.well-known/openid-configuration` — check issuer, JWKS, endpoints
- [ ] **Test token issuance** — request tokens via client credentials and authorization code flows
- [ ] **Test token validation** — ensure APIs accept the new tokens
- [ ] **Check application logs** for warnings or errors
