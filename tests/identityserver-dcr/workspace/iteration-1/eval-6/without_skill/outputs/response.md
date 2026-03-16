# Custom MongoDB Client Store for DCR

To store dynamically registered clients in MongoDB instead of SQL Server, you'll need to implement the store interface that Duende IdentityServer uses for DCR.

## Interface Implementation

```csharp
using Duende.IdentityServer.Models;
using MongoDB.Driver;

public interface IClientConfigurationStore
{
    Task AddAsync(Client client);
    Task<Client?> FindByClientIdAsync(string clientId);
    Task UpdateAsync(Client client);
    Task DeleteAsync(string clientId);
}

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientConfigurationStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<ClientDocument>("clients");
    }

    public async Task AddAsync(Client client)
    {
        var doc = MapToDocument(client);
        await _clients.InsertOneAsync(doc);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var doc = await _clients.Find(c => c.ClientId == clientId)
            .FirstOrDefaultAsync();
        return doc != null ? MapToClient(doc) : null;
    }

    public async Task UpdateAsync(Client client)
    {
        var doc = MapToDocument(client);
        await _clients.ReplaceOneAsync(
            c => c.ClientId == client.ClientId, doc);
    }

    public async Task DeleteAsync(string clientId)
    {
        await _clients.DeleteOneAsync(c => c.ClientId == clientId);
    }

    private ClientDocument MapToDocument(Client client)
    {
        return new ClientDocument
        {
            ClientId = client.ClientId,
            ClientName = client.ClientName,
            AllowedGrantTypes = client.AllowedGrantTypes.ToList(),
            RedirectUris = client.RedirectUris.ToList(),
            AllowedScopes = client.AllowedScopes.ToList(),
            RequirePkce = client.RequirePkce
        };
    }

    private Client MapToClient(ClientDocument doc)
    {
        return new Client
        {
            ClientId = doc.ClientId,
            ClientName = doc.ClientName,
            AllowedGrantTypes = doc.AllowedGrantTypes,
            RedirectUris = doc.RedirectUris,
            AllowedScopes = doc.AllowedScopes,
            RequirePkce = doc.RequirePkce
        };
    }
}

public class ClientDocument
{
    public string ClientId { get; set; } = null!;
    public string? ClientName { get; set; }
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> RedirectUris { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public bool RequirePkce { get; set; }
}
```

## Registration

```csharp
builder.Services.AddSingleton<IMongoClient>(
    new MongoClient("mongodb://localhost:27017"));
builder.Services.AddSingleton(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase("IdentityServer"));

builder.Services.AddScoped<IClientConfigurationStore, MongoClientConfigurationStore>();
```

## Notes

- Make sure to hash client secrets before storing them
- The store should be registered in DI so that the DCR middleware can use it
- You may want to add indexes on the `ClientId` field for performance
