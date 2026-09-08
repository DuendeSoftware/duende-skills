# Migrating `ICache<Client>` off the v7 abstraction

I don't have the precise v8 migration details memorized, so verify the specifics against Duende's official 8.0 upgrade guide. Based on general .NET caching knowledge, here's the likely path.

## What replaces `ICache<T>`

Duende deprecated its internal caching abstraction in favor of standard Microsoft caching. In modern .NET the recommended replacement is **`HybridCache`** (`Microsoft.Extensions.Caching.Hybrid`), which combines in-memory and distributed caching with built-in stampede protection. If your target framework doesn't support `HybridCache`, `IDistributedCache` / `IMemoryCache` are the fallbacks.

## Example with `HybridCache`

```csharp
using Microsoft.Extensions.Caching.Hybrid;

public class ClientCacheService
{
    private readonly HybridCache _cache;
    public ClientCacheService(HybridCache cache) => _cache = cache;

    public async Task<Client?> GetClientAsync(string key, CancellationToken ct)
    {
        return await _cache.GetOrCreateAsync(
            key,
            async token => await LoadFromDbAsync(key, token),
            cancellationToken: ct);
    }
}
```

Register it in `Program.cs`:

```csharp
builder.Services.AddHybridCache();
```

`HybridCache` uses `GetOrCreateAsync` (the factory pattern), which replaces the old `GetOrAddAsync`-style call.

## Registration change

Your old `builder.Services.AddTransient<ICache<Client>, CustomClientCache>();` line should be removed — you no longer implement the Duende cache interface; you consume the framework cache instead.

Because caching internals are implementation-specific, please double-check the official Duende 8.0 documentation for the exact abstraction they now expect (there may be a specific registration or keyed-service convention I'm not certain about).
