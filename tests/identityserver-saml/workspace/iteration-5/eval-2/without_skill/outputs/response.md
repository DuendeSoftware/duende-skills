# Production SAML Service Provider Store

Using `AddInMemorySamlServiceProviders` is fine for demos and local development, but in production you don't want your service-provider registrations living in process memory — they'd be lost on restart, can't be updated without a redeploy, and aren't shared across instances. The usual pattern is to back the store with a database and put a cache in front of it.

## 1. Implement a custom store

Most IdentityServer store abstractions follow the same shape: an interface you implement and register in DI. For SAML service providers, implement the store interface and load your SPs from your database:

```csharp
public class DbServiceProviderStore : IServiceProviderStore
{
    private readonly AppDbContext _db;
    private readonly IMemoryCache _cache;

    public DbServiceProviderStore(AppDbContext db, IMemoryCache cache)
    {
        _db = db;
        _cache = cache;
    }

    public async Task<ServiceProvider?> FindServiceProviderAsync(string entityId)
    {
        return await _cache.GetOrCreateAsync($"sp:{entityId}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(15);
            var sp = await _db.ServiceProviders
                .FirstOrDefaultAsync(x => x.EntityId == entityId);
            return sp?.ToModel();
        });
    }

    public async Task<IEnumerable<ServiceProvider>> GetAllAsync()
    {
        return await _db.ServiceProviders.Select(x => x.ToModel()).ToListAsync();
    }
}
```

## 2. Register it in DI

```csharp
builder.Services.AddMemoryCache();
builder.Services.AddScoped<IServiceProviderStore, DbServiceProviderStore>();
```

Because you registered your own implementation, it replaces the in-memory one.

## 3. Caching strategy

The example above caches each service provider lookup for 15 minutes using `IMemoryCache`. In a multi-node deployment, consider a distributed cache (Redis via `IDistributedCache`) so all nodes share the same cached data and you can invalidate entries centrally when an SP changes.

## Summary

- In-memory stores are for development only.
- Back the store with a real database (EF Core is common).
- Add a caching layer (in-memory for single node, Redis/`IDistributedCache` for multi-node) to avoid a DB hit on every SAML request.
- Provide a way to invalidate the cache when SP configuration changes.

Check the exact SAML store interface names and registration extension methods against your SAML library's documentation, since these differ between implementations.
