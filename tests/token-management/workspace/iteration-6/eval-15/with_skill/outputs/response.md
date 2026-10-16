# `UseCacheAutoTuning`

**Default: `false`.**

It's a property on `ClientCredentialsTokenManagementOptions`. When set to `true`, the cache entry lifetime follows the token's actual expiration (as returned by the token endpoint, minus `CacheLifetimeBuffer`) instead of a fixed estimate. With it `false`, the first request caches the token for `DefaultCacheLifetime` (5 minutes by default, because the real expiry isn't known when the entry is created).

```csharp
services.AddClientCredentialsTokenManagement(options =>
{
    options.UseCacheAutoTuning = true;   // opt in; default is false
    options.CacheLifetimeBuffer = 60;    // default 60 s
});
```

Related settings: `DefaultCacheLifetime` (5 min), `LocalCacheExpiration` (1 min for the in-memory L1 of HybridCache), `CacheKeyPrefix`, `NonceStoreKeyPrefix`.
