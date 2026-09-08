# Moving from In-Memory to a Production SAML SP Store

`AddInMemorySamlServiceProviders` is **development-only**. It holds your service providers in a static list in process memory: changes require a redeploy, nothing is shared across nodes, and there's no persistence. **Do not use it in production.**

For production you have two supported options:

1. **EF Core configuration store** (`AddConfigurationStore`) — recommended if you already use the Duende EF stores. SAML SPs are persisted alongside your other configuration data.
2. **A custom `ISamlServiceProviderStore`** — when your SP data lives in your own backend (an existing database, an internal admin API, etc.).

Below is the custom-store approach with a caching layer, which is what you asked for.

## Implement `ISamlServiceProviderStore`

The interface has two members: a single-lookup by entity ID and a stream of all SPs (used for metadata and SLO fan-out).

```csharp
using System.Runtime.CompilerServices;
using Duende.IdentityServer.Saml.Models;
using Duende.IdentityServer.Saml.Stores;

public class SqlSamlServiceProviderStore : ISamlServiceProviderStore
{
    private readonly AppDbContext _db;

    public SqlSamlServiceProviderStore(AppDbContext db) => _db = db;

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken ct)
    {
        var record = await _db.SamlServiceProviders
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.EntityId == entityId, ct);

        return record is null ? null : MapToModel(record);
    }

    public async IAsyncEnumerable<SamlServiceProvider> GetAllSamlServiceProvidersAsync(
        [EnumeratorCancellation] CancellationToken ct)
    {
        await foreach (var record in _db.SamlServiceProviders
                           .AsNoTracking()
                           .AsAsyncEnumerable()
                           .WithCancellation(ct))
        {
            yield return MapToModel(record);
        }
    }

    private static SamlServiceProvider MapToModel(SamlServiceProviderEntity e) =>
        new()
        {
            EntityId = e.EntityId,
            DisplayName = e.DisplayName,
            AssertionConsumerServiceUrls =
            [
                new IndexedEndpoint
                {
                    Location = e.AcsUrl,
                    Binding = SamlBinding.HttpPost,
                    Index = 0,
                    IsDefault = true
                }
            ],
            AllowedScopes = e.AllowedScopes.Split(' ')
        };
}
```

Return `null` from `FindByEntityIdAsync` for unknown SPs — the pipeline treats a null result (and any SP that fails validation) as non-existent.

## Register the store, then add caching

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddSamlServiceProviderStore<SqlSamlServiceProviderStore>()
    // HybridCache layer in front of your custom store
    .AddSamlServiceProviderStoreCache<SqlSamlServiceProviderStore>();
```

`AddSamlServiceProviderStoreCache<T>()` wraps your store with a `HybridCache`-backed layer so repeated lookups for the same entity ID don't hit your backend on every SAML request. Cache lifetime is controlled by:

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Caching.SamlServiceProviderStoreExpiration = TimeSpan.FromMinutes(30); // default 15 min
})
.AddSaml()
.AddSamlServiceProviderStore<SqlSamlServiceProviderStore>()
.AddSamlServiceProviderStoreCache<SqlSamlServiceProviderStore>();
```

## What you get for free

Whatever store you register (in-memory, EF, or custom) is automatically wrapped by `ValidatingSamlServiceProviderStore<T>`, which enforces: EntityId present, at least one ACS URL using HTTP-POST, at least one AllowedScopes entry, and positive lifetimes. Any SP that fails these checks is treated as non-existent, so validation errors never leak into the SAML response path.

If you'd rather not hand-roll a store, the EF Core route is:

```csharp
.AddConfigurationStore(options =>
{
    options.ConfigureDbContext = b => b.UseSqlServer(connectionString);
})
```

...then run `dotnet ef migrations add Update_DuendeIdentityServer_v8_0` to get the SAML SP tables.
