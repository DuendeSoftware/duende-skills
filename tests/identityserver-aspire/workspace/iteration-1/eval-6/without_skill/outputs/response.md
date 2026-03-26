# Migration Runner Dependency Chain in Aspire

You can create a migration runner that runs before IdentityServer:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// IdentityServer depends on migrations
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WaitFor(migrations)
    .WaitFor(sqlServer);

builder.Build().Run();
```

The migration runner project should be a simple console application that:
1. Connects to the database
2. Runs `Database.MigrateAsync()` for your DbContexts
3. Exits when complete

Aspire will see the migration runner complete and then allow IdentityServer to start.
