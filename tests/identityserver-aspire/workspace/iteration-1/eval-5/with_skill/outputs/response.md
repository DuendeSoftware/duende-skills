# Fixing "IDX20803: Unable to obtain configuration" in Aspire

## Root Cause

The error `IDX20803: Unable to obtain configuration from '.well-known/openid-configuration'` occurs because **your API is starting before IdentityServer is ready**. When the API's JWT Bearer authentication middleware initializes, it tries to download the OpenID Connect discovery document from IdentityServer. If IdentityServer hasn't finished starting yet, this HTTP request fails.

In Aspire, services start in parallel by default. Without explicit dependency ordering, the API may attempt to fetch the discovery document before IdentityServer is listening.

## Fix: Add WaitFor and WithReference in the AppHost

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Both WithReference AND WaitFor are needed
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)   // Makes the endpoint URL available
    .WaitFor(identityServer);         // Delays startup until IdentityServer is healthy
```

### Why both calls are needed:

| Call | Purpose |
|---|---|
| `.WithReference(identityServer)` | Makes the IdentityServer endpoint URL available to the API via service discovery |
| `.WaitFor(identityServer)` | Holds the API from starting until IdentityServer's health check returns healthy |

`WithReference` alone provides the URL but doesn't prevent the API from starting early. `WaitFor` alone delays startup but doesn't expose the endpoint URL.

## Required: Health Checks in IdentityServer

For `WaitFor(identityServer)` to work, **IdentityServer must expose a health check endpoint**. Aspire polls this endpoint to determine readiness. Without it, `WaitFor` has no readiness signal and may time out or let services start prematurely.

At minimum, add to IdentityServer's `Program.cs`:

```csharp
builder.Services.AddHealthChecks();

// After building the app
app.MapHealthChecks("/health");
```

If you're already using Aspire's `AddServiceDefaults()`, the `/health` endpoint may already be mapped, but you should verify it's present.

For production-grade readiness, add checks that verify IdentityServer can actually serve its discovery document:

```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"])
    .AddCheck<DiscoveryDocumentHealthCheck>("discovery", tags: ["ready"]);

app.MapHealthChecks("/health");
```
