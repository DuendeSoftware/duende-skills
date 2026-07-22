# Moving from In-Memory to a Production SAML Service Provider Store

## Why Replace `AddInMemorySamlServiceProviders`

`AddInMemorySamlServiceProviders` is convenient for development and testing but is unsuitable for production because:

- SP registrations are compiled into the application — a config change requires a redeployment.
- It doesn't scale across multiple instances (no shared state).
- You can't update SP configurations at runtime.

The recommended approach is to implement `IServiceProviderStore`, backed by your database of choice, and layer a memory cache on top to avoid a database hit on every SAML request.

---

## 1. Define Your Persistence Layer

First, ensure you have a way to store SP records in your database. Below is a conceptual EF Core entity; adapt to your schema:

```csharp
public class ServiceProviderRecord
{
    public int Id { get; set; }
    public string EntityId { get; set; } = default!;
    public string AcsUrl { get; set; } = default!;
    public string AcsBinding { get; set; } = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST";
    // Store additional settings as JSON or separate columns
    public string? ClaimMappingsJson { get; set; }
    public bool Enabled { get; set; } = true;
}
```

---

## 2. Implement `IServiceProviderStore`

```csharp
using Duende.IdentityServer.Saml.Models;
using Duende.IdentityServer.Saml.Stores;
using Microsoft.Extensions.Caching.Memory;

public class DatabaseServiceProviderStore : IServiceProviderStore
{
    private readonly AppDbContext _db;
    private readonly IMemoryCache _cache;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(15);

    public DatabaseServiceProviderStore(AppDbContext db, IMemoryCache cache)
    {
        _db = db;
        _cache = cache;
    }

    public async Task<ServiceProvider?> FindByEntityIdAsync(string entityId)
    {
        var cacheKey = $"saml:sp:{entityId}";

        if (_cache.TryGetValue(cacheKey, out ServiceProvider? cached))
            return cached;

        var record = await _db.ServiceProviders
            .AsNoTracking()
            .FirstOrDefaultAsync(sp => sp.EntityId == entityId && sp.Enabled);

        if (record is null)
        {
            // Cache negative result briefly to avoid DB hammering on invalid entity IDs
            _cache.Set(cacheKey, (ServiceProvider?)null, TimeSpan.FromMinutes(1));
            return null;
        }

        var sp = MapToModel(record);
        _cache.Set(cacheKey, sp, CacheDuration);
        return sp;
    }

    private static ServiceProvider MapToModel(ServiceProviderRecord record)
    {
        var sp = new ServiceProvider
        {
            EntityId = record.EntityId,
            AssertionConsumerServices =
            {
                new Service(record.AcsBinding, record.AcsUrl)
            }
        };

        // Optionally deserialize and apply claim mappings
        if (record.ClaimMappingsJson is not null)
        {
            var mappings = System.Text.Json.JsonSerializer
                .Deserialize<Dictionary<string, string>>(record.ClaimMappingsJson);

            if (mappings is not null)
                foreach (var (claimType, samlAttribute) in mappings)
                    sp.ClaimMapping[claimType] = samlAttribute;
        }

        return sp;
    }
}
```

---

## 3. Register the Store

Replace `AddInMemorySamlServiceProviders` with your custom store in `Program.cs`:

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddMemoryCache();

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSamlPlugin()
    .AddSamlServiceProviderStore<DatabaseServiceProviderStore>(); // <-- replaces AddInMemorySamlServiceProviders
```

> The exact extension method name may be `AddServiceProviderStore<T>()` depending on your version of the Duende SAML package — check the API surface of `ISamlBuilder`.

---

## 4. Cache Invalidation

For a multi-instance deployment, consider using `IDistributedCache` (Redis, SQL) instead of `IMemoryCache` so all nodes share the same cached entries. When an SP record is updated in the database, explicitly evict the cache entry:

```csharp
public async Task InvalidateCacheAsync(string entityId)
{
    _cache.Remove($"saml:sp:{entityId}");
}
```

Trigger `InvalidateCacheAsync` from your admin tooling whenever an SP is created, updated, or disabled.

---

## Summary

| Concern | Approach |
|---------|----------|
| Storage | EF Core entity in your existing database |
| Lookup | `IServiceProviderStore.FindByEntityIdAsync` |
| Caching | `IMemoryCache` (single instance) or `IDistributedCache` (multi-instance) |
| Cache TTL | 15 min positive / 1 min negative |
| Registration | `.AddSamlServiceProviderStore<DatabaseServiceProviderStore>()` |
