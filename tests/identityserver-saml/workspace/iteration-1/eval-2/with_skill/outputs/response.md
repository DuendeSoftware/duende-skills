# Moving SAML Service Providers to a Production Store

## Why Move Away from In-Memory?

`AddInMemorySamlServiceProviders` is fine for development and testing, but **not suitable for production** because:
- Service provider configurations are lost on application restart
- Changes require redeployment
- Cannot be managed dynamically

For production, implement a custom `ISamlServiceProviderStore` backed by a persistent store like EF Core.

## Custom ISamlServiceProviderStore with EF Core

### 1. Create the DbContext

```csharp
using Duende.IdentityServer.Models.Saml;
using Microsoft.EntityFrameworkCore;

public class SamlDbContext : DbContext
{
    public SamlDbContext(DbContextOptions<SamlDbContext> options) : base(options) { }

    public DbSet<SamlServiceProvider> SamlServiceProviders => Set<SamlServiceProvider>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SamlServiceProvider>(entity =>
        {
            entity.HasKey(sp => sp.EntityId);
            entity.Property(sp => sp.EntityId).HasMaxLength(200);
            entity.Property(sp => sp.DisplayName).HasMaxLength(200);
        });
    }
}
```

### 2. Implement ISamlServiceProviderStore

```csharp
using Duende.IdentityServer.Models.Saml;
using Duende.IdentityServer.Saml.Stores;
using Microsoft.EntityFrameworkCore;

public class DatabaseServiceProviderStore : ISamlServiceProviderStore
{
    private readonly SamlDbContext _db;

    public DatabaseServiceProviderStore(SamlDbContext db)
    {
        _db = db;
    }

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken cancellationToken)
    {
        return await _db.SamlServiceProviders
            .FirstOrDefaultAsync(
                sp => sp.EntityId == entityId,
                cancellationToken);
    }
}
```

### 3. Register in Program.cs

```csharp
// Program.cs
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Register the SAML DbContext
builder.Services.AddDbContext<SamlDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddIdentityServer(options =>
{
    options.EmitStaticAudienceClaim = true;
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml()
    // Use the custom EF Core-backed store instead of in-memory
    .AddSamlServiceProviderStore<DatabaseServiceProviderStore>();

builder.Services.AddRazorPages();

var app = builder.Build();

app.UseStaticFiles();
app.UseRouting();
app.UseIdentityServer();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
```

## Key Points

- **`ISamlServiceProviderStore`** is the interface to implement. It has a single method: `FindByEntityIdAsync(string entityId, CancellationToken cancellationToken)`.
- **`AddSamlServiceProviderStore<T>()`** registers your custom store with IdentityServer, replacing the in-memory store.
- The `CancellationToken` parameter was added in Duende IdentityServer v8. If you're on v7, omit it.
- You can seed initial data via EF Core migrations or a separate seed utility.
- Consider adding caching around the store for high-traffic scenarios.
