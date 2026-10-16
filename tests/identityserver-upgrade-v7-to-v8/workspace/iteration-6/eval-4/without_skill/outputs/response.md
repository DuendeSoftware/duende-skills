# Missing tables after moving to v8

**Yes, run the migrations.** Major versions of `Duende.IdentityServer.EntityFramework` usually change the operational and configuration store schemas. Not using a particular feature, such as SAML, does not exempt you. EF maps every entity in the model, so if v8 added tables (possibly for SAML service providers, new session or key storage) and the model queries them, you get "invalid object name" errors even if you never use the feature.

Steps:
1. Check that you actually reference v8 packages. Your csproj still shows `7.4.0`.
2. Add migrations for each context:
```bash
dotnet ef migrations add Upgrade_v8 -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef migrations add Upgrade_v8 -c ConfigurationDbContext -o Migrations/ConfigurationDb
```
3. Review the generated SQL (`dotnet ef migrations script`), then apply it with `dotnet ef database update`. In production, use a script or a migration bundle.
4. Back up the database first.
