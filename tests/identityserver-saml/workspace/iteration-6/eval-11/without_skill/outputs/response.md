# Extended properties on SAML service providers

Short answer: I believe it's possible in principle, but I can't confirm it for SAML with certainty.

In Duende IdentityServer, `Client` has a `Properties` dictionary that's persisted by the EF stores and is available in customization points (e.g. via `client.Properties["owner_team"]`). If the SAML service provider model offers a similar dictionary, then with Duende's EntityFramework store it would be persisted and you could read it in a custom claims/assertion-building service.

Caveats:
- The SAML service provider entity may not have a `Properties` bag; if not, you'd need a custom store with your own extra column/table keyed by EntityId and look it up in your assertion-building code.
- Your current Program.cs uses in-memory config and has no SAML registered, so first call `.AddSaml()` and register the SP.
- Check whether the store supports the property at all, then read it in a custom service that builds the assertion attributes:

```csharp
public class OwnerTeamAttributes(ISamlServiceProviderStore store)
{
    public async Task<string?> GetOwnerTeam(string entityId)
    {
        var sp = await store.FindByEntityIdAsync(entityId);
        return sp?.Properties.TryGetValue("owner_team", out var v) == true ? v : null;
    }
}
```

Test it against your version; names above are approximate.
