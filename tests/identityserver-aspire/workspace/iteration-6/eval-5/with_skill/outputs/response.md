`IDX20803` happens because services start in parallel: the API tries to download the discovery document/JWKS before IdentityServer is up. Fix it with a dependency graph using `WithReference` + `WaitFor`, and give IdentityServer a health check, since `WaitFor` depends on it.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithReference(api);

builder.Build().Run();
```

In IdentityServer's `Program.cs`:

```csharp
builder.Services.AddHealthChecks();
app.MapHealthChecks("/health");
```

For stronger readiness, add `DiscoveryDocumentHealthCheck` and `DiscoveryKeysHealthCheck` (see `identityserver-deployment`) so it's only healthy when it can serve discovery and signing keys.

Why both calls: `WithReference` supplies the URL but doesn't delay startup; `WaitFor` delays but doesn't provide the URL. Also make sure the API reads `Authentication:Authority` from configuration for `AddJwtBearer`, and don't override `IssuerUri` unless needed.
