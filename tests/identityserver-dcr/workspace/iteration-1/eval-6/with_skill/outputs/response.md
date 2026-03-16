# Custom IClientConfigurationStore with MongoDB

To use MongoDB as the backing store for dynamically registered clients, implement the `IClientConfigurationStore` interface.

## MongoDB Client Configuration Store

```csharp
using Duende.IdentityServer.Configuration;
using Duende.IdentityServer.Models;
using MongoDB.Driver;

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientConfigurationStore(IMongoDatabase database)
    {
        _clients = database.GetCollection<ClientDocument>("dcr_clients");

        // Create index on ClientId for fast lookups
        var indexKeysDefinition = Builders<ClientDocument>.IndexKeys
            .Ascending(c => c.ClientId);
        _clients.Indexes.CreateOne(
            new CreateIndexModel<ClientDocument>(indexKeysDefinition,
                new CreateIndexOptions { Unique = true }));
    }

    public async Task AddAsync(Client client)
    {
        var document = ClientDocument.FromClient(client);
        // Hash secrets before storing — never store plaintext secrets
        foreach (var secret in document.ClientSecrets)
        {
            secret.Value = secret.Value.Sha256();
        }
        await _clients.InsertOneAsync(document);
    }

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var document = await _clients.Find(c => c.ClientId == clientId)
            .FirstOrDefaultAsync();
        return document?.ToClient();
    }

    public async Task UpdateAsync(Client client)
    {
        var document = ClientDocument.FromClient(client);
        var filter = Builders<ClientDocument>.Filter
            .Eq(c => c.ClientId, client.ClientId);
        await _clients.ReplaceOneAsync(filter, document);
    }

    public async Task DeleteAsync(string clientId)
    {
        var filter = Builders<ClientDocument>.Filter
            .Eq(c => c.ClientId, clientId);
        await _clients.DeleteOneAsync(filter);
    }
}

/// <summary>
/// MongoDB document representation of a Client.
/// Maps between the IdentityServer Client model and a MongoDB-friendly document.
/// </summary>
public class ClientDocument
{
    public string Id { get; set; } = null!;
    public string ClientId { get; set; } = null!;
    public string? ClientName { get; set; }
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> RedirectUris { get; set; } = new();
    public List<string> PostLogoutRedirectUris { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public List<SecretDocument> ClientSecrets { get; set; } = new();
    public bool RequirePkce { get; set; }
    public bool AllowOfflineAccess { get; set; }
    public int AccessTokenLifetime { get; set; }
    public DateTime Created { get; set; }
    public DateTime? Updated { get; set; }

    public static ClientDocument FromClient(Client client)
    {
        return new ClientDocument
        {
            ClientId = client.ClientId,
            ClientName = client.ClientName,
            AllowedGrantTypes = client.AllowedGrantTypes.ToList(),
            RedirectUris = client.RedirectUris.ToList(),
            PostLogoutRedirectUris = client.PostLogoutRedirectUris.ToList(),
            AllowedScopes = client.AllowedScopes.ToList(),
            ClientSecrets = client.ClientSecrets
                .Select(s => new SecretDocument { Value = s.Value, Type = s.Type })
                .ToList(),
            RequirePkce = client.RequirePkce,
            AllowOfflineAccess = client.AllowOfflineAccess,
            AccessTokenLifetime = client.AccessTokenLifetime,
            Created = DateTime.UtcNow
        };
    }

    public Client ToClient()
    {
        return new Client
        {
            ClientId = ClientId,
            ClientName = ClientName,
            AllowedGrantTypes = AllowedGrantTypes,
            RedirectUris = RedirectUris,
            PostLogoutRedirectUris = PostLogoutRedirectUris,
            AllowedScopes = AllowedScopes,
            ClientSecrets = ClientSecrets
                .Select(s => new Secret(s.Value, s.Type))
                .ToList(),
            RequirePkce = RequirePkce,
            AllowOfflineAccess = AllowOfflineAccess,
            AccessTokenLifetime = AccessTokenLifetime
        };
    }
}

public class SecretDocument
{
    public string Value { get; set; } = null!;
    public string? Type { get; set; }
}
```

## DI Registration

```csharp
// Register MongoDB
builder.Services.AddSingleton<IMongoClient>(sp =>
    new MongoClient("mongodb://localhost:27017"));
builder.Services.AddSingleton(sp =>
    sp.GetRequiredService<IMongoClient>().GetDatabase("IdentityServer"));

// Register the custom client configuration store
builder.Services.AddSingleton<IClientConfigurationStore, MongoClientConfigurationStore>();

// Add DCR configuration
builder.Services.AddIdentityServerConfiguration();
```

## Key Points

1. **`IClientConfigurationStore`** has four methods: `AddAsync`, `FindByClientIdAsync`, `UpdateAsync`, and `DeleteAsync`. All four must be implemented.

2. **Secret storage**: Client secrets must be stored securely. Always hash secrets before persisting them — never store plaintext secrets. The example above hashes secrets in `AddAsync` using `Sha256()`.

3. **Unique index on ClientId**: Ensures no duplicate client registrations.

4. **Thread safety**: MongoDB driver is thread-safe by default, making this suitable for concurrent DCR requests.
