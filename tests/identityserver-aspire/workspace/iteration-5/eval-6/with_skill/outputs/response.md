A dedicated migration runner keeps schema changes out of IdentityServer's own startup path. You model it in the AppHost as a project that sits **between** SQL Server and IdentityServer in the dependency chain: SQL Server → migration runner → IdentityServer.

## AppHost wiring

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner: needs the connection string, waits for SQL Server to be up
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// IdentityServer: still needs the connection string, but now waits for MIGRATIONS
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(migrations);   // start only after the migration runner has finished

builder.Build().Run();
```

## Why it's wired this way

| Resource | `WithReference` | `WaitFor` | Reason |
|----------|-----------------|-----------|--------|
| `migrations` | `identityDb` | `sqlServer` | Needs the `identitydb` connection string; must wait for SQL to accept connections before applying migrations |
| `identity-server` | `identityDb` | `migrations` | Still needs the connection string for its EF stores, but must wait until the migration runner has completed so the schema exists |

Key points:

- IdentityServer waits on **`migrations`**, not directly on `sqlServer`. Because `migrations` itself waits for SQL, the whole chain is ordered: SQL up → migrations run → IdentityServer starts against a fully-migrated database.
- IdentityServer keeps `.WithReference(identityDb)` so it still receives the `ConnectionStrings__identitydb` value for its configuration and operational stores at runtime.
- The migration runner is a short-lived project that applies `Database.MigrateAsync()` for the configuration and operational `DbContext`s, then exits.

This avoids each IdentityServer instance racing to migrate on startup (important once you scale to multiple replicas) and gives you a single, ordered place where the schema is created. See `identityserver-data-storage` for the EF Core store and migration details.
