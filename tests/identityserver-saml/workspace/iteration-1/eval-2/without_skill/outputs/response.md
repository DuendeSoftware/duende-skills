# Production SAML Service Provider Store

## Moving Beyond In-Memory

For production use, you should not rely on `AddInMemorySamlServiceProviders` as it stores data only in memory and loses all configuration on restart. Instead, implement a database-backed store.

## Implementing a Custom Store

### 1. Create a DbContext

```csharp
using Microsoft.EntityFrameworkCore;

public class SamlDbContext : DbContext
{
    public SamlDbContext(DbContextOptions<SamlDbContext> options) : base(options) { }

    public DbSet<SamlServiceProviderEntity> ServiceProviders => Set<SamlServiceProviderEntity>();
}

public class SamlServiceProviderEntity
{
    public int Id { get; set; }
    public string EntityId { get; set; } = default!;
    public string DisplayName { get; set; } = default!;
    public string AcsUrl { get; set; } = default!;
    public bool RequireSigned { get; set; }
}
```

### 2. Implement the Store Interface

```csharp
public class EfCoreSamlServiceProviderStore : ISamlServiceProviderStore
{
    private readonly SamlDbContext _context;

    public EfCoreSamlServiceProviderStore(SamlDbContext context)
    {
        _context = context;
    }

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(string entityId)
    {
        var entity = await _context.ServiceProviders
            .FirstOrDefaultAsync(x => x.EntityId == entityId);

        if (entity == null) return null;

        return new SamlServiceProvider
        {
            EntityId = entity.EntityId,
            DisplayName = entity.DisplayName,
            AssertionConsumerServiceUrl = entity.AcsUrl,
        };
    }
}
```

### 3. Register the Store

```csharp
builder.Services.AddDbContext<SamlDbContext>(options =>
    options.UseSqlServer(connectionString));

builder.Services.AddIdentityServer()
    .AddSaml()
    .AddSamlServiceProviderStore<EfCoreSamlServiceProviderStore>();
```

## Key Points

- Use a real database for production deployments
- The store interface lets you implement custom lookup logic
- Consider adding caching for better performance
- Use EF Core migrations to manage the schema
