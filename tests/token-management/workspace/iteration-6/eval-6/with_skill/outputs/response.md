# Redis + 120 s buffer + encrypted token cache (v4)

v4 caches client credentials tokens with **HybridCache**: in-memory L1, and any registered `IDistributedCache` (Redis) acts as the L2 that's shared across instances.

```csharp
// L2 cache for HybridCache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");   // redis.example.com:6379
});

// Data Protection – keys must be shared by all instances, otherwise they can't read each other's entries
builder.Services.AddDataProtection()
    .SetApplicationName("webapp");   // plus PersistKeysTo... (Redis/blob/db) in production

builder.Services.AddClientCredentialsTokenManagement(options =>
{
    options.CacheLifetimeBuffer = 120;          // seconds subtracted from token lifetime
    options.CacheKeyPrefix = "MyApp.ATM::";     // keeps keys apart on the shared Redis
});

// Encrypt tokens at rest with a custom serializer
builder.Services.AddHybridCache()
    .AddSerializer<ClientCredentialsToken, EncryptedHybridCacheSerializer>();
```

```csharp
public sealed class EncryptedHybridCacheSerializer : IHybridCacheSerializer<ClientCredentialsToken>
{
    private readonly IDataProtector _protector;

    public EncryptedHybridCacheSerializer(IDataProtectionProvider provider)
        => _protector = provider.CreateProtector("ClientCredentialsToken");

    public ClientCredentialsToken Deserialize(ReadOnlySequence<byte> source)
    {
        var json = _protector.Unprotect(source.ToArray());
        return JsonSerializer.Deserialize<ClientCredentialsToken>(json)!;
    }

    public void Serialize(ClientCredentialsToken value, IBufferWriter<byte> target)
    {
        var json = JsonSerializer.SerializeToUtf8Bytes(value);
        target.Write(_protector.Protect(json));
    }
}
```

## Notes
- No `AddDistributedMemoryCache()` here: that was the v3 approach.
- `CacheLifetimeBuffer` defaults to 60; never set it to 0 (tokens may expire in transit → avoidable 401s). 120 is fine.
- To scope a custom `HybridCache` only to this library (rather than app-wide), register it as a keyed singleton: `services.AddKeyedSingleton<HybridCache>(ServiceProviderKeys.ClientCredentialsTokenCache, ...)`.
- Other options: `DefaultCacheLifetime` (5 min, used before the real expiry is known), `UseCacheAutoTuning` (default `false`), `LocalCacheExpiration` (1 min).
- This cache covers client credentials tokens; user tokens live in the auth session (cookie) unless you replace `IUserTokenStore`.
