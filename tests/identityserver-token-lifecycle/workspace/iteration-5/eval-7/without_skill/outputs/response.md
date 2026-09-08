# `/internal-token` Endpoint

Duende IdentityServer provides `IIdentityServerTools`, a helper for issuing tokens from within your own code (rather than going through the protocol endpoints). It has an `IssueClientJwtAsync` method that creates a signed client JWT. Here's a minimal API endpoint that uses it.

## Endpoint implementation

```csharp
using Duende.IdentityServer;

app.MapGet("/internal-token", async (IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600, // 10 minutes
        audiences: new[] { "backend.api" });

    return Results.Ok(new { token });
})
.RequireAuthorization();
```

## How it works

- `IIdentityServerTools` is injected from the DI container (registered by `AddIdentityServer()`).
- `IssueClientJwtAsync` issues a JWT signed with IdentityServer's key material:
  - `clientId: "internal_service"` sets the client identity.
  - `lifetime: 600` sets a 10-minute lifetime (value is in seconds).
  - `audiences: new[] { "backend.api" }` sets the audience so `backend.api` will accept it.
- `.RequireAuthorization()` ensures only authenticated callers can hit the endpoint.

The `backend.api` service validates the resulting token the same way it validates any token from this IdentityServer instance (issuer + audience checks).
