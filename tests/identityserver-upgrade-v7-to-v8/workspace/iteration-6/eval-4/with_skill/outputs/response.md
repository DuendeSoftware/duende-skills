# Missing tables after upgrading to v8

**Yes, you still need to run the migrations, even without SAML.** v8 adds SAML tables to both stores, and the EF model expects them whether or not you use SAML. The schema must match, so EF fails at runtime with missing-table errors.

- **Configuration store:** 7 SAML-related tables.
- **Operational store:** 3 SAML session tables.

```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 \
    -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext

dotnet ef migrations add Update_DuendeIdentityServer_v8_0_Saml \
    -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```

Both migrations are required. In production, generate scripts (`dotnet ef migrations script`) and review them. Back up first.

Also check your csproj. Your project file still references `7.4.0` and `net8.0`. For v8 you need `net10.0` and the latest stable 8.x of `Duende.IdentityServer` and `Duende.IdentityServer.EntityFramework`, and the EF Core packages updated to match.

If you also use `IUserSession` implementations, v8 adds `AddSamlSessionAsync`, `GetSamlSessionListAsync` and `RemoveSamlSessionAsync`. Implement them as no-ops if you don't use SAML.
