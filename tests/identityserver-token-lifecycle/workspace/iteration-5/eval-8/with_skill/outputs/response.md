# Tightening Access Token Lifetimes and Token Cleanup

One-hour JWT access tokens are too long precisely because JWTs **cannot be revoked** — they stay valid until `exp`. Shortening them to 5–15 minutes limits the blast radius of a leaked token; refresh tokens handle longevity. Below: shorter access-token lifetimes per client, plus operational-store cleanup so expired/consumed tokens don't pile up.

## 1. Shorter access token lifetimes

```csharp
// web_app
AccessTokenLifetime = 300   // 5 minutes

// m2m_client
AccessTokenLifetime = 600   // 10 minutes

// mobile_app
AccessTokenLifetime = 300   // 5 minutes
```

Applied in context:

```csharp
new Client
{
    ClientId = "web_app",
    // ...
    AccessTokenLifetime = 300 // was 3600
},
new Client
{
    ClientId = "m2m_client",
    // ...
    AccessTokenLifetime = 600
},
new Client
{
    ClientId = "mobile_app",
    // ...
    AccessTokenLifetime = 300
}
```

## 2. Operational store token cleanup

Token cleanup runs on the **operational store** (add it via `AddOperationalStore`, backed by e.g. EF Core). Configure the interval and consumed-token handling:

```csharp
builder.Services.AddIdentityServer()
    // ... AddInMemoryClients(...), etc. ...
    .AddOperationalStore(options =>
    {
        options.EnableTokenCleanup = true;        // turn on background cleanup
        options.TokenCleanupInterval = 1800;      // every 30 minutes (seconds)
        options.RemoveConsumedTokens = true;      // also purge consumed tokens
        options.ConsumedTokenCleanupDelay = 300;  // wait 5 minutes after consumption
    });
```

| Option | Value | Meaning |
| --- | --- | --- |
| `EnableTokenCleanup` | `true` | Runs the periodic cleanup host |
| `TokenCleanupInterval` | `1800` | Cleanup runs every 30 minutes (in seconds) |
| `RemoveConsumedTokens` | `true` | Consumed (used one-time) tokens are removed, not just expired ones |
| `ConsumedTokenCleanupDelay` | `300` | Grace of 5 minutes after consumption before removal |

> The `ConsumedTokenCleanupDelay` grace matters if you also implement `AcceptConsumedTokenAsync` for refresh-token resilience — it keeps consumed tokens around briefly so the grace-period logic still has a row to inspect. Without `EnableTokenCleanup`, expired and consumed tokens accumulate in the store indefinitely.
