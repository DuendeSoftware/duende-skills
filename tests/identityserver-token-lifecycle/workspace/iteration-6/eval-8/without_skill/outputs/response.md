```csharp
// web_app
AccessTokenLifetime = 300,   // 5 min
// m2m_client  (add the property)
AccessTokenLifetime = 600,   // 10 min
// mobile_app  (add the property)
AccessTokenLifetime = 300    // 5 min
```

Operational store with cleanup (requires `Duende.IdentityServer.EntityFramework`):

```csharp
builder.Services.AddIdentityServer()
    .AddInMemoryClients(/* as above with new lifetimes */)
    // ...
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b => b.UseSqlServer(
            builder.Configuration.GetConnectionString("IdentityServer"));
        options.EnableTokenCleanup = true;
        options.TokenCleanupInterval = 1800;          // 30 minutes (seconds)
        options.RemoveConsumedTokens = true;
        options.ConsumedTokenCleanupDelay = 300;      // 5 minutes (seconds)
    });
```

Notes:
- Lifetimes are in seconds.
- `TokenCleanupInterval` defaults to 3600; `RemoveConsumedTokens` defaults to false.
- Short access token lifetimes require refresh tokens for user clients (`AllowOfflineAccess`, `offline_access`); machine clients simply request a new token (cache it until near expiry).
- Mind clock skew: JWT bearer validation has a default 5-minute `ClockSkew`, which can nearly double an effective 5-minute lifetime. Consider lowering it in APIs.
