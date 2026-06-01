# Moving SAML Service Provider Store to Production

## Why Not In-Memory?

**In-memory stores are for development only.** They don't persist across restarts, can't be shared across nodes, and require redeployment to change SP registrations. For production, use either the built-in EF Core configuration store or implement a custom `ISamlServiceProviderStore`.

## Option 1: EF Core Configuration Store (Recommended)

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddConfigurationStore(options =>
    {
        options.ConfigureDbContext = b =>
            b.UseSqlServer(connectionString);
    });
```

Run migrations: `dotnet ef migrations add Update_DuendeIdentityServer_v8_0`

## Option 2: Custom Store with Caching

Implement `ISamlServiceProviderStore`:

```csharp
public class MySamlSpStore : ISamlServiceProviderStore
{
    private readonly IDbConnectionFactory _db;

    public MySamlSpStore(IDbConnectionFactory db)
    {
        _db = db;
    }

    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken ct)
    {
        await using var conn = await _db.CreateConnectionAsync(ct);
        var sp = await conn.QuerySingleOrDefaultAsync<SamlServiceProviderEntity>(
            "SELECT * FROM SamlServiceProviders WHERE EntityId = @EntityId",
            new { EntityId = entityId });

        return sp is null ? null : MapToModel(sp);
    }

    public async IAsyncEnumerable<SamlServiceProvider> GetAllSamlServiceProvidersAsync(
        [EnumeratorCancellation] CancellationToken ct)
    {
        await using var conn = await _db.CreateConnectionAsync(ct);
        var reader = await conn.ExecuteReaderAsync(
            "SELECT * FROM SamlServiceProviders", ct);

        while (await reader.ReadAsync(ct))
        {
            yield return MapFromReader(reader);
        }
    }

    private SamlServiceProvider MapToModel(SamlServiceProviderEntity entity)
    {
        // Map from your entity to SamlServiceProvider model
        return new SamlServiceProvider
        {
            EntityId = entity.EntityId,
            DisplayName = entity.DisplayName,
            // ... map remaining properties
        };
    }
}
```

## Register with Caching

```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddSamlServiceProviderStore<MySamlSpStore>()
    .AddSamlServiceProviderStoreCache<MySamlSpStore>();
```

The `AddSamlServiceProviderStoreCache<T>()` adds a `HybridCache` layer on top of your store, reducing database calls for frequently accessed SPs.

## Validation

All stores are automatically wrapped with `ValidatingSamlServiceProviderStore<T>` that checks:
- EntityId is required
- At least one ACS URL with HTTP-POST binding
- At least one entry in AllowedScopes
- Positive lifetime values

Invalid SPs are treated as non-existent (returns null).
