# Production SAML Service Provider Store with EF Core

## Why Not In-Memory?

`AddInMemorySamlServiceProviders` is fine for development but **not suitable for production**:
- Cannot be updated without restarting the application
- Data is lost on restart
- Cannot be shared across multiple nodes

## Implement ISamlServiceProviderStore

```csharp
// DatabaseServiceProviderStore.cs
using Duende.IdentityServer.Saml.Models;
using Duende.IdentityServer.Saml.Stores;
using Microsoft.EntityFrameworkCore;

public class DatabaseServiceProviderStore : ISamlServiceProviderStore
{
    private readonly SamlDbContext _db;

    public DatabaseServiceProviderStore(SamlDbContext db) => _db = db;

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken cancellationToken)
    {
        return await _db.SamlServiceProviders
            .Include(sp => sp.SigningCertificates)
            .Include(sp => sp.EncryptionCertificates)
            .FirstOrDefaultAsync(
                sp => sp.EntityId == entityId,
                cancellationToken);
    }
}
```

## EF Core DbContext

```csharp
// SamlDbContext.cs
using Duende.IdentityServer.Saml.Models;
using Microsoft.EntityFrameworkCore;

public class SamlDbContext : DbContext
{
    public SamlDbContext(DbContextOptions<SamlDbContext> options) : base(options) { }

    public DbSet<SamlServiceProvider> SamlServiceProviders => Set<SamlServiceProvider>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SamlServiceProvider>(entity =>
        {
            entity.HasKey(e => e.EntityId);
            // Configure additional mappings as needed
        });
    }
}
```

## Registration

```csharp
// Program.cs
builder.Services.AddDbContext<SamlDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Saml")));

builder.Services.AddIdentityServer()
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddSaml()
    .AddSamlServiceProviderStore<DatabaseServiceProviderStore>();
```

## Key Points

- Implement `ISamlServiceProviderStore` with `FindByEntityIdAsync(string entityId, CancellationToken cancellationToken)`
- Register using `AddSamlServiceProviderStore<T>()` — this replaces the in-memory store
- Use EF Core (or any data access technology) for persistence
