# Token Caching in Duende.AccessTokenManagement v4

## Default Cache

Duende.AccessTokenManagement v4 uses `HybridCache` for token caching. This is a newer caching abstraction in ASP.NET Core that provides a layered caching approach.

## How It Works

HybridCache provides two levels of caching:

- **L1 (In-Memory)**: A fast, in-process memory cache that serves tokens without any network calls
- **L2 (Distributed)**: An optional distributed cache (like Redis) for sharing tokens across multiple application instances

The L1 cache is always available by default. If you register an `IDistributedCache` implementation (like Redis), HybridCache automatically uses it as the L2 tier.

```csharp
// Optional: Add Redis as L2 distributed cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
});
```

## No Explicit Cache Registration Required

Unlike v3 which required `AddDistributedMemoryCache()`, v4 works out of the box. The HybridCache's in-memory L1 tier is automatic.

## CacheLifetimeBuffer

You can configure how long before expiration a token should be refreshed:

```csharp
services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60; // seconds before expiry to refresh
});
```

This ensures tokens are refreshed before they actually expire, avoiding race conditions where a token expires during an API call.
