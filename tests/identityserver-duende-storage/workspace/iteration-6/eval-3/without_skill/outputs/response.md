I can't confirm a "Duende Storage" API, so this uses the EF Core configuration store (`ConfigurationDbContext`) with the model mappers. Concurrency control is the part you'd add yourself.

```csharp
using Duende.IdentityServer.EntityFramework.DbContexts;
using Duende.IdentityServer.EntityFramework.Mappers;
using Duende.IdentityServer.Models;
using Microsoft.EntityFrameworkCore;

public class Admin(ConfigurationDbContext db)
{
    public async Task CreateAsync()
    {
        db.ApiScopes.Add(new ApiScope("orders.read", "Read orders").ToEntity());
        db.ApiResources.Add(new ApiResource("orders", "Orders API") { Scopes = { "orders.read" } }.ToEntity());
        db.Clients.Add(new Client
        {
            ClientId = "machine",
            AllowedGrantTypes = GrantTypes.ClientCredentials,
            ClientSecrets = { new Secret("s3cret".Sha256()) },
            AllowedScopes = { "orders.read" }
        }.ToEntity());
        await db.SaveChangesAsync();
    }

    public async Task UpdateScopeAsync(string name, string newDisplay)
    {
        var scope = await db.ApiScopes.SingleAsync(s => s.Name == name);
        scope.DisplayName = newDisplay;
        try { await db.SaveChangesAsync(); }
        catch (DbUpdateConcurrencyException) { /* reload and tell the admin */ }
    }
}
```
EF's built-in entities don't have a concurrency token on `ApiScope`, as far as I know. For optimistic concurrency, you would need a row-version column (`[Timestamp]` or `IsRowVersion()`) via a custom model/migration, or compare a `Updated` timestamp in the `WHERE` clause (`ExecuteUpdateAsync(... Where(s => s.Id == id && s.Updated == expected))`). Then catch the conflict and ask the admin to reload.
