# Upgrading Custom IClientStore from v7.4 to v8.0

When upgrading to IdentityServer v8, your custom `IClientStore` will need some changes to compile. Here's what I'd expect based on typical major version upgrades:

## 1. Update Target Framework

IdentityServer v8 likely targets a newer .NET version. Update your TFM:

```xml
<TargetFramework>net9.0</TargetFramework>
```

## 2. Update NuGet Packages

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```

## 3. Update IClientStore Implementation

The interface may have added a `CancellationToken` parameter to async methods, which is a common pattern in newer .NET libraries:

```csharp
public class CustomClientStore : IClientStore
{
    private readonly AppDbContext _db;
    public CustomClientStore(AppDbContext db) => _db = db;

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken cancellationToken = default)
    {
        return await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, cancellationToken);
    }
}
```

Check the release notes for any additional interface members that may have been added. You might need to implement new methods depending on what features v8 introduces.

After updating, rebuild and fix any remaining compilation errors based on the error messages.
