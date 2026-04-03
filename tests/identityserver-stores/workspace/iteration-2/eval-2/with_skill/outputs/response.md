# Custom MongoDB Client Store with Caching (IdentityServer v7)

## Custom IClientStore Implementation

```csharp
// MongoClientStore.cs
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

    // Note: No CancellationToken parameter — targeting IdentityServer v7
    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var document = await _clients
            .Find(c => c.ClientId == clientId)
            .FirstOrDefaultAsync();

        return document?.ToIdentityServerClient();
    }
}

// Document model for MongoDB
public class ClientDocument
{
    public string ClientId { get; set; } = default!;
    public string ClientName { get; set; } = default!;
    public List<string> AllowedGrantTypes { get; set; } = [];
    public List<string> AllowedScopes { get; set; } = [];
    public List<string> RedirectUris { get; set; } = [];
    // ... map additional fields as needed

    public Client ToIdentityServerClient()
    {
        return new Client
        {
            ClientId = ClientId,
            ClientName = ClientName,
            AllowedGrantTypes = AllowedGrantTypes,
            AllowedScopes = AllowedScopes,
            RedirectUris = RedirectUris
        };
    }
}
```

## Registration with Caching

```csharp
// Program.cs
builder.Services.AddIdentityServer(options =>
{
    // Set cache expiration to 5 minutes
    options.Caching.ClientStoreExpiration = TimeSpan.FromMinutes(5);
})
    .AddClientStore<MongoClientStore>()
    .AddInMemoryCaching()
    .AddClientStoreCache<MongoClientStore>();
```

## Key Points

- `FindClientByIdAsync` has **no CancellationToken** parameter because this targets IdentityServer v7 (CancellationToken was added in v8)
- `AddClientStore<MongoClientStore>()` registers the custom store
- `AddInMemoryCaching()` registers the `ICache<T>` implementation needed by the caching decorator
- `AddClientStoreCache<MongoClientStore>()` wraps the store with a caching decorator
- Cache expiration is configured via `options.Caching.ClientStoreExpiration`
