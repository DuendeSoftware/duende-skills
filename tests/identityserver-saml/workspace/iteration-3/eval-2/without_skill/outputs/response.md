# Moving SAML SP Configuration to Production

## Why Change from In-Memory?

In-memory stores are fine for development but not suitable for production because:
- Data is lost on app restart
- Can't be updated without redeployment
- Doesn't work well in multi-instance deployments

## Production Approaches

### Option 1: Database-backed Store

You can implement a custom store that reads from a database:

```csharp
public class DatabaseSamlServiceProviderStore : ISamlServiceProviderStore
{
    private readonly AppDbContext _context;

    public DatabaseSamlServiceProviderStore(AppDbContext context)
    {
        _context = context;
    }

    public async Task<ServiceProvider> FindByEntityIdAsync(string entityId)
    {
        return await _context.ServiceProviders
            .FirstOrDefaultAsync(sp => sp.EntityId == entityId);
    }

    public async Task<IEnumerable<ServiceProvider>> GetAllAsync()
    {
        return await _context.ServiceProviders.ToListAsync();
    }
}
```

### Option 2: Configuration File

For smaller deployments, you could load from a JSON configuration file that can be updated without recompilation.

### Registration

```csharp
services.AddSingleton<ISamlServiceProviderStore, DatabaseSamlServiceProviderStore>();
```

### Adding Caching

For better performance, wrap with a caching decorator:

```csharp
services.AddMemoryCache();
services.Decorate<ISamlServiceProviderStore, CachedSamlServiceProviderStore>();
```

The cached implementation would use `IMemoryCache` or `IDistributedCache` to reduce database round-trips.
