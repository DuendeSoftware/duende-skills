Duende's built-in config-store caching (`AddConfigurationStoreCache()`) uses `ICache<T>`, in-memory by default. To use Redis, register a distributed-cache-backed `ICache<T>`.

```csharp
var redis = builder.Configuration["Redis:ConnectionString"];
builder.Services.AddStackExchangeRedisCache(o => o.Configuration = redis);

builder.Services.AddIdentityServer(o =>
{
    o.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(10);
    o.Caching.ResourceStoreExpiration = TimeSpan.FromMinutes(10);
})
.AddConfigurationStore(o => o.ConfigureDbContext = b =>
    b.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer"),
        s => s.MigrationsAssembly(typeof(Program).Assembly.GetName().Name)))
.AddConfigurationStoreCache();

// override the in-memory ICache<T> after AddIdentityServer
builder.Services.AddTransient(typeof(ICache<>), typeof(DistributedCache<>));
```

```csharp
using System.Text.Json;
using Duende.IdentityServer.Services;
using Microsoft.Extensions.Caching.Distributed;

public class DistributedCache<T> : ICache<T> where T : class
{
    private readonly IDistributedCache _cache;
    public DistributedCache(IDistributedCache cache) => _cache = cache;
    private static string Key(string k) => $"ids:{typeof(T).Name}:{k}";

    public async Task<T?> GetAsync(string key)
    {
        var bytes = await _cache.GetAsync(Key(key));
        return bytes is null ? null : JsonSerializer.Deserialize<T>(bytes);
    }

    public Task SetAsync(string key, T item, TimeSpan expiration) =>
        _cache.SetAsync(Key(key), JsonSerializer.SerializeToUtf8Bytes(item),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = expiration });

    public async Task<T?> GetOrAddAsync(string key, TimeSpan duration, Func<Task<T>> get)
    {
        var item = await GetAsync(key);
        if (item is not null) return item;
        item = await get();
        if (item is not null) await SetAsync(key, item, duration);
        return item;
    }
}
```
Caveat: the models (Client, Resources) must serialize cleanly with System.Text.Json; test this. Also cache invalidation takes up to 10 minutes after config changes.
