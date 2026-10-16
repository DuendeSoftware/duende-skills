# Token caching in v4

**Default cache:** v4 uses **`HybridCache`** (ASP.NET Core 9+) for client credentials tokens: a two-tier cache with an in-memory L1 and an optional remote L2. With no extra registration you get the in-memory tier. If you register an `IDistributedCache` (for example `AddStackExchangeRedisCache`), HybridCache uses it automatically as L2, shared across instances. (v3 used `IDistributedCache` directly and required `AddDistributedMemoryCache()`.)

```csharp
builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration.GetConnectionString("Redis"));
```

**Options** (`AddClientCredentialsTokenManagement(options => ...)`):
- `CacheLifetimeBuffer`: seconds subtracted from the token lifetime (default 60) so near-expired tokens aren't served; don't set 0.
- `CacheKeyPrefix`: prefix for cache keys.
- `DefaultCacheLifetime`: 5 minutes, used for the first request before the true expiry is known.
- `UseCacheAutoTuning`: defaults to `false`; when `true` the entry lifetime follows the actual token expiration.
- `LocalCacheExpiration`: 1 minute for the local tier.
- `NonceStoreKeyPrefix`: DPoP nonces.

**Key format:** `{CacheKeyPrefix}::{client_name}::hashed({scope})::hashed({resource})` (MD5-hashed scope/resource). Implement `IClientCredentialsCacheKeyGenerator` if you add custom `TokenRequestParameters`.

**Customization:**
- Replace the whole thing with `services.AddSingleton<IClientCredentialsTokenCache, MyCache>()`.
- Scope a custom `HybridCache` to this library only: `services.AddKeyedSingleton<HybridCache>(ServiceProviderKeys.ClientCredentialsTokenCache, ...)`.
- Encrypt cached tokens (shared Redis) with a custom `IHybridCacheSerializer<ClientCredentialsToken>` using Data Protection.

User tokens aren't in this cache; they live in the authentication session (cookie) by default, or a custom `IUserTokenStore`. And never cache tokens yourself in fields.
