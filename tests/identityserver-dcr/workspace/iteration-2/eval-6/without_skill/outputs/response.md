To implement a custom client store backed by MongoDB, you'll need to create a class that implements a client store interface. Here's a skeleton:

### MongoDB Client Store

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Stores;
using MongoDB.Driver;

public class MongoDbClientStore : IClientStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoDbClientStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<ClientDocument>("clients");
    }

    public async Task<Client?> FindClientByIdAsync(string clientId)
    {
        var filter = Builders<ClientDocument>.Filter.Eq(c => c.ClientId, clientId);
        var doc = await _clients.Find(filter).FirstOrDefaultAsync();
        return doc?.ToClient();
    }

    public async Task AddClientAsync(ClientDocument client)
    {
        await _clients.InsertOneAsync(client);
    }

    public async Task UpdateClientAsync(string clientId, ClientDocument client)
    {
        var filter = Builders<ClientDocument>.Filter.Eq(c => c.ClientId, clientId);
        await _clients.ReplaceOneAsync(filter, client);
    }

    public async Task DeleteClientAsync(string clientId)
    {
        var filter = Builders<ClientDocument>.Filter.Eq(c => c.ClientId, clientId);
        await _clients.DeleteOneAsync(filter);
    }
}

public class ClientDocument
{
    public string ClientId { get; set; }
    public string ClientName { get; set; }
    public List<string> AllowedGrantTypes { get; set; }
    public List<string> RedirectUris { get; set; }
    public string ClientSecretHash { get; set; }

    public Client ToClient()
    {
        return new Client
        {
            ClientId = ClientId,
            ClientName = ClientName,
            AllowedGrantTypes = AllowedGrantTypes,
            RedirectUris = RedirectUris
        };
    }
}
```

### Register in DI

```csharp
builder.Services.AddSingleton<IClientStore, MongoDbClientStore>();
```

### Notes

- The `IClientStore` interface from IdentityServer only has `FindClientByIdAsync`. The add/update/delete methods are custom additions for DCR support.
- Make sure to hash client secrets before storing them in MongoDB
- Consider adding indexes on the `ClientId` field
- You may need to implement additional interfaces depending on what IdentityServer requires for DCR
