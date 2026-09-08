Here's the full dependency graph wired up in your AppHost `Program.cs`. The ordering guarantees the database is ready before IdentityServer starts, and that both the API and web app wait for IdentityServer before starting.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// SQL Server + a dedicated database for IdentityServer
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// IdentityServer waits for the database, and references the identitydb connection string
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Weather API waits for IdentityServer (it downloads JWKS at startup for token validation)
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

// Web app waits for IdentityServer (downloads the discovery document at startup)
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

## Why each call matters

| Call | Effect |
|------|--------|
| `builder.AddSqlServer("sql")` | Creates the SQL Server container resource |
| `sqlServer.AddDatabase("identitydb")` | Creates a database resource on that server; `WithReference(identityDb)` sets `ConnectionStrings__identitydb` |
| `.WithReference(identityDb)` on IdentityServer | Injects the connection string so its EF Core configuration and operational stores can connect |
| `.WaitFor(sqlServer)` on IdentityServer | Holds IdentityServer until SQL Server is accepting connections — IdentityServer touches EF stores on startup |
| `.WithReference(identityServer)` on API/web | Makes the IdentityServer endpoint URL discoverable to the dependent service |
| `.WaitFor(identityServer)` on API/web | Holds the dependent service until IdentityServer's health check reports healthy |

## Dependency flow

```
sql ─► identity-server ─► weather-api
                        ─► web-app ──► weather-api
```

`WithReference` and `WaitFor` are complementary and you need **both**. `WithReference` alone exposes the URL but doesn't prevent premature startup; `WaitFor` alone blocks startup but doesn't expose the endpoint. Without `WaitFor(identityServer)`, the API and web app can start before IdentityServer is ready and fail with `IDX20803: Unable to obtain configuration from '.../.well-known/openid-configuration'`.

> One prerequisite: for `WaitFor(identityServer)` to work, IdentityServer must expose a health check endpoint (`builder.Services.AddHealthChecks()` + `app.MapHealthChecks("/health")`). Aspire polls that endpoint to decide readiness.
