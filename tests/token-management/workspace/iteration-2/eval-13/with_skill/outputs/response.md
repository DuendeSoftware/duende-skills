# Token Caching in Duende.AccessTokenManagement v4

## HybridCache — The Default Cache

Duende.AccessTokenManagement v4 uses **HybridCache** (introduced in ASP.NET Core 9) for token caching. This is a two-tier cache architecture:

- **L1 (in-memory)**: Fast, process-local cache. This is the first tier checked when a token is requested.
- **L2 (distributed)**: Optional remote cache (e.g., Redis, SQL Server). If registered, HybridCache automatically uses it as a second tier.

By default, with no additional configuration, you get the in-memory L1 tier. There is **no need to call `AddDistributedMemoryCache()`** — this was required in v3 but is no longer necessary in v4. HybridCache handles the in-memory tier automatically.

## How It Works

When your code requests a token (either via `IHttpClientFactory` or manually via `IClientCredentialsTokenManager`):

1. The library checks the L1 in-memory cache first
2. If not found in L1, it checks the L2 distributed cache (if registered)
3. If not found in either tier, it requests a new token from the token endpoint
4. The token is stored in both cache tiers with a lifetime derived from the token's `expires_in` value minus the `CacheLifetimeBuffer`

## CacheLifetimeBuffer

The `CacheLifetimeBuffer` controls how many seconds before actual expiry the library considers a token "expired" and requests a new one. The default is **60 seconds**.

```csharp
services.AddClientCredentialsTokenManagement(options =>
{
    // Refresh tokens 120 seconds before they expire
    options.CacheLifetimeBuffer = 120;
});
```

This prevents serving a near-expired token that might expire in transit between your service and the API, which would result in unnecessary 401 responses.

## Adding a Distributed L2 Cache

To add Redis as the L2 tier (recommended for multi-instance deployments):

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

HybridCache automatically discovers and uses the registered `IDistributedCache` as its L2 tier. No additional wiring is needed.

## Key Differences from v3

| Aspect | v3 | v4 |
|---|---|---|
| Cache type | `IDistributedCache` directly | `HybridCache` (two-tier) |
| Setup required | Must call `AddDistributedMemoryCache()` or register Redis | Nothing required for in-memory; just register `IDistributedCache` for L2 |
| Cache tiers | Single tier only | L1 (in-memory) + L2 (distributed) |
