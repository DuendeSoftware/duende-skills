# Custom MongoDB IClientStore with Caching

## MongoClientStore Implementation

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public sealed class MongoClientStore : IClientStore
{
    private readonly IMongoDatabase _database;

    public MongoClientStore(IMongoDatabase database)
    {
        _database = database;
    }

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var collection = _database.GetCollection<ClientDocument>("clients");
        var doc = await collection.Find(c => c.ClientId == clientId).FirstOrDefaultAsync();
        return doc?.ToIdentityServerClient();
    }
}

public class ClientDocument
{
    public string ClientId { get; set; } = default!;
    public string ClientName { get; set; } = default!;
    public IList<string> AllowedGrantTypes { get; set; } = new List<string>();
    public IList<string> AllowedScopes { get; set; } = new List<string>();
    public IList<string> RedirectUris { get; set; } = new List<string>();
    public IList<string> ClientSecrets { get; set; } = new List<string>();

    public Client ToIdentityServerClient() => new Client
    {
        ClientId = ClientId,
        ClientName = ClientName,
        AllowedGrantTypes = AllowedGrantTypes,
        AllowedScopes = AllowedScopes,
        RedirectUris = RedirectUris,
        ClientSecrets = ClientSecrets.Select(s => new Secret(s.Sha256())).ToList()
    };
}
```

## Registration with Caching

```csharp
builder.Services.AddIdentityServer(options =>
{
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
})
    .AddClientStore<MongoClientStore>()
    .AddInMemoryCaching()
    .AddClientStoreCache<MongoClientStore>();
```

**Key points:**
- `MongoClientStore` implements `IClientStore` with a constructor accepting `IMongoDatabase`.
- `FindClientByIdAsync` does NOT include a `CancellationToken` parameter (v7 target).
- Registered via `AddClientStore<MongoClientStore>()`.
- `AddInMemoryCaching()` registers `ICache<T>` and `AddClientStoreCache<MongoClientStore>()` wraps the store.
- `ClientStoreExpiration` is set to 5 minutes.
