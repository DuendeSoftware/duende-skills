# Moving SAML Service Providers to Production

Using in-memory configuration for SAML service providers works for development, but **you should use a persistent store for production**. This ensures your SP configurations survive restarts and can be managed dynamically.

## Implementing a Custom Store

You'll want to implement a store interface that IdentityServer uses to look up service providers. Here's an EF Core-backed implementation:

```csharp
using Microsoft.EntityFrameworkCore;

public class SamlServiceProviderDbStore
{
    private readonly AppDbContext _db;

    public SamlServiceProviderDbStore(AppDbContext db)
    {
        _db = db;
    }

    public async Task<SamlServiceProvider?> GetByEntityIdAsync(string entityId)
    {
        return await _db.SamlServiceProviders
            .FirstOrDefaultAsync(sp => sp.EntityId == entityId);
    }
}
```

## DbContext

```csharp
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<SamlServiceProvider> SamlServiceProviders => Set<SamlServiceProvider>();
}
```

## Registration

Register your store in the DI container:

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<SamlServiceProviderDbStore>();

builder.Services.AddIdentityServer()
    .AddSaml();
```

## Tips

- Index the `EntityId` column for fast lookups
- Consider caching frequently accessed service providers
- Use migrations to version your schema