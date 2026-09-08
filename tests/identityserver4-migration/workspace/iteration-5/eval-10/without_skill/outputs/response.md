# Step-by-step migration checklist: IdentityServer4 v4.x → Duende IdentityServer

Since you're already on IdentityServer4 v4.x, you can migrate straight to Duende without the v3→v4 intermediate work. Here's a sensible order for a project with EF Core stores, ASP.NET Identity, and a reverse proxy in front.

## 1. Framework and packages (do first)
1. **Bump the target framework.** Move from `netcoreapp3.1` to a supported LTS such as `net8.0` (Duende v7). This is the foundation for everything else, so do it early and follow the ASP.NET Core migration guidance for each major version.
2. **Swap the NuGet packages.** Replace `IdentityServer4` / `IdentityServer4.EntityFramework` / `IdentityServer4.AspNetIdentity` with the `Duende.IdentityServer*` equivalents, and `IdentityModel` with `Duende.IdentityModel`. Update the `Microsoft.EntityFrameworkCore.*` packages to the matching major version.

## 2. Code
3. **Update namespaces.** Find-and-replace `IdentityServer4` → `Duende.IdentityServer` (and `IdentityModel` → `Duende.IdentityModel`) across `.cs` files and any `.cshtml` `@using` directives. In `Config.cs` that's `using IdentityServer4.Models` → `using Duende.IdentityServer.Models`.
4. **Modernize hosting (optional but recommended).** If you're coming from the `Startup.cs` + `Program.cs` pattern, consider consolidating into the minimal-hosting `Program.cs`. Keep the middleware order `UseRouting` → `UseIdentityServer` → `UseAuthorization`.
5. **Replace the signing credential.** Remove `AddDeveloperSigningCredential()` and rely on Duende's automatic key management (or configure a real certificate).
6. **Configure the license key.** Set `options.LicenseKey` from configuration/secret storage — Duende requires a license for production.

## 3. Database
7. **Create migrations for both stores.** The Duende schema adds tables/columns, so scaffold a migration for each context:
   ```bash
   dotnet ef migrations add ToDuende -c ConfigurationDbContext
   dotnet ef migrations add ToDuende -c PersistedGrantDbContext
   ```
8. **Apply them.**
   ```bash
   dotnet ef database update -c ConfigurationDbContext
   dotnet ef database update -c PersistedGrantDbContext
   ```
   Review each migration before applying and back up the database first.
9. **Pin Data Protection.** Call `SetApplicationName(...)` and persist keys to a durable store so cookies and persisted grants stay decryptable across the framework upgrade.

## 4. Hosting / reverse proxy
10. **Forwarded headers.** Behind a reverse proxy, configure `UseForwardedHeaders` so the discovery document advertises the correct public HTTPS URL and issuer.
11. **Check ASP.NET Identity and external auth handlers** — update any third-party authentication packages to the new .NET version.

## 5. Verify
12. **Hit the discovery endpoint** `/.well-known/openid-configuration` and confirm the issuer, endpoints, and published keys look right.
13. **Test token issuance** — run the client-credentials and authorization-code flows end to end and confirm your APIs validate the tokens.
14. **Watch the logs** for licensing or data-protection warnings.

Following that order — framework, packages, namespaces, code/config, database, proxy, then verification — keeps each step building on a compiling, runnable app.
