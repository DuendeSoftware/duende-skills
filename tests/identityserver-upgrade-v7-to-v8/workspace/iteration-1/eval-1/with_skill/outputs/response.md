# Upgrading Custom IClientStore from v7.4 to v8.0

To make your custom `IClientStore` compile with IdentityServer v8, you need three changes:

## 1. Update Target Framework

```xml
<!-- IdentityServer.csproj -->
<TargetFramework>net10.0</TargetFramework>
```

## 2. Update Package Version

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```

## 3. Update Your IClientStore Implementation

The `IClientStore` interface has two breaking changes in v8:

1. `FindClientByIdAsync` now requires a `CancellationToken` parameter
2. A new method `GetAllClientsAsync` must be implemented

```csharp
public class CustomClientStore : IClientStore
{
    private readonly AppDbContext _db;
    public CustomClientStore(AppDbContext db) => _db = db;

    // ✅ Added CancellationToken parameter
    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct)
    {
        return await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, ct);
    }

    // ✅ New required method in v8
    public async Task<IReadOnlyCollection<Client>> GetAllClientsAsync(CancellationToken ct)
    {
        return await _db.Clients.ToListAsync(ct);
    }
}
```

The `GetAllClientsAsync` method is used by Financial-Grade Security features and conformance reports. It must return all clients from your store.
