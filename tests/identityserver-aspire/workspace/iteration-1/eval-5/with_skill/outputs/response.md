# Fixing IDX20803: Unable to obtain configuration

## Root Cause

The error `IDX20803: Unable to obtain configuration from '.well-known/openid-configuration'` means your API is starting before IdentityServer is ready. When the API's JWT bearer handler tries to download the discovery document and signing keys during startup, IdentityServer isn't yet accepting requests.

## Fix: Add WaitFor and WithReference in the AppHost

```csharp
var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

// Fix: Add both WithReference AND WaitFor
var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)   // Makes the endpoint URL available
    .WaitFor(identityServer);         // Waits for health check to pass
```

Both calls are needed:
- **`.WithReference(identityServer)`** — Makes the IdentityServer endpoint URL available to the API via service discovery
- **`.WaitFor(identityServer)`** — Holds the API from starting until IdentityServer's health check returns healthy

## Health Check Requirement

`WaitFor()` polls the target's `/health` endpoint. IdentityServer must expose a health check for this to work:

```csharp
// In IdentityServer's Program.cs
builder.Services.AddHealthChecks();

app.MapHealthChecks("/health");
```

Without health checks, `WaitFor()` has no readiness signal and the dependent service may start too early or the AppHost may time out.

If using `AddServiceDefaults()` from the Aspire service defaults project, the `/health` endpoint may already be mapped, but verify it's present.
