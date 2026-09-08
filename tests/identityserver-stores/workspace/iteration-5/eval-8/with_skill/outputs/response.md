For a shared-database multi-tenant setup, keep a single `AppDbContext` and enforce tenant isolation at the application layer by scoping every query to the current `TenantId`. Here's a tenant-aware `IClientStore` that filters by both the requested `clientId` and the tenant supplied by an `ITenantContext`.

## ITenantContext.cs

```csharp
public interface ITenantContext
{
    string TenantId { get; }
}
```

(Populate this per request — e.g., from a claim, subdomain, or route value — and register it as scoped.)

## TenantAwareClientStore.cs

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

## Registration (Program.cs)

```csharp
builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(connectionString));
builder.Services.AddScoped<ITenantContext, HttpTenantContext>();

builder.Services.AddIdentityServer()
    .AddClientStore<TenantAwareClientStore>(); // use the builder helper, not AddTransient
```

### Why this is correct and safe

- **Filter on both `TenantId` and `ClientId`.** The `Where(c => c.TenantId == _tenantContext.TenantId && c.ClientId == clientId)` clause is the security boundary: a client id that exists for tenant A will not resolve when the current tenant is B, preventing cross-tenant client resolution.
- **`ITenantContext` is injected**, so the store always resolves the tenant for the current request rather than trusting a caller-supplied value.
- **Register via `AddClientStore<TenantAwareClientStore>()`**, not `AddTransient<IClientStore, ...>()`. The builder helper wires the store into IdentityServer's store pipeline (and lets you layer `AddClientStoreCache<T>()` later if needed).
- **`AppDbContext.Clients`** is your own entity with a `TenantId` column; map the entity to the IdentityServer `Client` model (`ToIdentityServerClient()`) before returning it.

> Note: operational data (grants, sessions) needs the same tenant discipline. Do not share a `PersistedGrantDbContext` across tenants without equivalent tenant scoping, or a grant issued for one tenant could be looked up by another.
