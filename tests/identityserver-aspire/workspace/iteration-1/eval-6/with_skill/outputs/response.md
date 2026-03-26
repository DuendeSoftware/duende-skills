# Dedicated Migration Runner in Aspire

Here's how to wire the dependency graph so migrations complete before IdentityServer starts:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner waits for SQL Server, then runs migrations
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// IdentityServer waits for migrations to complete, not SQL Server directly
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)      // Still needs the connection string
    .WaitFor(migrations);            // Wait for migrations, not sqlServer

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

builder.Build().Run();
```

## Dependency Flow

```
sqlServer -> migrations -> identity-server -> weather-api
```

### Key Points:

1. **Migration runner gets `WithReference(identityDb)`** - This passes the `ConnectionStrings__identitydb` connection string to the migration runner so it can connect to the database and apply migrations.

2. **Migration runner gets `WaitFor(sqlServer)`** - Ensures SQL Server is accepting connections before the migration runner tries to apply migrations.

3. **IdentityServer gets `WaitFor(migrations)`** - This is the critical part. IdentityServer waits for the migration runner to finish, not for SQL Server directly. The migration runner is a short-lived process that exits after applying migrations, and Aspire considers it "healthy" once it completes successfully.

4. **IdentityServer still gets `WithReference(identityDb)`** - IdentityServer still needs the connection string to connect to the database at runtime. `WaitFor` controls startup ordering; `WithReference` provides configuration.

## Migration Runner Implementation

The migration runner is a simple console app that applies EF Core migrations and exits:

```csharp
var builder = Host.CreateApplicationBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("identitydb");

using var db = new PersistedGrantDbContext(new DbContextOptionsBuilder<PersistedGrantDbContext>()
    .UseSqlServer(connectionString)
    .Options);

await db.Database.MigrateAsync();

// Apply configuration store migrations too
using var configDb = new ConfigurationDbContext(new DbContextOptionsBuilder<ConfigurationDbContext>()
    .UseSqlServer(connectionString)
    .Options);

await configDb.Database.MigrateAsync();
```
