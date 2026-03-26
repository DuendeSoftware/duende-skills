# Local API Authentication (Co-Hosted with IdentityServer)

When your API is hosted in the same application as IdentityServer, use local API authentication to avoid network calls for token validation.

## Setup

```csharp
// Program.cs (in the IdentityServer host)
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Add local API authentication
builder.Services.AddLocalApiAuthentication();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

// Protect endpoints with the local API policy
app.MapGet("/local-api/data", () => Results.Ok(new { message = "Local API data" }))
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.Run();
```

## What AddLocalApiAuthentication Configures

`AddLocalApiAuthentication()` sets up:
- An authentication handler named `IdentityServerAccessToken` (available as `IdentityServerConstants.LocalApi.AuthenticationScheme`)
- An authorization policy named `IdentityServerConstants.LocalApi.PolicyName` that requires the `IdentityServerApi` scope

## Client Configuration

Clients accessing local APIs must include `IdentityServerApi` in their `AllowedScopes`:

```csharp
var client = new Client
{
    ClientId = "local_client",
    AllowedScopes = { "openid", "profile", "IdentityServerApi" }
};
```

## Important Warning

**Local API authentication only works when the API is co-hosted with IdentityServer.** For separate API hosts, use JWT bearer authentication or introspection instead. `AddLocalApiAuthentication()` relies on internal IdentityServer services that are only available in the same process.
