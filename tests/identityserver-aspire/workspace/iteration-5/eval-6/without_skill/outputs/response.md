The clean way to do this in Aspire is a one-shot "migration runner" project that applies the EF Core migrations and then exits. You order the graph so SQL Server comes up first, the runner applies migrations, and only then does IdentityServer start against an already-migrated database.

## AppHost wiring

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql");
var identityDb = sql.AddDatabase("identitydb");

// Migration runner: gets the connection string, waits for SQL to be ready
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sql);

// IdentityServer: still needs the connection string, but starts only after
// the migration runner has finished successfully
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitForCompletion(migrations);

builder.Build().Run();
```

## Notes

- **`WithReference(identityDb)`** on the migration runner injects `ConnectionStrings__identitydb`, which its `DbContext` uses to run `Database.Migrate()`/`MigrateAsync()`.
- **`WaitFor(sql)`** holds the runner until SQL Server is accepting connections.
- **`WaitForCompletion(migrations)`** is the important edge for IdentityServer: unlike `WaitFor` (which waits for a resource to become *healthy/running*), `WaitForCompletion` waits for the migration project to **run to completion and exit successfully**. That's exactly what you want for a one-shot job — IdentityServer won't start until migrations have actually finished.
- IdentityServer keeps its own **`WithReference(identityDb)`** so it still receives the connection string for its stores at runtime — it just no longer needs to (and shouldn't) run migrations itself.

Resulting order:

```
sql ──► migrations (runs, exits) ──► identity-server
```

This centralizes schema management in one place and avoids IdentityServer instances racing to migrate on startup — which matters especially if you later run more than one IdentityServer instance.
