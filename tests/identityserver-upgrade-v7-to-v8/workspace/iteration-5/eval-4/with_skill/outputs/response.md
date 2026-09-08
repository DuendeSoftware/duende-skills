# Yes — you still need to run EF migrations, even without SAML

The runtime errors about missing tables are expected. In v8 the IdentityServer EF schema was extended with new **SAML-related tables**, and EF compares the expected schema against your database regardless of whether you actually use SAML. Because your database is still on the v7 schema, queries against the missing tables fail at runtime. The fix is to add and apply the v8 migrations.

## Why this happens

v8 adds SAML support, and that added tables to both the **Configuration Store** and the **Operational Store**. The `DbContext` model now includes those entities, so the schema in your database must match — even a non-SAML deployment must have the tables present.

## Configuration Store migration

```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0 \
    -c ConfigurationDbContext -o Migrations/ConfigurationDb
dotnet ef database update -c ConfigurationDbContext
```

## Operational Store migration

Your `Program.cs` uses `AddOperationalStore`, so you also need the operational-store migration for the new SAML session tables:

```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0_Saml \
    -c PersistedGrantDbContext -o Migrations/PersistedGrantDb
dotnet ef database update -c PersistedGrantDbContext
```

## Summary

- **Migrations are required even if you don't use SAML** — the schema must match the v8 model or EF throws at runtime.
- Run `dotnet ef migrations add ...` to generate the migration, then `dotnet ef database update ...` to apply it.
- Do this for every `DbContext` you use (`ConfigurationDbContext` and/or `PersistedGrantDbContext`).

After applying the migrations, the missing-table errors will go away.
