```csharp
public interface ITenantContext { string TenantId { get; } }

public sealed class ClientEntity
{
    public int Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string ClientName { get; set; } = default!;
    public string AllowedGrantTypes { get; set; } = "";
    public string AllowedScopes { get; set; } = "";
    public string RedirectUris { get; set; } = "";
    public string? SecretHash { get; set; }
    public bool Enabled { get; set; } = true;

    public Client ToIdentityServerClient() => new()
    {
        ClientId = ClientId, ClientName = ClientName, Enabled = Enabled,
        AllowedGrantTypes = AllowedGrantTypes.Split(' ', StringSplitOptions.RemoveEmptyEntries),
        AllowedScopes = AllowedScopes.Split(' ', StringSplitOptions.RemoveEmptyEntries),
        RedirectUris = RedirectUris.Split(' ', StringSplitOptions.RemoveEmptyEntries),
        ClientSecrets = SecretHash is null ? new List<Secret>() : new List<Secret> { new(SecretHash) }
    };
}

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<ClientEntity> Clients => Set<ClientEntity>();
    protected override void OnModelCreating(ModelBuilder mb)
        => mb.Entity<ClientEntity>().HasIndex(c => new { c.TenantId, c.ClientId }).IsUnique();
}

public sealed class TenantAwareClientStore : IClientStore
{
    private readonly AppDbContext _db;
    private readonly ITenantContext _tenantContext;

    public TenantAwareClientStore(AppDbContext db, ITenantContext tenantContext)
        => (_db, _tenantContext) = (db, tenantContext);

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct = default)
    {
        var tenantId = _tenantContext.TenantId;
        var entity = await _db.Clients.AsNoTracking()
            .Where(c => c.TenantId == tenantId && c.ClientId == clientId)
            .FirstOrDefaultAsync(ct);
        return entity?.ToIdentityServerClient();
    }

    public async IAsyncEnumerable<Client> GetAllClientsAsync(
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        var tenantId = _tenantContext.TenantId;
        await foreach (var e in _db.Clients.AsNoTracking().Where(c => c.TenantId == tenantId).AsAsyncEnumerable().WithCancellation(ct))
            yield return e.ToIdentityServerClient();
    }
}
```

Registration (helper method, not `AddTransient`):
```csharp
builder.Services.AddScoped<ITenantContext, HttpTenantContext>();
builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(connectionString));
builder.Services.AddIdentityServer().AddClientStore<TenantAwareClientStore>();
```
The project is on v8 so signatures include `CancellationToken` and `GetAllClientsAsync`; on v7 drop both. Don't wrap this with `AddClientStoreCache` unless the tenant is in the cache key. For a managed model, consider Spaces (Duende Storage). Keep operational data tenant-isolated too.
