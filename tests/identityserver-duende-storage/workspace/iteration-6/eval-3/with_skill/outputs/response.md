Duende Storage (preview) exposes .NET admin services registered by `AddConfigurationStorage()`. They are not HTTP endpoints, so put them behind your own authenticated/authorized/audited admin app. Create referenced scopes **before** the resources and clients that use them.

```csharp
using Duende.IdentityServer.Admin;
using Duende.IdentityServer.Admin.Clients;

public class ConfigProvisioner(
    IApiScopeAdmin scopeAdmin,
    IApiResourceAdmin resourceAdmin,
    IClientAdmin clientAdmin)
{
    public async Task CreateAsync(string clientSecretFromVault, CancellationToken ct)
    {
        // 1. Scope first
        var scope = await scopeAdmin.CreateAsync(new ApiScopeConfiguration
        {
            Name = "inventory.read",
            DisplayName = "Read inventory"
        }, ct);
        if (!scope.IsSuccess) throw new InvalidOperationException(string.Join("; ", scope.Errors));

        // 2. API resource referencing that scope
        var resource = await resourceAdmin.CreateAsync(new ApiResourceConfiguration
        {
            Name = "inventory-api",
            Scopes = ["inventory.read"]
        }, ct);
        if (!resource.IsSuccess) throw new InvalidOperationException(string.Join("; ", resource.Errors));

        // 3. client_credentials client
        var client = await clientAdmin.CreateAsync(new CreateClient
        {
            ClientId = "inventory-worker",
            ClientName = "Inventory worker",
            AllowedGrantTypes = ["client_credentials"],
            AllowedScopes = ["inventory.read"],
            ClientSecrets = [ new CreateClientSecret { PlaintextValue = clientSecretFromVault } ]
        }, ct);
        if (!client.IsSuccess) throw new InvalidOperationException(string.Join("; ", client.Errors));
    }
}
```
The secret is passed as plaintext, hashed on write and never returned. Take it from a vault. Create/update/delete return `SaveResult<TId>` (`IsSuccess`, `Id`, `Version`, `Errors`).

## Safe concurrent updates (optimistic concurrency)
`UpdateAsync` requires the `expectedVersion` from the preceding get (or create). If another admin saved in between, the update fails with a version conflict instead of silently overwriting.

```csharp
public async Task<bool> RenameScopeAsync(Guid id, string newDisplayName, CancellationToken ct)
{
    var got = await scopeAdmin.GetAsync(id, ct);       // GetResult<ApiScopeConfiguration>
    if (!got.Found) return false;                      // not found

    var item = got.Item;
    item.DisplayName = newDisplayName;

    var result = await scopeAdmin.UpdateAsync(id, item, got.Version, ct);
    if (!result.IsSuccess)
    {
        // Inspect result.Errors: version conflict -> reload and ask the admin to
        // re-apply (or re-read and retry); validation / duplicate-name / not-found
        // -> surface the error.
        return false;
    }
    return true;
}
```
Handle all four error kinds: validation, duplicate-name, not-found and version-conflict. On a conflict, re-get, show the admin the latest values, and let them retry, rather than blind-retrying with the new version.

If you search with `QueryAsync`, filters can be *contains* matches, so compare the exact name on the results before acting.
