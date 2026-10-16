```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

Flow: `sqlServer ─► identity-server ─► weather-api` and `identity-server ─► web-app ─► weather-api`.

- `WithReference` exposes the endpoint/connection string; `WaitFor` holds startup until the target is healthy. You need both.
- `WaitFor(sqlServer)` ensures the DB accepts connections before IdentityServer touches its EF stores.
- Clients fetch the discovery document and APIs fetch JWKS at startup; without `WaitFor(identityServer)` you get `IDX20803` errors.
- `WaitFor` relies on health checks, so IdentityServer must expose them:

```csharp
builder.Services.AddHealthChecks();
app.MapHealthChecks("/health");
```
