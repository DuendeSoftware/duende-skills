# `/internal-token` Endpoint Using `IIdentityServerTools`

When your own extensibility/host code needs to call a backend API, don't drive the protocol token endpoint yourself — use `IIdentityServerTools.IssueClientJwtAsync`, which mints a client JWT directly using IdentityServer's signing keys. Here's a minimal API endpoint that issues a 10-minute token for `internal_service` targeting `backend.api`, protected by authorization.

## Endpoint

```csharp
using Duende.IdentityServer;

app.MapGet("/internal-token", async (IIdentityServerTools tools) =>
{
    var token = await tools.IssueClientJwtAsync(
        clientId: "internal_service",
        lifetime: 600, // 10 minutes, in seconds
        audiences: new[] { "backend.api" });

    return Results.Ok(new { access_token = token });
})
.RequireAuthorization();
```

## Notes

- **`IIdentityServerTools`** is resolved from DI and injected straight into the endpoint delegate. It's registered automatically by `AddIdentityServer()`.
- **`IssueClientJwtAsync`** parameters:
  - `clientId: "internal_service"` — the client identity stamped into the token.
  - `lifetime: 600` — seconds (10 minutes).
  - `audiences: new[] { "backend.api" }` — the `aud` the backend will validate against.
- **`RequireAuthorization()`** locks the endpoint down so only authenticated callers can mint internal tokens. (You could also apply a named policy, e.g. `RequireAuthorization("InternalOnly")`, or use `[Authorize]` on a controller equivalent.)

The returned JWT is signed by IdentityServer, so `backend.api` validates it exactly like any other access token issued by this authority — check the issuer and that `aud` contains `backend.api`.
