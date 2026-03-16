# Tenant-Aware IClientStore for Multi-Tenant IdentityServer

Here's a shared-database multi-tenant `IClientStore` that filters clients by tenant using `ITenantContext`.

## ITenantContext Interface

```csharp
public interface ITenantContext
{
    string TenantId { get; }
}
```

## Client Entity with TenantId

```csharp
public class TenantClient
{
    public int Id { get; set; }
    public string ClientId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string ClientName { get; set; } = default!;
    public string AllowedGrantTypes { get; set; } = default!;
    public string AllowedScopes { get; set; } = default!;
    public string ClientSecrets { get; set; } = default!;
    public string? RedirectUris { get; set; }
    public string? PostLogoutRedirectUris { get; set; }
    // Add additional properties as needed
}
```

## AppDbContext

```csharp
using Microsoft.EntityFrameworkCore;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<TenantClient> Clients => Set<TenantClient>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TenantClient>(entity =>
        {
            entity.HasIndex(e => new { e.TenantId, e.ClientId }).IsUnique();
        });
    }
}
```

## TenantAwareClientStore

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using Microsoft.EntityFrameworkCore;

public sealed class TenantAwareClientStore : IClientStore
{
    private readonly AppDbContext _db;
    private readonly ITenantContext _tenantContext;

    public TenantAwareClientStore(AppDbContext db, ITenantContext tenantContext)
    {
        _db = db;
        _tenantContext = tenantContext;
    }

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var entity = await _db.Clients
            .Where(c => c.TenantId == _tenantContext.TenantId && c.ClientId == clientId)
            .FirstOrDefaultAsync();

        return entity?.ToIdentityServerClient();
    }
}
```

Note: `FindClientByIdAsync` does **not** include a `CancellationToken` parameter because this project targets Duende IdentityServer v7. The `CancellationToken` parameter was added in v8.

## Registration

Register the tenant-aware store using `AddClientStore<T>()`:

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer")));

builder.Services.AddScoped<ITenantContext, HttpTenantContext>(); // your tenant resolution logic

builder.Services.AddIdentityServer()
    .AddClientStore<TenantAwareClientStore>()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer"), sql =>
                sql.MigrationsAssembly(typeof(Program).Assembly.GetName().Name));
        options.EnableTokenCleanup = true;
    });
```

**Key points:**

- `AddClientStore<TenantAwareClientStore>()` registers the custom store with IdentityServer's DI — this is the correct Duende pattern for custom store registration.
- The `Where` clause filters by both `TenantId` (from `ITenantContext`) and `ClientId` to ensure proper tenant isolation.
- `ITenantContext` abstracts how the current tenant is resolved (e.g., from subdomain, header, or route).
