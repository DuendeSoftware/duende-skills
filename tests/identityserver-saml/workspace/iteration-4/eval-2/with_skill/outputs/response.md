# Moving SAML Service Provider Registration to Production

Using `AddInMemorySamlServiceProviders` means your SP configurations are hardcoded in the binary and lost on every restart — fine for development, unacceptable in production. Here are the two recommended production patterns, with the custom store + caching approach shown in detail.

---

## Option A: EF Core Configuration Store (Recommended for Most Teams)

If you're already using (or willing to adopt) Duende's EF Core configuration store, SAML SPs are stored automatically in the same database as OIDC clients and resources.

```csharp
builder.Services.AddIdentityServer()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString,
                sql => sql.MigrationsAssembly("YourMigrationsProject"));
    })
    // Remove AddInMemorySamlServiceProviders — EF Core picks up SPs automatically
    .AddSaml();
```

Run the EF migration to get the SAML-specific tables:

```bash
dotnet ef migrations add Update_DuendeIdentityServer_v8_0
dotnet ef database update
```

Service providers are then managed via the EF DbContext or the IdentityServer admin UI — no code changes needed when adding/removing SPs.

---

## Option B: Custom Store with Caching (Full Control)

Use this when SPs live in your own database, a REST API, or any other external source.

### 1. Implement `ISamlServiceProviderStore`

```csharp
using Duende.IdentityServer.Saml.Stores;
using Duende.IdentityServer.Saml.Models;

public class DatabaseSamlServiceProviderStore : ISamlServiceProviderStore
{
    private readonly IServiceProviderRepository _repository;

    public DatabaseSamlServiceProviderStore(IServiceProviderRepository repository)
    {
        _repository = repository;
    }

    // Called on every SSO/SLO request — must be fast (cache sits above this)
    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken ct)
    {
        var record = await _repository.GetByEntityIdAsync(entityId, ct);
        if (record is null) return null;

        return MapToSamlServiceProvider(record);
    }

    // Called when generating IdP metadata listing all known SPs
    public async IAsyncEnumerable<SamlServiceProvider> GetAllSamlServiceProvidersAsync(
        [EnumeratorCancellation] CancellationToken ct)
    {
        await foreach (var record in _repository.StreamAllAsync(ct))
        {
            yield return MapToSamlServiceProvider(record);
        }
    }

    private static SamlServiceProvider MapToSamlServiceProvider(SpRecord record) =>
        new SamlServiceProvider
        {
            EntityId = record.EntityId,
            DisplayName = record.DisplayName,
            Enabled = record.IsEnabled,

            AssertionConsumerServiceUrls =
            [
                new IndexedEndpoint
                {
                    Location = record.AcsUrl,
                    Binding = SamlBinding.HttpPost, // only HttpPost is valid
                    Index = 0,
                    IsDefault = true
                }
            ],

            SingleLogoutServiceUrls = record.SloUrl is not null
                ?
                [
                    new SamlEndpointType
                    {
                        Location = record.SloUrl,
                        Binding = SamlBinding.HttpRedirect
                    }
                ]
                : [],

            AllowedScopes = record.AllowedScopes,
            ClaimMappings = record.ClaimMappings,
            DefaultNameIdFormat = SamlNameIdFormat.EmailAddress,
            SigningBehavior = SamlSigningBehavior.SignAssertion
        };
}
```

> **Validation is automatic**: All stores are wrapped by `ValidatingSamlServiceProviderStore<T>` which checks EntityId is set, at least one ACS URL exists (HTTP-POST only), AllowedScopes is non-empty, and lifetimes are positive. Invalid SPs are silently treated as non-existent — check logs if an SP appears to be missing.

### 2. Register with the Caching Decorator

The `.AddSamlServiceProviderStoreCache<T>()` extension wraps your store in a **HybridCache** layer. This is crucial: `FindByEntityIdAsync` is called on every SSO and SLO request, so without caching your SP store becomes a hot path to your database.

```csharp
builder.Services.AddIdentityServer(options =>
{
    // Tune cache expiration (default: 15 minutes)
    options.Caching.SamlServiceProviderStoreExpiration = TimeSpan.FromMinutes(30);
})
    .AddInMemoryClients(Config.Clients)
    .AddInMemoryIdentityResources(Config.IdentityResources)
    .AddInMemoryApiScopes(Config.ApiScopes)
    .AddTestUsers(TestUsers.Users)
    .AddSaml()
    // Register the store WITH the HybridCache decorator — not AddSamlServiceProviderStore
    .AddSamlServiceProviderStoreCache<DatabaseSamlServiceProviderStore>();

// Register your repository as a scoped service
builder.Services.AddScoped<IServiceProviderRepository, SqlServiceProviderRepository>();
```

The cache key is the SP's `entityId`. Cache entries expire after `SamlServiceProviderStoreExpiration`. A cache miss falls through to your `DatabaseSamlServiceProviderStore.FindByEntityIdAsync`.

### 3. (Optional) Cache Invalidation via IDistributedCache

For distributed deployments (multiple nodes), use a shared distributed cache so that an SP update propagated from one node invalidates others. Configure HybridCache with a Redis or SQL Server backplane:

```csharp
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
});

// HybridCache uses the IDistributedCache registered above as its L2 cache
builder.Services.AddHybridCache();
```

With this in place, `AddSamlServiceProviderStoreCache<T>` will use Redis as the distributed layer — an SP change written to one node will be picked up by all nodes within the cache expiration window.

---

## Comparison

| Approach | Best for | Trade-offs |
|----------|----------|------------|
| EF Core config store | Teams already on Duende's EF store | Tied to EF; requires migration |
| Custom store + cache | External SP registry, REST API, legacy DB | More code; you own the mapping |
| In-memory *(avoid in prod)* | Local development only | Lost on restart, hardcoded |

---

## What to Keep in Mind

- **Clock skew & assertion lifetime**: These are separate from cache expiration. A 30-minute cache means SP config changes (like a new ACS URL) take up to 30 minutes to propagate.
- **Certificate rotation**: IdP signing certs are in metadata, which SPs cache too (default 12h). Plan certificate rotation accordingly.
- **Operational stores**: If you're on multiple nodes, also configure `ISamlSigninStateStore` and `ISamlLogoutSessionStore`. Adding `AddOperationalStore()` (EF Core) registers both automatically.
