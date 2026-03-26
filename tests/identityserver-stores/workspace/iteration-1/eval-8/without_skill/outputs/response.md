# Multi-Tenant Client Store

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

        return entity?.ToModel();
    }
}
```

Register:
```csharp
builder.Services.AddTransient<IClientStore, TenantAwareClientStore>();
```