# Dedicated Migration Runner in Aspire

Here's how to wire a migration runner project so database migrations complete before IdentityServer starts:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner — depends on SQL Server
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// IdentityServer — waits for migrations to complete, not directly for SQL Server
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)    // Still needs the connection string
    .WaitFor(migrations);          // Waits for migration runner to finish

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

builder.Build().Run();
```

## Dependency Flow

```
sqlServer -> migrations -> identity-server -> weather-api
```

## Key Points

- The migration runner has `.WithReference(identityDb)` to get the connection string and `.WaitFor(sqlServer)` to ensure the database is accepting connections.
- IdentityServer uses `.WaitFor(migrations)` to wait for the migration runner to complete — **not** `.WaitFor(sqlServer)` directly. This ensures the schema is ready before IdentityServer starts.
- IdentityServer still has `.WithReference(identityDb)` so it gets the connection string for its EF Core stores.
- The migration runner project runs `Database.MigrateAsync()` for the configuration and operational stores, then exits.
