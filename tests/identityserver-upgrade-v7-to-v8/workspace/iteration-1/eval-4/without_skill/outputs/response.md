# Database Migrations After IdentityServer v8 Upgrade

When upgrading a major version of IdentityServer that uses EF Core, it's generally a good practice to check if schema changes are required. Even if you don't use new features like SAML, there might be structural changes to existing tables.

## Recommended Steps

1. Try generating a migration to see if there are schema differences:

```bash
dotnet ef migrations add UpgradeToV8 -c ConfigurationDbContext
```

2. Inspect the generated migration file — if it's empty, no changes are needed. If it contains table additions or modifications, you need to apply it.

3. Apply the migration:

```bash
dotnet ef database update
```

## Why You Might Still Need Migrations

Major version upgrades often include:
- New columns on existing tables
- New tables for new features
- Index changes for performance

Even if you don't plan to use the new features, the DbContext model in the updated package will expect the schema to match. EF Core validates the model against the database schema and will throw errors if they don't align.

## Best Practice

Always generate a migration after a major package upgrade and inspect what changed before applying it to production.
