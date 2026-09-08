# Token Caching in Duende.AccessTokenManagement v4

## Default cache: `HybridCache`

In v4, client credentials tokens are cached using **`HybridCache`** (the ASP.NET Core 9+ caching abstraction) — **not** `IDistributedCache` directly as in v3. This is the default; you don't wire anything up to get in-memory caching.

## Two-tier architecture (L1 + L2)

`HybridCache` is two-tier:

- **L1 — in-memory:** a fast, per-process cache. This is the default tier and works out of the box with no configuration.
- **L2 — distributed (optional):** a remote/shared cache such as Redis. If you register an `IDistributedCache` implementation, `HybridCache` **automatically** uses it as the L2 tier so tokens are shared across instances.

```csharp
// Register Redis and HybridCache picks it up as the L2 tier automatically
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

Reads hit L1 first, then fall back to L2, keeping most lookups in-process while still sharing tokens across a multi-instance deployment.

## No explicit cache registration required

Unlike v3 — where you had to call `AddDistributedMemoryCache()` (or register Redis) or the first token request would fail — **v4 needs no explicit cache registration** for the default in-memory tier. You only add a distributed cache when you specifically want a shared L2 tier for scale-out.

## `CacheLifetimeBuffer` controls refresh timing

Tokens are cached for their lifetime minus a buffer, so a near-expired token is refreshed *before* it actually expires (avoiding a token that dies in transit to the API). Configure it via the options:

```csharp
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60;        // seconds subtracted from token lifetime (default 60)
    options.CacheKeyPrefix = "MyApp.ATM::";  // optional prefix for cache keys
});
```

- **`CacheLifetimeBuffer`** — seconds shaved off the cached lifetime so refresh happens early. Keep it positive; setting it to `0` risks serving a token that expires between retrieval and use.

## Summary

| | v4 |
|---|---|
| Cache used | `HybridCache` (default) |
| Tiers | L1 in-memory + optional L2 distributed (Redis) |
| Explicit registration | Not required for L1; add `IDistributedCache` only for shared L2 |
| Refresh control | `CacheLifetimeBuffer` (default 60s) |

In short: v4 caches tokens automatically with `HybridCache`, gives you an in-memory tier for free, transparently promotes a registered `IDistributedCache` to a shared L2 tier, and lets you tune early refresh with `CacheLifetimeBuffer`.
