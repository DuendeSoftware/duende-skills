# Migrating `ICache<Client>` to v8

In v8 the internal `ICache<T>` abstraction is replaced by Microsoft's **`HybridCache`** (from `Microsoft.Extensions.Caching.Hybrid`). IdentityServer registers keyed `HybridCache` instances, so you inject the one you want by key rather than resolving a plain `HybridCache`.

## Before (v7)

```csharp
public class CustomClientCache : ICache<Client>
{
    public Task<Client?> GetOrAddAsync(string key, TimeSpan duration, Func<Task<Client?>> factory)
        => factory();
    // SetAsync / GetAsync / RemoveAsync ...
}

// registration
builder.Services.AddTransient<ICache<Client>, CustomClientCache>();
```

## After (v8) — use `HybridCache` with keyed injection

```csharp
using Microsoft.Extensions.Caching.Hybrid;
using Microsoft.Extensions.DependencyInjection;

public class ClientCacheService
{
    private readonly HybridCache _cache;

    public ClientCacheService(
        [FromKeyedServices("ConfigurationStoreCache")] HybridCache cache)
        => _cache = cache;

    public async Task<Client?> GetClientAsync(string key, CancellationToken ct)
    {
        return await _cache.GetOrCreateAsync(
            key,
            async token => await LoadFromDbAsync(key, token),
            new HybridCacheEntryOptions
            {
                Expiration = TimeSpan.FromMinutes(5)
            },
            cancellationToken: ct);
    }
}
```

## Key points

- **Keyed injection is required.** Use `[FromKeyedServices("ConfigurationStoreCache")]` (the string constant is `ServiceProviderKeys.ConfigurationStoreCache`). A plain `HybridCache` injection resolves a *different* instance and will not behave as the configuration-store cache.
- **`GetOrCreateAsync` replaces `GetOrAddAsync`.** The factory receives a `CancellationToken`, and expiration is supplied via `HybridCacheEntryOptions` rather than a `TimeSpan` argument.
- **You no longer register your own cache as transient.** `HybridCache` is provided by the framework; drop the `AddTransient<ICache<Client>, ...>()` registration. Add the `Microsoft.Extensions.Caching.Hybrid` package if it isn't already present.
- **`CachingOptions.CacheLockTimeout` is now obsolete** — `HybridCache` handles stampede protection internally, so that option no longer applies and should be removed.
