# Migration Runner in Aspire

You can add a dedicated migration runner project that runs before IdentityServer:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner runs first
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// IdentityServer waits for migrations
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(migrations);

builder.Build().Run();
```

The migration runner project should apply EF Core migrations and then exit. IdentityServer waits for the migration runner to complete before starting, ensuring the database schema is ready.
