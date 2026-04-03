# Token Caching in Duende.AccessTokenManagement v4

## Default Caching Behavior

Duende.AccessTokenManagement caches tokens automatically so your application doesn't re-request tokens from the authorization server on every API call.

By default, the library uses `IDistributedCache` for token caching. You need to register a distributed cache implementation in your DI container:

```csharp
// For development / single-instance
builder.Services.AddDistributedMemoryCache();

// For production / multi-instance
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis.example.com:6379";
});
```

## How Caching Works

When a token is requested:
1. The library first checks the cache for an existing valid token
2. If found and not expired, the cached token is returned
3. If not found or expired, a new token is requested from the token endpoint
4. The new token is stored in the cache with an expiry based on the token's `expires_in` value

## Cache Configuration

You can configure the cache lifetime buffer, which controls how many seconds before the actual token expiry the cached token is considered stale:

```csharp
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 60; // seconds before expiry to refresh
});
```

The default buffer ensures tokens are refreshed before they actually expire, avoiding 401 errors from using tokens that expire in transit.

## Custom Cache Implementations

If you need custom caching behavior (e.g., encryption at rest), you can implement `IClientCredentialsTokenCache`:

```csharp
builder.Services.AddSingleton<IClientCredentialsTokenCache, MyCustomCache>();
```

This gives you full control over how tokens are stored and retrieved.
