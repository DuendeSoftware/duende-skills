# Protecting local APIs hosted inside IdentityServer

Duende IdentityServer provides a local API authentication handler that validates tokens in-process (using IdentityServer's own keys and store), with no discovery/JWKS network calls.

```csharp
using Duende.IdentityServer;

builder.Services.AddIdentityServer(/* ... */);

builder.Services.AddLocalApiAuthentication();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(IdentityServerConstants.LocalApi.PolicyName, policy =>
    {
        policy.AddAuthenticationSchemes(IdentityServerConstants.LocalApi.AuthenticationScheme);
        policy.RequireAuthenticatedUser();
    });
});

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/local/data", () => "ok")
   .RequireAuthorization(IdentityServerConstants.LocalApi.PolicyName);
```

Controller form: `[Authorize(LocalApi.PolicyName)]`.

Then:
- Register an `ApiScope` named `IdentityServerApi` (`IdentityServerConstants.LocalApi.ScopeName`) and allow clients to request it.
- Clients request that scope and call your endpoint with the bearer token.
- To require additional scopes, add `policy.RequireClaim("scope", "myscope")` to the policy.
- Local API tokens work with both JWT and reference tokens, and DPoP is supported.
