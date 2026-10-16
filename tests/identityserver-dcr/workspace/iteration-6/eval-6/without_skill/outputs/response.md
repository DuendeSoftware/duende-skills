# Custom IClientConfigurationStore with MongoDB

The interface is minimal; DCR only needs to add clients:

```csharp
namespace Duende.IdentityServer.Configuration.Stores;

public interface IClientConfigurationStore
{
    Task AddAsync(Client client);
}
```

Skeleton:
```csharp
using Duende.IdentityServer.Models;
using Duende.IdentityServer.Configuration.Stores;
using MongoDB.Bson.Serialization.Attributes;
using MongoDB.Driver;

public class MongoClientConfigurationStore : IClientConfigurationStore
{
    private readonly IMongoCollection<ClientDocument> _clients;

    public MongoClientConfigurationStore(IMongoDatabase db)
        => _clients = db.GetCollection<ClientDocument>("clients");

    public Task AddAsync(Client client)
        => _clients.InsertOneAsync(ClientDocument.From(client));
}

public class ClientDocument
{
    [BsonId] public string ClientId { get; set; } = default!;
    public string? ClientName { get; set; }
    public List<string> RedirectUris { get; set; } = new();
    public List<string> AllowedGrantTypes { get; set; } = new();
    public List<string> AllowedScopes { get; set; } = new();
    public List<string> SecretHashes { get; set; } = new();
    public bool RequirePkce { get; set; }

    public static ClientDocument From(Client c) => new()
    {
        ClientId = c.ClientId, ClientName = c.ClientName,
        RedirectUris = c.RedirectUris.ToList(),
        AllowedGrantTypes = c.AllowedGrantTypes.ToList(),
        AllowedScopes = c.AllowedScopes.ToList(),
        SecretHashes = c.ClientSecrets.Select(s => s.Value).ToList(),
        RequirePkce = c.RequirePkce
    };
}
```

Registration:
```csharp
builder.Services.AddSingleton<IMongoClient>(new MongoClient(cs));
builder.Services.AddSingleton(sp => sp.GetRequiredService<IMongoClient>().GetDatabase("idsrv"));
builder.Services.AddIdentityServerConfiguration();
builder.Services.AddTransient<IClientConfigurationStore, MongoClientConfigurationStore>();
```

This handles only DCR *writes*. IdentityServer must also read these clients at runtime, so implement `IClientStore` (`FindClientByIdAsync`) over the same collection and register it with `.AddClientStore<MongoClientStore>()`. Add a unique index on ClientId.
