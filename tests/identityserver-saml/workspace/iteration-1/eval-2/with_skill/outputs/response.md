# Moving SAML Service Providers to a Production Store

In-memory stores (`AddInMemorySamlServiceProviders`) are fine for development and testing, but **not suitable for production** — they don't persist across restarts and can't be updated dynamically.

For production, implement a custom `ISamlServiceProviderStore` backed by EF Core and register it with `AddSamlServiceProviderStore<T>()`.

## Custom Store Implementation

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using Microsoft.EntityFrameworkCore;

public class SamlServiceProviderStore : ISamlServiceProviderStore
{
    private readonly SamlDbContext _db;

    public SamlServiceProviderStore(SamlDbContext db)
    {
        _db = db;
    }

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken cancellationToken = default)
    {
        var entity = await _db.ServiceProviders
            .Include(sp => sp.AssertionConsumerServices)
            .Include(sp => sp.SigningCertificates)
            .Include(sp => sp.EncryptionCertificates)
            .FirstOrDefaultAsync(
                sp => sp.EntityId == entityId,
                cancellationToken);

        if (entity == null) return null;

        return MapToModel(entity);
    }

    private static SamlServiceProvider MapToModel(SamlServiceProviderEntity entity)
    {
        return new SamlServiceProvider
        {
            EntityId = entity.EntityId,
            DisplayName = entity.DisplayName,
            AssertionConsumerServiceUrls = entity.AssertionConsumerServices
                .Select(a => new Uri(a.Url))
                .ToList(),
            EncryptAssertions = entity.EncryptAssertions,
            RequireConsent = entity.RequireConsent,
            SigningBehavior = entity.SigningBehavior,
            AllowIdpInitiated = entity.AllowIdpInitiated
        };
    }
}
```

## EF Core DbContext

```csharp
public class SamlDbContext : DbContext
{
    public SamlDbContext(DbContextOptions<SamlDbContext> options) : base(options) { }

    public DbSet<SamlServiceProviderEntity> ServiceProviders => Set<SamlServiceProviderEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SamlServiceProviderEntity>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.EntityId).IsUnique();
            entity.HasMany(e => e.AssertionConsumerServices);
            entity.HasMany(e => e.SigningCertificates);
            entity.HasMany(e => e.EncryptionCertificates);
        });
    }
}

public class SamlServiceProviderEntity
{
    public int Id { get; set; }
    public string EntityId { get; set; } = default!;
    public string? DisplayName { get; set; }
    public bool EncryptAssertions { get; set; }
    public bool RequireConsent { get; set; }
    public SamlSigningBehavior SigningBehavior { get; set; }
    public bool AllowIdpInitiated { get; set; }
    public List<AssertionConsumerServiceEntity> AssertionConsumerServices { get; set; } = [];
    public List<CertificateEntity> SigningCertificates { get; set; } = [];
    public List<CertificateEntity> EncryptionCertificates { get; set; } = [];
}

public class AssertionConsumerServiceEntity
{
    public int Id { get; set; }
    public string Url { get; set; } = default!;
}

public class CertificateEntity
{
    public int Id { get; set; }
    public byte[] RawData { get; set; } = default!;
}
```

## Registration in Program.cs

```csharp
builder.Services.AddDbContext<SamlDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("SamlDb")));

builder.Services.AddIdentityServer()
    .AddSaml()
    .AddSamlServiceProviderStore<SamlServiceProviderStore>();
```

## Key Points

- `ISamlServiceProviderStore` has a single method: `FindByEntityIdAsync(string entityId, CancellationToken cancellationToken)`
- Register with `.AddSamlServiceProviderStore<T>()` — this replaces `AddInMemorySamlServiceProviders`
- The `CancellationToken` parameter was added in v8 — omit it if targeting v7
- Design the EF Core schema with proper indexing on `EntityId` for efficient lookups