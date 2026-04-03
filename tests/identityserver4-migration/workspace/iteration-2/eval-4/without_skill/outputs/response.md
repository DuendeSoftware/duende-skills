# Database Migrations for Duende IdentityServer

After upgrading to Duende IdentityServer, you'll need to create database migrations to update the schema.

## Create Migrations

```bash
dotnet ef migrations add UpgradeToDuende -c PersistedGrantDbContext
dotnet ef migrations add UpgradeToDuende -c ConfigurationDbContext
```

Then apply:

```bash
dotnet ef database update -c PersistedGrantDbContext
dotnet ef database update -c ConfigurationDbContext
```

## Schema Changes

Duende IdentityServer introduces some new tables and columns compared to IdentityServer4:

- **Keys table** — for automatic key management, storing signing keys
- New columns on various tables for additional features
- Updated indexes for performance

The migration should handle these changes automatically. Review the generated migration code before applying to ensure no data loss.

I'd recommend backing up your database before applying any migrations, and testing in a staging environment first.
