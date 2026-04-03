Here's a custom `IClientConfigurationStore` backed by MongoDB for storing dynamically registered clients.

### IClientConfigurationStore Interface

The `IClientConfigurationStore` interface defines four methods for managing dynamically registered clients:

```csharp
public interface IClientConfigurationStore
{
    Task AddAsync(Client client);
    Task<Client?> FindByClientIdAsync(string clientId);
    Task UpdateAsync(Client client);
    Task DeleteAsync(string clientId);
}
```

### MongoDB Implementation

```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Configuration;
using MongoDB.Driver;
using MongoDB.Bson.Serialization.Attributes;

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<MongoClientDocument> _clients;

    public MongoClientConfigurationStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<MongoClientDocument>("dcr_clients");
        
        // Create a unique index on ClientId
        var indexKeys = Builders<MongoClientDocument>.IndexKeys.Ascending(x => x.ClientId);
        _clients.Indexes.CreateOne(new CreateIndexModel<MongoClientDocument>(
            indexKeys, new CreateIndexOptions { Unique = true }));
    }

    public async Task AddAsync(Client client)
    {
        var document = MapToDocument(client);
        await _clients.InsertOneAsync(document);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var filter = Builders<MongoClientDocument>.Filter.Eq(x => x.ClientId, clientId);
        var document = await _clients.Find(filter).FirstOrDefaultAsync();
        
        if (document == null)
            return null;

        return MapToClient(document);
    }

    public async Task UpdateAsync(Client client)
    {
        var filter = Builders<MongoClientDocument>.Filter.Eq(x => x.ClientId, client.ClientId);
        var document = MapToDocument(client);
        await _clients.ReplaceOneAsync(filter, document);
    }

    public async Task DeleteAsync(string clientId)
    {
        var filter = Builders<MongoClientDocument>.Filter.Eq(x => x.ClientId, clientId);
        await _clients.DeleteOneAsync(filter);
    }

    private MongoClientDocument MapToDocument(Client client)
    {
        return new MongoClientDocument
        {
            ClientId = client.ClientId,
            ClientName = client.ClientName,
            AllowedGrantTypes = client.AllowedGrantTypes.ToList(),
            RedirectUris = client.RedirectUris.ToList(),
            AllowedScopes = client.AllowedScopes.ToList(),
            RequirePkce = client.RequirePkce,
            // IMPORTANT: Client secrets should already be hashed by IdentityServer
            // before being passed to the store. Store the hashed values, never plaintext.
            ClientSecrets = client.ClientSecrets.Select(s => new MongoSecretDocument
            {
                Type = s.Type,
                Value = s.Value, // This should be a hashed value
                Description = s.Description,
                Expiration = s.Expiration
            }).ToList(),
            Created = DateTime.UtcNow
        };
    }

    private Client MapToClient(MongoClientDocument document)
    {
        return new Client
        {
            ClientId = document.ClientId,
            ClientName = document.ClientName,
            AllowedGrantTypes = document.AllowedGrantTypes,
            RedirectUris = document.RedirectUris,
            AllowedScopes = document.AllowedScopes,
            RequirePkce = document.RequirePkce,
            ClientSecrets = document.ClientSecrets.Select(s => new Secret
            {
                Type = s.Type,
                Value = s.Value,
                Description = s.Description,
                Expiration = s.Expiration
            }).ToList()
        };
    }
}

// MongoDB document model
public class MongoClientDocument
{
    [BsonId]
    public string ClientId { get; set; } = string.Empty;
    public string? ClientName { get; set; }
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> RedirectUris { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public bool RequirePkce { get; set; }
    public List<MongoSecretDocument> ClientSecrets { get; set; } = new();
    public DateTime Created { get; set; }
}

public class MongoSecretDocument
{
    public string? Type { get; set; }
    public string? Value { get; set; }
    public string? Description { get; set; }
    public DateTime? Expiration { get; set; }
}
```

### Register in DI

```csharp
// Program.cs
builder.Services.AddSingleton<IMongoDatabase>(sp =>
{
    var client = new MongoClient(builder.Configuration.GetConnectionString("MongoDB"));
    return client.GetDatabase("identity");
});

builder.Services.AddTransient<IClientConfigurationStore, MongoClientConfigurationStore>();
```

### Security Note

**Client secrets must be stored securely (hashed, not plaintext).** The DCR flow in IdentityServer hashes client secrets before passing them to the store. Your implementation should never store or log the raw secret values. The `Value` property in `ClientSecrets` should contain SHA-256 hashed values by the time they reach your store.
