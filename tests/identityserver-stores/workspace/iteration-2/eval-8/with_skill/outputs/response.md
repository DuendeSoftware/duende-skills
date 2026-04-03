# Tenant-Aware IClientStore for Multi-Tenant IdentityServer

## Custom Store Implementation

```csharp
// TenantAwareClientStore.cs
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using Microsoft.EntityFrameworkCore;

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
```

## ITenantContext Interface

```csharp
// ITenantContext.cs
public interface ITenantContext
{
    string TenantId { get; }
}

// Example implementation that reads tenant from the request
public class HttpTenantContext : ITenantContext
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public HttpTenantContext(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public string TenantId =>
        _httpContextAccessor.HttpContext?.Request.Headers["X-Tenant-Id"].FirstOrDefault()
        ?? throw new InvalidOperationException("Tenant ID not found in request");
}
```

## Registration

```csharp
// Program.cs
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ITenantContext, HttpTenantContext>();

builder.Services.AddIdentityServer()
    .AddClientStore<TenantAwareClientStore>();
```

## Key Points

- `TenantAwareClientStore` implements `IClientStore` and takes both `AppDbContext` and `ITenantContext`
- `FindClientByIdAsync` filters by **both** `clientId` and `TenantId` to enforce tenant isolation
- Registered via `AddClientStore<TenantAwareClientStore>()` on the IdentityServer builder
- `ITenantContext` provides the current tenant identifier (resolved from the request)
