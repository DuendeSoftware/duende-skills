# Local API Authentication (Co-hosted with IdentityServer)

When your API is hosted in the same application as IdentityServer, you can use local API authentication to avoid network overhead for token validation.

## Setup

```csharp
// Program.cs (in the IdentityServer host)
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Add local API authentication — no network calls needed
builder.Services.AddLocalApiAuthentication();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

// Protect local API endpoints using the built-in policy
app.MapGet("/local-api/data", () => Results.Ok(new { message = "Protected local data" }))
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.MapPost("/local-api/data", (DataModel model) => Results.Created())
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.Run();
```

## What AddLocalApiAuthentication Configures

`AddLocalApiAuthentication()` sets up:

- An authentication handler named `IdentityServerAccessToken` (available as `IdentityServerConstants.LocalApi.AuthenticationScheme`)
- An authorization policy named `IdentityServerConstants.LocalApi.PolicyName` that requires the `IdentityServerApi` scope

## Client Configuration Requirement

Clients that access local APIs **must include `IdentityServerApi` in their `AllowedScopes`**:

```csharp
// IdentityServer client configuration
var client = new Client
{
    ClientId = "local_client",
    AllowedGrantTypes = GrantTypes.ClientCredentials,
    ClientSecrets = { new Secret("secret".Sha256()) },
    AllowedScopes = { "openid", "profile", "IdentityServerApi" }
};
```

Without `IdentityServerApi` in the client's scopes, the token won't include the required scope and the policy check will fail.

## Important Warning

**Local API authentication only works when the API is co-hosted with IdentityServer** — i.e., running in the same ASP.NET Core application process. If your API is a separate application, you must use standard JWT bearer authentication or reference token introspection instead. `AddLocalApiAuthentication()` relies on IdentityServer's internal token validation pipeline, which is only available in the same host.

## Using with Controllers

```csharp
[Authorize(Policy = IdentityServerConstants.LocalApi.PolicyName)]
[ApiController]
[Route("local-api/[controller]")]
public class LocalDataController : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new { message = "Local API data" });
}
```
