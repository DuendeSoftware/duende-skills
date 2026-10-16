## Migration checklist (IdentityServer4 v4.x → Duende IdentityServer v7)

1. **Prepare**: back up databases, put code in source control, inventory customizations (custom stores, services, extension grants, UI), and read Duende's migration guide. Obtain a Duende license.
2. **Upgrade the framework**: netcoreapp3.1 → net8.0 (v7 requires .NET 8+). Fix breaking ASP.NET Core changes; consider moving to the minimal hosting model.
3. **Update packages**: `IdentityServer4` → `Duende.IdentityServer`, `IdentityServer4.EntityFramework` → `Duende.IdentityServer.EntityFramework`, `IdentityServer4.AspNetIdentity` → `Duende.IdentityServer.AspNetIdentity`, `IdentityModel` → `Duende.IdentityModel`; EF Core to 8.x.
4. **Namespaces**: replace `IdentityServer4.*` with `Duende.IdentityServer.*` everywhere, including Razor `_ViewImports.cshtml`.
5. **Code changes**: adjust for API changes (e.g. interfaces like `IProfileService`, `IPersistedGrantStore` additions, async changes), and review default behavior changes.
6. **Signing keys**: replace `AddDeveloperSigningCredential` with real keys or automatic key management; keep the old key as validation key so existing tokens still validate during rollover.
7. **Issuer URI**: set `IssuerUri` explicitly or make sure forwarded headers produce the same issuer as before.
8. **Reverse proxy**: configure `UseForwardedHeaders` (X-Forwarded-For/Proto/Host) early in the pipeline, and trust known proxies; ensure HTTPS scheme is seen so cookies/redirects are correct.
9. **Database**: create and apply EF migrations for both ConfigurationDbContext and PersistedGrantDbContext (new columns/tables in newer versions); test on a copy first.
10. **ASP.NET Identity**: update `AddAspNetIdentity<ApplicationUser>()`, migrate Identity schema for the new EF/Identity version, and verify password hashing compatibility.
11. **Data protection**: keep the same application name and key ring persisted/shared so cookies and encrypted data still decrypt.
12. **License key**: add `LicenseKey` to options.
13. **UI**: update quickstart UI controllers/views to new namespaces.
14. **Test**: run flows (code+PKCE, client credentials, refresh, logout), token validation by APIs, then deploy to staging, then production with rollback plan.
