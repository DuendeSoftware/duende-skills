# Production SAML service provider stores

In-memory is development-only. For production use one of:

1. **EF Core configuration store (recommended)**
```csharp
builder.Services.AddIdentityServer()
    .AddSaml()
    .AddConfigurationStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs))
    .AddOperationalStore(o => o.ConfigureDbContext = b => b.UseSqlServer(cs));
```
Run the migration: `dotnet ef migrations add Update_DuendeIdentityServer_v8_0`. `AddOperationalStore()` also registers EF `ISamlSigninStateStore` and `ISamlLogoutSessionStore`, which you need for multi-node.
2. **Duende Storage (preview)**: `AddStorage` + `AddConfigurationStorage()`/`AddOperationalStorage()`, administered with `ISamlServiceProviderAdmin`.
3. **Custom `ISamlServiceProviderStore`** (below).

## Custom store with caching

```csharp
public class MySamlSpStore(AppDbContext db) : ISamlServiceProviderStore
{
    public async Task<SamlServiceProvider?> FindByEntityIdAsync(
        string entityId, CancellationToken ct)
    {
        var row = await db.SamlSps.AsNoTracking()
            .SingleOrDefaultAsync(x => x.EntityId == entityId, ct);
        return row?.ToModel();
    }

    public async IAsyncEnumerable<SamlServiceProvider> GetAllSamlServiceProvidersAsync(
        [EnumeratorCancellation] CancellationToken ct)
    {
        await foreach (var row in db.SamlSps.AsNoTracking().AsAsyncEnumerable().WithCancellation(ct))
            yield return row.ToModel();
    }
}
```

Registration — the built-in HybridCache layer does the caching; you don't write your own:

```csharp
builder.Services
    .AddIdentityServer(options =>
    {
        options.Caching.SamlServiceProviderStoreExpiration = TimeSpan.FromMinutes(30); // default 15
    })
    .AddSaml()
    .AddSamlServiceProviderStore<MySamlSpStore>()
    .AddSamlServiceProviderStoreCache<MySamlSpStore>();
```

(Use `AddSamlServiceProviderStoreCache<T>()` alone, as in the docs, to register store + cache; adjust per your DI setup.) Configure a HybridCache with a distributed (e.g. Redis) L2 for multi-node.

## Validation
Every store is automatically wrapped by `ValidatingSamlServiceProviderStore<T>`: EntityId required, ≥1 ACS URL (HTTP-POST only), ≥1 AllowedScopes, positive lifetimes. **Invalid SPs are treated as non-existent**, so a "SP not found" error may really be a validation failure. Add custom rules via `ISamlServiceProviderConfigurationValidator`.

## Production checklist
- `ISamlSigninStateStore` + `ISamlLogoutSessionStore` on a shared store (EF/Redis).
- X.509 signing cert with private key (or Automatic Key Management).
- Keep caching in mind: changes to an SP show up after the cache expires.
- Don't enable `AllowIdpInitiated` globally; avoid `DoNotSign`.
