Here's how to pass the OIDC configuration from the AppHost to each service using `WithEnvironment`. The web app gets authority, client ID, and scopes; the API gets just the authority. All values flow into standard `IConfiguration` keys (double underscores map to the `:` separator, and `__0`, `__1`, ... index into arrays).

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Web app: needs authority, client id, and scopes
var webApp = builder.AddProject<Projects.WebApp>("web-app")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"))
    .WithEnvironment("Authentication__ClientId", "web-app")
    .WithEnvironment("Authentication__Scopes__0", "openid")
    .WithEnvironment("Authentication__Scopes__1", "profile")
    .WithEnvironment("Authentication__Scopes__2", "weather.read");

// API: only needs the authority URL
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)
    .WaitFor(identityServer)
    .WithEnvironment("Authentication__Authority", identityServer.GetEndpoint("https"));

builder.Build().Run();
```

## How the values map

| Environment variable | Config key | Consumed by |
|----------------------|-----------|-------------|
| `Authentication__Authority` | `Authentication:Authority` | Web app (OIDC) + API (JWT bearer) |
| `Authentication__ClientId` | `Authentication:ClientId` | Web app OIDC handler |
| `Authentication__Scopes__0..2` | `Authentication:Scopes:0..2` | Web app scope list |

`identityServer.GetEndpoint("https")` resolves to the IdentityServer HTTPS endpoint at runtime (dynamic port), so you never hard-code the authority URL.

## Reading it in the apps

- **Web app:** configure `AddOpenIdConnect` with `Authority = builder.Configuration["Authentication:Authority"]`, `ClientId = builder.Configuration["Authentication:ClientId"]`, and bind the scope list from the `Authentication:Scopes` section.
- **API:** configure `AddJwtBearer` with `options.Authority = builder.Configuration["Authentication:Authority"]`.

## On IssuerUri

Do **not** set `IdentityServer__IssuerUri` here. By default IdentityServer infers the issuer from incoming requests, which is correct inside Aspire's network. Overriding it is only needed when the internal Aspire URL differs from what external clients see — and setting it unnecessarily causes `iss`-claim / token-validation mismatches. Leave it unset.
