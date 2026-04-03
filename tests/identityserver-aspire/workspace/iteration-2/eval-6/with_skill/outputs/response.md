# Dedicated Migration Runner in Aspire

Here's how to wire the dependency graph so that database migrations complete before IdentityServer starts: SQL Server → Migration Runner → IdentityServer.

## AppHost Code

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Database resources
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner — depends on SQL Server, runs migrations first
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// IdentityServer — waits for migrations to complete, NOT directly for SQL Server
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(migrations);

// API and web app — wait for IdentityServer
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer);

builder.Build().Run();
```

## Dependency Flow

```
sqlServer ─► migrations ─► identity-server ─► weather-api
                                             ─► web-app
```

## Key Details

### Migration runner project:
- **`.WithReference(identityDb)`** — Gets the `ConnectionStrings__identitydb` connection string so it can connect to the database and run migrations.
- **`.WaitFor(sqlServer)`** — Ensures SQL Server is accepting connections before migrations start.

### IdentityServer project:
- **`.WithReference(identityDb)`** — Gets the same connection string for its EF Core stores (configuration and operational data).
- **`.WaitFor(migrations)`** — Waits for the migration runner to finish before starting. This ensures the database schema is fully up to date when IdentityServer connects.

Notice that IdentityServer waits for `migrations`, not `sqlServer`. This is the key pattern — the migration runner acts as an intermediary that ensures both "database is up" and "schema is migrated" before IdentityServer attempts to use the database.

### Migration runner implementation

The migration runner project is typically a simple console app or hosted service that:
1. Applies EF Core migrations (`Database.MigrateAsync()`)
2. Optionally seeds initial data
3. Exits when done

When the migration runner exits successfully, Aspire considers it "completed" and allows `WaitFor(migrations)` to unblock IdentityServer.
