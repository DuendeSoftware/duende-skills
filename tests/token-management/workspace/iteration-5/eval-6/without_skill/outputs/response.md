# Distributed Token Caching with Redis + Encryption

For a multi-instance deployment you want the token cache shared across instances (Redis) and, because the Redis instance is shared with other apps, encrypted at rest. Here's an approach.

## 1. Register Redis as the distributed cache

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});
```

The token management library uses the registered distributed cache to store tokens, so all instances share the same cache.

## 2. Configure the cache lifetime buffer

```csharp
builder.Services.AddClientCredentialsTokenManagement(options =>
{
    // Refresh tokens 120 seconds before they actually expire
    options.CacheLifetimeBuffer = 120;
})
.AddClient("catalog", client =>
{
    client.TokenEndpoint = "https://sts.example.com/connect/token";
    client.ClientId = "catalog-worker";
    client.ClientSecret = "worker-secret";
    client.Scope = "catalog:read";
});
```

## 3. Encrypt cached tokens with Data Protection

Since the Redis instance is shared, wrap the distributed cache so entries are encrypted before they're written and decrypted on read, using ASP.NET Core Data Protection:

```csharp
builder.Services.AddDataProtection();

// Decorate IDistributedCache so values are encrypted at rest
builder.Services.AddSingleton<IDistributedCache>(sp =>
{
    var redis = new RedisCache(new RedisCacheOptions
    {
        Configuration = builder.Configuration.GetConnectionString("Redis")
    });
    var protector = sp.GetRequiredService<IDataProtectionProvider>()
                      .CreateProtector("TokenCache");
    return new EncryptedDistributedCache(redis, protector);
});

public sealed class EncryptedDistributedCache : IDistributedCache
{
    private readonly IDistributedCache _inner;
    private readonly IDataProtector _protector;

    public EncryptedDistributedCache(IDistributedCache inner, IDataProtector protector)
    {
        _inner = inner;
        _protector = protector;
    }

    public byte[]? Get(string key)
    {
        var data = _inner.Get(key);
        return data is null ? null : _protector.Unprotect(data);
    }

    public void Set(string key, byte[] value, DistributedCacheEntryOptions options)
        => _inner.Set(key, _protector.Protect(value), options);

    // ... implement the remaining IDistributedCache members by delegating to _inner
    // and protecting/unprotecting the byte[] payloads ...
}
```

## Production notes

- **Share the Data Protection keyring** across instances (e.g. persist keys to Redis or a shared store), otherwise instances can't decrypt each other's entries.
- Keep the client secret in a secret store, not in code.
- A positive `CacheLifetimeBuffer` (120s here) avoids serving a token that expires in transit.

> Note: the exact caching abstraction can differ between library versions, so confirm against the current Duende.AccessTokenManagement docs whether it caches through `IDistributedCache` directly or through another cache abstraction, and adapt the encryption wrapper accordingly.
