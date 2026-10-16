# Custom `IClientConfigurationStore` backed by MongoDB

## The interface
Per the DCR reference, a custom store implements:

```csharp
public interface IClientConfigurationStore
{
    Task AddAsync(Client client);
    Task<Client?> FindByClientIdAsync(string clientId);
    Task UpdateAsync(Client client);
    Task DeleteAsync(string clientId);
}
```

## Skeleton
```csharp
using Duende.IdentityServer.Models;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientConfigurationStore(IMongoDatabase database)
        => _clients = database.GetCollection<ClientDocument>("dynamic_clients");

    public async Task AddAsync(Client client)
        => await _clients.InsertOneAsync(ClientDocument.FromClient(client));

    public async Task<Client?> FindByClientIdAsync(string clientId)
    {
        var doc = await _clients.Find(c => c.ClientId == clientId).FirstOrDefaultAsync();
        return doc?.ToClient();
    }

    public async Task UpdateAsync(Client client)
        => await _clients.ReplaceOneAsync(c => c.ClientId == client.ClientId,
                                          ClientDocument.FromClient(client));

    public async Task DeleteAsync(string clientId)
        => await _clients.DeleteOneAsync(c => c.ClientId == clientId);
}

public class ClientDocument
{
    [BsonId] public string ClientId { get; set; } = default!;
    public string? ClientName { get; set; }
    public List<string> RedirectUris { get; set; } = new();
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public List<string> SecretHashes { get; set; } = new();   // hashed only
    public bool RequirePkce { get; set; }

    public static ClientDocument FromClient(Client c) => new()
    {
        ClientId = c.ClientId,
        ClientName = c.ClientName,
        RedirectUris = c.RedirectUris.ToList(),
        AllowedGrantTypes = c.AllowedGrantTypes.ToList(),
        AllowedScopes = c.AllowedScopes.ToList(),
        SecretHashes = c.ClientSecrets.Select(s => s.Value).ToList(),
        RequirePkce = c.RequirePkce
    };

    public Client ToClient()
    {
        var c = new Client
        {
            ClientId = ClientId, ClientName = ClientName, RequirePkce = RequirePkce,
            AllowedGrantTypes = AllowedGrantTypes, RedirectUris = RedirectUris, AllowedScopes = AllowedScopes
        };
        foreach (var h in SecretHashes) c.ClientSecrets.Add(new Secret { Value = h });
        return c;
    }
}
```

## Registration
```csharp
builder.Services.AddSingleton<IMongoClient>(new MongoClient(builder.Configuration["Mongo:ConnectionString"]));
builder.Services.AddSingleton(sp => sp.GetRequiredService<IMongoClient>().GetDatabase("idsrv"));

builder.Services.AddIdentityServerConfiguration();
builder.Services.AddTransient<IClientConfigurationStore, MongoClientConfigurationStore>();
```

## Notes
- Dynamically registered clients receive generated secrets: store only the **hashed** value, never plaintext.
- `IClientConfigurationStore` serves DCR; IdentityServer itself must also be able to resolve these clients at runtime, so back `IClientStore` with the same collection (see the `identityserver-stores` patterns).
- Add a unique index on `ClientId`.
- Remember the endpoint still needs an authorization policy, and the feature needs a Business Edition license.
