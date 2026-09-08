# Upgrading a custom `IClientStore` from v7.4 to v8.0

I don't have the exact v8.0 breaking-change list memorized, so treat the specifics below as a starting point and verify against the official Duende migration guide for 7.x → 8.0. That said, here's the general approach.

## 1. Update the package references

Bump your Duende packages to 8.0 in the `.csproj`:

```xml
<PackageReference Include="Duende.IdentityServer" Version="8.0.0" />
<PackageReference Include="Duende.IdentityServer.EntityFramework" Version="8.0.0" />
```

Check NuGet for the exact latest patch version.

## 2. Update the target framework if needed

Newer major versions of IdentityServer typically raise the minimum .NET version. Check the release notes for the required TFM (likely a recent LTS such as `net8.0` or newer) and update:

```xml
<TargetFramework>net8.0</TargetFramework>
```

## 3. Fix the `IClientStore` implementation

The most common source of compile errors when a store interface changes is a signature mismatch. Once you reference v8, the compiler will tell you exactly which members no longer match. Rebuild and let the errors guide you.

A common modernization in ASP.NET Core interfaces is the addition of a `CancellationToken` parameter, so you may need:

```csharp
public class CustomClientStore : IClientStore
{
    private readonly AppDbContext _db;
    public CustomClientStore(AppDbContext db) => _db = db;

    public async Task<Client?> FindClientByIdAsync(string clientId, CancellationToken ct = default)
    {
        return await _db.Clients.FirstOrDefaultAsync(c => c.ClientId == clientId, ct);
    }
}
```

## 4. Rebuild and resolve remaining errors

Run `dotnet build` and address each interface member the compiler flags. If v8 added new required members to `IClientStore`, you'll need to implement them — the build output will name them explicitly.

I'd strongly recommend cross-referencing the official Duende 8.0 upgrade documentation, since custom store contracts are exactly the kind of thing that changes between major versions and I can't confirm the full set of changes from memory.
