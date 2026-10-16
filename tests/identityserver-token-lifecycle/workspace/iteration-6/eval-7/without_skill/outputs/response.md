```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;

builder.Services.AddAuthentication()
    .AddLocalApi(); // validates IdentityServer-issued tokens for local endpoints

builder.Services.AddAuthorization(o =>
    o.AddPolicy("InternalToken", p => p
        .AddAuthenticationSchemes(IdentityServerConstants.LocalApi.AuthenticationScheme)
        .RequireAuthenticatedUser()));
```

(Note: `AddAuthentication()` goes before `AddIdentityServer()` or after; either works. For local API tokens the `IdentityServerConstants.LocalApi.ScopeName` scope must be allowed on the calling client. You can substitute whatever scheme/policy fits your app.)

```csharp
var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.MapGet("/internal-token", async (IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600,                          // 10 minutes (seconds)
        audiences: new[] { "backend.api" });

    return Results.Ok(new { access_token = token, expires_in = 600 });
})
.RequireAuthorization("InternalToken");

app.Run();
```

Notes:
- `IIdentityServerTools` is registered automatically by `AddIdentityServer`.
- `IssueClientJwtAsync` produces a JWT signed with IdentityServer's signing key, with `client_id`, `aud`, `iss`, `iat/exp`.
- `backend.api` must validate issuer, audience and signature as usual.
- Lock the endpoint down tightly; anyone who can call it gets a signed token. Consider scope/role requirements in the policy.
