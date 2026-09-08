Here's how to wire up the full dependency graph in your Aspire AppHost `Program.cs`. The goal is a chain: SQL Server → IdentityServer → (Weather API + Web App).

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// SQL Server and a database for IdentityServer
var sql = builder.AddSqlServer("sql");
var identityDb = sql.AddDatabase("identitydb");

// IdentityServer depends on the database
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sql);

// Weather API depends on IdentityServer
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

// Web App depends on IdentityServer (and typically the API)
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
```

## How it works

- **`AddSqlServer("sql")`** provisions the SQL Server resource (a container in local dev).
- **`AddDatabase("identitydb")`** creates a logical database resource on that server. Referencing it injects the connection string into IdentityServer as `ConnectionStrings__identitydb`.
- **`WithReference(...)`** makes a resource's connection string / endpoint available to the consumer.
- **`WaitFor(...)`** delays the consumer's startup until the referenced resource is running/healthy.

The result is that IdentityServer won't start until SQL Server is up, and neither the API nor the web app will start until IdentityServer is up. This prevents the classic race condition where an API tries to fetch OIDC metadata before the identity provider is listening.

## Ordering diagram

```
sql ──► identity-server ──► weather-api
                        └─► web-app ──► weather-api
```

> Tip: For `WaitFor(identityServer)` to actually block on *readiness* (not just "process started"), make sure IdentityServer exposes a health endpoint so Aspire has a signal to poll.
