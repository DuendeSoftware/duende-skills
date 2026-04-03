# Wiring the Full Aspire Dependency Graph

Here's the updated `Program.cs` that sets up SQL Server, IdentityServer, the Weather API, and the Web App with the correct dependency ordering:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Add SQL Server and database resources
var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

// Add IdentityServer project — depends on the database
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Add Weather API — depends on IdentityServer for token validation
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer);

// Add Web App — depends on IdentityServer for OIDC and on the API
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

## How the dependency graph works

The dependency flow is:

```
sqlServer ─► identity-server ─► weather-api
                               ─► web-app ──► weather-api
```

### Key details:

1. **`builder.AddSqlServer("sql")`** creates a SQL Server container resource managed by Aspire.
2. **`sqlServer.AddDatabase("identitydb")`** creates a named database resource. This automatically sets `ConnectionStrings__identitydb` in any project that references it.
3. **IdentityServer** uses `.WithReference(identityDb)` to get the connection string and `.WaitFor(sqlServer)` to ensure the database is accepting connections before starting. This is critical because IdentityServer connects to its EF Core configuration and operational stores on startup.
4. **Weather API** uses both `.WithReference(identityServer)` to make IdentityServer's endpoint URL available via service discovery, and `.WaitFor(identityServer)` to hold startup until IdentityServer's health check returns healthy. Without this, the API would fail with `IDX20803: Unable to obtain configuration` errors when trying to fetch the JWKS.
5. **Web App** similarly uses `.WithReference(identityServer)` and `.WaitFor(identityServer)` to ensure OIDC login flows work from the start.

Both `.WithReference()` and `.WaitFor()` are needed on each dependent service — `WithReference` provides the URL, while `WaitFor` prevents premature startup.
