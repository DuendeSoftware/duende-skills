# Custom MongoDB Client Store with Caching

## MongoClientStore Implementation

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public class MongoClientStore : IClientStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<ClientDocument>("clients");
    }

    // v7 — no CancellationToken parameter
    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var doc = await _clients.Find(c => c.ClientId == clientId).FirstOrDefaultAsync();
        return doc?.ToClient();
    }
}

public class ClientDocument
{
    public string ClientId { get; set; } = default!;
    public string ClientName { get; set; } = default!;
    public List<string> AllowedGrantTypes { get; set; } = [];
    public List<string> AllowedScopes { get; set; } = [];
    public List<string> RedirectUris { get; set; } = [];
    public List<SecretDocument> ClientSecrets { get; set; } = [];
    // ... other properties

    public Client ToClient() => new Client
    {
        ClientId = ClientId,
        ClientName = ClientName,
        AllowedGrantTypes = AllowedGrantTypes,
        AllowedScopes = AllowedScopes,
        RedirectUris = RedirectUris,
        ClientSecrets = ClientSecrets.Select(s => new Secret(s.Value)).ToList()
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

## Key Points

- **`AddClientStore<MongoClientStore>()`** — Registers the custom store
- **`AddInMemoryCaching()`** — Registers the `ICache<T>` infrastructure needed for store caching
- **`AddClientStoreCache<MongoClientStore>()`** — Wraps the store with a caching decorator
- **`ClientStoreExpiration = TimeSpan.FromMinutes(5)`** — Cache entries expire after 5 minutes
- **No CancellationToken** — v7 store interfaces don't include CancellationToken parameters