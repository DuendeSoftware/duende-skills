# Yes — missing-table errors mean you need to run migrations

Those runtime errors ("Invalid object name" / missing tables) almost always mean your database schema is out of sync with the EF model. When you upgraded the Duende packages to v8, the `DbContext` model that ships with IdentityServer very likely changed (new or altered entities), so your v7 database no longer matches. EF doesn't care which *features* you use — it validates the whole schema — so **not using SAML doesn't exempt you**. You still need to migrate.

## How to fix it

Generate a migration for each IdentityServer `DbContext` you use, then apply it. Based on your `Program.cs` you're using the operational store (`PersistedGrantDbContext`); if you also register the configuration store, migrate that too.

```bash
# create the migration (name is up to you)
dotnet ef migrations add UpgradeToDuende8 \
    -c PersistedGrantDbContext -o Migrations/PersistedGrantDb

# apply it to the database
dotnet ef database update -c PersistedGrantDbContext
```

Repeat with `-c ConfigurationDbContext` if you use the configuration store.

## Why "I don't use SAML" doesn't matter

Migrations bring the physical database in line with the EF model. If v8's model added tables or columns, those objects must exist even if your app never touches them at runtime — otherwise EF's queries reference schema that isn't there and you get the errors you're seeing.

## Recommendation

- Run `dotnet ef migrations add ...` then `dotnet ef database update ...` for each context.
- Inspect the generated migration before applying it in production, and back up the database first.
- Check the official Duende 8.0 upgrade guide for the exact set of schema changes so you know what the migration will add — I can't enumerate them precisely from memory.
