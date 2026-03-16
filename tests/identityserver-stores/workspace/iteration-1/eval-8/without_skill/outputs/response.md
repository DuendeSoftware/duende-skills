# Multi-Tenant IClientStore Implementation

Here's how to implement a tenant-aware client store with shared database and tenant filtering.

## Tenant Context Interface

```csharp
public interface ITenantContext
{
    string TenantId { get; }
}
```

## AppDbContext with TenantId Column

```csharp
using Microsoft.EntityFrameworkCore;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<ClientEntity> Clients => Set<ClientEntity>();
}

public class ClientEntity
{
    public int Id { get; set; }
    public string ClientId { get; set; } = default!;
    public string TenantId { get; set; } = default!;
    public string? ClientName { get; set; }
    public string AllowedGrantTypesJson { get; set; } = default!;
    public string AllowedScopesJson { get; set; } = default!;
    public string? ClientSecretsJson { get; set; }
}
```

## TenantAwareClientStore

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

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

        if (entity is null) return null;

        return new Client
        {
            ClientId = entity.ClientId,
            ClientName = entity.ClientName,
            AllowedGrantTypes = JsonSerializer.Deserialize<List<string>>(entity.AllowedGrantTypesJson) ?? new(),
            AllowedScopes = JsonSerializer.Deserialize<List<string>>(entity.AllowedScopesJson) ?? new()
        };
    }
}
```

## Registration

```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer")));

builder.Services.AddScoped<ITenantContext, HttpTenantContext>();
builder.Services.AddTransient<IClientStore, TenantAwareClientStore>();

builder.Services.AddIdentityServer()
    .AddOperationalStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(builder.Configuration.GetConnectionString("IdentityServer"));
    });
```

This registers the tenant-aware store in the DI container. The `FindClientByIdAsync` method filters by both `ClientId` and `TenantId` to enforce tenant isolation.
