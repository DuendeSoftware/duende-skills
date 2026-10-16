```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sql = builder.AddSqlServer("sql");
var db = sql.AddDatabase("identitydb");

var migrations = builder.AddProject<Projects.MigrationRunner>("migrations")
    .WithReference(db)
    .WaitFor(db);

var identityServer = builder.AddProject<Projects.IdentityServer>("identityserver")
    .WithReference(db)
    .WaitFor(migrations);

builder.AddProject<Projects.WeatherApi>("weatherapi")
    .WithReference(identityServer).WaitFor(identityServer);

builder.AddProject<Projects.WebApp>("webapp")
    .WithReference(identityServer).WaitFor(identityServer);

builder.Build().Run();
```

The migration runner waits for the database. IdentityServer waits for `migrations`. Note: `WaitFor` waits for the resource to be running, and a one-shot worker exits. Use `WaitForCompletion(migrations)` instead so IdentityServer starts only after the runner exits successfully:

```csharp
.WaitForCompletion(migrations)
```
