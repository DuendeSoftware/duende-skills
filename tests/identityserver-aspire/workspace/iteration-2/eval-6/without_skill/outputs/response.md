# Running Migrations Before IdentityServer in Aspire

You can create a separate project that runs migrations and have other services depend on it. Here's a basic approach:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Migration runner runs first
var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb);

// IdentityServer starts after migrations
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

builder.Build().Run();
```

## Notes

The migration runner should be a simple console application that applies your Entity Framework Core migrations:

```csharp
var builder = WebApplication.CreateBuilder(args);
var connectionString = builder.Configuration.GetConnectionString("identitydb");

using var context = new MyDbContext(
    new DbContextOptionsBuilder<MyDbContext>()
        .UseSqlServer(connectionString)
        .Options);

await context.Database.MigrateAsync();
```

You'll want to make sure the migration runner project references the same EF Core context that IdentityServer uses. The runner should exit when migrations are complete, signaling to Aspire that dependent services can start.

You might also want to add error handling and logging to the migration runner so you can troubleshoot any migration failures through the Aspire dashboard.
