# EF Migrations Required in v8 (Even Without SAML)

Yes, **EF migrations are required even if you don't use SAML**. IdentityServer v8 adds 5 SAML-related tables to the database schema, and Entity Framework will throw runtime errors if the schema doesn't match.

## Run the Migration

```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 -c ConfigurationDbContext
dotnet ef database update
```

If you also use the `PersistedGrantDbContext`:

```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 -c PersistedGrantDbContext
dotnet ef database update
```

## Why This Is Required

The v8 schema includes new SAML-related tables that EF Core expects to exist. Even if you never use SAML features, the `ConfigurationDbContext` model has been updated to include these tables. Without the migration, you'll get runtime errors about missing tables when EF tries to validate the model against the database.

## Common Pitfall

This is one of the most common issues during v8 upgrades — people skip the migration thinking it's optional since they don't use SAML, then get cryptic runtime errors about missing database objects.
