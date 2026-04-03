# Passing OIDC Configuration via WithEnvironment

Here's how to pass the authority URL, client ID, and scopes to your web app, and the authority URL to the API using `WithEnvironment`:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// API — only needs the authority URL for JWT Bearer token validation
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

// Web App — needs authority, client ID, and scopes for OIDC
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile")
    .WithEnvironment("Authentication__Scopes__2", "weather.read");

builder.Build().Run();
```

## How this works

### Environment variable naming convention

The double-underscore (`__`) convention maps to .NET configuration's section delimiter (`:`). So:
- `Authentication__Authority` → `Authentication:Authority`
- `Authentication__ClientId` → `Authentication:ClientId`
- `Authentication__Scopes__0` → `Authentication:Scopes:0` (array index)

### Authority URL with GetEndpoint

`identityServer.GetEndpoint("https")` returns the dynamic HTTPS endpoint URL assigned by Aspire at runtime. This resolves to something like `https://localhost:5001`. Using `GetEndpoint` ensures the URL is always correct regardless of port assignment.

### IssuerUri

Do NOT set `IssuerUri` unless the internal Aspire URL differs from what clients see. By default, IdentityServer infers the issuer from incoming requests, which works correctly within Aspire's network. Mismatched issuer URIs cause token validation failures because the `iss` claim in tokens won't match the expected authority.

### Reading in app code

In the web app, read these values via `IConfiguration`:

```csharp
builder.Configuration["Authentication:Authority"]  // the OIDC authority
builder.Configuration["Authentication:ClientId"]    // the client ID
// Scopes are available as Authentication:Scopes:0, Authentication:Scopes:1, etc.
```

In the API, configure JWT Bearer with:

```csharp
builder.Configuration["Authentication:Authority"]  // the authority for token validation
```
