# Production SAML service provider store

For production, replace `AddInMemorySamlServiceProviders` with a persistent store: either Duende's Entity Framework configuration store (if it supports SAML SPs in your version) or a custom implementation of the SP store interface, backed by your database and wrapped with caching so each SAML request doesn't hit the DB.

```csharp
public class CachingSamlServiceProviderStore(
    DbSamlSpStore inner, IMemoryCache cache) : ISamlServiceProviderStore
{
    public async Task<SamlServiceProvider?> FindByEntityIdAsync(string entityId)
    {
        return await cache.GetOrCreateAsync($"saml-sp:{entityId}", async e =>
        {
            e.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await inner.FindByEntityIdAsync(entityId);
        });
    }
}

public class DbSamlSpStore(AppDbContext db) : ISamlServiceProviderStore
{
    public async Task<SamlServiceProvider?> FindByEntityIdAsync(string entityId)
    {
        var row = await db.SamlServiceProviders.AsNoTracking()
            .SingleOrDefaultAsync(x => x.EntityId == entityId);
        return row?.ToModel();
    }
}
```

Registration:

```csharp
builder.Services.AddMemoryCache();
builder.Services.AddScoped<DbSamlSpStore>();
builder.Services.AddSamlServiceProviderStore<CachingSamlServiceProviderStore>();
```

Tips: use short TTLs (or cache invalidation), cache null results briefly, use a distributed cache (Redis) across nodes, and keep signing keys/certificates out of the DB or protected. Interface and registration method names are approximate—check your version.
