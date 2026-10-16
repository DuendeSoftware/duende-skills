```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(migrations);  // wait for migrations

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

Graph: `sql ─► migrations ─► identity-server ─► weather-api / web-app`.

The runner references the same `identitydb` so it receives `ConnectionStrings__identitydb`. `WaitFor(migrations)` waits for the runner to be running/healthy. Because the runner is a one-shot process that exits, `WaitForCompletion(migrations)` is the more precise choice, since it makes IdentityServer wait until the runner has finished successfully:

```csharp
.WaitForCompletion(migrations)
```

IdentityServer's health check (`/health`) is still needed for downstream `WaitFor`. See `identityserver-data-storage` for EF migration details.
