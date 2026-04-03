# Multi-Tenant Client Store

```csharp
public class TenantClientStore : IClientStore
{
    private readonly AppDbContext _db;
    private readonly IHttpContextAccessor _httpContext;

    public TenantClientStore(AppDbContext db, IHttpContextAccessor httpContext)
    {
        _db = db;
        _httpContext = httpContext;
    }

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var tenantId = _httpContext.HttpContext?.Request.Headers["X-Tenant-Id"].FirstOrDefault();

        var entity = await _db.Clients
            .Where(c => c.TenantId == tenantId && c.ClientId == clientId)
            .FirstOrDefaultAsync();

        return entity?.MapToClient();
    }
}
```

Register:
```csharp
builder.Services.AddTransient<IClientStore, TenantClientStore>();
```

This filters clients by tenant ID from the request header.
