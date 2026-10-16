I can't confirm "Duende Storage" tooling, so this is the general pattern, using EF Core migrations as the example.

**Principle**: the app's runtime login only has DML (SELECT/INSERT/UPDATE/DELETE); a separate migration identity with DDL rights runs in the pipeline.

1. Generate idempotent SQL scripts per provider:
```
dotnet ef migrations script --idempotent -c ConfigurationDbContext -o config.sql
dotnet ef migrations script --idempotent -c PersistedGrantDbContext -o operational.sql
```
Do this once per provider (PostgreSQL and Oracle), each with its own provider-specific migrations assembly.
2. In CI/CD, run the scripts with `psql -f` for PostgreSQL and `sqlplus` / SQLcl for Oracle, using a DDL-capable service account from the secrets store.
3. Or build an EF migration bundle: `dotnet ef migrations bundle`.
4. Grant the app account DML only on the resulting tables, and remove any `Database.Migrate()` on startup.
5. Run the migration step before the app deploy, and keep the scripts under review as pipeline artifacts.
