```csharp
using Duende.IdentityServer;
using Duende.IdentityServer.Services;

builder.Services.AddAuthentication()
    .AddLocalApi();   // accepts IdentityServer-issued access tokens

builder.Services.AddAuthorization(o =>
    o.AddPolicy("InternalToken", p => p
        .AddAuthenticationSchemes(IdentityServerConstants.LocalApi.AuthenticationScheme)
        .RequireAuthenticatedUser()));

// ... AddIdentityServer(...) as before ...

var app = builder.Build();

app.UseIdentityServer();
app.UseAuthorization();

app.MapGet("/", () => "IdentityServer is running");

app.MapGet("/internal-token", async (IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600,                              // 10 minutes, in seconds
        audiences: new[] { "backend.api" });

    return Results.Ok(new { access_token = token, expires_in = 600 });
})
.RequireAuthorization("InternalToken");

app.Run();
```

Notes:
- `IIdentityServerTools` is registered by `AddIdentityServer()`; it signs with IdentityServer's key, so this skips the protocol endpoints.
- `lifetime` is in seconds; `audiences` becomes the `aud` claim; `client_id` is `internal_service`.
- Callers need the local API scope (`IdentityServerConstants.LocalApi.ScopeName`) in their client's `AllowedScopes`.
- The target `backend.api` must validate issuer, signature, and the `backend.api` audience.
- Restrict the policy further (scope/role) — this endpoint mints signed tokens.
