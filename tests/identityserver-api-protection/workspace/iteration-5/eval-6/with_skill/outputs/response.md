# Protecting a local API co-hosted with IdentityServer

When your API lives in the **same application** as IdentityServer, you don't need to make an HTTP round-trip to the token/introspection endpoint to validate tokens. IdentityServer provides **local API authentication** for exactly this case — it validates the token in-process.

## Setup

In the IdentityServer host, add local API authentication alongside your IdentityServer registration:

```csharp
// Program.cs (the IdentityServer host application)
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddInMemoryIdentityResources(Config.IdentityResources);

// Enables in-process validation for local API endpoints
builder.Services.AddLocalApiAuthentication();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseIdentityServer();   // also runs UseAuthentication internally
app.UseAuthorization();

// Protect local endpoints with the built-in local API policy
app.MapGet("/local-api/data", () => Results.Ok(new { message = "Local protected data" }))
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.Run();
```

## What `AddLocalApiAuthentication()` gives you

- An authentication handler `IdentityServerConstants.LocalApi.AuthenticationScheme` (the string `"IdentityServerAccessToken"`).
- An authorization policy `IdentityServerConstants.LocalApi.PolicyName` that requires the `IdentityServerApi` scope.

Protect endpoints with that policy name (or `[Authorize(Policy = IdentityServerConstants.LocalApi.PolicyName)]` on controllers).

## Clients must request the `IdentityServerApi` scope

The local API policy requires the `IdentityServerApi` scope, so any client calling these endpoints must have it in its allowed scopes and request it:

```csharp
var client = new Client
{
    ClientId = "local_client",
    AllowedScopes = { "openid", "profile", "IdentityServerApi" }
};
```

## Important limitation

`AddLocalApiAuthentication()` **only works when the API is co-hosted with IdentityServer** — it relies on in-process access to IdentityServer's token validation services. For an API running in a **separate host/process**, this won't work; use JWT bearer authentication or reference-token introspection there instead.

### Optional: enrich the principal

You can add extra claims during local validation:

```csharp
builder.Services.AddLocalApiAuthentication(principal =>
{
    principal.Identities.First().AddClaim(new Claim("additional_claim", "value"));
    return Task.FromResult(principal);
});
```
