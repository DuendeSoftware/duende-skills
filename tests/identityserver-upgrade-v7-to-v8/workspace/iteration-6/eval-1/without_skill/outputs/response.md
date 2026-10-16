# Custom `IClientStore` when moving to IdentityServer v8

I can't verify v8's exact API surface from memory, so check the official upgrade guide and the compiler output. Here is what I'd expect.

## What to change

1. **Bump packages** in the csproj. v8 targets newer .NET, so you will likely also need to move off `net8.0`.
```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```
2. **Check the `IClientStore` signature.** In v7 it is `Task<Client?> FindClientByIdAsync(string clientId)`. Your implementation already matches that, so it may compile unchanged. If v8 adds a `CancellationToken` parameter, as many Duende interfaces have been moving to, update it like this:
```csharp
public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct = default)
    => await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, ct);
```
3. **Entity types.** `_db.Clients` uses the `Client` model directly. That is fragile. Map from your own entity to `Duende.IdentityServer.Models.Client` instead, because the model may have new or changed properties.
4. **Other custom services in your file.** `IClock` and `ICache<Client>` may also have changed, so rebuild and fix each error in turn.

Then run `dotnet build` and work through the errors.
