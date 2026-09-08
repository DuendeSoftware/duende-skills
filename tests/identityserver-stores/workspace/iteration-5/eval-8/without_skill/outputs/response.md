For a shared-database multi-tenant IdentityServer, you keep all tenants' clients in one table with a `TenantId` column and filter by the current tenant in a custom `IClientStore`. Here's the implementation.

## ITenantContext.cs

```csharp
public interface ITenantContext
{
    string TenantId { get; }
}
```

A typical implementation reads the tenant from the current request (host header, path, or a claim):

```csharp
public class HttpTenantContext : ITenantContext
{
    private readonly IHttpContextAccessor _accessor;
    public HttpTenantContext(IHttpContextAccessor accessor) => _accessor = accessor;

    public string TenantId =>
        _accessor.HttpContext?.Request.Headers["X-Tenant-Id"].ToString() ?? string.Empty;
}
```

## TenantAwareClientStore.cs

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using Microsoft.EntityFrameworkCore;

public class TenantAwareClientStore : IClientStore
{
    private readonly AppDbContext _db;
    private readonly ITenantContext _tenant;

    public TenantAwareClientStore(AppDbContext db, ITenantContext tenant)
    {
        _db = db;
        _tenant = tenant;
    }

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var entity = await _db.Clients
            .FirstOrDefaultAsync(c =>
                c.ClientId == clientId &&
                c.TenantId == _tenant.TenantId);

        return entity?.ToModel();
    }
}
```

## Registration

```csharp
builder.Services.AddHttpContextAccessor();
builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(connectionString));
builder.Services.AddScoped<ITenantContext, HttpTenantContext>();

builder.Services.AddIdentityServer()
    .AddClientStore<TenantAwareClientStore>();
```

### Explanation

- **`ITenantContext`** resolves the current tenant per request, so the store never has to be told which tenant it's serving.
- **`FindClientByIdAsync`** filters on both `ClientId` **and** `TenantId`, which is what keeps tenant A from resolving tenant B's clients even if two tenants reuse the same client id.
- **`AddClientStore<TenantAwareClientStore>()`** registers the custom store through the IdentityServer builder rather than a plain `AddTransient`, so it plugs into the store resolution pipeline correctly.
- `AppDbContext.Clients` is your own EF entity carrying the `TenantId` column; `ToModel()`/a mapper converts it to the IdentityServer `Client`.
