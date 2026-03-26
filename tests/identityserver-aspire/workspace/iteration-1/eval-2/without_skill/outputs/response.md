# Passing Configuration via Environment Variables in Aspire

You can use `WithEnvironment` to pass configuration values to your services. Here's how:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WithEnvironment("IdentityServer__IssuerUri", "https://localhost:5001");

// Web App
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WithEnvironment("Authentication__Authority", "https://localhost:5001")
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes", "openid profile weather.read");

// API
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WithEnvironment("Authentication__Authority", "https://localhost:5001");

builder.Build().Run();
```

The double-underscore convention (`__`) maps to the colon (`:`) separator in .NET configuration. So `Authentication__Authority` becomes `Authentication:Authority` in `IConfiguration`.

In the web app, read these values:

```csharp
services.AddAuthentication()
    .AddOpenIdConnect(options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
        options.ClientId = builder.Configuration["Authentication:ClientId"];
    });
```
