# Aspire AppHost: Full Dependency Graph

Here's the complete `Program.cs` for your Aspire AppHost with the full dependency graph wired up:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Database resources
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// IdentityServer — depends on the database
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Weather API — depends on IdentityServer for JWT validation
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

// Web App — depends on IdentityServer for OIDC and the API
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

## Dependency Flow

```
sqlServer -> identity-server -> weather-api
                             -> web-app -> weather-api
```

## What Each Call Does

| Call | Effect |
|------|--------|
| `builder.AddSqlServer("sql")` | Creates a SQL Server container resource |
| `sqlServer.AddDatabase("identitydb")` | Creates a logical database resource on the SQL Server |
| `.WithReference(identityDb)` | Makes the connection string available to IdentityServer via `ConnectionStrings__identitydb` |
| `.WaitFor(sqlServer)` | Ensures SQL Server is accepting connections before IdentityServer starts |
| `.WithReference(identityServer)` | Makes the IdentityServer endpoint URL available to the dependent service via service discovery |
| `.WaitFor(identityServer)` | Holds the dependent service from starting until IdentityServer's health check returns healthy |

Both `WithReference` and `WaitFor` are needed for each dependency:
- `WithReference` alone provides the URL but doesn't prevent premature startup
- `WaitFor` alone delays startup but doesn't expose the endpoint URL

Without `WaitFor(identityServer)` on the API and web app, they may start before IdentityServer is ready, causing `InvalidOperationException: IDX20803: Unable to obtain configuration from '.well-known/openid-configuration'` errors.
