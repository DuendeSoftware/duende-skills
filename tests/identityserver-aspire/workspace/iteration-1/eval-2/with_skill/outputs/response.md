# Passing OIDC Configuration via WithEnvironment

Use `WithEnvironment` to pass authentication settings from the AppHost to dependent services as standard configuration values.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Web App — needs authority, client ID, and scopes
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile")
    .WithEnvironment("Authentication__Scopes__2", "weather.read");

// API — just needs the authority URL
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

builder.Build().Run();
```

## Key Points

- `identityServer.GetEndpoint("https")` returns the dynamic HTTPS URL of the IdentityServer resource at runtime.
- The double-underscore (`__`) convention maps to nested configuration keys: `Authentication__Scopes__0` becomes `Authentication:Scopes:0` in `IConfiguration`.
- The web app reads these via `builder.Configuration["Authentication:Authority"]`, `builder.Configuration["Authentication:ClientId"]`, and binds the scopes array from `Authentication:Scopes`.
- The API only needs the authority URL for JWT bearer validation.

## IssuerUri Consideration

Do NOT set `IssuerUri` unless the internal Aspire URL differs from what clients see. IdentityServer infers the issuer from incoming requests by default, which works correctly within Aspire's network. Mismatched issuer URIs cause token validation failures.
