Set the lifetimes (in seconds):

```csharp
// web_app
AccessTokenLifetime = 300,    // 5 min
// m2m_client (add)
AccessTokenLifetime = 600,    // 10 min
// mobile_app (add)
AccessTokenLifetime = 300     // 5 min
```

Operational store cleanup:

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(/* with updated lifetimes */)
    // ... existing config ...
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(
            builder.Configuration.GetConnectionString("IdentityServer"));
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;       // 30 min (seconds; default 3600)
        options.RemoveConsumedTokens = true;       // also clean consumed tokens
        options.ConsumedTokenCleanupDelay = 300;   // wait 5 min after consumption
    });
```

Notes:
- Short JWT lifetimes (5–15 min) are the right mitigation because JWTs can't be revoked before `exp`.
- User-facing clients (`web_app`, `mobile_app`) then need refresh tokens: `AllowOfflineAccess = true` plus the `offline_access` scope, so users aren't re-prompted every 5 minutes. M2M clients just request a new token, ideally cached until near expiry.
- Without `EnableTokenCleanup`, expired and consumed grants accumulate indefinitely.
- The operational store requires `Duende.IdentityServer.EntityFramework` and a database; cleanup doesn't apply to in-memory stores.
