# Production SAML Store

In-memory stores shouldn't be used in production. You should implement a database-backed store.

```csharp
public interface ISamlServiceProviderStore
{
    Task<SamlServiceProvider> FindByEntityIdAsync(string entityId);
}

public class DbSamlStore : ISamlServiceProviderStore
{
    private readonly AppDbContext _db;

    public DbSamlStore(AppDbContext db) => _db = db;

    public async Task<SamlServiceProvider> FindByEntityIdAsync(string entityId)
    {
        return await _db.SamlProviders
            .FirstOrDefaultAsync(sp => sp.EntityId == entityId);
    }
}
```

Register it with DI:

```csharp
builder.Services.AddScoped<ISamlServiceProviderStore, DbSamlStore>();
```

This gives you a persistent store for SAML service providers backed by Entity Framework Core.
