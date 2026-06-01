# Migrating ICache<Client> to HybridCache in v8

In IdentityServer v8, `ICache<T>` is removed and replaced with Microsoft's `HybridCache` from `Microsoft.Extensions.Caching.Hybrid`. Here's how to migrate:

## 1. Update Your Service

```csharp
using Microsoft.Extensions.Caching.Hybrid;
using Microsoft.Extensions.DependencyInjection;

// ❌ Before (v7)
public class CustomClientCache : ICache<Client>
{
    public Task<Client?> GetOrAddAsync(string key, TimeSpan duration, Func<Task<Client?>> factory)
    {
        return factory();
    }
    // ...
}

// ✅ After (v8) — Use HybridCache with keyed service injection
public class MyClientService
{
    private readonly HybridCache _cache;

    public MyClientService(
        [FromKeyedServices("ConfigurationStoreCache")] HybridCache cache)
    {
        _cache = cache;
    }

    public async Task<Client?> GetClientAsync(string key, CancellationToken ct)
    {
        return await _cache.GetOrCreateAsync(key,
            async token => await LoadClientFromDbAsync(key, token),
            new HybridCacheEntryOptions
            {
                Expiration = TimeSpan.FromMinutes(5)
            },
            cancellationToken: ct);
    }
}
```

## Key Changes

1. **Replace `ICache<T>` with `HybridCache`** from `Microsoft.Extensions.Caching.Hybrid`
2. **Use keyed service injection**: `[FromKeyedServices("ConfigurationStoreCache")]` (or the constant `ServiceProviderKeys.ConfigurationStoreCache`)
3. **Use `GetOrCreateAsync`** instead of `GetOrAddAsync`
4. **`CachingOptions.CacheLockTimeout` is obsolete** — HybridCache handles concurrency internally

## 2. Update Registration

Remove your old `ICache<Client>` registration:

```csharp
// ❌ Remove
builder.Services.AddTransient<ICache<Client>, CustomClientCache>();

// ✅ HybridCache is registered automatically by IdentityServer v8
// If you need custom configuration:
builder.Services.AddHybridCache(options =>
{
    options.DefaultEntryOptions = new HybridCacheEntryOptions
    {
        Expiration = TimeSpan.FromMinutes(10)
    };
});
```
