# Token Caching in Duende.AccessTokenManagement v4

## HybridCache — The Default Cache

In v4, client credentials tokens are cached using **`HybridCache`** (introduced in ASP.NET Core 9). This replaces the `IDistributedCache`-based caching used in v3.

## Two-Tier Architecture (L1 + L2)

`HybridCache` is a two-tier cache:

1. **L1 (In-Memory)** — A fast, in-process memory cache. This is always active and requires no configuration. Tokens are served from L1 on cache hits, avoiding any network round-trips.

2. **L2 (Distributed)** — An optional remote cache tier (e.g., Redis, SQL Server). If you register an `IDistributedCache` implementation, `HybridCache` automatically picks it up as the L2 tier. This enables cache sharing across multiple application instances.

```csharp
// ✅ L1 (in-memory) is automatic — no registration needed

// ✅ Add L2 (distributed) by registering a distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

## No More Explicit `AddDistributedMemoryCache()`

In v3, you had to explicitly call `AddDistributedMemoryCache()` (or `AddStackExchangeRedisCache()`) — forgetting this caused a runtime exception.

In v4, **this is no longer required**. `HybridCache`'s L1 tier works out of the box. You only need to register a distributed cache if you want cross-instance cache sharing (the L2 tier).

```csharp
// ❌ v3 — required, or runtime error
services.AddDistributedMemoryCache();

// ✅ v4 — not needed; HybridCache L1 is automatic
// Only add a distributed cache if you want L2 (e.g., Redis for multi-instance)
```

## CacheLifetimeBuffer

The `CacheLifetimeBuffer` option controls how many seconds before a token's actual expiration the library will consider it expired and request a new one. This prevents serving a token that expires during transit.

```csharp
services.AddClientCredentialsTokenManagement(options =>
{
    // Refresh tokens 60 seconds before they expire (this is the default)
    options.CacheLifetimeBuffer = 60;
});
```

For example, if a token has a 3600-second lifetime and `CacheLifetimeBuffer` is 60, the token is cached for 3540 seconds. After that, the next request triggers a fresh token acquisition from the authorization server.

Setting this to 0 is not recommended — a token could expire between retrieval and use at the downstream API, causing unnecessary 401 errors.

## Cache Key Format

The default cache key format is:

```
{CacheKeyPrefix}::{client_name}::hashed({scope})::hashed({resource})
```

Scope and resource values are MD5-hashed to keep key length bounded. You can customize the key generation by implementing `IClientCredentialsCacheKeyGenerator`.
