# Migrating ICache<Client> in IdentityServer v8

When upgrading to IdentityServer v8, the caching infrastructure has likely changed. Here's my best guidance:

## Possible Migration Path

If `ICache<T>` has been removed in v8, you'll likely need to replace it with a standard .NET caching mechanism. Options include:

### Using IDistributedCache

```csharp
public class CustomClientCache
{
    private readonly IDistributedCache _cache;

    public CustomClientCache(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<Client?> GetClientAsync(string key)
    {
        var cached = await _cache.GetStringAsync(key);
        if (cached != null)
            return JsonSerializer.Deserialize<Client>(cached);
        return null;
    }
}
```

### Using IMemoryCache

```csharp
public class CustomClientCache
{
    private readonly IMemoryCache _cache;

    public CustomClientCache(IMemoryCache cache)
    {
        _cache = cache;
    }

    public async Task<Client?> GetOrAddAsync(string key, TimeSpan duration, Func<Task<Client?>> factory)
    {
        return await _cache.GetOrCreateAsync(key, async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = duration;
            return await factory();
        });
    }
}
```

## Registration

```csharp
// Remove the old registration
// builder.Services.AddTransient<ICache<Client>, CustomClientCache>();

// Register standard caching
builder.Services.AddMemoryCache();
// or
builder.Services.AddDistributedMemoryCache();
```

Check the v8 migration docs for the exact recommended replacement pattern. The framework may provide a built-in caching abstraction that integrates with IdentityServer's internal cache invalidation.
