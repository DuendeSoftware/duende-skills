You can push these settings from the AppHost as environment variables with `WithEnvironment`. Aspire (and ASP.NET Core config) treats `__` as the hierarchy separator, and `__0`, `__1`, ... as array indexes, so `Authentication__Scopes__0` becomes `Authentication:Scopes:0` in `IConfiguration`.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server");

// Web app needs authority, client id, and scopes
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile")
    .WithEnvironment("Authentication__Scopes__2", "api");

// API only needs the authority
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

builder.Build().Run();
```

### Notes

- `identityServer.GetEndpoint("https")` yields the runtime HTTPS URL of IdentityServer, so the authority is never hard-coded.
- In the **web app**, read these with `builder.Configuration["Authentication:Authority"]`, `builder.Configuration["Authentication:ClientId"]`, and bind the scopes via `builder.Configuration.GetSection("Authentication:Scopes")` into a `string[]`, then add each to your OpenID Connect handler's `Scope` collection.
- In the **API**, wire `options.Authority = builder.Configuration["Authentication:Authority"]` in `AddJwtBearer`.

This keeps the AppHost as the single source of truth for OIDC wiring while each service reads plain configuration values.
