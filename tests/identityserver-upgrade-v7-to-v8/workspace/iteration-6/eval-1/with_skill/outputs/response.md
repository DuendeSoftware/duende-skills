# Custom `IClientStore` for IdentityServer v8

v8 requires **.NET 10**, and every v7 compile break is mechanical. For your store, three things change.

## 1. Project file
```xml
<TargetFramework>net10.0</TargetFramework>
<PackageReference Include="Duende.IdentityServer" Version="8.0.1" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.1" />
```
Use the latest stable 8.x from NuGet, and also update `Microsoft.EntityFrameworkCore.SqlServer` to match .NET 10.

## 2. `CancellationToken` on every method
```csharp
public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct)
    => await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, ct);
```
Propagate `ct`. Don't pass `CancellationToken.None`.

## 3. New required method: `GetAllClientsAsync`
```csharp
public async IAsyncEnumerable<Client> GetAllClientsAsync(
    [EnumeratorCancellation] CancellationToken ct)
{
    await foreach (var c in _db.Clients.AsAsyncEnumerable().WithCancellation(ct))
        yield return c;
}
```
Financial-grade security features and conformance reports use it. It is rarely called, but it must exist for the class to compile.

## Full v8 store
```csharp
public class CustomClientStore : IClientStore
{
    private readonly AppDbContext _db;
    public CustomClientStore(AppDbContext db) => _db = db;

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct)
        => await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, ct);

    public async IAsyncEnumerable<Client> GetAllClientsAsync(
        [EnumeratorCancellation] CancellationToken ct)
    {
        await foreach (var c in _db.Clients.AsAsyncEnumerable().WithCancellation(ct))
            yield return c;
    }
}
```
Add `using System.Runtime.CompilerServices;`. Nullable reference types are now on across the v8 assemblies, so fix any new warnings.

## Related items in your Program.cs
- `IClock` → `TimeProvider`.
- `ICache<Client>` → keyed `HybridCache`.
- Run the EF migrations for the `ConfigurationDbContext` and `PersistedGrantDbContext`, even if you don't use SAML.
