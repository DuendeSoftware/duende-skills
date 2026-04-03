# Fixing IDX20803: Unable to Obtain Configuration

The error `IDX20803: Unable to obtain configuration from '.well-known/openid-configuration'` means the API is trying to fetch IdentityServer's discovery document but IdentityServer isn't ready yet.

## Root Cause

The API is starting before IdentityServer is fully operational. When the API configures JWT Bearer authentication, it immediately tries to download the JWKS (signing keys) from IdentityServer's `/.well-known/openid-configuration` endpoint. If IdentityServer hasn't finished starting up, this request fails.

In Aspire, services start in parallel by default. Without explicit dependency ordering, the API has no way to know it should wait for IdentityServer.

## Fix: Add WithReference and WaitFor in the AppHost

In your AppHost's `Program.cs`, ensure the API project has both `.WithReference(identityServer)` and `.WaitFor(identityServer)`:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var sqlServer = builder.AddSqlServer("sql");
var identityDb = sqlServer.AddDatabase("identitydb");

var identityServer = builder.AddProject<Projects.IdentityServer>("identity-server")
    .WithReference(identityDb)
    .WaitFor(sqlServer);

var api = builder.AddProject<Projects.WeatherApi>("weather-api")
    .WithReference(identityServer)   // Makes the endpoint URL available
    .WaitFor(identityServer);        // Holds startup until IdentityServer is healthy

builder.Build().Run();
```

### What each call does:

- **`.WithReference(identityServer)`** — Makes IdentityServer's endpoint URL available to the API via Aspire service discovery. Without this, the API won't know where IdentityServer is.
- **`.WaitFor(identityServer)`** — Prevents the API from starting until IdentityServer's health check returns healthy. This is the key piece that fixes the timing issue.

Both are needed. `WithReference` alone provides the URL but doesn't prevent premature startup. `WaitFor` alone doesn't expose the endpoint URL.

## Required: IdentityServer Must Expose Health Checks

For `WaitFor()` to work, IdentityServer needs to expose a health check endpoint. Aspire polls `/health` to determine readiness. If IdentityServer doesn't have health checks configured, `WaitFor()` has no readiness signal and may time out or let dependents start too early.

Add health checks in IdentityServer's `Program.cs`:

```csharp
// Register health checks
builder.Services.AddHealthChecks();

// After building the app
app.MapHealthChecks("/health");
```

This gives Aspire a `/health` endpoint to poll. When it returns HTTP 200, Aspire knows IdentityServer is ready and allows the API to start.

If you're using `AddServiceDefaults()` from the Aspire service defaults project, the `/health` endpoint may already be mapped — but you still need to register the health checks in the DI container with `AddHealthChecks()`.
