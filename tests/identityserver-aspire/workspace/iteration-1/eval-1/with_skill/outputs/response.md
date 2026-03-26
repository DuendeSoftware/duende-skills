# Wiring the Full Dependency Graph in Aspire AppHost

Here's the complete `Program.cs` for your Aspire AppHost that establishes the correct startup ordering:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Database resources
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// IdentityServer waits for SQL Server to be ready
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Weather API waits for IdentityServer (needs JWKS for token validation)
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

// Web App waits for IdentityServer (needs discovery doc for OIDC)
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

## Why This Ordering Matters

The dependency graph flows like this:

```
sqlServer -> identity-server -> weather-api
                             -> web-app -> weather-api
```

Each call serves a specific purpose:

| Call | Effect |
|------|--------|
| `.WithReference(identityDb)` | Makes the `ConnectionStrings__identitydb` available to IdentityServer |
| `.WaitFor(sqlServer)` | Holds IdentityServer from starting until SQL Server accepts connections |
| `.WithReference(identityServer)` | Makes IdentityServer's endpoint URL available via service discovery |
| `.WaitFor(identityServer)` | Holds the dependent service until IdentityServer's health check returns healthy |

Both `WithReference` and `WaitFor` are needed on the API and web app. `WithReference` alone provides the URL but doesn't prevent premature startup. `WaitFor` alone delays startup but doesn't expose the endpoint URL.

Without `WaitFor(identityServer)`, the API and web app may start before IdentityServer is ready, causing `IDX20803: Unable to obtain configuration from '.well-known/openid-configuration'` errors.

## Health Check Requirement

For `WaitFor(identityServer)` to work, IdentityServer must expose a health check endpoint. At minimum:

```csharp
// In IdentityServer's Program.cs
builder.Services.AddHealthChecks();
app.MapHealthChecks("/health");
```

Aspire polls this endpoint to determine when IdentityServer is ready to accept traffic.
