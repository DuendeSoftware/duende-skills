```csharp
public interface ITenantContext { string TenantId { get; } }

public class ClientEntity
{
    public int Id { get; set; }
    public string TenantId { get; set; } = default!;
    public string ClientId { get; set; } = default!;
    public string ClientName { get; set; } = default!;
    public string AllowedGrantTypes { get; set; } = "";   // space-delimited
    public string AllowedScopes { get; set; } = "";
    public string RedirectUris { get; set; } = "";
    public string? SecretHash { get; set; }
    public bool Enabled { get; set; } = true;
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> o) : base(o) { }
    public DbSet<ClientEntity> Clients => Set<ClientEntity>();
    protected override void OnModelCreating(ModelBuilder mb)
        => mb.Entity<ClientEntity>().HasIndex(c => new { c.TenantId, c.ClientId }).IsUnique();
}

public class TenantClientStore : IClientStore
{
    private readonly AppDbContext _db;
    private readonly ITenantContext _tenant;
    public TenantClientStore(AppDbContext db, ITenantContext tenant) => (_db, _tenant) = (db, tenant);

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct = default)
    {
        var tenantId = _tenant.TenantId;
        var e = await _db.Clients.AsNoTracking()
            .FirstOrDefaultAsync(c => c.TenantId == tenantId && c.ClientId == clientId && c.Enabled, ct);
        if (e is null) return null;
        return new Client
        {
            ClientId = e.ClientId,
            ClientName = e.ClientName,
            AllowedGrantTypes = e.AllowedGrantTypes.Split(' ', StringSplitOptions.RemoveEmptyEntries),
            AllowedScopes = e.AllowedScopes.Split(' ', StringSplitOptions.RemoveEmptyEntries),
            RedirectUris = e.RedirectUris.Split(' ', StringSplitOptions.RemoveEmptyEntries),
            ClientSecrets = e.SecretHash is null ? new List<Secret>() : new List<Secret> { new Secret(e.SecretHash) }
        };
    }
}
```
Registration:
```csharp
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ITenantContext, HttpTenantContext>(); // resolves from host/claim/header
builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlServer(cs));
builder.Services.AddIdentityServer().AddClientStore<TenantClientStore>();
```
Note: don't wrap this in the shared client-store cache without including the tenant in the cache key, or tenants will see each other's clients.
