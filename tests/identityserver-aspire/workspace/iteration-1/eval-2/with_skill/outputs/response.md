# Passing OIDC Configuration via WithEnvironment

Here's how to use `WithEnvironment` to pass authentication settings from the AppHost to your services:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Web App gets the full OIDC configuration
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile")
    .WithEnvironment("Authentication__Scopes__2", "weather.read");

// API only needs the authority URL for JWT validation
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

builder.Build().Run();
```

## How This Works

The `WithEnvironment` calls set environment variables that map to `IConfiguration` keys via the double-underscore (`__`) convention:

| Environment Variable | Configuration Key | Purpose |
|---|---|---|
| `Authentication__Authority` | `Authentication:Authority` | OIDC authority URL |
| `Authentication__ClientId` | `Authentication:ClientId` | Client identifier |
| `Authentication__Scopes__0` | `Authentication:Scopes:0` | Array element (openid) |
| `Authentication__Scopes__1` | `Authentication:Scopes:1` | Array element (profile) |
| `Authentication__Scopes__2` | `Authentication:Scopes:2` | Array element (weather.read) |

The `identityServer.GetEndpoint("https")` call returns the dynamic HTTPS endpoint URL assigned by Aspire, so the authority URL is always correct regardless of port assignment.

## Reading in the Web App

```csharp
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie()
.AddOpenIdConnect(options =>
{
    options.Authority = builder.Configuration["Authentication:Authority"];
    options.ClientId = builder.Configuration["Authentication:ClientId"];
    var scopes = builder.Configuration.GetSection("Authentication:Scopes").Get<string[]>();
    if (scopes is not null)
    {
        options.Scope.Clear();
        foreach (var scope in scopes)
            options.Scope.Add(scope);
    }
});
```

## Reading in the API

```csharp
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.Authority = builder.Configuration["Authentication:Authority"];
    });
```

### Issuer URI Note

By default, IdentityServer infers the issuer URI from incoming requests. Do NOT set `IssuerUri` unless the internal Aspire URL differs from what clients see. Mismatched issuer URIs cause token validation failures.
