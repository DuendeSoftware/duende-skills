# Protecting API endpoints hosted inside your IdentityServer app

When the API and IdentityServer run in the **same application**, you can validate tokens in-process instead of calling back over the network. Duende IdentityServer supports this with **local API authentication**.

## Enable local API authentication

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryApiScopes(Config.ApiScopes);

// Register the local API authentication handler
builder.Services.AddLocalApiAuthentication();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthentication();
app.UseAuthorization();

// Protect endpoints with the local API policy
app.MapGet("/api/data", () => Results.Ok(new { message = "Protected" }))
    .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);

app.Run();
```

`AddLocalApiAuthentication()` wires up an authentication scheme and an authorization policy exposed as `IdentityServerConstants.LocalApi.PolicyName`. Apply that policy to any endpoint (minimal API `.RequireAuthorization(...)`, or `[Authorize(Policy = ...)]` on a controller) to require a valid local access token.

## Notes

- Because validation happens in-process, there's no HTTP call to the introspection or token endpoint — lower latency for endpoints hosted next to IdentityServer.
- The access token still has to carry the appropriate API scope for your authorization checks; make sure your clients are configured to request the scope your endpoints expect.
- This approach is specific to the co-hosted scenario. If you later split the API into its own service, switch to standard JWT bearer validation (or introspection for reference tokens) pointing at the IdentityServer authority.

If you need extra per-request claims, `AddLocalApiAuthentication` accepts a transformation delegate you can use to augment the `ClaimsPrincipal`.
