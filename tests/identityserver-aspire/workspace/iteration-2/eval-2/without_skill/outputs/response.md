# Passing Authentication Settings via Environment Variables

You can use `WithEnvironment` on your Aspire project resources to pass configuration values. Here's the approach:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server");

// API - pass the authority URL
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WithEnvironment("Authentication__Authority", "https://localhost:5001");

// Web App - pass authority, client ID, and scopes
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WithEnvironment("Authentication__Authority", "https://localhost:5001")
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes", "openid profile weather.read");

builder.Build().Run();
```

## Notes

- The `__` (double underscore) in environment variable names maps to `:` in .NET configuration, so `Authentication__Authority` becomes `Authentication:Authority`.
- You may also want to set the `IssuerUri` on IdentityServer to ensure token validation works correctly:

```csharp
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithEnvironment("IdentityServer__IssuerUri", "https://localhost:5001");
```

- In your web app, read these with `builder.Configuration["Authentication:Authority"]`.
- For the scopes, you can split them in your app code or configure them as a comma-separated list.
