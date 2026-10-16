# `ICache<Client>` → `HybridCache` in v8

v8 replaces IdentityServer's `ICache<T>` with Microsoft's **`HybridCache`**. The IdentityServer caches are exposed as a **keyed service** named `"ConfigurationStoreCache"` (`ServiceProviderKeys.ConfigurationStoreCache`).

## Your registration
Remove the `ICache<Client>` registration and the class:
```csharp
// ❌ delete
builder.Services.AddTransient<ICache<Client>, CustomClientCache>();
```
Whether it was registered as transient doesn't matter any more. Instead, take the keyed `HybridCache` where you need caching.

## Consuming code
```csharp
public class CachedClientLookup
{
    private readonly HybridCache _cache;
    private readonly AppDbContext _db;

    public CachedClientLookup(
        [FromKeyedServices("ConfigurationStoreCache")] HybridCache cache,
        AppDbContext db)
    { _cache = cache; _db = db; }

    public async Task<Client?> GetAsync(string clientId, CancellationToken ct)
        => await _cache.GetOrCreateAsync(
            $"client:{clientId}",
            async token => await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, token),
            new HybridCacheEntryOptions { Expiration = TimeSpan.FromMinutes(5) },
            cancellationToken: ct);
}
```

## Notes
- **Use the keyed service.** Injecting plain `HybridCache` gets a different instance from the one IdentityServer uses.
- `GetOrAddAsync(key, duration, factory)` becomes `GetOrCreateAsync(key, factory(token), options, cancellationToken)`. The factory receives a token, so pass it through.
- `CachingOptions.CacheLockTimeout` is obsolete.
- `SetAsync`/`GetAsync`/`RemoveAsync` map to `SetAsync`/`RemoveAsync` on `HybridCache`. There is no separate "get only" call, so use `GetOrCreateAsync`.
- Your `CustomClientStore` also needs the `CancellationToken` parameter and `GetAllClientsAsync`, and the target framework must be `net10.0`.
