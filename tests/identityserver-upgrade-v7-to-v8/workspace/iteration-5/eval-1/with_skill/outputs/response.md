# Making your custom `IClientStore` compile under v8

There are three changes for the store itself, plus two project-file updates. In v8 the `IClientStore` interface gained a `CancellationToken` on every method and a new `GetAllClientsAsync` member.

## 1. Update the store implementation

```csharp
public class CustomClientStore : IClientStore
{
    private readonly AppDbContext _db;
    public CustomClientStore(AppDbContext db) => _db = db;

    // v8: CancellationToken is now the last parameter
    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct)
    {
        return await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, ct);
    }

    // v8: new required member — returns IAsyncEnumerable<Client>
    public IAsyncEnumerable<Client> GetAllClientsAsync(CancellationToken ct)
    {
        return _db.Clients.AsAsyncEnumerable();
    }
}
```

Notes:
- `FindClientByIdAsync` now takes `CancellationToken ct` as its final parameter — propagate it into your EF query rather than passing `CancellationToken.None`.
- `GetAllClientsAsync(CancellationToken ct)` is a **new required method** returning `IAsyncEnumerable<Client>`. It's used by Financial-Grade Security features and conformance reports; return all clients from your store.

## 2. Update the target framework

v8.0 requires **.NET 10**, so update the TFM before anything else:

```xml
<TargetFramework>net10.0</TargetFramework>
```

## 3. Update the Duende packages

Bump all `Duende.*` packages to the latest stable **8.x**. Check [NuGet](https://www.nuget.org/packages/Duende.IdentityServer) for the current version rather than hardcoding — at time of writing the latest stable is `8.0.1`:

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.1" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.1" />
```

That's everything the compiler needs for the `IClientStore`. Note that `CancellationToken` was added to *all* async store/service interfaces in v8, so if you have other custom stores (`IResourceStore`, `IPersistedGrantStore`, `IProfileService`, etc.) they'll need the same treatment.
