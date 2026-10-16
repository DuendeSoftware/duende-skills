# Distributed caching for multi-instance IdentityServer

Some features require ASP.NET Core `IDistributedCache`; the default is a per-node in-memory cache, so state written by one instance isn't visible to another.

| Feature | Why it needs a distributed cache |
|---|---|
| **OIDC state data formatter** | Stores external-provider state server-side (instead of in the URL) |
| JWT replay cache | Prevents replay of client-credential JWTs across instances |
| Device flow throttling | Rate-limits polling across instances |
| Authorization parameter store | Stores PAR request data |

Your intermittent external-provider login failures fit this: the login redirect starts on instance A and the callback hits instance B, which doesn't have the state → failure.

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

Also required for multi-instance (the same root cause class):
- **Data Protection**: persisted to shared durable storage, with an explicit application name, since it protects OIDC state, cookies, grants:
```csharp
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(redis, "DataProtection-Keys")
    .ProtectKeysWithCertificate(cert)
    .SetApplicationName("My.IdentityServer");
```
(Configure Redis persistence RDB/AOF so keys survive restarts.)
- **Shared operational data** (grants, consent) via EF operational store, which includes the signing key store; **shared signing keys**. Your current in-memory stores for configuration are fine only if every instance runs the same build.
- Enable `AddConfigurationStoreCache()` when using EF configuration.
- ForwardedHeaders for proxies/load balancer.
