# Protecting Local APIs Hosted with IdentityServer

When your API is hosted in the same application as IdentityServer, you can use local API authentication to avoid the overhead of network calls for token validation.

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

// Protect local API endpoints with the built-in policy
app.MapGet("/local-api/data", () => Results.Ok(new { message = "Local API data" }))
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.MapPost("/local-api/data", (DataModel model) => Results.Created())
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.Run();
```

## What `AddLocalApiAuthentication()` Configures

It sets up:
- An authentication handler named `IdentityServerAccessToken` (available as `IdentityServerConstants.LocalApi.AuthenticationScheme`)
- An authorization policy named `IdentityServerConstants.LocalApi.PolicyName` that requires the `IdentityServerApi` scope

## Client Configuration Requirement

Clients that access local APIs **must** include `IdentityServerApi` in their allowed scopes:

```csharp
var client = new Client
{
    ClientId = "local_client",
    AllowedScopes = { "openid", "profile", "IdentityServerApi" }
};
```

## Important Warning

**`AddLocalApiAuthentication()` only works when the API is co-hosted with IdentityServer.** For separate API hosts, you must use JWT bearer authentication or token introspection instead. If you try to use local API authentication in a standalone API that is not running the IdentityServer middleware, it will not function.
