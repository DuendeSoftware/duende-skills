# Tenant-Aware Client Store

```csharp
public interface ITenantContext
{
    string TenantId { get; }
}

public class TenantAwareClientStore : IClientStore
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

public class AppDbContext : DbContext
{
    public DbSet<ClientEntity> Clients => Set<ClientEntity>();

    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
}

public class ClientEntity
{
    public int Id { get; set; }
    public string ClientId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    // ... other client properties
}
```

Register:
```csharp
builder.Services.AddIdentityServer()
    .AddClientStore<TenantAwareClientStore>();
```