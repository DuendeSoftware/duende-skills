`IDX20803: Unable to obtain configuration from '.../.well-known/openid-configuration'` means your API (or its JWT bearer / OIDC handler) tried to download IdentityServer's discovery document at startup and the request failed — because **IdentityServer wasn't ready yet**. In Aspire, resources start in parallel by default, so the API races ahead of IdentityServer and the metadata fetch throws.

## Root cause

The API is starting before IdentityServer is up and serving `/.well-known/openid-configuration` (and JWKS). There's no dependency ordering telling Aspire to hold the API until IdentityServer is healthy.

## The fix

In the **AppHost**, make the API both reference *and* wait for IdentityServer:

```csharp
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)   // exposes the IdentityServer endpoint URL to the API
    .WaitFor(identityServer);        // holds the API until IdentityServer is healthy
```

- **`WithReference(identityServer)`** makes IdentityServer's endpoint URL discoverable to the API (so the authority resolves correctly).
- **`WaitFor(identityServer)`** delays API startup until IdentityServer reports healthy — eliminating the race that produces IDX20803.

You need **both**: `WithReference` alone provides the URL but doesn't prevent premature startup; `WaitFor` alone blocks startup but doesn't expose the endpoint.

## Make WaitFor actually work — health checks

`WaitFor()` polls the target's health endpoint to decide when it's "ready." If IdentityServer doesn't expose one, `WaitFor` has no readiness signal. Add health checks in **IdentityServer's** `Program.cs`:

```csharp
builder.Services.AddHealthChecks();
// ...
app.MapHealthChecks("/health");
```

For stronger guarantees, add readiness checks that confirm IdentityServer can actually serve its discovery document and signing keys before the API is released to start (`DiscoveryDocumentHealthCheck` / `DiscoveryKeysHealthCheck` — see the deployment skill).

With the dependency edge (`WithReference` + `WaitFor`) and a health check in place, the API won't start until IdentityServer's discovery endpoint is live, and IDX20803 goes away.
