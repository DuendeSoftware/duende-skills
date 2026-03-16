# Database Migrations After Duende IdentityServer Upgrade

After upgrading, you'll need to create EF Core migrations to update the database schema.

## Creating Migrations

```bash
dotnet ef migrations add DuendeUpgrade -c PersistedGrantDbContext
dotnet ef migrations add DuendeUpgrade -c ConfigurationDbContext
```

Then apply them:

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

## Expected Schema Changes

Duende IdentityServer adds several new tables and columns compared to IdentityServer4:

- **Keys table** — for automatic key management
- **ServerSideSessions table** — for server-side session support
- Various new columns on existing client and resource tables

Review the generated migration code carefully before applying to production databases.
