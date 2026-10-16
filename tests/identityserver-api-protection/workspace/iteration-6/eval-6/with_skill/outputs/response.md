# Protecting local APIs hosted in IdentityServer

Use **local API authentication**; tokens are validated in-process by IdentityServer, without remote calls. It only works when the API is co-hosted with IdentityServer (for separate hosts, use JWT bearer or introspection).

```csharp
// Program.cs (IdentityServer host)
builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

builder.Services.AddLocalApiAuthentication();
```

`AddLocalApiAuthentication()` registers:
- an authentication handler named `IdentityServerAccessToken` (`IdentityServerConstants.LocalApi.AuthenticationScheme`)
- an authorization policy `IdentityServerConstants.LocalApi.PolicyName`, which requires the `IdentityServerApi` scope.

## Protect endpoints

```csharp
app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/local-api/data", () => Results.Ok(data))
   .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);
```

Controllers:

```csharp
[Authorize(Policy = IdentityServerConstants.LocalApi.PolicyName)]
[ApiController]
[Route("local-api/[controller]")]
public class LocalDataController : ControllerBase
{
    [HttpGet] public IActionResult Get() => Ok(data);
}
```

## Clients must request the `IdentityServerApi` scope

```csharp
new Client
{
    ClientId = "local_client",
    AllowedScopes = { "openid", "profile", "IdentityServerApi" }
};
```

Forgetting this is the most common reason local API calls get rejected. Also define the `IdentityServerApi` scope if not already present.

## Adding claims
```csharp
builder.Services.AddLocalApiAuthentication(principal =>
{
    principal.Identities.First().AddClaim(new Claim("additional_claim", "value"));
    return Task.FromResult(principal);
});
```
