# Passing Configuration to Services in Aspire

You can use `WithEnvironment` to pass configuration values to your services in an Aspire AppHost.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Web App
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile");

// API
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

builder.Build().Run();
```

The double-underscore (`__`) maps to nested configuration paths. In the web app, you'd read these as `Authentication:Authority`, `Authentication:ClientId`, etc.

You can also set the IssuerUri for IdentityServer if needed:

```csharp
.WithEnvironment("IdentityServer__IssuerUri", identityServer.GetEndpoint("https"));
```
