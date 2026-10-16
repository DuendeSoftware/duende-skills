# Redis cache, 120s buffer, encrypted tokens

```csharp
builder.Services.AddStackExchangeRedisCache(o =>
{
    o.Configuration = builder.Configuration.GetConnectionString("Redis");
    o.InstanceName = "tokens:";
});

builder.Services.AddDataProtection()
    .SetApplicationName("webapp")
    .PersistKeysToStackExchangeRedis(  // or blob/file share/DB – must be shared across instances
        ConnectionMultiplexer.Connect(builder.Configuration.GetConnectionString("Redis")!),
        "DataProtection-Keys");

builder.Services.AddOpenIdConnectAccessTokenManagement(o =>
{
    o.RefreshBeforeExpiration = TimeSpan.FromSeconds(120);
});

builder.Services.AddClientCredentialsTokenManagement(o =>
{
    o.CacheLifetimeBuffer = 120;   // seconds
});
```

Token cache in v4 is based on HybridCache; with a registered `IDistributedCache` (Redis) it becomes the L2 cache while memory is L1. To encrypt cached payloads, use a custom `HybridCacheSerializer`/cache wrapper that runs the serialized token through `IDataProtector.Protect` and `Unprotect`:

```csharp
builder.Services.AddHybridCache().AddSerializer<TokenResult, ProtectedTokenSerializer>();
```

Make sure the Data Protection key ring and application name are the same on every instance, otherwise instances can't read each other's entries. Also use a dedicated `InstanceName` prefix since Redis is shared.
